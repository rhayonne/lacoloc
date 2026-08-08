# Parcours de location — Locataire & Propriétaire (flux + cas d'usage)

Ce document détaille, **par acteur**, le chemin complet pour louer :
- **Propriétaire** : de la **création de l'immeuble** (puis des chambres) jusqu'au
  **bail signé des deux parties** et aux **échéances** générées.
- **Locataire** : trouver et louer une **colocation** (bail individuel) ou une
  **location** simple (non colocation).

> Voir aussi : [09_immeuble_vers_bail.md](09_immeuble_vers_bail.md) (détails BD du
> bail), [06_etat_des_lieux.md](06_etat_des_lieux.md) (cycle de l'EDL),
> [12_finances_recettes.md](12_finances_recettes.md) (échéances),
> [01_casos_de_uso.md](01_casos_de_uso.md) (cas d'usage généraux).

---

## 1. Vue d'ensemble — deux acteurs, un même bien

Deux documents distincts, signés séparément : l'**EDL** (état des lieux) puis le
**bail** (contrat). Les échéances (caution + loyers) ne sont générées que quand
le **bail** est signé des **deux** côtés.

```mermaid
graph LR
    subgraph Propriétaire
        P1["Créer immeuble"] --> P2["Pièces communes\n+ inventaire (draft)"]
        P2 --> P3["Créer chambres\n(bail individuel)"]
        P3 --> P4["EDL d'entrée\n+ Configuration du bail\n→ Finaliser"]
        P4 --> P5["Signer bail\n(bailleur)"]
        P5 --> P6["Échéances générées\n(caution + loyers)"]
    end
    subgraph Locataire
        L1["Chercher\n(chambre / immeuble)"] --> L2["Demande de contact"]
        L2 --> L3["Invité → activer\nle compte"]
        L3 --> L4["Accepter et signer\nl'EDL"]
        L4 --> L5["Signer le bail"]
        L5 --> L6["Finances :\néchéances à payer"]
    end
    P3 -.publie l'annonce.-> L1
    L2 -.notifie.-> P4
    P4 -.« Demander signature ».-> L4
    L5 --- P6
```

---

## 2. Propriétaire — créer l'immeuble, puis les chambres

Tout le cadastro do imóvel é feito em **draft** (`ImmeubleDraft`) : nada vai ao
banco antes do « Enregistrer ».

```mermaid
flowchart TD
    START([Propriétaire connecté]) --> NEW["« Nouveau » (Mes Propriétés)\n→ NouveauImmeublePage"]

    subgraph DRAFT["Draft (rien en BD avant « Enregistrer »)"]
        NEW --> BASE["Informations de base :\ntype (dropdown) · nom · adresse (autocomplete BAN\ndata.geopf.fr → ville/dept/région/code postal)\n· m² · description · photos communes"]
        BASE --> BAILT{"Type de bail ?"}
        BAILT -->|"bail_location\n(« Location » : 1 contrat, N preneurs)"| CONTR
        BAILT -->|"bail_individuel\n(« Colocation » : 1 contrat / chambre)"| CONTR
        CONTR["Informations contractuelles :\nmeublé ? (Oui/Non) · prix loyer ·\ndépôt de garantie (max légal 2 mois vide / 1 meublé) ·\ndurée du bail · classe DPE · référence IRL"]
        CONTR --> COMMONS["Parties communes : checkboxes des 7 pièces types\n(Séjour, Entrée, Cuisine, Arrière-cuisine,\nBalcon, Salle de bain, WC) + quantité\n→ « Ajouter les pièces communes et inventaire »\n(matérialisé dans le DRAFT)"]
        COMMONS --> ELECTRO["Électroménager (popup « Ajouter article »\nfiltré catégorie Électroménager) → draft"]
        ELECTRO --> CHRG["Charges locatives (accordéon AppAccordion,\ncatalogue Charges_Reference) — NIVEAU IMMEUBLE\n(les chambres héritent, plus de charges par chambre)"]
    end

    CHRG --> SAVE["« Enregistrer »\n(_ensureLocationData complète ville/dept/CP si absents)"]
    SAVE --> DB[("Immeubles + Pieces\n+ Inventaire (CommonsSeeder.seedSelection ;\ninventaire des pièces seulement si meublé)")]

    DB --> KIND{"Bail ?"}
    KIND -->|location| ANNONCE
    KIND -->|individuel| CH["Créer les chambres\n(CreerChambrePage)"]

    subgraph CHAMBRE["Chambre (unité louée en colocation)"]
        CH --> CH1["Choisir l'immeuble\n(champs BLOQUÉS avant ce choix)"]
        CH1 --> CH2["room_name · m² · prix loyer ·\ndescription · photos"]
        CH2 --> CH3["Dépôt de garantie + durée bail :\nPRÉ-REMPLIS depuis l'immeuble (éditables)"]
        CH3 --> CH4["Statut : louée / désactivée\n(pas de section équipements → Inventaire ;\npas de charges → immeuble)"]
        CH4 --> INV["Équipements de l'annonce =\narticles d'Inventaire liés à la chambre\navec dans_annonce = true"]
    end

    INV --> ANNONCE(["Annonce publique visible\n(HomePage : chambres actives / immeuble actif)"])
```

**Points clés :**
- Le type de bail de l'**immeuble** décide de toute la suite : `bail_location`
  → un seul contrat pour le logement ; `bail_individuel` → une chambre = un
  contrat (colocation).
- La chambre **hérite** dépôt/durée de l'immeuble (pré-remplis, éditables) ;
  les **charges** vivent au niveau de l'immeuble ; les **équipements** affichés
  dans l'annonce sont les articles d'`Inventaire` de la chambre avec
  `dans_annonce=true` (RPC publique `chambre_equipements_annonce`).

---

## 3. Flux de location complet (le contrat, pas à pas)

C'est LE flux central du système. Trois grandes phases : **EDL** → **bail** →
**échéances / vie du contrat**.

```mermaid
flowchart TD
    subgraph PH0["Phase 0 — Mise en relation"]
        A1["Locataire : « Entrer en contact »\n(Demandes_Contact)"] --> A2["Propriétaire notifié (Interactions)\n→ invite le locataire\n(edge invite-locataire : compte + mdp temp.)"]
        A2 --> A3["Locataire active le compte\n(/completer-inscription : nouveau mdp)\n+ checklist : profil · signature · garant"]
    end

    PH0 --> PH1

    subgraph PH1["Phase 1 — EDL d'entrée"]
        B1["« Nouveau » → choisir immeuble\n(badge X/Y chambres dispo si individuel)\n→ choisir la chambre (individuel)"]
        B1 --> B2["Remplir l'EDL : Bien · Dates · Locataire(s) ·\nrelevés compteurs · murs/observations ·\ninventaire (auto-seed depuis Inventaire)"]
        B2 --> B3["⚠️ Configuration du bail — 3 champs OBLIGATOIRES\n(badges rouges sur l'onglet Bail) :\n1. Fenêtre d'avenant (0/7/15/30/60/90 j)\n2. Mode de règlement de la caution\n3. Bail avec / sans garant"]
        B3 --> B4{"« Avec garant » ?"}
        B4 -->|oui| B5["Chaque locataire (avec compte) doit avoir\n≥ 1 garant rattaché — auto-rattachement\ndes garants actifs ; sinon notification\n« bail_garant_requis » au locataire"]
        B4 -->|non| B6
        B5 --> B6["Propriétaire : « Finaliser »\n→ situation=finalise · chambre est_loue=true\n→ EDL verrouillé (lecture seule)"]
        B6 --> B7["« Demander signature » (anti-spam 1×/5 j)\n→ notification + e-mail au locataire"]
        B7 --> B8["Locataire : « Accepter et signer »\n(runLocataireSignatureFlow : signature salva\n→ aperçu PDF → accepter)\n→ locataire_accepte=true · date_finalisation"]
    end

    PH1 --> PH2

    subgraph PH2["Phase 2 — Bail (document distinct de l'EDL)"]
        C1["Bail accessible : bouton « Générer bail »\n(ligne EDL) ou Documentation › Baux\nou « Signer bail » dans la fiche EDL"]
        C1 --> C2["Propriétaire : « Signer bail »\n(runSignerBailFlow : relit l'EDL frais ;\ngarant manquant ⇒ BLOQUÉ)\n→ bail_proprietaire_signature_url"]
        C1 --> C3["Locataire : « Signer bail »\n(pas de question garant côté locataire)\n→ bail_locataire_signature_url"]
        C2 --> C4{"Les DEUX signatures\nbail_* présentes ?"}
        C3 --> C4
        C4 -->|oui| C5["Échéances générées (Recettes) :\n1 caution (loyer × dépôt_mois)\n+ 1 loyer/mois sur la durée du bail\n⚠️ INSERT réservé au propriétaire (RLS) —\nsi le locataire signe en dernier, rattrapage\nensureBailEcheances à l'ouverture proprio"]
    end

    PH2 --> PH3

    subgraph PH3["Phase 3 — Vie et fin du contrat"]
        D1["Finances : proprio voit « à recevoir »,\nlocataire voit ses échéances à payer"]
        D1 --> D2{"Événements"}
        D2 -->|"Congé du locataire"| D3["« Rompre le bail » (exige bail signé\npar le locataire) : congé + préavis\n→ fin effective · échéances futures retirées\n(annulation possible → échéances restaurées)"]
        D2 -->|"Fin de bail"| D4["EDL de SORTIE créé À PARTIR de\nl'entrée finalisée (copie structure,\ncontrepoint entrée/sortie)"]
        D2 -->|"Nouveau colocataire\n(fenêtre d'avenant ouverte)"| D5["Avenant : privatif is_avenant=true\nlié au collectif finalisé"]
        D4 --> D6["Sortie finalisée → chambre est_loue=false\n→ pop-up décompte de VÉTUSTÉ si dégradations"]
        D3 --> D6
        D6 --> FIM([Contrat clôturé — chambre relouable])
    end
```

**Règles à retenir :**

| Étape | Règle |
|---|---|
| Finaliser l'EDL | Impossible tant que **fenêtre d'avenant**, **mode caution** et **choix garant** ne sont pas renseignés (`EdlReadiness`, badges rouges). |
| « Avec garant » | Chaque locataire **avec compte** doit avoir ≥ 1 garant rattaché (`etat_de_lieux_garants`). En bail location, le rattachement est **par preneur**. Le garant créé/activé par le locataire est **auto-rattaché** (privatifs + communes location). |
| Signatures | EDL et bail sont **deux documents** : signatures EDL (`locataire_accepte` + signatures EDL) ≠ signatures bail (`bail_*_signature_url`). |
| Échéances | Générées **une seule fois** (idempotent) quand les 2 signatures bail existent. Montant = `EDL.montant` sinon loyer chambre/immeuble. |
| Occupation | Entrée **finalisée** → `est_loue=true` ; sortie **finalisée** → `est_loue=false`. |
| Suppression | EDL finalisé : jamais supprimable. Dernier privatif supprimé → collectif orphelin supprimé **par trigger DB** (`trg_delete_orphan_collectif`). |

---

## 4. Locataire — Colocation (bail individuel) vs Location (simple)

La différence clé : en **colocation** l'unité louée est **une chambre** (EDL
privatif lié à un EDL commune partagé, invisible dans les listes) ; en
**location simple** l'unité est **le logement entier** (un seul EDL « location »,
plusieurs preneurs possibles mais un seul contrat).

