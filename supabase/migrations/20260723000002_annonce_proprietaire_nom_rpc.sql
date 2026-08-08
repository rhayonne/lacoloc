-- RPC `annonce_proprietaire_nom(immeuble)` — nom du propriétaire d'une annonce.
--
-- Utilisée par le pop-up « Entrer en contact » (avant qu'une demande n'existe,
-- donc avant que la politique `users_client_select_demande_counterpart` ne donne
-- au locataire l'accès au profil du propriétaire). N'expose que le nom, et
-- seulement pour un immeuble actif. Réservée aux authentifiés.
--
-- Appliquée en prod le 2026-07-23 (via MCP) ; consignée ici pour `db reset`.

create or replace function public.annonce_proprietaire_nom(p_immeuble_id bigint)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select u.full_name
    from public."Immeubles" i
    join public."Users_Client" u on u.id = i.owner_id
   where i.id = p_immeuble_id
     and coalesce(i.is_active, true) = true
$$;

revoke execute on function public.annonce_proprietaire_nom(bigint) from public, anon;
grant execute on function public.annonce_proprietaire_nom(bigint) to authenticated;
