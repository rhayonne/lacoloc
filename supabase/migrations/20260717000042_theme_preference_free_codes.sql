-- La préférence de thème ne peut plus être limitée à une liste figée : le super
-- admin crée désormais ses propres thèmes (« Themes_Reference »). On remplace
-- le CHECK par une clé étrangère vers le code du thème.
ALTER TABLE "Users_Client"
  DROP CONSTRAINT IF EXISTS "Users_Client_theme_preference_check";

-- Si le thème choisi est supprimé, on remet la personne sur le thème par
-- défaut (NULL) plutôt que de bloquer la suppression.
ALTER TABLE "Users_Client"
  DROP CONSTRAINT IF EXISTS "Users_Client_theme_preference_fkey";
ALTER TABLE "Users_Client"
  ADD CONSTRAINT "Users_Client_theme_preference_fkey"
  FOREIGN KEY (theme_preference) REFERENCES "Themes_Reference"(code)
  ON UPDATE CASCADE ON DELETE SET NULL;
