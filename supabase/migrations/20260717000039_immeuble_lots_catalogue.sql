-- ══════════════════════════════════════════════════════════════════════════════
-- Lots de copropriété — catalogue indépendant (créés à part, puis rattachés à
-- un immeuble). Regroupe aussi les infos de copropriété (nom, adresse, syndic)
-- qui vivaient jusqu'ici au niveau de l'immeuble.
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. Le lot appartient au propriétaire (owner_id), pas seulement à l'immeuble :
--    on peut le créer avant de savoir à quel immeuble il sera rattaché.
ALTER TABLE "Immeuble_Lots"
  ALTER COLUMN immeuble_id DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS owner_id              UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS nom_copropriete        TEXT,
  ADD COLUMN IF NOT EXISTS adresse_copropriete     TEXT,
  ADD COLUMN IF NOT EXISTS syndic_fournisseur_id   INT REFERENCES "Fournisseurs"(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS batiment                TEXT,
  ADD COLUMN IF NOT EXISTS etage                   TEXT,
  ADD COLUMN IF NOT EXISTS porte                   TEXT,
  ADD COLUMN IF NOT EXISTS reference_cadastrale    TEXT,
  ADD COLUMN IF NOT EXISTS tantiemes_total         NUMERIC(10,2);

-- Backfill : associe le owner_id de l'immeuble déjà rattaché (données de test).
UPDATE "Immeuble_Lots" l
SET owner_id = i.owner_id
FROM "Immeubles" i
WHERE l.immeuble_id = i.id AND l.owner_id IS NULL AND i.owner_id IS NOT NULL;

-- Détacher un immeuble ne doit pas supprimer le lot (donnée légale indépendante)
ALTER TABLE "Immeuble_Lots" DROP CONSTRAINT IF EXISTS "Immeuble_Lots_immeuble_id_fkey";
ALTER TABLE "Immeuble_Lots"
  ADD CONSTRAINT "Immeuble_Lots_immeuble_id_fkey"
  FOREIGN KEY (immeuble_id) REFERENCES "Immeubles"(id) ON DELETE SET NULL;

-- RLS basée directement sur owner_id (le lot peut exister sans immeuble)
DROP POLICY IF EXISTS "immeuble_lots_owner_all" ON "Immeuble_Lots";
CREATE POLICY "immeuble_lots_owner_all" ON "Immeuble_Lots"
  FOR ALL USING (owner_id = auth.uid());

-- 2. Les infos de copropriété (nom, syndic) déménagent de l'immeuble vers le lot.
ALTER TABLE "Immeubles"
  DROP COLUMN IF EXISTS nom_copropriete,
  DROP COLUMN IF EXISTS syndic_fournisseur_id;
