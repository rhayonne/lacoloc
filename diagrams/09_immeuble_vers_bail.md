# Do Immeuble ao Bail — Fluxo Completo

Este documento descreve **tudo o que é necessário** para chegar a um **contrat de
bail** assinado e às **échéances** geradas, partindo da criação do imóvel. O bail
**não é criado manualmente**: ele é **gerado a partir de um EDL d'entrée aceito
pelo locataire**, e consolidado com os dados do imóvel, da chambre, das charges e
dos garants. O EDL e o bail são **dois documentos distintos**, com **assinaturas
independentes** (colunas EDL vs colunas `bail_*`).

> Relacionados: [06_etat_des_lieux.md](06_etat_des_lieux.md) (ciclo do EDL),
> [10_parcours_location.md](10_parcours_location.md) (parcours por ator),
> [08_gestion_inventaire.md](08_gestion_inventaire.md) (pièces/inventaire),
> [12_finances_recettes.md](12_finances_recettes.md) (échéances),
> [02_modelo_de_dados.md](02_modelo_de_dados.md) (ERD).

---

## 1. Organograma — caminho completo (proprietaire + locataire)

```mermaid
flowchart TD
    START([Propriétaire connecté]) --> IMM

    subgraph A["1 · Immeuble (NouveauImmeublePage — tout en DRAFT)"]
        IMM["Créer immeuble<br/>type · adresse (BAN data.geopf.fr) · bail location/individuel<br/>location_meuble · prix_loyer · dépôt garantie (max légal 2/1) ·<br/>durée bail · IRL · DPE"]
        IMM --> COMMONS["Parties communes : checkboxes 7 pièces + quantité<br/>→ « Ajouter les pièces communes et inventaire » (draft)<br/>+ Électroménager (popup) + Charges locatives (accordéon)"]
        COMMONS --> SAVE["« Enregistrer » → Immeubles + Pieces + Inventaire<br/>(CommonsSeeder.seedSelection ; inventaire si meublé)"]
    end

    A --> B

    subgraph B["2 · Chambres (bail individuel)"]
        CH["Créer chambre(s) — champs bloqués avant le choix de l'immeuble<br/>room_name · m² · prix_loyer · photos<br/>dépôt/durée HÉRITÉS de l'immeuble (éditables)"]
        CH --> INV["Équipements de l'annonce = Inventaire de la chambre<br/>avec dans_annonce=true (plus de selected_options)<br/>Charges : au niveau de l'IMMEUBLE uniquement"]
    end

    B --> C

    subgraph C["3 · EDL d'entrée (EtatDesLieuxPage)"]
        NEW["« Nouveau » → showSelectImmeubleDialog<br/>(badge chambres dispo) → routage bail × meublé"]
        NEW --> LOC["Choisir / inviter le locataire<br/>(preneur ou locataire_id)"]
        LOC --> FILL["Remplir EDL : Bien · Dates · Relevés ·<br/>murs/observations · inventaire (auto-seed)"]
        FILL --> CFG["⚠️ Configuration du bail — OBLIGATOIRE pour finaliser :<br/>fenêtre d'avenant (0–90 j) · mode de règlement caution ·<br/>bail avec/sans garant (badges rouges EdlReadiness)"]
        CFG --> FIN["Propriétaire : « Finaliser »<br/>finaliser() → situation=finalise ·<br/>chambre est_loue=true · EDL verrouillé"]
    end

    C --> D

    subgraph D["4 · Signature EDL (locataire)"]
        NOTIF["« Demander signature » (anti-spam 1×/5 j)<br/>→ notification + e-mail (edl_a_signer)"]
        SIGN["Locataire : « Accepter et signer »<br/>(aperçu PDF avant) → locataireAccepter()<br/>→ locataire_accepte=true · date_finalisation"]
        NOTIF --> SIGN
    end

    D --> E

    subgraph E["5 · Bail — signatures bail_* (2 parties)"]
        OPEN["Accès : « Générer bail » (ligne EDL) ·<br/>« Signer bail » (fiche EDL) · Documentation › Baux"]
        OPEN --> GARANT{"bail_avec_garant ?<br/>(décision du proprio,<br/>jamais posée au locataire)"}
        GARANT -->|"avec, et 0 garant"| BLOCK["Notification bail_garant_requis<br/>→ SIGNATURE ET IMPRESSION BLOQUÉES"]
        GARANT -->|ok| SIGNP["Proprio signe → bail_proprietaire_signature_url<br/>Locataire signe → bail_locataire_signature_url<br/>(runSignerBailFlow : relit l'EDL frais)"]
        BLOCK -. "locataire crée/active un garant<br/>(auto-rattaché)" .-> SIGNP
        SIGNP --> BOTH{"2 signatures présentes ?"}
        BOTH -->|oui| ECH["Échéances générées (Recettes, idempotent) :<br/>caution (loyer × dépôt_mois) + 1 loyer/mois<br/>⚠️ INSERT réservé au proprio (RLS) — locataire<br/>signe en dernier ⇒ rattrapage ensureBailEcheances"]
        ECH --> PREVIEW["BailPdfPreviewPage — Imprimer / Télécharger<br/>(garant manquant ⇒ boutons désactivés + bandeau)"]
        PREVIEW --> PRINT([Bail signé + échéances ✅])
    end
```

