-- Table des garants (caution) liés aux locataires
CREATE TABLE IF NOT EXISTS "Garants" (
  id                  serial        PRIMARY KEY,
  locataire_id        uuid          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type_garant         text          NOT NULL DEFAULT 'physique' CHECK (type_garant IN ('physique', 'morale')),
  type_caution        text          NOT NULL DEFAULT 'solidaire' CHECK (type_caution IN ('simple', 'solidaire')),
  is_active           boolean       NOT NULL DEFAULT true,
  -- Identité
  nom                 text          NOT NULL,
  prenom              text,
  date_naissance      date,
  lieu_naissance      text,
  nationalite         text,
  -- Adresse
  adresse             text,
  code_postal         text,
  ville               text,
  -- Contact
  email               text,
  telephone           text,
  -- Situation professionnelle
  profession          text,
  employeur           text,
  revenu_mensuel_net  numeric(10,2),
  -- Données bancaires
  iban                text,
  bic                 text,
  titulaire_compte    text,
  -- Personne morale uniquement
  raison_sociale      text,
  siret               text,
  representant_legal  text,
  -- Divers
  notes               text,
  created_at          timestamptz   NOT NULL DEFAULT now()
);

ALTER TABLE "Garants" ENABLE ROW LEVEL SECURITY;

-- Locataire : CRUD sur ses propres garants
CREATE POLICY "locataire_own_garants"
  ON "Garants"
  FOR ALL
  TO authenticated
  USING  ( locataire_id = (SELECT auth.uid()) )
  WITH CHECK ( locataire_id = (SELECT auth.uid()) );

-- Propriétaire : lecture des garants de ses locataires (via EDL)
CREATE POLICY "proprietaire_read_garants"
  ON "Garants"
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM etat_de_lieux edl
      WHERE edl.proprietaire_id = (SELECT auth.uid())
        AND edl.locataire_id = "Garants".locataire_id
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON "Garants" TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE "Garants_id_seq" TO authenticated;
