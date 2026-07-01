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

/// Calcule l'empreinte SHA-256 (hex) d'une chaîne canonique.
async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/// Enregistre une entrée d'audit de signature électronique (faisceau d'indices).
/// Body : { edlId, documentType: 'edl'|'bail', role: 'proprietaire'|'locataire' }
/// - Valide le JWT de l'appelant (identité non falsifiable).
/// - Vérifie via RLS que l'appelant a accès à l'EDL (sinon 403).
/// - Calcule l'empreinte d'intégrité côté serveur à partir des données de l'EDL.
/// - Capture l'IP et le user-agent ; insère via service role (journal immuable).
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const { edlId, documentType, role } = await req.json();
    if (!edlId || !documentType || !role) {
      return json({ error: 'Paramètres manquants.' }, 400);
    }
    if (!['edl', 'bail'].includes(documentType) ||
        !['proprietaire', 'locataire'].includes(role)) {
      return json({ error: 'Paramètres invalides.' }, 400);
    }

    const authHeader = req.headers.get('Authorization') ?? '';
    const service = createClient(
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
      return json({ error: 'Non authentifié.' }, 401);
    }

    // L'appelant doit pouvoir voir l'EDL (RLS) → faisceau d'indices légitime.
    const { data: edl } = await userClient
      .from('etat_de_lieux')
      .select(
        'id, type_edl, partie, type_bail, proprietaire_id, locataire_id, ' +
        'date_etat_lieux, montant, proprietaire_signature_url, ' +
        'locataire_signature_url, proprietaire_signed_at, locataire_signed_at',
      )
      .eq('id', edlId)
      .maybeSingle();
    if (!edl) {
      return json({ error: "Accès refusé à cet état des lieux." }, 403);
    }

    // Empreinte d'intégrité : hash des données canoniques de l'EDL au moment
    // de la signature (lie l'audit à l'état exact du document).
    const canonical = [
      documentType,
      edl.id,
      edl.type_edl,
      edl.partie,
      edl.type_bail,
      edl.proprietaire_id,
      edl.locataire_id,
      edl.date_etat_lieux,
      edl.montant,
      edl.proprietaire_signature_url,
      edl.locataire_signature_url,
      edl.proprietaire_signed_at,
      edl.locataire_signed_at,
    ].map((v) => (v === null || v === undefined ? '' : String(v))).join('|');
    const documentHash = await sha256Hex(canonical);

    const ip = (req.headers.get('x-forwarded-for') ?? '')
      .split(',')[0].trim() || null;
    const userAgent = req.headers.get('user-agent') ?? null;

    const { error: insErr } = await service.from('signature_audit').insert({
      etat_de_lieux_id: edl.id,
      document_type: documentType,
      role,
      signer_id: caller.user.id,
      signer_email: caller.user.email ?? null,
      document_hash: documentHash,
      ip_address: ip,
      user_agent: userAgent,
    });
    if (insErr) {
      return json({ error: insErr.message }, 500);
    }

    return json({ ok: true, documentHash });
  } catch (err) {
    return json(
      { error: err instanceof Error ? err.message : String(err) },
      500,
    );
  }
});
