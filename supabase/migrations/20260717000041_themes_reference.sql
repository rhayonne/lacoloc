-- ══════════════════════════════════════════════════════════════════════════════
-- Thèmes de l'application (gérés par le super admin)
-- ══════════════════════════════════════════════════════════════════════════════
-- Un thème = 3 couleurs sources (collées depuis huemint.com) ; l'app dérive le
-- reste de la palette (surfaces, bordures, on-colors…) — voir
-- lib/theme/palette_builder.dart.
--
-- Les thèmes « intégrés » (is_builtin) n'ont pas de couleurs sources : leur
-- palette est réglée à la main dans lib/theme/app_palette.dart. La ligne existe
-- quand même ici pour qu'on puisse les activer/désactiver et en faire le thème
-- par défaut comme les autres.

CREATE TABLE IF NOT EXISTS "Themes_Reference" (
  id               SERIAL PRIMARY KEY,
  code             TEXT NOT NULL UNIQUE,
  label            TEXT NOT NULL,
  description      TEXT,

  -- Les 3 couleurs sources, en hex « #RRGGBB ». NULL si is_builtin.
  color_surface    TEXT,  -- Fond de page (le papier)
  color_on_surface TEXT,  -- Texte (l'encre)
  color_primary    TEXT,  -- Action (les boutons)

  is_builtin       BOOLEAN NOT NULL DEFAULT false,  -- non supprimable
  is_active        BOOLEAN NOT NULL DEFAULT true,   -- proposé dans « Mon profil »
  is_default       BOOLEAN NOT NULL DEFAULT false,  -- vu par les visiteurs
  ordre            INT NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Un thème personnalisé doit porter ses 3 couleurs ; un thème intégré non.
  CONSTRAINT themes_custom_needs_colors CHECK (
    is_builtin OR (
      color_surface IS NOT NULL AND
      color_on_surface IS NOT NULL AND
      color_primary IS NOT NULL
    )
  ),
  CONSTRAINT themes_hex_format CHECK (
    (color_surface    IS NULL OR color_surface    ~* '^#[0-9a-f]{6}$') AND
    (color_on_surface IS NULL OR color_on_surface ~* '^#[0-9a-f]{6}$') AND
    (color_primary    IS NULL OR color_primary    ~* '^#[0-9a-f]{6}$')
  )
);

-- Un seul thème par défaut à la fois.
CREATE UNIQUE INDEX IF NOT EXISTS themes_single_default
  ON "Themes_Reference" ((is_default)) WHERE is_default;

ALTER TABLE "Themes_Reference" ENABLE ROW LEVEL SECURITY;

-- Lecture publique : un visiteur non connecté doit pouvoir charger le thème
-- par défaut avant toute session. Ce sont des données purement cosmétiques.
DROP POLICY IF EXISTS "themes_select_public" ON "Themes_Reference";
CREATE POLICY "themes_select_public" ON "Themes_Reference"
  FOR SELECT USING (true);

-- Écriture : super admin uniquement.
DROP POLICY IF EXISTS "themes_write_superadmin" ON "Themes_Reference";
CREATE POLICY "themes_write_superadmin" ON "Themes_Reference"
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM "Users_Client" uc
      JOIN "User_Types_Reference" utr ON utr.id = uc.type_user_id
      WHERE uc.id = auth.uid() AND utr.code = 'super_admin'
    )
  );

-- Seed : les 3 thèmes intégrés. « Ardoise » est le thème par défaut.
INSERT INTO "Themes_Reference" (code, label, description, is_builtin, is_active, is_default, ordre)
VALUES
  ('ardoise', 'Ardoise', 'Bleu pétrole et fond froid. Le thème par défaut.', true, true, true,  1),
  ('ocre',    'Ocre',    'Papier chaud et orange brûlé.',                     true, true, false, 2),
  ('encre',   'Encre',   'Gris chauds, une seule couleur d''accent. Sobre.',  true, true, false, 3)
ON CONFLICT (code) DO NOTHING;
