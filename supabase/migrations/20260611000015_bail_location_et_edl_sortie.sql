-- Renommage du bail « collectif » → « location » + couplage EDL sortie ↔ entrée.
--
-- Contexte :
--  • Le bail « collectif » (plusieurs locataires, UN seul contrat partagé, sans
--    baux individuels rattachés) prêtait à confusion avec le « collectif » =
--    parties communes d'un bail individuel. On le renomme « location » (simple).
--  • Un EDL de sortie est créé à partir d'un EDL d'entrée FINALISÉ et lui reste
--    couplé (edl_entree_id) pour la copie de structure + le contrepoint PDF.

-- 1) Immeubles : bail_collectif → bail_location.
--    ALTER ... RENAME COLUMN propage automatiquement aux policies RLS / vues /
--    contraintes dépendantes (suivi de dépendances Postgres).
alter table public."Immeubles"
  rename column bail_collectif to bail_location;

-- 2) etat_de_lieux.type_bail : 'collectif' → 'location'.
--    Un CHECK n'autorisait que ('collectif','individuel') → on le remplace par
--    ('location','individuel') autour de l'UPDATE.
alter table public.etat_de_lieux
  drop constraint if exists etat_de_lieux_type_bail_check;

update public.etat_de_lieux
  set type_bail = 'location'
  where type_bail = 'collectif';

alter table public.etat_de_lieux
  add constraint etat_de_lieux_type_bail_check
    check (type_bail = any (array['location'::text, 'individuel'::text]));

-- 3) etat_de_lieux : couplage d'un EDL de sortie à son EDL d'entrée source.
--    Vaut pour le collectif (partie=commune) comme pour le privatif.
alter table public.etat_de_lieux
  add column if not exists edl_entree_id bigint
    references public.etat_de_lieux(id) on delete set null;

create index if not exists idx_edl_entree
  on public.etat_de_lieux(edl_entree_id);
