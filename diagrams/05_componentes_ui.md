# Componentes de UI — La Coloc

## Hierarquia de Widgets Principais

```mermaid
graph TD
    APP["MyApp (MaterialApp + ResponsiveBreakpoints + FlutterLocalization)"]

    subgraph PublicArea["Área Pública"]
        HOME["HomePage"]
        FILTER["FilterPanel (opções, cidade, région,\ndépartement, bail, m², preço)"]
        GRID["ChambresList (GridView responsiva)"]
        CARD["ChambreCard (foto 16:9, pills, botão)"]
        DETAIL["ChambreDetailPage (carrossel + zoom)"]
    end

    subgraph PropUI["Dashboard do Propriétaire"]
        PPROFIL["ProprietaireProfil (SidebarX)"]
        VG["VueGeneralePage (stats + atalhos)"]
        GEST["Gestion (TabBar: Propriétés/Chambres/Visites/Inventaire)"]
        EDL["EtatDesLieuxPage (TabBar: Vision/Entrée/Sortie)"]
        INTPAGE["InteractionsPage (DataTable)"]
        FINPAGE["FacturesListPage / FournisseursPage"]
    end

    subgraph Forms["Formulários (flutter_form_builder)"]
        NEWIMM["NouveauImmeublePage"]
        NEWCH["CreerChambrePage"]
        NEWPC["CreerPiecePage"]
        NEWFACT["NouvelleFacturePage"]
        REGFORM["CrierCompteLocataire/Proprietaire"]
        INVFORM["InventaireForm (Ajouter un article)"]
    end

    subgraph Shared["Widgets / utils compartilhados"]
        ADDR["AddressAutocompleteField (data.gouv.fr)"]
        EMAIL["EmailField (utils/email_field.dart)"]
        PHONE["PhoneField (utils/phone_field.dart)"]
        PHOTO["PhotoPickerField (StorageService)"]
        FPH["FormPageHeader"]
        RFW["ResponsiveFormWrapper"]
    end

    APP --> HOME
    HOME --> FILTER & GRID
    GRID --> CARD --> DETAIL

    APP --> PPROFIL
    PPROFIL --> VG & GEST & EDL & INTPAGE & FINPAGE

    GEST --> NEWIMM & NEWCH & NEWPC & INVFORM
    FINPAGE --> NEWFACT
    NEWIMM --> ADDR & PHOTO
    NEWCH --> PHOTO
    NEWPC --> PHOTO
    EDL --> PHOTO & PHONE & EMAIL
    REGFORM --> EMAIL & PHONE
```

---

## Estrutura do ProprietaireProfil (SidebarX)

```mermaid
graph LR
    PP["ProprietaireProfil"]

    subgraph Sidebar["SidebarX (índices)"]
        I0["0 — Vue générale"]
        I1["1 — Gestion Immobilière"]
        I2["2 — Finances"]
        I3["3 — Fournisseurs"]
        I4["4 — État des lieux"]
        I5["5 — Documentation"]
        I6["6 — Interactions"]
        I7["7 — Mon Profil"]
    end

    subgraph Content["Conteúdo"]
        C0["VueGeneralePage"]
        C1["Abas: Propriétés / Chambres / Visites / Inventaire"]
        C2["FacturesListPage"]
        C3["FournisseursPage"]
        C4["EtatDesLieuxPage"]
        C5["DocumentationPage"]
        C6["InteractionsPage"]
        C7["MonProfilProprietairePage"]
    end

    PP --> Sidebar
    I0 --> C0
    I1 --> C1
    I2 --> C2
    I3 --> C3
    I4 --> C4
    I5 --> C5
    I6 --> C6
    I7 --> C7
```

---

## Padrão Responsivo das Tabelas (États des lieux)

```mermaid
flowchart LR
    LB["LayoutBuilder mede largura REAL do card"]
    LB -->|"&lt; 900px"| CARDS["Layout de cards verticais\n(avatar, lieu, ÉTAT/FINALISATION/SITUATION, Continuer)"]
    LB -->|"&ge; 900px"| TABLE["Layout de tabela\n(colunas fixas + colunas flexíveis)"]
```

- A decisão usa `LayoutBuilder` (largura do componente), nunca `MediaQuery` (largura da janela).
- Labels e valores usam `maxLines: 1` + `ellipsis` para nunca estourar (`RenderFlex overflow`).
- O botão "Nouveau" vira `IconButton.filled` compacto em tela estreita.

---

## Campos Padronizados (regras do projeto)

```mermaid
graph TD
    subgraph Regras
        R1["Telefone → SEMPRE PhoneField (utils/phone_field.dart)\ndentro de FormBuilder. Nunca TextField raw."]
        R2["E-mail → SEMPRE EmailField (utils/email_field.dart)\ncom validação regex + formatter."]
        R3["Leitura do telefone do form → PhoneField.fullNumberFromState()\nusa instantValue (não value) para funcionar sem save()."]
        R4["Idade → calcular de date_of_birth; age é fallback legado."]
        R5["Endereço → AddressAutocompleteField → data.gouv.fr."]
    end
```

---

## Ciclo de Vida de Estado (StatefulWidget padrão)

```mermaid
stateDiagram-v2
    [*] --> initState
    initState --> Loading : _future = _load()
    Loading --> Success : FutureBuilder → dados
    Loading --> Error : exceção → mensagem
    Success --> Idle : exibe lista/grid/tabela
    Idle --> Reload : _reload() executa _load() ANTES,\nsetState só atribui (nunca retorna Future)
    Reload --> Loading
    Idle --> [*] : dispose
```

> **Armadilha conhecida**: `setState(() => _future = _load())` faz o closure retornar
> um `Future` (Dart avalia a atribuição) → erro *"setState callback returned a Future"*.
> Sempre rodar `_load()` fora e atribuir num corpo de bloco: `setState(() { _future = f; });`.
