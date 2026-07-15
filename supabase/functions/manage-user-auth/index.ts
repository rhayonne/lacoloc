import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function corsFor(req: Request) {
  return {
    'Access-Control-Allow-Origin': req.headers.get('Origin') ?? '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers':
      req.headers.get('Access-Control-Request-Headers') ??
      'authorization, x-client-info, apikey, content-type',
  };
}

Deno.serve(async (req) => {
  const cors = corsFor(req);

  const json = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors });
  }

  // try/catch global : on garantit qu'aucune réponse ne part sans en-têtes CORS
  // (sinon le navigateur affiche « Failed to fetch » au lieu du vrai message).
  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Non autorisé' }, 401);

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: 'Non autorisé' }, 401);

    const body = await req.json();
    const { targetUserId, action, newPassword } = body as {
      targetUserId?: string;
      action?: string;
      newPassword?: string;
    };

    const allowed = ['ban', 'unban', 'set_password'];
    if (!targetUserId || !allowed.includes(action ?? '')) {
      return json({ error: 'Paramètres invalides (targetUserId, action: ban|unban|set_password)' }, 400);
    }

    // Vérification du profil appelant
    const { data: callerProfile, error: profileError } = await adminClient
      .from('Users_Client')
      .select('entreprise_id, User_Types_Reference(code)')
      .eq('id', user.id)
      .single();

    if (profileError || !callerProfile) return json({ error: 'Profil introuvable' }, 403);

    const callerType = (callerProfile as any).User_Types_Reference?.code as string;

    if (callerType !== 'super_admin' && callerType !== 'admin_groupe') {
      return json({ error: 'Interdit' }, 403);
    }

    if (callerType === 'admin_groupe') {
      const callerEntrepriseId = (callerProfile as any).entreprise_id;
      const { data: targetProfile } = await adminClient
        .from('Users_Client')
        .select('entreprise_id')
        .eq('id', targetUserId)
        .single();

      if (
        !callerEntrepriseId ||
        callerEntrepriseId !== (targetProfile as any)?.entreprise_id
      ) {
        return json({ error: 'Interdit — utilisateur hors de votre entreprise' }, 403);
      }
    }

    // ── set_password ──────────────────────────────────────────────────────
    if (action === 'set_password') {
      if (!newPassword || newPassword.length < 6) {
        return json({ error: 'Mot de passe trop court (6 caractères minimum)' }, 400);
      }
      // supabase-js v2 : la méthode admin est updateUserById (pas updateUser !)
      const { error: pwError } = await adminClient.auth.admin.updateUserById(
        targetUserId,
        { password: newPassword },
      );
      if (pwError) return json({ error: pwError.message }, 500);
      return json({ ok: true });
    }

    // ── ban / unban ───────────────────────────────────────────────────────────
    const banDuration = action === 'ban' ? '876600h' : 'none';
    const { error: banError } = await adminClient.auth.admin.updateUserById(
      targetUserId,
      { ban_duration: banDuration },
    );

    if (banError) return json({ error: banError.message }, 500);

    return json({ ok: true });
  } catch (e) {
    return json({ error: `Erreur serveur : ${(e as Error).message}` }, 500);
  }
});
