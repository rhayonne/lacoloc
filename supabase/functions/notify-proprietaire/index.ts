// Notifie l'administrateur qu'un compte propriétaire vient d'être créé.
//
// ── Pourquoi cette fonction reste PUBLIQUE (`verify_jwt: false`) ──────────────
// Elle est appelée juste après `auth.signUp`, et l'inscription publique passe
// par une confirmation d'e-mail (`emailRedirectTo`) : à cet instant il n'y a
// **pas encore de session**, donc pas de JWT à vérifier. Exiger un jeton
// supprimerait la notification au lieu de la sécuriser.
//
// ── Ce qui la protège malgré tout ────────────────────────────────────────────
// 1. **Le corps de la requête n'est pas cru.** Le nom et le téléphone sont
//    relus depuis `Users_Client` (service role) à partir de l'e-mail : ce qui
//    part dans le mail vient du compte, pas de l'appelant.
// 2. **Il faut un compte réellement créé à l'instant** (fenêtre de 15 min).
//    Sans cela, n'importe qui pouvait déclencher un envoi en boucle vers la
//    boîte de l'admin ; désormais il faudrait d'abord créer un vrai compte,
//    ce que GoTrue limite déjà.
// 3. **Tout est échappé** avant d'entrer dans le HTML — auparavant `fullName`
//    et `note` étaient interpolés bruts, donc injectables dans la boîte de
//    l'administrateur.
//
// ── Envoi : SMTP, comme le reste du projet ───────────────────────────────────
// Cette fonction utilisait **Resend** (`RESEND_API_KEY`), seule de tout le
// projet — et ce secret n'a jamais été renseigné, donc aucune notification
// n'est jamais partie. Elle passe maintenant par le **même SMTP** que
// `invite-locataire` et `notify-edl` (`SMTP_HOST/PORT/USER/PASS/FROM`), déjà
// configuré : plus aucun compte tiers à créer.
//
// Destinataire : `FORM_NEW_PROPRIETAIRE` si le secret est défini, sinon
// l'e-mail du **super admin** lu en base — de sorte que la notification
// fonctionne sans configuration supplémentaire.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import nodemailer from 'npm:nodemailer@6';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

/// Fenêtre pendant laquelle une inscription est considérée « fraîche ».
const FENETRE_MINUTES = 15;

