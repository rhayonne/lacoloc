# Gestion Immobilière & Inventaire — La Coloc

A seção **Gestion Immobilière** (índice 1 do dashboard do propriétaire) é um `TabBar`
com 4 abas. O imóvel (`Immeuble`) é o container; o quarto (`Chambre`) é o produto
alugado; as `Pièces` são áreas comuns; o `Inventaire` cataloga os móveis.

```mermaid
graph TD
    GI["Gestion Immobilière (TabBar)"]
    GI --> T0["Mes Propriétés"]
    GI --> T1["Mes Chambres"]
    GI --> T2["Agenda — Visites"]
    GI --> T3["Inventaire"]

    T0 --> IMM["MesImmeublesPage (grid)"]
    IMM --> NIMM["NouveauImmeublePage (criar/editar)"]
    IMM --> IDET["ImmeubleDetailPage"]
    IDET --> PIECES["Pièces (CreerPiecePage)"]
    IDET --> INVI["Inventaire do imóvel"]

    T1 --> CH["MesChambresPage (grid)"]
    CH --> CCH["CreerChambrePage (criar/editar)"]

    T2 --> AG["AgendaVisitesPage (CRUD Visites)"]

    T3 --> INV["InventairePage"]
    INV --> ADD["Ajouter un article (InventaireForm)"]
```

---

## Hierarquia Immeuble → Chambre / Pièce / Inventaire

```mermaid
graph TD
    IMM["🏢 Immeuble (container)\nname, address, total_m2,\nbail_collectif/individuel, common_photos"]
    IMM --> CH["🚪 Chambres (produto alugado)\nroom_name, m2, prix_loyer,\nest_loue, room_photos, selected_options"]
    IMM --> PC["🛋️ Pièces (áreas comuns)\nnom, m2, photos[{url, dans_annonce}]"]
    IMM --> INV["📦 Inventaire (móveis)"]

    INV --> LOC{"Localização\n(exclusiva)"}
    LOC -->|chambre_id| CH
    LOC -->|piece_id| PC

    INV --> REF["Meubles_Reference\n(nom, categorie)"]
    INV -.->|"ou texto livre"| CUSTOM["nom_custom"]
```

---

## Formulário "Ajouter un article" (Inventaire)

```mermaid
flowchart TD
    START["Ajouter / Modifier un article"]
    START --> IMMSEL["1. Immeuble (dropdown)"]
    IMMSEL --> LIEU["2. Chambre + Pièce lado a lado\n(exclusão mútua: só um selecionável)"]
    START --> TYPE["3. Type de meuble — Autocomplete\n(digita para filtrar Meubles_Reference;\nexibe só o nome)"]
    START --> QTY["4. Quantité, Valeur, Description, Photos"]

    LIEU -->|seleciona chambre| LOCKP["Pièce desabilitada"]
    LIEU -->|seleciona pièce| LOCKC["Chambre desabilitada"]

    TYPE --> SAVE["Enregistrer → InventaireDatasource.create/update"]
    QTY --> SAVE
    LIEU --> SAVE
```

- O **tipo de meuble** é um campo de busca (`Autocomplete<MeubleReferenceModel>`):
  digita-se para filtrar a lista de `Meubles_Reference`; exibe apenas `nom`
  (a `categorie` é pesquisável mas não mostrada). A criação de novos tipos é feita
  pelo **Super Admin** em `MeubleTypesPage` (não há mais "saisir un nom libre" no form).
- **Chambre e Pièce** aparecem juntas após escolher o immeuble; selecionar uma
  desabilita a outra (`onChanged: null`). A opção "—" limpa a seleção.
- `nom_custom` ainda existe no modelo como fallback legado, mas o fluxo atual usa
  `meuble_ref_id`.

---

## Agenda — Visites

```mermaid
graph LR
    AG["AgendaVisitesPage"] --> V["VisiteModel"]
    V --> TY["type_visite:\netat_des_lieux_entree / etat_des_lieux_sortie /\nvisite_entree / reparation"]
    V --> VIS["nom_visiteur, telephone, date_visite"]
    V --> FRN["fournisseur_id? → Fournisseurs"]
```
