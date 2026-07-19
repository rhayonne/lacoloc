-- ══════════════════════════════════════════════════════════════════════════════
-- Système de charges locatives
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. Table de référence des charges (gérée par le super admin)
CREATE TABLE IF NOT EXISTS "Charges_Reference" (
  id          SERIAL PRIMARY KEY,
  nom         TEXT    NOT NULL,
  icone       TEXT    NOT NULL DEFAULT 'receipt_long',
  description TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  ordre       INT     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE "Charges_Reference" ENABLE ROW LEVEL SECURITY;

-- Lecture publique (annonces publiques)
CREATE POLICY "charges_ref_select_public" ON "Charges_Reference"
  FOR SELECT USING (true);

-- Écriture : super admin uniquement
CREATE POLICY "charges_ref_write_superadmin" ON "Charges_Reference"
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM "Users_Client" uc
      JOIN "User_Types_Reference" utr ON utr.id = uc.type_user_id
      WHERE uc.id = auth.uid() AND utr.code = 'super_admin'
    )
  );

-- Seed : charges les plus courantes en location française
INSERT INTO "Charges_Reference" (nom, icone, description, ordre) VALUES
  ('Eau froide',                  'water_drop',            'Consommation d''eau froide (compteur collectif ou forfait)',   1),
  ('Eau chaude',                  'thermostat',            'Production d''eau chaude sanitaire collective',                2),
  ('Chauffage collectif',         'local_fire_department', 'Chauffage central ou collectif',                              3),
  ('Électricité parties communes','bolt',                  'Éclairage et prises des parties communes',                    4),
  ('Internet / Wi-Fi',            'wifi',                  'Accès internet partagé inclus dans le logement',              5),
  ('Ordures ménagères',           'delete_outline',        'Enlèvement des ordures ménagères (TEOM ou forfait)',           6),
  ('Entretien parties communes',  'cleaning_services',     'Ménage, nettoyage des couloirs, paliers, etc.',               7),
  ('Gardiennage / Sécurité',      'security',              'Gardien, digicode, interphone, badge d''accès',               8),
  ('Ascenseur',                   'elevator',              'Maintenance et utilisation de l''ascenseur',                  9),
  ('Assurance copropriété',       'verified_user',         'Quote-part de l''assurance de l''immeuble',                  10),
  ('Interphone',                  'doorbell',              'Abonnement et maintenance interphone',                        11),
  ('Espaces verts',               'park',                  'Entretien jardin, cour, terrasse commune',                   12),
  ('Cave / Cellier',              'storage',               'Accès à une cave ou cellier privatif',                       13),
  ('Parking / Box',               'local_parking',         'Place de stationnement ou box inclus',                       14),
  ('Autres charges',              'receipt_long',          'Charges diverses non catégorisées',                          15);

-- 2. Charges rattachées à un immeuble (bail location)
CREATE TABLE IF NOT EXISTS "Immeuble_Charges" (
  id            SERIAL PRIMARY KEY,
  immeuble_id   INT  NOT NULL REFERENCES "Immeubles"(id) ON DELETE CASCADE,
  charge_ref_id INT  NOT NULL REFERENCES "Charges_Reference"(id),
  type          TEXT NOT NULL CHECK (type IN ('inclus', 'fixe')) DEFAULT 'inclus',
  montant       NUMERIC(10,2),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (immeuble_id, charge_ref_id)
);

ALTER TABLE "Immeuble_Charges" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "immeuble_charges_public_read" ON "Immeuble_Charges"
  FOR SELECT USING (true);

CREATE POLICY "immeuble_charges_owner_write" ON "Immeuble_Charges"
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM "Immeubles" i WHERE i.id = immeuble_id AND i.owner_id = auth.uid()
    )
  );

-- 3. Charges rattachées à une chambre (bail individuel / colocation)
CREATE TABLE IF NOT EXISTS "Chambre_Charges" (
  id            SERIAL PRIMARY KEY,
  chambre_id    INT  NOT NULL REFERENCES "Chambres"(id) ON DELETE CASCADE,
  charge_ref_id INT  NOT NULL REFERENCES "Charges_Reference"(id),
  type          TEXT NOT NULL CHECK (type IN ('inclus', 'fixe')) DEFAULT 'inclus',
  montant       NUMERIC(10,2),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (chambre_id, charge_ref_id)
);

ALTER TABLE "Chambre_Charges" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chambre_charges_public_read" ON "Chambre_Charges"
  FOR SELECT USING (true);

CREATE POLICY "chambre_charges_owner_write" ON "Chambre_Charges"
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM "Chambres" c
      JOIN "Immeubles" i ON c.immeuble_id = i.id
      WHERE c.id = chambre_id AND i.owner_id = auth.uid()
    )
  );

-- 4. Nouveaux champs dans Immeubles (bail + DPE + IRL)
ALTER TABLE "Immeubles"
  ADD COLUMN IF NOT EXISTS depot_garantie_mois NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS dpe_classe          CHAR(1) CHECK (dpe_classe IN ('A','B','C','D','E','F','G')),
  ADD COLUMN IF NOT EXISTS irl_reference       TEXT,
  ADD COLUMN IF NOT EXISTS duree_bail_mois     INT;

-- 5. Nouveaux champs dans Chambres
ALTER TABLE "Chambres"
  ADD COLUMN IF NOT EXISTS depot_garantie_mois NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS duree_bail_mois     INT;
