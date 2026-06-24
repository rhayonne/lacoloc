# Do Immeuble ao Bail — Fluxo Completo

Este documento descreve **tudo o que é necessário** para chegar a um **contrat de
bail** imprimível, partindo da criação do imóvel. O bail **não é criado
manualmente**: ele é **gerado a partir de um EDL d'entrée aceito e assinado pelo
locataire**, e consolidado com os dados do imóvel, da chambre, das charges e dos
garants.

> Relacionados: [06_etat_des_lieux.md](06_etat_des_lieux.md) (ciclo do EDL),
> [08_gestion_inventaire.md](08_gestion_inventaire.md) (pièces/inventaire),
> [02_modelo_de_dados.md](02_modelo_de_dados.md) (ERD).

---

## 1. Organograma — caminho completo (proprietaire + locataire)

```mermaid
flowchart TD
    START([Propriétaire connecté]) --> IMM

    subgraph A["1 · Immeuble (NouveauImmeublePage)"]
        IMM["Créer immeuble<br/>type · adresse (BAN) · bail · location_meuble<br/>prix_loyer · dépôt garantie · durée bail · IRL · DPE"]
        IMM --> SEED{"location_meuble<br/>défini ?"}
        SEED -->|Oui| COMMONS["Bouton « Ajouter les pièces communes<br/>et inventaire » → CommonsSeeder.seed()<br/>(7 pièces + inventaire si meublé)"]
        SEED -->|plus tard| COMMONS
    end

    A --> B

    subgraph B["2 · Chambres & Charges (Gestion Immobilière)"]
        CH["Créer chambre(s)<br/>room_name · m2 · options · prix_loyer<br/>dépôt garantie · durée bail · est_loue"]
        CHG["Charges (ImmeubleCharges / ChambreCharges)<br/>type fixe / inclus"]
        CH --> CHG
    end

    B --> C

    subgraph C["3 · EDL d'entrée (EtatDesLieuxPage)"]
        NEW["« Nouveau » → showSelectImmeubleDialog<br/>routage par bail × meublé"]
        NEW --> LOC["Choisir / inviter le locataire<br/>(preneur ou locataire_id)"]
        LOC --> FILL["Remplir EDL : Bien · Dates · Relevés ·<br/>Composition · murs/observations · inventaire"]
        FILL --> FIN["Propriétaire : « Finaliser » + signe<br/>finaliser() → situation=finalise<br/>chambre est_loue=true"]
    end

    C --> D

    subgraph D["4 · Signature locataire"]
        NOTIF["Notification + e-mail au locataire<br/>(edl_a_signer)"]
        SIGN["Locataire : « Accepter et signer »<br/>locataireAccepter() → date_finalisation<br/>+ locataire_signature_url"]
        NOTIF --> SIGN
    end

    D --> E

    subgraph E["5 · Bail (Documentation › Baux)"]
        APPEAR["Le bail apparaît dans la liste<br/>(EDL entrée accepté : privatif individuel<br/>ou commune de bail location)"]
        APPEAR --> OPEN["Clic « Bail » → _openBail()"]
        OPEN --> GARANT{"bail_avec_garant<br/>déjà décidé ?"}
        GARANT -->|non| ASKG["Pop-up « Ce bail nécessite-t-il<br/>un garant ? » (Oui/Non)<br/>→ setBailAvecGarant()"]
        ASKG --> CHECKG
        GARANT -->|oui| CHECKG{"garant requis<br/>ET 0 garant ?"}
        CHECKG -->|oui| BLOCK["Notifier le locataire (bail_garant_requis)<br/>+ alerte tableau de bord locataire<br/>→ impression BLOQUÉE"]
        CHECKG -->|non| SIGNB
        BLOCK --> SIGNB
        SIGNB["Signature bailleur si absente<br/>(ensureBailSignature)"]
        SIGNB --> PREVIEW["BailPdfPreviewPage<br/>Imprimer / Télécharger"]
        PREVIEW --> GATE{"garant manquant ?"}
        GATE -->|oui| DISABLED["Aperçu visible, mais<br/>Imprimer/Télécharger désactivés + bandeau"]
        GATE -->|non| PRINT([Bail imprimable ✅])
    end

    %% Côté locataire pour les garants
    BLOCK -.notifie.-> LGAR["Locataire : Documents › Garants<br/>créer ≥ 1 garant (GarantsPage)"]
    LGAR -.débloque.-> PRINT
```

---

## 2. Pré-requisitos (o que é « necessaire »)

