-- La recherche de locataires (autocomplete du formulaire d'EDL) ne doit
-- retourner **que** des locataires. L'ancienne version filtrait sur
-- `uc.type_user_id = 1` (id codé en dur). On remplace ce filtre fragile par
-- une jointure sur `User_Types_Reference` et `code = 'locataire'` — même
-- résultat, mais robuste si les ids de types changent.
--
-- La garde de sécurité est conservée telle quelle : appelant authentifié +
-- rôle gestionnaire ; execute révoqué de anon/public, accordé à authenticated.
--
-- NB : DROP + CREATE pour éviter tout refus de CREATE OR REPLACE si la
-- signature diffère de l'existante.

DROP FUNCTION IF EXISTS public.search_locataires(text);

CREATE FUNCTION public.search_locataires(search_query text DEFAULT ''::text)
 RETURNS TABLE(
   id uuid,
   full_name text,
   email text,
   phone text,
   created_at timestamp with time zone
 )
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    uc.id, uc.full_name, uc.email, uc.phone, uc.created_at
  FROM "Users_Client" uc
  JOIN "User_Types_Reference" utr ON utr.id = uc.type_user_id
  WHERE utr.code = 'locataire'   -- n'inclut QUE les locataires (plus de id hardcodé)
    AND auth.uid() IS NOT NULL
    AND public.current_user_role() IN ('proprietaire', 'admin_groupe', 'super_admin')
    AND (
      search_query = ''
      OR uc.full_name ILIKE '%' || search_query || '%'
      OR uc.email ILIKE '%' || search_query || '%'
    )
  ORDER BY uc.full_name ASC NULLS LAST
  LIMIT 20;
$function$;

REVOKE ALL     ON FUNCTION public.search_locataires(text) FROM anon, public;
GRANT  EXECUTE ON FUNCTION public.search_locataires(text) TO authenticated;
