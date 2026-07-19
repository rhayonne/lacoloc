-- ══════════════════════════════════════════════════════════════════════════════
-- Lots de copropriété (unité légale rattachée à un immeuble)
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. Table des lots (numéro de lot du règlement de copropriété + tantièmes)
CREATE TABLE IF NOT EXISTS "Immeuble_Lots" (
  id           SERIAL PRIMARY KEY,
  immeuble_id  INT  NOT NULL REFERENCES "Immeubles"(id) ON DELETE CASCADE,
  numero_lot   TEXT NOT NULL,
  type_lot     TEXT NOT NULL CHECK (type_lot IN ('habitation', 'cave', 'parking', 'grenier', 'autre')) DEFAULT 'habitation',
  tantiemes    NUMERIC(10,2),
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE "Immeuble_Lots" ENABLE ROW LEVEL SECURITY;

-- Privé : seul le propriétaire de l'immeuble gère ses lots (donnée légale/admin,
-- pas d'exposition publique comme les pièces/inventaire).
CREATE POLICY "immeuble_lots_owner_all" ON "Immeuble_Lots"
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM "Immeubles" i WHERE i.id = immeuble_id AND i.owner_id = auth.uid()
    )
  );

-- 2. Copropriété au niveau de l'immeuble : nom + syndic (réutilise Fournisseurs,
--    catégorie « Syndic / Copropriété » déjà existante).
ALTER TABLE "Immeubles"
  ADD COLUMN IF NOT EXISTS nom_copropriete       TEXT,
  ADD COLUMN IF NOT EXISTS syndic_fournisseur_id INT REFERENCES "Fournisseurs"(id) ON DELETE SET NULL;
