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

/// Extrait l'IP réelle du client depuis les headers de la requête.
/// Deno Deploy / Supabase placent l'IP dans x-forwarded-for ou x-real-ip.
function extractIp(req: Request): string {
  return (
    req.headers.get('cf-connecting-ip') ??
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('x-real-ip') ??
    'unknown'
  );
}

/// Identifie l'OS / l'appareil à partir du User-Agent.
function parseDevice(ua: string): string {
  if (/iPhone/i.test(ua)) return 'iPhone';
  if (/iPad/i.test(ua)) return 'iPad';
  if (/Android/i.test(ua)) return 'Android';
  if (/CrOS/i.test(ua)) return 'ChromeOS';
  if (/Windows NT/i.test(ua)) return 'Windows';
  if (/Macintosh|Mac OS X/i.test(ua)) return 'Mac';
  if (/Linux/i.test(ua)) return 'Linux';
  return 'Inconnu';
}

/// Identifie le navigateur à partir du User-Agent.
function parseBrowser(ua: string): string {
  if (/Edg\//i.test(ua)) return 'Edge';
  if (/OPR\//i.test(ua)) return 'Opera';
  if (/YaBrowser/i.test(ua)) return 'Yandex';
  if (/SamsungBrowser/i.test(ua)) return 'Samsung';
  if (/Chrome\//i.test(ua)) return 'Chrome';
  if (/Firefox\//i.test(ua)) return 'Firefox';
  if (/Safari\//i.test(ua)) return 'Safari';
  return 'Inconnu';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // JWT obligatoire — l'appelant est l'utilisateur qui vient de se connecter.
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

  // Vérification du JWT
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return json({ error: 'Non autorisé' }, 401);

  // Corps optionnel envoyé par le client Flutter (timezone, …)
  let body: Record<string, string> = {};
  try { body = await req.json(); } catch (_) { /* corps absent ou invalide */ }

  // IP + User-Agent depuis les headers HTTP (plus fiable que le corps)
  const ip = extractIp(req);
  const ua = req.headers.get('user-agent') ?? '';
  const device = parseDevice(ua);
  const browser = parseBrowser(ua);
  const timezone = (body['timezone'] ?? '').slice(0, 64) || null;

  // Récupération du profil (nom + type) via service role
  const { data: profile } = await adminClient
    .from('Users_Client')
    .select('full_name, User_Types_Reference!type_user_id(code)')
    .eq('id', user.id)
    .maybeSingle();

  // deno-lint-ignore no-explicit-any
  const p = profile as any;
  const userName: string = p?.full_name ?? user.email ?? '';
  const userType: string = p?.User_Types_Reference?.code ?? '';

  await adminClient.from('connection_logs').insert({
    user_id: user.id,
    user_email: user.email,
    user_name: userName,
    user_type: userType,
    ip_address: ip,
    user_agent: ua,
    device,
    browser,
    timezone,
  });

  return json({ ok: true });
});
