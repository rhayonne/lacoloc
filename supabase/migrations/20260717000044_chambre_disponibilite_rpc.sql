-- RPC publique : disponibilité d'une chambre + date de libération connue.
--
-- Contexte : la recherche de logement (locataire, public) doit pouvoir
-- afficher les chambres déjà louées (le locataire veut voir « ce qui va se
-- libérer bientôt »), avec un filtre pour les masquer et un filtre
-- « disponible à partir du <date> ». La date de fin du bail en cours vit dans
-- `etat_de_lieux` (RLS réservée aux parties du contrat) — impossible à lire
-- directement pour un visiteur qui parcourt les annonces.
--
-- Comme `chambre_equipements_annonce` : SECURITY DEFINER, n'expose **aucune**
-- donnée sensible (pas d'identité de locataire, pas de montant) — seulement
-- chambre_id + un booléen + une date.
create or replace function public.chambre_disponibilite(p_chambre_ids bigint[] default null)
returns table(chambre_id bigint, disponible boolean, date_disponible date)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id as chambre_id,
    not c.est_loue as disponible,
    case
      when not c.est_loue then current_date
      else (
        select coalesce(e.bail_fin_effective, e.date_fin_bail)
          from etat_de_lieux e
         where e.chambre_id = c.id
           and e.partie = 'privative'
           and e.type_edl = 'entree'
           and e.actif = true
         order by e.created_at desc
         limit 1
      )
    end as date_disponible
  from "Chambres" c
  where c.is_active = true
    and (p_chambre_ids is null or c.id = any(p_chambre_ids));
$$;

revoke execute on function public.chambre_disponibilite(bigint[]) from public;
grant execute on function public.chambre_disponibilite(bigint[]) to anon, authenticated;
