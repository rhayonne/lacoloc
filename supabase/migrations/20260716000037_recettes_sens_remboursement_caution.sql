-- Ajoute la direction du flux d'argent sur une ligne de `Recettes`, pour
-- représenter le **remboursement de la caution** au propriétaire (résiliation
-- du bail sans litige) sans dupliquer la ligne entre les deux parties :
--   sens = 'recevoir' (défaut) → argent dû AU propriétaire (loyer, caution
--          d'entrée, décompte de vétusté…) — comportement inchangé.
--   sens = 'payer'             → argent dû PAR le propriétaire (remboursement
--          de la caution en fin de bail) ; la même ligne est vue par le
--          locataire comme « à recevoir » (inversion faite côté UI/Flutter).
-- `statut` garde exactement les mêmes valeurs ('a_recevoir' | 'recu' |
-- 'en_retard') — sa signification est juste interprétée selon `sens`.

alter table if exists public."Recettes"
  add column if not exists sens text not null default 'recevoir';

alter table if exists public."Recettes"
  drop constraint if exists recettes_sens_check;

alter table if exists public."Recettes"
  add constraint recettes_sens_check check (sens in ('recevoir', 'payer'));

create index if not exists recettes_sens_idx on public."Recettes"(sens);