```mermaid
flowchart TD
    START([Visiteur / Locataire]) --> SEARCH["Parcourir « Rechercher location »\n(chambres) ou « Immeubles »"]
    SEARCH --> FILTER["Filtrer : ville, prix, surface,\nmeublé, équipements, type d'immeuble…"]
    FILTER --> KIND{"Type de bien ?"}

    %% Colocation
    KIND -->|Colocation\n(bail individuel)| C1["Ouvrir la fiche immeuble\n→ voir les chambres dispo"]
    C1 --> C2["Ouvrir la fiche d'une chambre"]
    C2 --> C3["« Entrer en contact »\n(Demande de contact)"]

    %% Location simple
    KIND -->|Location simple\n(non colocation)| S1["Ouvrir la fiche immeuble\n(logement entier)"]
    S1 --> S2["« Entrer en contact »"]

    C3 --> CONTACT
    S2 --> CONTACT["Le propriétaire est notifié\n(Interactions)"]
    CONTACT --> INVITE["Propriétaire crée/invite le locataire\n(edge invite-locataire)"]
    INVITE --> ACT["Locataire active son compte\n(mot de passe + profil)"]
    ACT --> CHECK["Checklist « Conditions pour louer » :\nprofil · signature · garant (obligatoire)"]
    CHECK --> EDL["EDL d'entrée finalisé par le proprio\n→ « Accepter et signer »\n(aperçu PDF avant d'accepter)"]
    EDL --> BAIL["« Signer bail » (signature du profil)\n— 2e signature ⇒ échéances générées"]
    BAIL --> FIN["Menu Finances : caution + loyers\nà payer ; Documents › Mes baux :\nconsulter le bail signé"]
    FIN --> END([Locataire installé ✅])
```

