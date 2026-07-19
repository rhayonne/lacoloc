-- Les deux parties d'une demande de contact doivent pouvoir se voir.
--
-- Problème : la RLS de `Users_Client` n'autorisait la lecture croisée que via
-- un `etat_de_lieux` partagé (ou `invited_by_proprietaire_id`). Or une
-- **demande de contact** ne crée ni l'un ni l'autre → le proprietaire voyait
-- « — » à la place du nom/âge/téléphone/e-mail du locataire (alors que le
-- tableau des demandes est justement fait pour décider qui accepter), et le
-- locataire voyait « Propriétaire : — ». Idem pour le nom de l'expéditeur dans
-- le fil de discussion (`Messages` → embed `Users_Client!sender_id`).
--
-- Une demande de contact est précisément une mise en relation : à partir du
-- moment où elle existe, chaque partie voit l'identité de l'autre — et
-- **uniquement** celle de l'autre partie d'une demande la concernant.
--
-- SECURITY DEFINER (comme `can_access_edl`) pour ne pas dépendre de la RLS de
-- `Demandes_Contact`/`Immeubles` à l'intérieur d'une politique de RLS.
create or replace function public.shares_demande_with(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public."Demandes_Contact" d
      left join public."Immeubles" i on i.id = d.immeuble_id
     where (d.locataire_id = auth.uid() and i.owner_id = p_user)
        or (i.owner_id      = auth.uid() and d.locataire_id = p_user)
  );
$$;

revoke execute on function public.shares_demande_with(uuid) from public, anon;
grant execute on function public.shares_demande_with(uuid) to authenticated;

-- Une seule politique, symétrique : je vois l'autre partie de mes demandes.
drop policy if exists users_client_select_demande_counterpart on public."Users_Client";
create policy users_client_select_demande_counterpart on public."Users_Client"
  for select to authenticated
  using (public.shares_demande_with(id));
