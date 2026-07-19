-- « Conditions obligatoires » pour finaliser/signer un EDL (bail + EDL signés
-- ensemble) : mode de caution + garants rattachés à l'EDL. L'avenant
-- (avenant_window_days) et le choix avec/sans garant (bail_avec_garant)
-- existent déjà sur etat_de_lieux ; ils deviennent obligatoires côté appli.

-- 1) Mode de règlement de la caution (dépôt de garantie), choisi par le
--    locataire. Détails selon le mode (chèque → banque/numéro, etc.).
ALTER TABLE public.etat_de_lieux
  ADD COLUMN IF NOT EXISTS caution_mode text
    CHECK (caution_mode IN ('cheque','virement','especes','wero_paypal')),
  ADD COLUMN IF NOT EXISTS caution_details jsonb;

COMMENT ON COLUMN public.etat_de_lieux.caution_mode IS 'Mode de règlement de la caution : cheque | virement | especes | wero_paypal';

-- 2) Garants rattachés à un EDL (sélection parmi les garants actifs du
--    locataire). Un garant peut être lié à plusieurs EDL ; unicité par paire.
CREATE TABLE IF NOT EXISTS public.etat_de_lieux_garants (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  etat_de_lieux_id bigint NOT NULL REFERENCES public.etat_de_lieux(id) ON DELETE CASCADE,
  garant_id bigint NOT NULL REFERENCES public."Garants"(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (etat_de_lieux_id, garant_id)
);
CREATE INDEX IF NOT EXISTS idx_edl_garants_edl ON public.etat_de_lieux_garants(etat_de_lieux_id);

ALTER TABLE public.etat_de_lieux_garants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS edl_garants_select ON public.etat_de_lieux_garants;
CREATE POLICY edl_garants_select ON public.etat_de_lieux_garants
  FOR SELECT USING (public.can_access_edl(etat_de_lieux_id));

DROP POLICY IF EXISTS edl_garants_write ON public.etat_de_lieux_garants;
CREATE POLICY edl_garants_write ON public.etat_de_lieux_garants
  FOR ALL USING (public.can_access_edl(etat_de_lieux_id))
  WITH CHECK (public.can_access_edl(etat_de_lieux_id));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.etat_de_lieux_garants TO authenticated;
