import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Non autorisé' }, 401);

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // Verifica o chamador via JWT
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return json({ error: 'Non autorisé' }, 401);

  const body = await req.json();
  const { targetUserId, action } = body as {
    targetUserId?: string;
    action?: string;
  };

  if (!targetUserId || !['ban', 'unban'].includes(action ?? '')) {
    return json({ error: 'Paramètres invalides (targetUserId, action: ban|unban)' }, 400);
  }

  // Verifica o tipo do chamador
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

  // Se admin_groupe, verifica que o alvo pertence à mesma empresa
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

  // '876600h' ≈ 100 ans = ban permanente; 'none' = desbanimento
  const banDuration = action === 'ban' ? '876600h' : 'none';
  const { error: banError } = await adminClient.auth.admin.updateUser(targetUserId, {
    ban_duration: banDuration,
  });

  if (banError) return json({ error: banError.message }, 500);

  return json({ ok: true });
});
