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

/// Mot de passe temporaire aléatoire (sans caractères ambigus).
function genPassword(length = 14): string {
  const chars =
    'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let out = '';
  for (let i = 0; i < length; i++) out += chars[bytes[i] % chars.length];
  return out;
}

/// Construit le lien d'activation : racine de l'app + email + mot de passe
/// temporaire en query. La page d'accueil détecte ces paramètres, connecte
/// automatiquement le locataire et l'amène au formulaire de changement de
/// mot de passe.
function buildActivationLink(
  baseUrl: string,
  email: string,
  tempPassword: string,
): string {
  const sep = baseUrl.includes('?') ? '&' : '?';
  return `${baseUrl}${sep}email=${encodeURIComponent(email)}&temp=${encodeURIComponent(tempPassword)}`;
}

async function sendActivationEmail(
  email: string,
  fullName: string,
  tempPassword: string,
  activationLink: string,
  phone?: string,
  isResend = false,
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

  const displayName = fullName || email;

  // Corps et sujet différents selon création vs renvoi de mot de passe.
  const subject = isResend
    ? `Réinitialisation de votre accès — La Coloc`
    : `Bienvenue sur La Coloc — Activez votre compte`;

  const intro = isResend
    ? `
        <h2 style="color: #006685;">Réinitialisation de votre accès</h2>
        <p>Bonjour <strong>${displayName}</strong>,</p>
        <p>
          Une réinitialisation de mot de passe a été demandée pour votre compte
          <strong>La Coloc</strong> (<em>${email}</em>).
        </p>
      `
    : `
        <h2 style="color: #006685;">Bienvenue sur La Coloc, ${displayName} !</h2>
        <p>Votre propriétaire vous a créé un compte sur <strong>La Coloc</strong>.</p>
        ${phone ? `<p><strong>Téléphone enregistré :</strong> ${phone}</p>` : ''}
      `;

  const buttonLabel = isResend
    ? 'Définir mon nouveau mot de passe'
    : 'Activer mon compte et choisir mon mot de passe';

  const footer = isResend
    ? `Si vous n'avez pas demandé cette réinitialisation, ignorez cet e-mail — votre mot de passe actuel reste inchangé.`
    : `Ce lien reste valable tant que vous n'avez pas changé votre mot de passe.<br>
       Si vous n'attendiez pas cet e-mail, vous pouvez l'ignorer en toute sécurité.`;

  const html = `
    <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #1a1a2e;">
      ${intro}
      <p>Voici votre <strong>mot de passe temporaire</strong> :</p>
      <div style="font-size: 20px; font-weight: 700; letter-spacing: 1px;
                  background: #f0f6fa; border: 1px solid #cfe0e7; color: #006685;
                  padding: 14px 18px; border-radius: 8px; text-align: center;
                  margin: 12px 0;">
        ${tempPassword}
      </div>
      <p>
        Cliquez sur le bouton ci-dessous pour vous connecter. Vous serez
        invité(e) à <strong>choisir votre propre mot de passe</strong>.
      </p>
      <a href="${activationLink}"
         style="display: inline-block; background: #006685; color: white;
                padding: 14px 28px; border-radius: 8px; text-decoration: none;
                margin: 16px 0; font-weight: 600;">
        ${buttonLabel}
      </a>
      <p style="color: #666; font-size: 13px; margin-top: 32px;">
        ${footer}
      </p>
    </div>
  `;

  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: { user, pass },
    });

    await transporter.sendMail({
      from,
      to: displayName !== email ? `${displayName} <${email}>` : email,
      subject,
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

function isAlreadyRegistered(msg: string): boolean {
  return (
    msg.includes('already been registered') ||
    msg.includes('already registered') ||
    msg.includes('already exists') ||
    msg.includes('déjà enregistré')
  );
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
      redirectTo,
      mailTo,
      test,
      emailType,
    } = body;

    // En dev, le client peut rediriger l'e-mail vers une boîte de test
    // (ADDR_MAIL_CONFIRMATION) sans changer l'e-mail réel du compte.
    const recipient =
      (typeof mailTo === 'string' && mailTo) ? mailTo : email;

    // Racine de l'app (page qui détecte ?email&?temp). Fournie par le client
    // (.env URL_EMAIL_CONFIRMATION_*), avec repli sur le secret APP_URL.
    const appUrl =
      (typeof redirectTo === 'string' && redirectTo) ||
      Deno.env.get('APP_URL') ||
      'https://votre-app.com';

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // ── Test mode (envoi d'e-mail de diagnostic — RÉSERVÉ AU SUPER ADMIN) ──────
    // Auparavant ouvert sans authentification (`verify_jwt: false`), ce mode
    // était abusé par des appels externes. Désormais on exige le JWT d'un
    // compte **super_admin** (vérifié côté service role, non falsifiable).
    if (test === true) {
      const startedAt = Date.now();
      const authHeader = req.headers.get('Authorization') ?? '';
      const token = authHeader.replace(/^Bearer\s+/i, '').trim();
      if (!token) {
        return json({ ok: false, error: 'Authentification requise.' }, 401);
      }
      const { data: caller, error: authErr } = await supabase.auth.getUser(token);
      if (authErr || !caller?.user) {
        return json({ ok: false, error: 'Jeton invalide ou expiré.' }, 401);
      }
      const { data: profile } = await supabase
        .from('Users_Client')
        .select('User_Types_Reference(code)')
        .eq('id', caller.user.id)
        .maybeSingle();
      // deno-lint-ignore no-explicit-any
      const callerType = (profile as any)?.User_Types_Reference?.code;
      if (callerType !== 'super_admin') {
        return json({ ok: false, error: 'Réservé au super admin.' }, 403);
      }

      const to = recipient;
      if (!to) return json({ ok: false, error: 'email (ou mailTo) requis pour le test.' }, 400);

      // emailType : 'reset' → e-mail de réinitialisation ; sinon → activation.
      const isResend = emailType === 'reset';
      const tempPassword = 'MOT-DE-PASSE-TEST';
      const link = buildActivationLink(appUrl, to, 'TEST');
      const subject = isResend
        ? 'Réinitialisation de votre accès — La Coloc'
        : 'Bienvenue sur La Coloc — Activez votre compte';

      const { sent, smtpError } = await sendActivationEmail(
        to,
        fullName ?? 'Test La Coloc',
        tempPassword,
        link,
        phone,
        isResend,
      );

      return json({
        ok: sent,
        test: true,
        emailType: emailType ?? 'invite',
        recipient: to,
        subject,
        activationLink: link,
        smtpConfigured: !!(Deno.env.get('SMTP_HOST') && Deno.env.get('SMTP_USER') && Deno.env.get('SMTP_PASS')),
        requestedBy: caller.user.email,
        durationMs: Date.now() - startedAt,
        timestamp: new Date().toISOString(),
        ...(smtpError ? { smtpError } : {}),
      }, sent ? 200 : 502);
    }

    // ── Resend mode ──────────────────────────────────────────────────────────
    // Réinitialise un nouveau mot de passe temporaire et renvoie le lien.
    if (resend === true) {
      if (!existingUserId) return json({ error: 'userId est obligatoire.' }, 400);
      if (!email) return json({ error: 'email est obligatoire.' }, 400);

      // Si le nom n'est pas fourni par le client, on le récupère depuis la BD.
      let resolvedName: string = (typeof fullName === 'string' && fullName) ? fullName : '';
      if (!resolvedName) {
        const { data: userRow } = await supabase
          .from('Users_Client')
          .select('full_name')
          .eq('id', existingUserId)
          .maybeSingle();
        resolvedName = (userRow as any)?.full_name ?? '';
      }

      const tempPassword = genPassword();
      const { error: updErr } = await supabase.auth.admin.updateUserById(
        existingUserId,
        {
          password: tempPassword,
          user_metadata: { needs_completion: true },
        },
      );
      if (updErr) return json({ error: updErr.message }, 400);

      const link = buildActivationLink(appUrl, email, tempPassword);
      const { sent: emailSent, smtpError } = await sendActivationEmail(
        recipient ?? '', resolvedName, tempPassword, link, phone, true,
      );
      if (emailSent) await markEmailStatus(supabase, existingUserId);

      return json({ emailSent, ...(smtpError ? { smtpError } : {}) });
    }

    // ── Create mode ────────────────────────────────────────────────────────
    if (!fullName || !email) {
      return json({ error: 'fullName et email sont obligatoires.' }, 400);
    }

    const tempPassword = genPassword();
    const { data: createdData, error: createErr } =
      await supabase.auth.admin.createUser({
        email,
        password: tempPassword,
        email_confirm: true,
        user_metadata: {
          full_name: fullName,
          type_code: 'locataire',
          needs_completion: true,
          ...(phone ? { phone } : {}),
          ...(dateOfBirth ? { date_of_birth: dateOfBirth } : {}),
        },
      });

    if (createErr) {
      const msg: string = createErr.message ?? '';
      return json(
        { error: isAlreadyRegistered(msg) ? 'Un compte avec cet e-mail existe déjà.' : msg },
        400,
      );
    }

    const newUserId: string | undefined = createdData?.user?.id;

    // Attendre la création de la ligne Users_Client via trigger
    await new Promise((resolve) => setTimeout(resolve, 400));

    if (newUserId && proprietaireId) {
      await supabase
        .from('Users_Client')
        .update({ invited_by_proprietaire_id: proprietaireId })
        .eq('id', newUserId);
    }

    const link = buildActivationLink(appUrl, email, tempPassword);
    const { sent: emailSent, smtpError } = await sendActivationEmail(
      recipient, fullName, tempPassword, link, phone,
    );
    if (newUserId && emailSent) await markEmailStatus(supabase, newUserId);

    return json({ userId: newUserId, emailSent, ...(smtpError ? { smtpError } : {}) });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
