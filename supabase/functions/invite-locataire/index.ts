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

async function sendInviteEmail(
  email: string,
  fullName: string,
  actionLink: string,
  phone?: string,
): Promise<{ sent: boolean; smtpError?: string }> {
  const host = Deno.env.get('SMTP_HOST') ?? '';
  const port = parseInt(Deno.env.get('SMTP_PORT') ?? '587', 10);
  const user = Deno.env.get('SMTP_USER') ?? '';
  const pass = Deno.env.get('SMTP_PASS') ?? '';
  const from = Deno.env.get('SMTP_FROM') ?? `La Coloc <${user}>`;
  const secure = port === 465;

  if (!host || !user || !pass) {
    return { sent: false, smtpError: `Missing secrets — host="${host}" user="${user}" pass=${pass ? '***' : '(empty)'}` };
  }

  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: { user, pass },
    });

    const html = `
      <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #1a1a2e;">
        <h2 style="color: #006685;">Bienvenue sur La Coloc, ${fullName} !</h2>
        <p>Votre propriétaire vous a invité(e) à rejoindre la plateforme <strong>La Coloc</strong>.</p>
        ${phone ? `<p><strong>Téléphone enregistré :</strong> ${phone}</p>` : ''}
        <p>
          Cliquez sur le bouton ci-dessous pour accéder à votre page d'inscription.
          Vos informations sont déjà pré-remplies — il vous suffit de créer votre
          mot de passe et de compléter votre profil :
        </p>
        <a href="${actionLink}"
           style="display: inline-block; background: #006685; color: white;
                  padding: 14px 28px; border-radius: 8px; text-decoration: none;
                  margin: 16px 0; font-weight: 600;">
          Compléter mon inscription
        </a>
        <p style="color: #666; font-size: 13px; margin-top: 32px;">
          Ce lien est à usage unique et expire dans 24 heures.<br>
          Si vous n'attendiez pas cet e-mail, vous pouvez l'ignorer en toute sécurité.
        </p>
      </div>
    `;

    await transporter.sendMail({
      from,
      to: `${fullName} <${email}>`,
      subject: 'Bienvenue sur La Coloc — Complétez votre inscription',
      html,
    });
    return { sent: true };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('SMTP error:', msg);
    return { sent: false, smtpError: msg };
  }
}

// deno-lint-ignore no-explicit-any
async function markEmailStatus(supabase: any, userId: string): Promise<void> {
  await supabase
    .from('Users_Client')
    .update({
      invitation_email_sent: true,
      invitation_sent_at: new Date().toISOString(),
    })
    .eq('id', userId);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const {
      fullName,
      email,
      phone,
      dateOfBirth,
      proprietaireId,
      resend,
      userId: existingUserId,
    } = body;

    const appUrl = Deno.env.get('APP_URL') ?? 'https://votre-app.com';

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // ── Resend mode ────────────────────────────────────────────────────────
    if (resend === true) {
      if (!existingUserId) return json({ error: 'userId est obligatoire.' }, 400);

      // Generate a fresh magic link for the existing user
      const { data: magicData } = await supabase.auth.admin.generateLink({
        type: 'magiclink',
        email: email ?? '',
        options: { redirectTo: appUrl },
      });
      const actionLink = magicData?.properties?.action_link ?? appUrl;

      const { sent: emailSent, smtpError } = await sendInviteEmail(email ?? '', fullName ?? '', actionLink, phone);
      if (emailSent) await markEmailStatus(supabase, existingUserId);

      return json({ emailSent, ...(smtpError ? { smtpError } : {}) });
    }

    // ── Create mode ────────────────────────────────────────────────────────
    if (!fullName || !email) {
      return json({ error: 'fullName et email sont obligatoires.' }, 400);
    }

    const { data: linkData, error: linkError } =
      await supabase.auth.admin.generateLink({
        type: 'invite',
        email,
        options: {
          redirectTo: appUrl,
          data: {
            full_name: fullName,
            type_code: 'locataire',
            needs_completion: true,
            ...(phone ? { phone } : {}),
            ...(dateOfBirth ? { date_of_birth: dateOfBirth } : {}),
          },
        },
      });

    if (linkError) {
      const msg: string = linkError.message ?? '';
      const isAlreadyRegistered =
        msg.includes('already been registered') ||
        msg.includes('already registered') ||
        msg.includes('déjà enregistré');
      return json(
        { error: isAlreadyRegistered ? 'Un compte avec cet e-mail existe déjà.' : msg },
        400,
      );
    }

    const actionLink: string = linkData?.properties?.action_link ?? appUrl;
    const newUserId: string | undefined = linkData?.user?.id;

    // Attendre la création de la ligne Users_Client via trigger
    await new Promise((resolve) => setTimeout(resolve, 400));

    if (newUserId && proprietaireId) {
      await supabase
        .from('Users_Client')
        .update({ invited_by_proprietaire_id: proprietaireId })
        .eq('id', newUserId);
    }

    const { sent: emailSent, smtpError } = await sendInviteEmail(email, fullName, actionLink, phone);
    if (newUserId && emailSent) await markEmailStatus(supabase, newUserId);

    return json({ userId: newUserId, emailSent, ...(smtpError ? { smtpError } : {}) });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
