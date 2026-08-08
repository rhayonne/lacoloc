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

/// Échappe le HTML (les champs viennent d'entrées utilisateur).
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
      host, port, secure, auth: { user, pass },
    });
    await transporter.sendMail({ from, to, subject, html });
    return { sent: true };
  } catch (err) {
    return { sent: false, smtpError: err instanceof Error ? err.message : String(err) };
  }
}

const TYPE_LABELS: Record<string, string> = {
  etat_des_lieux_entree: 'État des lieux — entrée',
  etat_des_lieux_sortie: 'État des lieux — sortie',
  visite_entree: 'Visite',
  visite: 'Visite',
  reparation: 'Réparation',
  autre: 'Rendez-vous',
};

function fmtDateTime(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  return new Intl.DateTimeFormat('fr-FR', {
    weekday: 'long', day: '2-digit', month: 'long', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  }).format(d);
}

function fmtHeure(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  return new Intl.DateTimeFormat('fr-FR', {
    hour: '2-digit', minute: '2-digit',
  }).format(d);
}

/// Notifie par e-mail le contact (locataire OU invité hors système) d'un
/// rendez-vous de l'agenda du propriétaire.
/// Body : { visiteId, mailTo? }.
/// Le destinataire (invite_email ou e-mail du locataire lié) est résolu côté
/// serveur depuis la visite → non falsifiable. Le propriétaire doit être
/// l'auteur de la visite (lecture via RLS avec le client de l'appelant).
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const { visiteId, mailTo } = await req.json();
    if (!visiteId) return json({ error: 'visiteId requis.' }, 400);

    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) return json({ error: 'Authentification requise.' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: caller, error: authErr } = await userClient.auth.getUser();
    if (authErr || !caller?.user) {
      return json({ error: 'Jeton invalide ou expiré.' }, 401);
    }

    // Contrôle d'accès : lecture de la visite avec le client de l'appelant
    // (RLS owner-only). S'il n'y a pas accès → 403.
    const { data: vAuth } = await userClient
      .from('Visites')
      .select('id')
      .eq('id', visiteId)
      .maybeSingle();
    if (!vAuth) return json({ error: 'Accès refusé à ce rendez-vous.' }, 403);

    // Lecture service role pour composer l'e-mail.
    const { data: v } = await supabase
      .from('Visites')
      .select('id, owner_id, type_visite, nom_visiteur, invite_email, invite_nom, locataire_id, immeuble_id, heure_debut, heure_fin, notes')
      .eq('id', visiteId)
      .maybeSingle();
    if (!v) return json({ error: 'Rendez-vous introuvable.' }, 404);

    // Destinataire : e-mail invité prioritaire, sinon e-mail du locataire lié.
    let recipient = (typeof v.invite_email === 'string' ? v.invite_email : '').trim();
    if (!recipient && v.locataire_id) {
      const { data: u } = await supabase
        .from('Users_Client')
        .select('email')
        .eq('id', v.locataire_id)
        .maybeSingle();
      recipient = (u?.email ?? '').trim();
    }

    // Redirection DEV : honorée uniquement si == secret DEV_TEST_EMAIL.
    const devTestEmail = (Deno.env.get('DEV_TEST_EMAIL') ?? '').trim().toLowerCase();
    const rawMailTo = (typeof mailTo === 'string' && mailTo) ? mailTo.trim() : '';
    if (devTestEmail !== '' && rawMailTo.toLowerCase() === devTestEmail) {
      recipient = rawMailTo;
    }
    if (!recipient) return json({ sent: false, smtpError: 'aucun destinataire.' });

    // Émetteur (propriétaire) + lieu (immeuble).
    const { data: owner } = await supabase
      .from('Users_Client')
      .select('email, full_name')
      .eq('id', v.owner_id)
      .maybeSingle();

    let lieu = '';
    if (v.immeuble_id) {
      const { data: imm } = await supabase
        .from('Immeubles')
        .select('name, address')
        .eq('id', v.immeuble_id)
        .maybeSingle();
      lieu = [imm?.name, imm?.address].filter(Boolean).join(' — ');
    }

    const typeLabel = TYPE_LABELS[v.type_visite as string] ?? 'Rendez-vous';
    const quand = fmtDateTime(v.heure_debut);
    const finH = fmtHeure(v.heure_fin);
    const emetteur = esc(owner?.full_name ?? '');
    const invite = esc(v.invite_nom ?? v.nom_visiteur ?? '');

    const subject = `Rendez-vous — ${typeLabel}${quand ? ` le ${new Date(v.heure_debut).toLocaleDateString('fr-FR')}` : ''}`;
    const html = `
      <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #1a1a2e;">
        <h2 style="color: #006685;">Vous avez un rendez-vous</h2>
        <p>Bonjour ${invite || ''},</p>
        <p>${emetteur ? `<strong>${emetteur}</strong> vous` : 'Vous'} propose un rendez-vous&nbsp;:</p>
        <table style="border-collapse: collapse; margin: 16px 0;">
          <tr><td style="padding: 6px 12px; color:#666;">Type</td><td style="padding: 6px 12px;"><strong>${esc(typeLabel)}</strong></td></tr>
          <tr><td style="padding: 6px 12px; color:#666;">Quand</td><td style="padding: 6px 12px;"><strong>${esc(quand)}</strong>${finH ? ` → ${esc(finH)}` : ''}</td></tr>
          ${lieu ? `<tr><td style="padding: 6px 12px; color:#666;">Lieu</td><td style="padding: 6px 12px;"><strong>${esc(lieu)}</strong></td></tr>` : ''}
          ${emetteur ? `<tr><td style="padding: 6px 12px; color:#666;">Organisateur</td><td style="padding: 6px 12px;">${emetteur}</td></tr>` : ''}
          ${v.notes ? `<tr><td style="padding: 6px 12px; color:#666;">Notes</td><td style="padding: 6px 12px;">${esc(v.notes)}</td></tr>` : ''}
        </table>
        <p style="color: #666; font-size: 13px; margin-top: 32px;">
          Notification automatique — HabitaFrance.
        </p>
      </div>
    `;

    const { sent, smtpError } = await sendEmail(recipient, subject, html);
    // Horodatage best-effort (non bloquant).
    if (sent) {
      await supabase.from('Visites')
        .update({ notified_at: new Date().toISOString() })
        .eq('id', visiteId);
    }
    return json({ sent, recipient, ...(smtpError ? { smtpError } : {}) });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