---

## 2. Pré-requisitos (o que é « nécessaire »)

| Etapa | Obrigatório | Onde | Tabela/Campo |
|---|---|---|---|
| **Immeuble** | type, adresse, bail (`bail_location`/`bail_individuel`), `location_meuble` | NouveauImmeublePage | `Immeubles` |
| | prix_loyer (location), dépôt garantie, durée bail, IRL, DPE (recomendados p/ bail completo) | idem | `Immeubles.prix_loyer / depot_garantie_mois / duree_bail_mois / irl_reference / dpe_classe` |
| **Pièces communes + inventaire** | seleção de pièces no draft → `CommonsSeeder.seedSelection()` no save (inventaire só se meublé) | seção Parties communes do cadastro | `Pieces`, `Inventaire` |
| **Chambre** (bail individuel) | room_name; prix_loyer; dépôt/durée herdados do imóvel (editáveis) | CreerChambrePage | `Chambres` |
| **Charges** | opcional — **só ao nível do immeuble** (a chambre herda; fallback `BailPdfData.useChambreCharges` p/ legado) | cadastro do immeuble (accordéon) | `ImmeubleCharges` |
| **EDL d'entrée** | locataire (preneur/`locataire_id`) + preenchimento | EtatDesLieuxPage | `etat_de_lieux` |
| **Configuration du bail** | **fenêtre d'avenant** + **mode caution** + **choix garant** — sem os 3, « Finaliser » é bloqueado (`EdlReadiness`) | fiche EDL (onglet/section Bail) | `avenant_window_days`, `caution_mode`/`caution_details`, `bail_avec_garant` |
| **Garant** (se « avec ») | ≥ 1 garant ativo rattaché **por locataire com conta** (bail location: per-preneur via `etat_de_lieux_garants`); auto-rattachement ao criar/ativar | fiche EDL + GarantsPage (locataire) | `Garants`, `etat_de_lieux_garants` |
| **Finalização** | proprietaire « Finaliser » → `situation=finalise`, chambre `est_loue=true` | fiche EDL | `etat_de_lieux.situation` |
| **Aceitação EDL** | locataire « Accepter et signer » (aperçu PDF antes) → `date_finalisation` | espace locataire | `etat_de_lieux.locataire_accepte` |
| **Assinaturas do BAIL** | bailleur **e** locataire — colunas **`bail_*`**, distintas das assinaturas do EDL | « Signer bail » (fiche EDL / Documentation › Baux) | `bail_proprietaire_signature_url`, `bail_locataire_signature_url` + `bail_*_signed_at` |
| **Échéances** | geradas automaticamente na 2ª assinatura do bail (idempotente; INSERT só do proprietaire → rattrapage `ensureBailEcheances`) | automático | `Recettes` (caution + loyers, statut `a_recevoir`) |
| **Impressão** | garant presente se exigido (≥ 1) | BailPdfPreviewPage | gate `BailPdfData.garantManquant` |

> **Caution / dépôt de garantie**: o valor é `loyer HC × depot_garantie_mois`
> (Article 4.4 do bail) e vira uma **échéance própria** em `Recettes` (notes
> « Dépôt de garantie (caution) ») exigível no início do bail. O **modo de
> règlement** (`caution_mode` + détails) é obrigatório antes de finalizar.

---

## 3. Diagrama de casos de uso (Immeuble → Bail)

