-- Choix du propriétaire à la création/génération du bail : le bail nécessite-t-il
-- un (ou des) garant(s) ? NULL = non encore décidé ; true = garant requis ;
-- false = sans garant. Quand true et que le locataire n'a aucun garant actif,
-- le bail ne peut pas être imprimé (gate côté app) et le locataire est notifié.
ALTER TABLE etat_de_lieux
  ADD COLUMN IF NOT EXISTS bail_avec_garant boolean;

COMMENT ON COLUMN etat_de_lieux.bail_avec_garant IS
  'Le bail nécessite un garant ? NULL=non décidé, true=requis, false=sans garant.';
