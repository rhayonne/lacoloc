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

/// Échappe le HTML pour empêcher l'injection de balises/scripts dans le corps
/// des e-mails (les champs `locataireNom`, `comodo`, `texte`, noms d'immeuble…
/// proviennent d'entrées utilisateur).
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
  const from = Deno.env.get('SMTP_FROM') ?? `Super Loc <${user}>`;
  const secure = port === 465;
  if (!host || !user || !pass) {
    return { sent: false, smtpError: 'SMTP non configuré.' };
  }
  try {
    const transporter = nodemailer.createTransport({
      host, port, secure, auth: { user, pass },
    });
    await transporter.sendMail({ from, to, subject, html });
    return { sent: true };
  } catch (err) {
    return { sent: false, smtpError: err instanceof Error ? err.message : String(err) };
  }
}

/// Notifie par e-mail un événement EDL.
/// Body : { edlId, event: 'accepte' | 'addition' | 'a_signer', locataireNom?,
///          mailTo?, comodo?, texte? }
/// - 'accepte' / 'addition' → e-mail au **propriétaire** (résolu depuis l'EDL).
/// - 'a_signer' → e-mail au(x) **locataire(s)** (privatif → locataire_id ;
///   commune → preneurs), après finalisation par le propriétaire.
/// Les destinataires sont résolus côté serveur (service role) → non falsifiable.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const { edlId, event, locataireNom, mailTo, comodo, texte } =
      await req.json();
    if (!edlId) return json({ error: 'edlId requis.' }, 400);

    // ── Authentification obligatoire ───────────────────────────────────────
    // Sans ce contrôle, n'importe qui pouvait déclencher des e-mails (avec un
    // contenu arbitraire) vers les utilisateurs en énumérant les `edlId`.
    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) return json({ error: 'Authentification requise.' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Client scellé au JWT de l'appelant → les lectures respectent la RLS.
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: caller, error: authErr } = await userClient.auth.getUser();
    if (authErr || !caller?.user) {
      return json({ error: 'Jeton invalide ou expiré.' }, 401);
    }

    // Contrôle d'accès : on lit l'EDL avec le client de l'appelant (RLS). S'il
    // n'a pas le droit de voir cet EDL, la lecture renvoie null → 403. On ne
    // peut donc notifier que sur un EDL auquel on a réellement accès.
    const { data: edlAuth } = await userClient
      .from('etat_de_lieux')
      .select('id')
      .eq('id', edlId)
      .maybeSingle();
    if (!edlAuth) {
      return json({ error: 'Accès refusé à cet état des lieux.' }, 403);
    }

    // EDL + propriétaire + immeuble (lecture service role pour les e-mails).
    const { data: edl } = await supabase
      .from('etat_de_lieux')
      .select('id, type_edl, proprietaire_id, immeuble_id, locataire_id, partie')
      .eq('id', edlId)
      .maybeSingle();
    if (!edl) return json({ error: 'EDL introuvable.' }, 404);

    const { data: owner } = await supabase
      .from('Users_Client')
      .select('email, full_name')
      .eq('id', edl.proprietaire_id)
      .maybeSingle();

    let immeubleName = '';
    if (edl.immeuble_id) {
      const { data: imm } = await supabase
        .from('Immeubles')
        .select('name')
        .eq('id', edl.immeuble_id)
        .maybeSingle();
      immeubleName = imm?.name ?? '';
    }

    // ── Événement « à signer » : e-mail au(x) locataire(s) après finalisation.
    // Destinataires résolus côté serveur depuis l'EDL (non falsifiable) :
    // privatif → locataire_id ; commune → preneurs.
    // Redirection mailTo honorée uniquement si le serveur l'autorise (DEV).
    const overrideAllowed =
      (Deno.env.get('ALLOW_CLIENT_MAIL_OVERRIDE') ?? '').toLowerCase() === 'true';
    const rawMailTo = (typeof mailTo === 'string' && mailTo) ? mailTo : '';

    if (event === 'a_signer') {
      let emails: string[] = [];
      if (overrideAllowed && rawMailTo) {
        emails = [rawMailTo];
      } else if (edl.partie === 'commune') {
        const { data: preneurs } = await supabase
          .from('etat_de_lieux_preneurs')
          .select('locataire_id')
          .eq('etat_de_lieux_id', edlId);
        const ids = (preneurs ?? [])
          .map((p: { locataire_id: string | null }) => p.locataire_id)
          .filter((x: string | null): x is string => !!x);
        if (ids.length) {
          const { data: us } = await supabase
            .from('Users_Client')
            .select('email')
            .in('id', ids);
          emails = (us ?? [])
            .map((u: { email: string | null }) => u.email)
            .filter((x: string | null): x is string => !!x);
        }
      } else if (edl.locataire_id) {
        const { data: u } = await supabase
          .from('Users_Client')
          .select('email')
          .eq('id', edl.locataire_id)
          .maybeSingle();
        if (u?.email) emails = [u.email];
      }
      if (!emails.length) return json({ sent: false, smtpError: 'aucun locataire à notifier.' });

      const tLabel = edl.type_edl === 'sortie' ? 'de sortie' : "d'entrée";
      const immSafe = esc(immeubleName);
      const subject = `État des lieux à signer${immeubleName ? ` — ${immeubleName}` : ''}`;
      const html = `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #1a1a2e;">
          <h2 style="color: #006685;">État des lieux à signer</h2>
          <p>Bonjour,</p>
          <p>
            Le propriétaire a <strong>finalisé</strong> l'état des lieux ${tLabel}
            ${immeubleName ? `de <strong>${immSafe}</strong>` : ''}. Il ne
            reste plus qu'à le <strong>relire et le signer</strong>.
          </p>
          <p>Connectez-vous à Super Loc, onglet <strong>« État des lieux »</strong>,
             pour consulter le document et l'accepter.</p>
          <p style="color: #666; font-size: 13px; margin-top: 32px;">
            Notification automatique — Super Loc.
          </p>
        </div>
      `;
      const { sent, smtpError } = await sendEmail(emails.join(','), subject, html);
      return json({ sent, ...(smtpError ? { smtpError } : {}) });
    }

    // En dev (override autorisé), le client peut rediriger vers une boîte de test.
    const recipient =
      (overrideAllowed && rawMailTo) ? rawMailTo : owner?.email;
    if (!recipient) return json({ error: 'e-mail propriétaire introuvable.' }, 404);

    const typeLabel = edl.type_edl === 'sortie' ? 'de sortie' : "d'entrée";
    const who = locataireNom ? `<strong>${esc(locataireNom)}</strong>` : 'Le locataire';
    const ownerName = esc(owner?.full_name ?? '');
    const immeubleSafe = esc(immeubleName);

    let subject: string;
    let html: string;

    if (event === 'addition') {
      // Avenant fait par le locataire après finalisation.
      subject = `Nouvel avenant à un état des lieux${immeubleName ? ` — ${immeubleName}` : ''}`;
      html = `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #1a1a2e;">
          <h2 style="color: #006685;">Nouvel avenant</h2>
          <p>Bonjour ${ownerName},</p>
          <p>
            ${who} a ajouté un élément à l'état des lieux ${typeLabel}
            ${immeubleName ? `de <strong>${immeubleSafe}</strong>` : ''}.
          </p>
          ${comodo ? `<p><strong>Comodo :</strong> ${esc(comodo)}</p>` : ''}
          ${texte ? `<p><strong>Observation :</strong> ${esc(texte)}</p>` : ''}
          <p>Connectez-vous à Super Loc et ouvrez l'état des lieux concerné,
             onglet <strong>« Avenants »</strong>, pour consulter l'ajout
             (photo éventuelle incluse).</p>
          <p style="color: #666; font-size: 13px; margin-top: 32px;">
            Notification automatique — Super Loc.
          </p>
        </div>
      `;
    } else {
      subject = `État des lieux accepté${immeubleName ? ` — ${immeubleName}` : ''}`;
      html = `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #1a1a2e;">
          <h2 style="color: #006685;">État des lieux accepté</h2>
          <p>Bonjour ${ownerName},</p>
          <p>
            ${who} a <strong>accepté et signé</strong> l'état des lieux ${typeLabel}
            ${immeubleName ? `de <strong>${immeubleSafe}</strong>` : ''}.
          </p>
          <p>Connectez-vous à Super Loc pour consulter le document signé.</p>
          <p style="color: #666; font-size: 13px; margin-top: 32px;">
            Notification automatique — Super Loc.
          </p>
        </div>
      `;
    }

    const { sent, smtpError } = await sendEmail(recipient, subject, html);
    return json({ sent, ...(smtpError ? { smtpError } : {}) });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