```mermaid
graph TD
    P(["🏢 Propriétaire"])
    L(["🏠 Locataire"])

    subgraph Préparation
        U1["Créer / éditer un immeuble (draft)"]
        U2["Générer pièces communes + inventaire"]
        U3["Créer / éditer des chambres"]
        U4["Définir loyer, charges (immeuble), dépôt, durée"]
    end

    subgraph EDL
        U5["Créer un EDL d'entrée"]
        U6["Choisir / inviter le locataire"]
        U7["Configuration du bail :\navenant · caution · garant"]
        U8["Finaliser + Demander signature"]
        U9["Accepter et signer l'EDL (locataire)"]
    end

    subgraph Bail
        U10["Signer le bail (bailleur)"]
        U11["Signer le bail (locataire)"]
        U12["Imprimer / Télécharger le bail"]
        U13["Enregistrer / activer ses garants"]
        U14["Recevoir l'alerte « garant requis »"]
        U15["Échéances générées (Finances)"]
        U16["Rompre le bail / annuler la résiliation"]
    end

    P --> U1 & U2 & U3 & U4
    P --> U5 & U6 & U7 & U8
    P --> U10 & U12 & U16
    L --> U9 & U11 & U13 & U14

    U7 -. "« avec garant » et 0 garant" .-> U14
    U14 -. débloque .-> U13
    U13 -. auto-rattachement .-> U10
    U8 -. notifie .-> U9
    U9 -. rend le bail signable .-> U10
    U10 -. + .-> U11
    U11 -. 2 signatures .-> U15
    U13 -. permet .-> U12
```

---

## 4. Diagrama de sequência (assinatura do bail + échéances)

```mermaid
sequenceDiagram
    actor P as Propriétaire
    participant FICHE as Fiche EDL / Documentation › Baux
    participant FLOW as runSignerBailFlow
    participant DS as EtatDesLieuxDatasource
    participant G as GarantsDatasource
    participant R as RecettesDatasource
    actor L as Locataire

    P->>FICHE: « Signer bail »
    FICHE->>FLOW: runSignerBailFlow(role: proprietaire)
    FLOW->>DS: findById (EDL frais)
    FLOW->>FLOW: ensureBailGarant(edl)
    alt bail_avec_garant == null
        FLOW-->>P: Pop-up « avec / sans garant ? »
        FLOW->>DS: setBailAvecGarant(id, choix)
    end
    alt garant requis && 0 garant
        FLOW-->>L: notification bail_garant_requis
        FLOW-->>P: « Garant manquant » → flux INTERROMPU (blocked)
        L->>G: créer / activer un garant (GarantsPage)
        G->>DS: autoLinkGarantsForLocataire (privatifs + communes location)
    end
    FLOW->>DS: setBailSignature(role: proprietaire)
    DS->>R: ensureBailEcheances (si 2 signatures — proprio only)

    L->>FICHE: « Signer bail » (pas de question garant)
    FICHE->>FLOW: runSignerBailFlow(role: locataire)
    FLOW->>DS: setBailSignature(role: locataire)
    Note over DS,R: Locataire signe en dernier : INSERT Recettes<br/>refusé par la RLS sous sa session → les échéances<br/>sont générées au prochain accès du PROPRIO à l'EDL<br/>(ensureBailEcheances, idempotent).
    R-->>P: Échéances « à recevoir » (caution + loyers)
    R-->>L: Échéances « à payer » (Finances)
```

---

## 5. Regras de edição após finalização

- Um EDL **finalisé** (`situation = finalise`) **não é mais editável**: o botão
  **« Continuer »** desaparece da tabela (Vision générale / Entrée / Sortie). Só
  restam **« œil » (Visualiser)** e, quando aplicável, **« Avenant »**.
- Um EDL finalisé **não pode ser suprimido**. Ao suprimir o **último privatif**
  de um contrato, o collectif órfão (não finalisé) é suprimido **atomicamente
  por trigger DB** (`trg_delete_orphan_collectif`).
- Para um novo locataire numa chambre livre de um collectif finalizado: **Avenant**
  (ver [06_etat_des_lieux.md](06_etat_des_lieux.md)).
- Durante a **janela de avenant/additions** (`avenant_window_days`, escolhida por
  EDL), ambas as partes podem registrar **additions** na fiche do EDL individuel.
- **Résiliation**: « Rompre le bail » exige o bail assinado pelo locataire;
  registra congé + préavis, calcula a fin effective e **remove as échéances
  futuras**. « Annuler la résiliation » limpa o congé e **restaura** as échéances
  removidas (`regenerateMissingInstallments`).
