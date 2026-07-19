-- Accès TOTAL du super admin aux états des lieux (menu « États des lieux »
-- de l'administration) : sans ces politiques, la RLS ne laissait voir les EDL
-- qu'au propriétaire/locataire → la page admin listait « Aucun état des
-- lieux » et aucune édition/suppression n'était possible.
-- Les tables filles (preneurs, relevés, clés, sections, lignes, garants du
-- bail) passent déjà par can_access_edl()/can_write_edl(), qui incluent le
-- super admin — rien à faire là.

-- L'EDL lui-même : tout (select/insert/update/delete), tous les EDL.
drop policy if exists super_admin_all_etat_de_lieux on public.etat_de_lieux;
create policy super_admin_all_etat_de_lieux
  on public.etat_de_lieux
  for all
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- Observations (politiques par rôle/addition qui n'incluent pas l'admin).
drop policy if exists super_admin_all_edl_observations on public.etat_de_lieux_observations;
create policy super_admin_all_edl_observations
  on public.etat_de_lieux_observations
  for all
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- Chambres : lecture (fiche) + écriture (setActive remet est_loue à jour).
drop policy if exists super_admin_all_chambres on public."Chambres";
create policy super_admin_all_chambres
  on public."Chambres"
  for all
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- Lecture des données nécessaires à la fiche EDL côté admin.
drop policy if exists super_admin_select_immeubles on public."Immeubles";
create policy super_admin_select_immeubles
  on public."Immeubles" for select to authenticated
  using (public.is_super_admin());

drop policy if exists super_admin_select_pieces on public."Pieces";
create policy super_admin_select_pieces
  on public."Pieces" for select to authenticated
  using (public.is_super_admin());

drop policy if exists super_admin_select_inventaire on public."Inventaire";
create policy super_admin_select_inventaire
  on public."Inventaire" for select to authenticated
  using (public.is_super_admin());

drop policy if exists super_admin_select_garants on public."Garants";
create policy super_admin_select_garants
  on public."Garants" for select to authenticated
  using (public.is_super_admin());
