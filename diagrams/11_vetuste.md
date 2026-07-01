# Vétusté & Décompte de réparations locatives (Option B)

> Mécanique complète : barème par proprietaire → détection des dégradations à la
> sortie → décompte calculé → document PDF → somme « à recevoir » (Finances).
> Code : [vetuste_page.dart](../lib/presentation/users/proprietaires/vetuste_page.dart),
> [vetuste.dart (datasource)](../lib/data/datasources/vetuste.dart),
> [vetuste_calc.dart](../lib/utils/vetuste_calc.dart),
> [vetuste_pdf_builder.dart](../lib/presentation/users/proprietaires/vetuste_pdf_builder.dart).

## Modèle de données

```mermaid
erDiagram
    vetuste_bareme {
        int id PK
        uuid owner_id FK
        text categorie
        int duree_vie_annees
        int franchise_annees
        numeric coefficient_annuel
        numeric residuel_min_pct
    }
    vetuste_decompte {
        int id PK
        uuid owner_id FK
        int immeuble_id FK
        int chambre_id FK
        uuid locataire_id FK
        int etat_de_lieux_id FK
        text statut
        numeric total_montant
        int recette_id FK
    }
    vetuste_decompte_ligne {
        int id PK
        int decompte_id FK
        text equipement
        text categorie
        numeric valeur_achat
        numeric age_annees
        text etat_entree
        text etat_sortie
        numeric abattement_pct
        numeric valeur_residuelle
        bool imputable
    }
    Recettes {
        int id PK
        uuid locataire_id FK
        numeric montant
        text statut
    }

    vetuste_decompte ||--o{ vetuste_decompte_ligne : "lignes"
    vetuste_decompte }o--o| Recettes : "génère l'à recevoir"
    vetuste_bareme }o--|| Meuble_Categories_Reference : "1 ligne par catégorie"
    vetuste_decompte }o--o| etat_de_lieux : "origine (EDL sortie)"
```

- O barème é chaveado pela **catégorie de meuble** (`Meuble_Categories_Reference.nom`).
  `Inventaire.categorie_vetuste` (ou a categoria do `meuble_ref`) decide qual linha usar.

## Fórmula (décret 2016-382)

```
abattement%        = clamp((âge − franchise) × coefficient_annuel, 0, 100 − residuel_min_pct)
valeur_résiduelle  = valeur_achat × (1 − abattement%/100)
```

`VetusteCalc.abattementPct` / `valeurResiduelle`. `âge` = (date sortie − `date_acquisition`) en années.

## Fluxo — détection à la sortie

```mermaid
sequenceDiagram
    actor P as Propriétaire
    participant PG as EDL sortie (page)
    participant DS as VetusteDatasource
    participant DB as Supabase

    P->>PG: Finaliser (EDL type_edl = sortie)
    PG->>DS: buildCandidatesForSortie(sortie)
    DS->>DB: listSections(sortie) + listSections(edl_entree_id)
    DB-->>DS: lignes (etat_usure)
    DS->>DS: compara N<B<U<M ; retém dégradations\n+ pré-remplit via Inventaire (valeur_achat/date/cat)
    DS-->>PG: candidats (lignes calculées)
    alt candidats non vides
        PG->>P: Pop-up « Dégradation détectée — créer la vétusté ? »
        P->>PG: Oui
        PG->>DS: createDecompteFromSortie (idempotent: findByEdl)
        DS->>DB: insert vetuste_decompte + lignes
    end
```

## Fluxo — décompte → à recevoir

```mermaid
graph TD
    TAB["Aba Vétusté (VetustePage)"] --> BAR["AppAccordion « Barème »\n(editável, seed auto)"]
    TAB --> LIST["Liste des décomptes\n(groupés par EDL/immeuble)"]
    TAB --> ADD["« Ajouter une vétusté » (manuel)\n→ immeuble + chambre"]
    LIST --> ED["_DecompteEditor"]
    ADD --> ED
    ED --> CALC["imputable on/off · catégorie · valeur d'achat\n→ recalcul live (abattement, résiduelle, total)"]
    ED --> PDF["DocumentPdfButton → PDF\n« Décompte de réparations locatives »"]
    ED --> REC["« Générer l'à recevoir »"]
    REC --> R1["RecettesDatasource.createManual\n(statut a_recevoir, échéance +30j)"]
    REC --> R2["updateDecompte(statut: genere)"]
    REC --> R3["Notif locataire (si EDL lié)"]
    R1 --> FIN["Finances proprietaire **et** locataire\n(RLS locataire_select_recettes)"]
```

## Saisie des données nécessaires

- **Inventaire** (formulaire d'article + popup électroménager) : `valeur_achat`, `date_acquisition`,
  `categorie_vetuste`. Ver [08_gestion_inventaire.md](08_gestion_inventaire.md).
- **EDL** : `etat_usure` (N/B/U/M) par ligne d'équipement, à l'entrée puis à la sortie.
  Ver [06_etat_des_lieux.md](06_etat_des_lieux.md).

## RLS

- `vetuste_bareme` / `vetuste_decompte` / `vetuste_decompte_ligne` : propriétaire (`owner_id`).
- Leitura locataire em `vetuste_decompte`/`_ligne` (via `locataire_id` ou `is_edl_preneur`).
- `Recettes` : `owner_all_recettes` + `locataire_select_recettes` (a somme à recevoir aparece para o locataire).

> Ciclo de vida do « à recevoir » (statuts, markPaid/markLate) : ver
> [12_finances_recettes.md](12_finances_recettes.md). Notificação ao locataire :
> ver [13_notifications.md](13_notifications.md).