/// Longueur max du champ libre repris dans le mail.
const MAX_NOTE = 2000;

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function esc(value: unknown): string {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

async function sendEmail(
  to: string,
  subject: string,
  html: string,
): Promise<{ sent: boolean; smtpError?: string }> {
  const host = Deno.env.get('SMTP_HOST') ?? '';
  const port = parseInt(Deno.env.get('SMTP_PORT') ?? '587', 10);
  const user = Deno.env.get('SMTP_USER') ?? '';
  const pass = Deno.env.get('SMTP_PASS') ?? '';
  const from = Deno.env.get('SMTP_FROM') ?? `HabitaFrance <${user}>`;
  const secure = port === 465;
  if (!host || !user || !pass) {
    return { sent: false, smtpError: 'SMTP non configuré.' };
  }
  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: { user, pass },
    });
    await transporter.sendMail({ from, to, subject, html });
    return { sent: true };
  } catch (err) {
    return {
      sent: false,
      smtpError: err instanceof Error ? err.message : String(err),
    };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const email = String(body?.email ?? '').trim().toLowerCase();
    const note = String(body?.note ?? '').slice(0, MAX_NOTE);

    if (!email) return json({ sent: false, reason: 'missing_email' });

    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // ── Le compte doit exister et venir d'être créé ──────────────────────────
    // On interroge `Users_Client` (et non `listUsers`, paginé : au-delà de 200
    // comptes une inscription récente peut ne pas être sur la 1re page, et
    // l'ordre n'est pas garanti). La ligne est créée par le trigger
    // `handle_new_auth_user` ; comme le client appelle juste après `signUp`, on
    // laisse une seconde chance au trigger avant d'abandonner.
    type Compte = {
      email: string;
      full_name: string | null;
      phone: string | null;
      created_at: string;
    };
    let compte: Compte | null = null;

    for (let essai = 0; essai < 2 && !compte; essai++) {
      if (essai > 0) await new Promise((r) => setTimeout(r, 600));
      const { data, error } = await admin
        .from('Users_Client')
        .select('email, full_name, phone, created_at')
        .ilike('email', email)
        .maybeSingle();
      if (error) {
        console.error('lookup Users_Client:', error.message);
        return json({ sent: false, reason: 'lookup_failed' });
      }
      compte = data as Compte | null;
    }

    if (!compte) {
      // Pas de compte : rien à annoncer. La réponse est volontairement la même
      // qu'un envoi ignoré — on ne confirme pas l'existence d'une adresse.
      return json({ sent: false, reason: 'no_recent_signup' });
    }

    const creeIlYaMs = Date.now() - new Date(compte.created_at).getTime();
    if (creeIlYaMs > FENETRE_MINUTES * 60_000) {
      return json({ sent: false, reason: 'no_recent_signup' });
    }

    // ── Destinataire ────────────────────────────────────────────────────────
    // Secret s'il existe, sinon le super admin en base : la notification
    // fonctionne sans configuration, et reste redirigeable par secret.
    // Priorité : réglage en base (écran « Configuration → Emails
    // administration », modifiable par le super admin sans redéploiement) →
    // secret d'environnement → super admin en base.
    let destinataire = '';
    const { data: reglages } = await admin
      .from('Platform_Settings')
      .select('email_nouveaux_comptes')
      .maybeSingle();
    destinataire = (reglages?.email_nouveaux_comptes ?? '').trim();

    if (!destinataire) {
      destinataire = (Deno.env.get('FORM_NEW_PROPRIETAIRE') ?? '').trim();
    }
    if (!destinataire) {
      const { data: sa } = await admin
        .from('Users_Client')
        .select('email, User_Types_Reference!type_user_id(code)')
        .eq('active', true)
        .limit(50);
      destinataire =
        (sa ?? []).find(
          (u: Record<string, unknown>) =>
            (u.User_Types_Reference as { code?: string } | null)?.code ===
              'super_admin' && String(u.email ?? '').includes('@'),
        )?.email as string ?? '';
    }
    if (!destinataire) {
      console.warn('Aucun destinataire : ni FORM_NEW_PROPRIETAIRE ni super admin.');
      return json({ sent: false, reason: 'no_recipient' });
    }

    const fullName = esc(compte.full_name ?? '—');
    const phone = esc(compte.phone ?? '—');

    const html = `
      <h2>Nouvelle demande de compte Propriétaire</h2>
      <p style="margin:0 0 12px"><strong>Opération :</strong> nouveau compte
      propriétaire — en attente d'activation.</p>
      <table style="border-collapse:collapse">
        <tr><td style="padding:4px 12px"><strong>Nom complet</strong></td><td>${fullName}</td></tr>
        <tr><td style="padding:4px 12px"><strong>E-mail</strong></td><td>${esc(compte.email)}</td></tr>
        <tr><td style="padding:4px 12px"><strong>Téléphone</strong></td><td>${phone}</td></tr>
        ${note ? `<tr><td style="padding:4px 12px"><strong>Message</strong></td><td>${esc(note)}</td></tr>` : ''}
      </table>
      <br>
      <p>Connectez-vous au panel d'administration (Utilisateurs) pour
      activer ce compte. L'intéressé recevra l'e-mail d'activation depuis
      sa fiche.</p>
    `;

    const { sent, smtpError } = await sendEmail(
      destinataire,
      `[Nouveau compte propriétaire] ${compte.full_name ?? compte.email}`,
      html,
    );
    if (!sent) console.error('notify-proprietaire SMTP:', smtpError);
    return json({ sent, ...(smtpError ? { smtpError } : {}) });
  } catch (err) {
    console.error('notify-proprietaire error:', err);
    return json({ sent: false, error: String(err) });
  }
});
