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

/// Échappe le HTML (anti-injection dans le corps des e-mails : full_name,
/// email, phone proviennent d'entrées utilisateur).
function esc(value: unknown): string {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
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
  const from = Deno.env.get('SMTP_FROM') ?? `HabitaFrance <${user}>`;
  const secure = port === 465;

  if (!host || !user || !pass) {
    // Ne pas divulguer les valeurs de configuration SMTP dans la réponse.
    console.error('SMTP non configuré (host/user/pass manquant).');
    return { sent: false, smtpError: 'SMTP non configuré.' };
  }

  const displayName = fullName || email;
  const nameSafe = esc(displayName);
  const emailSafe = esc(email);
  const phoneSafe = esc(phone);

  // Corps et sujet différents selon création vs renvoi de mot de passe.
  const subject = isResend
    ? `Réinitialisation de votre accès — HabitaFrance`
    : `Bienvenue sur HabitaFrance — Activez votre compte`;

  const intro = isResend
    ? `
        <h2 style="color: #006685;">Réinitialisation de votre accès</h2>
        <p>Bonjour <strong>${nameSafe}</strong>,</p>
        <p>
          Une réinitialisation de mot de passe a été demandée pour votre compte
          <strong>HabitaFrance</strong> (<em>${emailSafe}</em>).
        </p>
      `
    : `
        <h2 style="color: #006685;">Bienvenue sur HabitaFrance, ${nameSafe} !</h2>
        <p>Votre propriétaire vous a créé un compte sur <strong>HabitaFrance</strong>.</p>
        ${phone ? `<p><strong>Téléphone enregistré :</strong> ${phoneSafe}</p>` : ''}
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

/// Vérifie que l'appelant est authentifié et possède un rôle autorisé à gérer
/// des comptes locataires (proprietaire / admin_groupe / super_admin). Retourne
/// `null` si OK, sinon une `Response` d'erreur (401/403) à renvoyer directement.
/// Le JWT est validé côté service role → non falsifiable.
// deno-lint-ignore no-explicit-any
async function requireManager(supabase: any, req: Request): Promise<Response | null> {
  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!token) return json({ error: 'Authentification requise.' }, 401);
  const { data: caller, error: authErr } = await supabase.auth.getUser(token);
  if (authErr || !caller?.user) {
    return json({ error: 'Jeton invalide ou expiré.' }, 401);
  }
  const { data: profile } = await supabase
    .from('Users_Client')
    .select('User_Types_Reference(code)')
    .eq('id', caller.user.id)
    .maybeSingle();
  // deno-lint-ignore no-explicit-any
  const code = (profile as any)?.User_Types_Reference?.code;
  if (!['proprietaire', 'admin_groupe', 'super_admin'].includes(code)) {
    return json({ error: 'Action réservée aux gestionnaires de comptes.' }, 403);
  }
  return null;
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
      del,
      userId: existingUserId,
      redirectTo,
      mailTo,
      test,
      emailType,
    } = body;

    // Redirection d'e-mail (mailTo) — en DEV, le client envoie l'adresse de la
    // boîte de test (ADDR_MAIL_CONFIRMATION) pour ne pas écrire aux locataires
    // réels. Pour éviter qu'un appelant détourne le lien (mot de passe temp)
    // vers une adresse arbitraire, le serveur n'honore `mailTo` QUE s'il
    // correspond EXACTEMENT à l'adresse de test configurée côté serveur
    // (secret `DEV_TEST_EMAIL`). En PROD ce secret est absent / le client
    // n'envoie pas de mailTo → le lien part toujours vers l'e-mail réel.
    const devTestEmail = (Deno.env.get('DEV_TEST_EMAIL') ?? '').trim().toLowerCase();
    const rawMailTo = (typeof mailTo === 'string' && mailTo) ? mailTo.trim() : '';
    const overrideOk = devTestEmail !== '' && rawMailTo.toLowerCase() === devTestEmail;
    const recipient = overrideOk ? rawMailTo : email;

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

      // Mode test = super_admin authentifié → on honore mailTo sans restriction.
      const to = rawMailTo || email;
      if (!to) return json({ ok: false, error: 'email (ou mailTo) requis pour le test.' }, 400);

      // emailType : 'reset' → e-mail de réinitialisation ; sinon → activation.
      const isResend = emailType === 'reset';
      const tempPassword = 'MOT-DE-PASSE-TEST';
      const link = buildActivationLink(appUrl, to, 'TEST');
      const subject = isResend
        ? 'Réinitialisation de votre accès — HabitaFrance'
        : 'Bienvenue sur HabitaFrance — Activez votre compte';

      const { sent, smtpError } = await sendActivationEmail(
        to,
        fullName ?? 'Test HabitaFrance',
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
    // RÉSERVÉ aux gestionnaires authentifiés (propriétaire/admin/super admin) :
    // sans ce contrôle, n'importe qui pouvait réinitialiser le mot de passe de
    // n'importe quel compte (via son userId) → prise de contrôle de compte.
    if (resend === true) {
      const denied = await requireManager(supabase, req);
      if (denied) return denied;
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

    // ── Delete mode (annuler une invitation en attente) ──────────────────────
    // Supprime le compte d'un locataire **invité mais pas encore activé**.
    // RÉSERVÉ : super_admin, admin_groupe (même entreprise) ou le propriétaire
    // qui a émis l'invitation (invited_by_proprietaire_id). On refuse de
    // supprimer un compte déjà activé ou lié à des contrats (etat_de_lieux).
    if (del === true) {
      const denied = await requireManager(supabase, req);
      if (denied) return denied;
      if (!existingUserId) return json({ error: 'userId est obligatoire.' }, 400);

      const authHeader = req.headers.get('Authorization') ?? '';
      const token = authHeader.replace(/^Bearer\s+/i, '').trim();
      const { data: caller } = await supabase.auth.getUser(token);
      const callerId = caller?.user?.id;
      if (!callerId) return json({ error: 'Jeton invalide ou expiré.' }, 401);

      const { data: callerProfile } = await supabase
        .from('Users_Client')
        .select('entreprise_id, User_Types_Reference(code)')
        .eq('id', callerId)
        .maybeSingle();
      // deno-lint-ignore no-explicit-any
      const callerType = (callerProfile as any)?.User_Types_Reference?.code;

      const { data: targetProfile } = await supabase
        .from('Users_Client')
        .select('invited_by_proprietaire_id, entreprise_id')
        .eq('id', existingUserId)
        .maybeSingle();
      if (!targetProfile) return json({ error: 'Utilisateur introuvable.' }, 404);

      // Refuse la suppression d'un compte déjà activé (needs_completion=false).
      const { data: targetAuth } = await supabase.auth.admin.getUserById(existingUserId);
      // deno-lint-ignore no-explicit-any
      const needsCompletion = (targetAuth as any)?.user?.user_metadata?.needs_completion;
      if (needsCompletion === false) {
        return json(
          { error: 'Ce compte est déjà activé ; il ne peut pas être supprimé ici.' },
          400,
        );
      }

      // Sécurité : aucun contrat (etat_de_lieux) lié au locataire.
      const { count } = await supabase
        .from('etat_de_lieux')
        .select('id', { count: 'exact', head: true })
        .eq('locataire_id', existingUserId);
      if (count && count > 0) {
        return json(
          { error: 'Ce compte est associé à des contrats — suppression impossible.' },
          400,
        );
      }

      // Autorisation fine.
      // deno-lint-ignore no-explicit-any
      const targetEntreprise = (targetProfile as any).entreprise_id;
      // deno-lint-ignore no-explicit-any
      const callerEntreprise = (callerProfile as any)?.entreprise_id;
      const isSuper = callerType === 'super_admin';
      const isSameEntreprise =
        callerType === 'admin_groupe' && callerEntreprise &&
        callerEntreprise === targetEntreprise;
      // deno-lint-ignore no-explicit-any
      const isInviter = (targetProfile as any).invited_by_proprietaire_id === callerId;
      if (!isSuper && !isSameEntreprise && !isInviter) {
        return json(
          { error: 'Vous ne pouvez supprimer que les invitations que vous avez émises.' },
          403,
        );
      }

      const { error: delErr } = await supabase.auth.admin.deleteUser(existingUserId);
      if (delErr) return json({ error: delErr.message }, 500);
      return json({ deleted: true });
    }

    // ── Create mode ────────────────────────────────────────────────────────
    // RÉSERVÉ aux gestionnaires authentifiés : sans ce contrôle, n'importe qui
    // pouvait créer des comptes (service role) avec des données arbitraires.
    {
      const denied = await requireManager(supabase, req);
      if (denied) return denied;
    }
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
