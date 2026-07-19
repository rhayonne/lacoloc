-- ══════════════════════════════════════════════════════════════════════════════
-- Préférence de thème par utilisateur
-- ══════════════════════════════════════════════════════════════════════════════
-- Stocke le thème choisi dans « Mon profil » (voir lib/theme/app_palette.dart,
-- AppPaletteId.code). La colonne suit l'utilisateur d'un appareil à l'autre.
-- NULL = thème par défaut (« ocre ») : on n'impose pas de valeur aux comptes
-- existants, l'app retombe sur le défaut côté client.
ALTER TABLE "Users_Client"
  ADD COLUMN IF NOT EXISTS theme_preference TEXT
    CHECK (theme_preference IN ('ocre', 'ardoise', 'encre')); -- remplacé par une FK en 20260717000042
