-- Configuration du bail (posée par le propriétaire dans l'onglet « Configuration
-- bail » de l'EDL, puisque bail et EDL sont signés ensemble) + résiliation.
--
-- preavis_mois : durée de préavis configurable (défaut applicatif : 1 mois en
--   meublée, 3 en location vide). Sert au calcul du prorata à la rupture.
-- bail_conge_date : date du congé/résiliation notifiée.
-- bail_fin_effective : fin effective = congé + préavis (loyer dû jusque-là).
-- bail_resilie_motif / bail_resilie_at : motif + horodatage de la résiliation.

ALTER TABLE public.etat_de_lieux
  ADD COLUMN IF NOT EXISTS preavis_mois integer,
  ADD COLUMN IF NOT EXISTS bail_conge_date date,
  ADD COLUMN IF NOT EXISTS bail_fin_effective date,
  ADD COLUMN IF NOT EXISTS bail_resilie_motif text,
  ADD COLUMN IF NOT EXISTS bail_resilie_at timestamptz;

COMMENT ON COLUMN public.etat_de_lieux.preavis_mois IS 'Préavis configurable (mois) ; null → défaut applicatif (1 meublée / 3 vide)';
COMMENT ON COLUMN public.etat_de_lieux.bail_fin_effective IS 'Fin effective du bail = bail_conge_date + preavis_mois (loyer dû jusque-là)';
