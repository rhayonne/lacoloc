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

async function sendEmail(
  to: string,
  subject: string,
  html: string,
): Promise<{ sent: boolean; smtpError?: string }> {
  const host = Deno.env.get('SMTP_HOST') ?? '';
  const port = parseInt(Deno.env.get('SMTP_PORT') ?? '587', 10);
  const user = Deno.env.get('SMTP_USER') ?? '';
  const pass = Deno.env.get('SMTP_PASS') ?? '';
  const from = Deno.env.get('SMTP_FROM') ?? `La Coloc <${user}>`;
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

/// Notifie par e-mail le propriétaire d'un événement EDL.
/// Body : { edlId, event: 'accepte' | 'addition', locataireNom?, mailTo?,
///          comodo?, texte? }
/// L'e-mail du propriétaire est résolu côté serveur (service role) à partir de
/// l'EDL → non falsifiable par le client.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const { edlId, event, locataireNom, mailTo, comodo, texte } =
      await req.json();
    if (!edlId) return json({ error: 'edlId requis.' }, 400);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // EDL + propriétaire + immeuble.
    const { data: edl } = await supabase
      .from('etat_de_lieux')
      .select('id, type_edl, proprietaire_id, immeuble_id')
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

    // En dev, le client peut rediriger l'e-mail vers une boîte de test.
    const recipient =
      (typeof mailTo === 'string' && mailTo) ? mailTo : owner?.email;
    if (!recipient) return json({ error: 'e-mail propriétaire introuvable.' }, 404);

    const typeLabel = edl.type_edl === 'sortie' ? 'de sortie' : "d'entrée";
    const who = locataireNom ? `<strong>${locataireNom}</strong>` : 'Le locataire';

    let subject: string;
    let html: string;

    if (event === 'addition') {
      // Ajout (« addition ») fait par le locataire après finalisation.
      subject = `Nouvelle addition à un état des lieux${immeubleName ? ` — ${immeubleName}` : ''}`;
      html = `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #1a1a2e;">
          <h2 style="color: #006685;">Nouvelle addition</h2>
          <p>Bonjour ${owner?.full_name ?? ''},</p>
          <p>
            ${who} a ajouté un élément à l'état des lieux ${typeLabel}
            ${immeubleName ? `de <strong>${immeubleName}</strong>` : ''}.
          </p>
          ${comodo ? `<p><strong>Comodo :</strong> ${comodo}</p>` : ''}
          ${texte ? `<p><strong>Observation :</strong> ${texte}</p>` : ''}
          <p>Connectez-vous à La Coloc et ouvrez l'état des lieux concerné,
             onglet <strong>« Additions »</strong>, pour consulter l'ajout
             (photo éventuelle incluse).</p>
          <p style="color: #666; font-size: 13px; margin-top: 32px;">
            Notification automatique — La Coloc.
          </p>
        </div>
      `;
    } else {
      subject = `État des lieux accepté${immeubleName ? ` — ${immeubleName}` : ''}`;
      html = `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #1a1a2e;">
          <h2 style="color: #006685;">État des lieux accepté</h2>
          <p>Bonjour ${owner?.full_name ?? ''},</p>
          <p>
            ${who} a <strong>accepté et signé</strong> l'état des lieux ${typeLabel}
            ${immeubleName ? `de <strong>${immeubleName}</strong>` : ''}.
          </p>
          <p>Connectez-vous à La Coloc pour consulter le document signé.</p>
          <p style="color: #666; font-size: 13px; margin-top: 32px;">
            Notification automatique — La Coloc.
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
