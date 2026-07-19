-- Table de référence pour les catégories de meuble (gérée par le super admin)
CREATE TABLE IF NOT EXISTS "Meuble_Categories_Reference" (
  id    serial  PRIMARY KEY,
  nom   text    NOT NULL,
  ordre integer NOT NULL DEFAULT 0
);

ALTER TABLE "Meuble_Categories_Reference" ENABLE ROW LEVEL SECURITY;

-- Tous les utilisateurs authentifiés peuvent lire
CREATE POLICY "all_can_read_meuble_categories"
  ON "Meuble_Categories_Reference"
  FOR SELECT
  TO authenticated
  USING (true);

-- Seul le super admin peut créer / modifier / supprimer
CREATE POLICY "super_admin_can_manage_meuble_categories"
  ON "Meuble_Categories_Reference"
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM "Users_Client" uc
      JOIN "User_Types_Reference" utr ON utr.id = uc.type_user_id
      WHERE uc.id = (SELECT auth.uid()) AND utr.code = 'super_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "Users_Client" uc
      JOIN "User_Types_Reference" utr ON utr.id = uc.type_user_id
      WHERE uc.id = (SELECT auth.uid()) AND utr.code = 'super_admin'
    )
  );

-- Seed initial
INSERT INTO "Meuble_Categories_Reference" (nom, ordre) VALUES
  ('Mobilier',         10),
  ('Literie',          20),
  ('Électroménager',   30),
  ('Rangement',        40),
  ('Cuisine',          50),
  ('Salle de bain',    60),
  ('Éclairage',        70),
  ('Décoration',       80),
  ('Électronique',     90),
  ('Autre',           100)
ON CONFLICT DO NOTHING;
