# Changelogs — HabitaFrance

Notes de mise à jour générées automatiquement à chaque merge sur `main`.

## Structure

```
changelogs/
├── v1/           ← un dossier par version majeure
│   ├── 1.0.md   ← un fichier par version mineure
│   ├── 1.1.md
│   └── …
├── v2/           ← créé lors du passage à une nouvelle version majeure
│   └── 2.0.md
└── README.md
```

## Règles de versioning

| Changement | Exemple | Action |
|---|---|---|
| **Majeur** — rupture de compatibilité, refonte | `1.x → 2.0` | Nouveau dossier `v2/` + nouveau fichier `2.0.md` |
| **Mineur** — nouvelle fonctionnalité | `1.0 → 1.1` | Même dossier `v1/`, nouveau fichier `1.1.md` |
| **Patch** — correction, hotfix | `1.0.0 → 1.0.1` | Même dossier `v1/`, même fichier `1.0.md`, nouvelle section |

La version est lue depuis `pubspec.yaml` (`version: X.Y.Z+build`).

## Workflow automatique

`.github/workflows/release-notes.yml` s'exécute à chaque push sur `main` :

1. Lit la version dans `pubspec.yaml`
2. Crée le dossier `vX/` si nécessaire
3. Crée le fichier `X.Y.md` (nouvelle version mineure/majeure) ou ajoute une section au fichier existant (patch)
4. Commite le changelog dans `main` (`[skip ci]` — ne redéclenche pas le deploy)

## Modifier les notes manuellement

Le fichier généré contient une section **Notes** vide. Après le merge, éditez-la directement dans `main` pour ajouter un résumé lisible des changements.
