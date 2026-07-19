-- Correction du lint de sécurité `function_search_path_mutable` : on fige le
-- search_path des fonctions (surtout la SECURITY DEFINER handle_new_auth_user,
-- où un search_path mutable est un vecteur d'injection de schéma).
-- Appliqué directement sur Supabase via MCP (le DB est la source de vérité).
alter function public.handle_new_auth_user() set search_path = public;
alter function public.edl_slug(text, integer) set search_path = public;
alter function public.edl_initials(text) set search_path = public;
