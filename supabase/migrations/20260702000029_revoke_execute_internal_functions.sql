-- Réduction de la surface d'attaque (lint anon/authenticated_security_definer
-- _function_executable) : ces fonctions sont soit des triggers (exécutés en tant
-- que propriétaire de la table, jamais appelés en RPC), soit internes
-- (build_edl_code n'est utilisé que par le trigger set_edl_code). On révoque
-- EXECUTE de public/anon/authenticated — sans impact fonctionnel.
-- NB : les fonctions-prédicats de RLS (is_super_admin, can_access_edl, …) NE
-- sont PAS touchées : elles doivent rester exécutables sinon la RLS casse.
-- Appliqué directement sur Supabase via MCP (le DB est la source de vérité).

-- Fonctions trigger (retour `trigger`, sans arguments)
revoke execute on function public.assert_locataire_type()        from public, anon, authenticated;
revoke execute on function public.handle_new_auth_user()          from public, anon, authenticated;
revoke execute on function public.prevent_role_self_escalation()  from public, anon, authenticated;
revoke execute on function public.set_default_user_group()        from public, anon, authenticated;
revoke execute on function public.set_edl_code()                  from public, anon, authenticated;
revoke execute on function public.set_edl_entreprise()            from public, anon, authenticated;
revoke execute on function public.set_entreprise_from_owner()     from public, anon, authenticated;
revoke execute on function public.set_immeuble_entreprise()       from public, anon, authenticated;

-- Event trigger
revoke execute on function public.rls_auto_enable()               from public, anon, authenticated;

-- Fonction interne appelée uniquement par le trigger set_edl_code (definer)
revoke execute on function public.build_edl_code(bigint, uuid, text, date) from public, anon, authenticated;