### Cas d'usage — Locataire

```mermaid
graph TD
    L(["🏠 Locataire / Visiteur"])
    subgraph Recherche
        U1["Parcourir chambres"]
        U2["Parcourir immeubles + fiche détail"]
        U3["Filtrer (ville, prix, meublé, équipements…)"]
        U4["Voir le détail d'une chambre"]
    end
    subgraph Contact_Compte["Contact & compte"]
        U5["Entrer en contact (demande)"]
        U6["Activer le compte (invitation)"]
        U7["Compléter le profil"]
        U8["Enregistrer sa signature"]
        U9["Enregistrer / activer un garant\n(auto-rattaché aux baux « avec garant »)"]
    end
    subgraph Contrat
        U10["Accepter et signer l'EDL\n(aperçu PDF avant)"]
        U11["Signer le bail (bail_*)"]
        U12["Ajouter des observations / additions\n(fenêtre d'avenant)"]
        U13["Consulter ses baux (Documents › Mes baux)"]
        U14["Payer les échéances (Finances)"]
        U15["Recevoir notifications (Interactions)\n+ tableau de bord (pendências)"]
    end
    L --> U1 & U2 & U3 & U4
    L --> U5 & U6 & U7 & U8 & U9
    L --> U10 & U11 & U12 & U13 & U14 & U15
```