| Etapa | Obrigatório | Onde | Tabela/Campo |
|---|---|---|---|
| **Immeuble** | type, adresse, bail (`bail_location`/`bail_individuel`), `location_meuble` | NouveauImmeublePage | `Immeubles` |
| | prix_loyer (location), dépôt garantie, durée bail, IRL, DPE (recomendados p/ bail completo) | idem | `Immeubles.prix_loyer / depot_garantie_mois / duree_bail_mois / irl_reference / dpe_classe` |
| **Pièces communes + inventaire** | gerados via `CommonsSeeder.seed()` (precisa `location_meuble`) | botão no cadastro do imóvel | `Pieces`, `Inventaire` |
| **Chambre** (bail individuel) | room_name; prix_loyer/dépôt/durée na chambre (senão herda do imóvel) | CreerChambrePage | `Chambres` |
| **Charges** | opcional (fixe/inclus) — entram no detalhe do bail | Gestion Immobilière | `ImmeubleCharges` / `ChambreCharges` |
| **EDL d'entrée** | locataire (preneur/`locataire_id`) + finalização + assinatura | EtatDesLieuxPage | `etat_de_lieux` |
| **Finalização** | proprietaire « Finaliser » (assina) → `situation=finalise`, chambre `est_loue=true` | fiche EDL | `etat_de_lieux.situation` |
| **Aceitação** | locataire « Accepter et signer » → `date_finalisation` + `locataire_signature_url` | espace locataire | `etat_de_lieux.locataire_accepte` |
| **Bail visível** | EDL **entrée** + `locataire_accepte = true` (privatif individuel OU commune de bail location) | Documentation › Baux | — |
| **Garant** (se exigido) | proprietaire escolhe `bail_avec_garant=true` → locataire cadastra ≥ 1 garant | pop-up + GarantsPage | `etat_de_lieux.bail_avec_garant`, `Garants` |
| **Assinaturas no bail** | bailleur (`proprietaire_signature_url`) + locataire (`locataire_signature_url`) | fluxo de assinatura | `etat_de_lieux.*_signature_url` |
| **Impressão** | garant presente se exigido (≥ 1) | BailPdfPreviewPage | gate `BailPdfData.garantManquant` |

> **Caution / dépôt de garantie**: hoje é apenas um **valor calculado**
> (`loyer HC × depot_garantie_mois`) exibido no Article 4.4 do bail. Não há
> rastreamento de depósito efetivamente pago/devolvido.

---

## 3. Diagrama de casos de uso (Immeuble → Bail)

```mermaid
graph TD
    P(["🏢 Propriétaire"])
    L(["🏠 Locataire"])

    subgraph Préparation
        U1["Créer / éditer un immeuble"]
        U2["Générer pièces communes + inventaire"]
        U3["Créer / éditer des chambres"]
        U4["Définir loyer, charges, dépôt, durée"]
    end

    subgraph EDL
        U5["Créer un EDL d'entrée"]
        U6["Choisir / inviter le locataire"]
        U7["Finaliser + signer (bailleur)"]
        U8["Accepter et signer (locataire)"]
    end

    subgraph Bail
        U9["Ouvrir le bail (Documentation › Baux)"]
        U10["Choisir : bail avec / sans garant"]
        U11["Signer le bail (bailleur)"]
        U12["Imprimer / Télécharger le bail"]
        U13["Enregistrer ses garants"]
        U14["Recevoir l'alerte « garant requis »"]
    end

    P --> U1 & U2 & U3 & U4
    P --> U5 & U6 & U7
    P --> U9 & U10 & U11 & U12
    L --> U8 & U13 & U14

    U10 -. si « avec garant » & 0 garant .-> U14
    U14 -. débloque .-> U13
    U13 -. permet .-> U12
    U7 -. notifie .-> U8
    U8 -. rend visible .-> U9
```

---

## 4. Diagrama de sequência (geração + impressão do bail)

```mermaid
sequenceDiagram
    actor P as Propriétaire
    participant DOC as Documentation › Baux
    participant DS as EtatDesLieuxDatasource
    participant G as GarantsDatasource
    participant N as Notifications (locataire)
    actor L as Locataire
    participant PDF as BailPdfPreviewPage

    P->>DOC: Clic « Bail »
    DOC->>DS: ensureBailGarant(edl)
    alt bail_avec_garant == null
        DOC-->>P: Pop-up « avec / sans garant ? »
        P-->>DOC: choix
        DOC->>DS: setBailAvecGarant(id, choix)
    end
    alt garant requis
        DOC->>G: garantsForEdl(edl)
        alt 0 garant
            DOC->>N: notifyEdlLocataire(bail_garant_requis)
            DOC-->>P: « Garant manquant » (impression bloquée)
            L->>G: créer un garant (GarantsPage)
        end
    end
    DOC->>DS: ensureBailSignature(role: proprietaire)
    DOC->>PDF: ouvrir l'aperçu
    PDF->>G: BailPdfData (garants, charges, dépôt…)
    alt garant manquant
        PDF-->>P: Imprimer/Télécharger désactivés + bandeau
    else
        PDF-->>P: Bail imprimable ✅
    end
```

---

## 5. Regras de edição após finalização

- Um EDL **finalisé** (`situation = finalise`) **não é mais editável**: o botão
  **« Continuer »** desaparece da tabela (Vision générale / Entrée / Sortie). Só
  restam **« œil » (Visualiser)** e, quando aplicável, **« Avenant »**.
- Para um novo locataire numa chambre livre de um collectif finalizado: **Avenant**
  (ver [06_etat_des_lieux.md](06_etat_des_lieux.md)).
- Durante a **janela de avenant/additions**, ambas as partes podem registrar
  **additions** (algo não verificado) na fiche do EDL individuel.
