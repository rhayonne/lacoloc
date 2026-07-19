-- Le card « Locataires invités » ne doit montrer que les comptes **encore en
-- attente d'activation**. On exclut ceux dont l'activation est terminée
-- (`auth.users.raw_user_meta_data->>'needs_completion' = 'false'`, posé à la fin
-- de CompleterInscriptionPage). Les comptes sans la clé (legacy) ou à 'true'
-- restent visibles.

CREATE OR REPLACE FUNCTION public.list_invited_locataires(p_proprietaire_id uuid)
 RETURNS TABLE(id uuid, full_name text, email text, phone text, created_at timestamp with time zone, invitation_email_sent boolean, invitation_sent_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    uc.id,
    uc.full_name,
    uc.email,
    uc.phone,
    uc.created_at,
    uc.invitation_email_sent,
    uc.invitation_sent_at
  FROM "Users_Client" uc
  WHERE uc.invited_by_proprietaire_id = p_proprietaire_id
  AND (
    uc.invitation_sent_at IS NULL
    OR uc.invitation_sent_at >= NOW() - INTERVAL '20 days'
  )
  AND EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = uc.id
      AND (au.raw_user_meta_data ->> 'needs_completion') IS DISTINCT FROM 'false'
  )
  ORDER BY uc.created_at DESC;
$function$;
