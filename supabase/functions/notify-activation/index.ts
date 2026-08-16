// Prévient un utilisateur que son compte vient d'être activé.
//
// Déclenché à la main depuis la fiche du compte (Super Admin → Utilisateurs),
// bouton « Envoyer l'e-mail d'activation ». C'est le pendant de l'attente
// imposée au propriétaire : il s'inscrit, reste inactif (modèle payant), et
// c'est ce message qui lui dit qu'il peut entrer.
//
// ── Contrôle d'accès ─────────────────────────────────────────────────────────
// `verify_jwt: false` au niveau du gateway (sinon le préflight CORS est bloqué
// → « Failed to fetch », même problème que `manage-user-auth`), mais le jeton
// est vérifié **à la main** ici : seuls `super_admin` et `admin_systeme`
// peuvent déclencher un envoi. Sans cela, n'importe qui pourrait faire envoyer
// des e-mails « votre compte est activé » en énumérant des identifiants.
//
// Le contenu vient **entièrement du serveur** (compte lu par service role,
// adresses lues dans `Platform_Settings`) : l'appelant ne fournit qu'un id.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import nodemailer from 'npm:nodemailer@6';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

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
  if (!host || !user || !pass) {
    return { sent: false, smtpError: 'SMTP non configuré.' };
  }
  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
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
    const { targetUserId } = await req.json().catch(() => ({}));
    if (!targetUserId) return json({ error: 'targetUserId requis.' }, 400);

    const url = Deno.env.get('SUPABASE_URL') ?? '';
    const admin = createClient(
      url,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // ── L'appelant doit être administrateur ─────────────────────────────────
    const token = (req.headers.get('Authorization') ?? '')
      .replace(/^Bearer\s+/i, '')
      .trim();
    if (!token) return json({ error: 'Authentification requise.' }, 401);

    const { data: auteur } = await admin.auth.getUser(token);
    if (!auteur?.user) return json({ error: 'Jeton invalide.' }, 401);

    const { data: profilAuteur } = await admin
      .from('Users_Client')
      .select('User_Types_Reference!type_user_id(code)')
      .eq('id', auteur.user.id)
      .maybeSingle();
    const roleAuteur =
      (profilAuteur?.User_Types_Reference as { code?: string } | null)?.code;
    if (roleAuteur !== 'super_admin' && roleAuteur !== 'admin_systeme') {
      return json({ error: 'Réservé aux administrateurs.' }, 403);
    }

    // ── Le compte concerné ──────────────────────────────────────────────────
    const { data: compte } = await admin
      .from('Users_Client')
      .select('email, full_name, active')
      .eq('id', targetUserId)
      .maybeSingle();
    if (!compte) return json({ error: 'Compte introuvable.' }, 404);
    if (!compte.active) {
      // On n'annonce pas une activation qui n'a pas eu lieu.
      return json({ error: 'Ce compte n\'est pas activé.' }, 400);
    }

    const { data: reglages } = await admin
      .from('Platform_Settings')
      .select('email_support')
      .maybeSingle();
    const support = (reglages?.email_support ?? '').trim();

    const appUrl = (Deno.env.get('APP_URL') ?? url).replace(/\/+$/, '');
    const lienProfil = `${appUrl}/`;
    const lienManuel = `${appUrl}/manual/index.html`;

    const html = `
      <h2>Votre compte HabitaFrance est activé</h2>
      <p>Bonjour ${esc(compte.full_name ?? '')},</p>
      <p>Votre compte a été validé par un administrateur : vous pouvez
      désormais accéder à votre espace.</p>
      <p style="margin:24px 0">
        <a href="${esc(lienProfil)}"
           style="background:#0d5c63;color:#fff;padding:12px 20px;
                  border-radius:6px;text-decoration:none;display:inline-block">
          Accéder à mon espace
        </a>
      </p>
      <p><strong>Pour bien démarrer</strong> — le manuel utilisateur décrit
      chaque écran de la plateforme : ajouter un immeuble et ses chambres,
      publier une annonce, réaliser un état des lieux, générer un bail et
      suivre les loyers.<br>
      <a href="${esc(lienManuel)}">Consulter le manuel utilisateur</a></p>
      ${
      support
        ? `<p><strong>Une question ?</strong> Écrivez à
             <a href="mailto:${esc(support)}">${esc(support)}</a>, un
             administrateur vous répondra.</p>`
        : ''
    }
      <hr style="border:none;border-top:1px solid #ddd;margin:24px 0">
      <p style="color:#666;font-size:13px">Identifiant de connexion :
      ${esc(compte.email)}</p>
    `;

    const { sent, smtpError } = await sendEmail(
      compte.email,
      'Votre compte HabitaFrance est activé',
      html,
    );
    if (!sent) console.error('notify-activation SMTP:', smtpError);
    return json({ sent, ...(smtpError ? { smtpError } : {}) });
  } catch (err) {
    console.error('notify-activation error:', err);
    return json({ sent: false, error: String(err) }, 500);
  }
});