---

## 5. Cas d'usage — Propriétaire

```mermaid
graph TD
    P(["🏢 Propriétaire"])
    subgraph Patrimoine
        U1["Créer / éditer immeuble\n(draft : contractuel, pièces, électro, charges)"]
        U2["Générer pièces communes + inventaire\n(seedSelection, si meublé)"]
        U3["Créer / éditer chambres\n(hérite dépôt/durée)"]
        U4["Gérer l'inventaire (dans_annonce)"]
        U5["Agenda : rendez-vous (créneaux)\n+ plages d'ouverture"]
    end
    subgraph Relation
        U6["Voir les demandes de contact"]
        U7["Inviter un locataire (edge fn)"]
    end
    subgraph Contrat
        U8["Créer un EDL d'entrée\n(+ copie parties communes d'un\ncontrat précédent, au choix)"]
        U9["Configuration du bail :\navenant · caution · garant"]
        U10["Finaliser + Demander signature"]
        U11["Signer le bail (bailleur)"]
        U12["Rompre le bail (congé + préavis)\n/ annuler la résiliation"]
        U13["Créer un avenant / EDL de sortie"]
        U14["Décompte de vétusté (sortie)"]
    end
    subgraph Finances
        U15["Recettes : échéances générées,\nmarquer payé/impayé"]
        U16["Dépenses / Factures · Fournisseurs"]
    end
    P --> U1 & U2 & U3 & U4 & U5
    P --> U6 & U7
    P --> U8 & U9 & U10 & U11 & U12 & U13 & U14
    P --> U15 & U16
```

---

## 6. Séquence — Colocation (de la recherche aux échéances)

```mermaid
sequenceDiagram
    actor L as Locataire
    participant APP as HabitaFrance
    actor P as Propriétaire
    participant DB as Supabase

    P->>DB: Créer immeuble + chambres (bail individuel)
    L->>APP: Rechercher → fiche immeuble → fiche chambre
    L->>DB: Demande de contact (chambre)
    DB-->>P: Notification (Interactions)
    P->>APP: Inviter le locataire (edge invite-locataire)
    APP-->>L: E-mail d'activation (mot de passe temp.)
    L->>APP: Activer le compte + profil + signature + garant
    P->>DB: EDL d'entrée (commune interne + privatif chambre)
    P->>DB: Configuration du bail (avenant · caution · garant)
    P->>DB: Finaliser → est_loue=true, EDL verrouillé
    P->>DB: « Demander signature » (anti-spam 5 j)
    DB-->>L: Notification + e-mail « EDL à signer »
    L->>APP: Accepter et signer l'EDL (aperçu PDF → signature)
    DB-->>P: Notification « EDL accepté » (+ e-mail)
    P->>DB: « Signer bail » → bail_proprietaire_signature_url
    L->>APP: « Signer bail » → bail_locataire_signature_url
    Note over DB: 2 signatures bail présentes →<br/>generateFromBail (caution + loyers, idempotent).<br/>Locataire signe en dernier ? INSERT refusé (RLS) →<br/>rattrapage ensureBailEcheances à l'ouverture proprio.
    DB-->>P: Finances : à recevoir
    DB-->>L: Finances : à payer
```

---

## 7. États du bien / contrat

```mermaid
stateDiagram-v2
    [*] --> Annonce: chambre/immeuble actif
    Annonce --> EnContact: demande de contact
    EnContact --> EDL_Entree: locataire invité + EDL créé
    EDL_Entree --> ConfigBail: avenant + caution + garant renseignés
    ConfigBail --> Finalise: proprio « Finaliser » (est_loue=true, EDL verrouillé)
    Finalise --> EdlSigne: locataire « Accepter et signer » (date_finalisation)
    EdlSigne --> BailSigne: signatures bail_* des 2 parties → échéances générées
    BailSigne --> Resilie: « Rompre le bail » (congé + préavis, échéances rognées)
    Resilie --> BailSigne: annulation résiliation (échéances restaurées)
    BailSigne --> Sortie: EDL de sortie créé depuis l'entrée
    Resilie --> Sortie
    Sortie --> [*]: sortie finalisée → est_loue=false (+ décompte vétusté)

    note right of Finalise
        Fenêtre d'avenant (N jours après
        finalisation) : additions des 2 parties,
        avenant possible (nouveau colocataire)
    end note
```
