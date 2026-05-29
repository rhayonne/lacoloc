# État des Lieux (EDL) — Fluxo Completo

O état des lieux é o "contrato" entre propriétaire e locataire. Ele tem um **tipo**
(`entree` / `sortie`), um **tipo de bail** (`collectif` / `individuel`), uma
**partie** (`commune` / `privative`) e uma **situation** que evolui com o tempo.

> Modelos de referência (documentos reais preenchidos à mão) em [`../Maquettes/`](../Maquettes/):
> `edl partie commune` e `edl partie privée`.

## Partie commune × privative (vínculo collectif ↔ individuel)

```mermaid
graph TD
    IMM["🏢 Immeuble"]
    IMM -->|bail collectif| CO1["EDL partie=commune\n(chambre_id null)\n— ÚNICO"]
    IMM -->|bail individuel| CO2["EDL partie=commune\n(compartilhado do imóvel)"]
    CO2 --> P1["EDL partie=privative\nchambre A · edl_collectif_id → commune"]
    CO2 --> P2["EDL partie=privative\nchambre B · edl_collectif_id → commune"]
    CO2 --> P3["EDL partie=privative\nchambre C · edl_collectif_id → commune"]
```

- **Bail collectif** → existe **somente** o EDL `commune`.
- **Bail individuel** → 1 EDL `commune` por imóvel (parties communes) + 1 EDL
  `privative` por chambre/locataire, cada um apontando para o `commune` via
  `edl_collectif_id`.
- Datasource: `EtatDesLieuxDatasource.ensureCollectif()`, `findCollectif()`,
  `listPrivativesByCollectif()`.

## Estrutura de dados do documento (tabelas filhas)

```mermaid
erDiagram
    etat_de_lieux ||--o{ etat_de_lieux_preneurs : "preneurs (colocataires)"
    etat_de_lieux ||--o{ etat_de_lieux_releves  : "compteurs/chauffage/eau chaude"
    etat_de_lieux ||--o{ etat_de_lieux_cles     : "remise des clés (privative)"
    etat_de_lieux ||--o{ etat_de_lieux_sections : "pièces do documento"
    etat_de_lieux_sections ||--o{ etat_de_lieux_lignes : "linhas de equipamento"
    etat_de_lieux ||--o| etat_de_lieux : "edl_collectif_id (privative→commune)"
```

| Tabela | Conteúdo no documento | Datasource |
|---|---|---|
| `etat_de_lieux_preneurs` | LE(S) PRENEUR(S) — nome + adresse | `EdlDetailsDatasource.*Preneur` |
| `etat_de_lieux_releves` | Compteurs eau/gaz/élec, chauffage, eau chaude | `*Releve` |
| `etat_de_lieux_cles` | REMISE DES CLÉS (type, nombre, date) | `*Cle` |
| `etat_de_lieux_sections` | Cada pièce (ENTREE, SEJOUR, CHAMBRE…) + commentaire global | `*Section` |
| `etat_de_lieux_lignes` | EQUIPEMENT · NATURE/NOMBRE · ÉTAT D'USURE · FONCTIONNEMENT · COMMENTAIRES | `*Ligne` |

`etat_usure`: `N` neuf · `B` bon état · `U` état d'usage · `M` mauvais.
As linhas de equipamento são alimentadas pelo `Inventaire` + estrutura da
chambre/immeuble, mais itens estruturais (SOL, MURs, PLAFOND, FENETRES…).

## Estados (`SituationEdl`)

```mermaid
stateDiagram-v2
    [*] --> aVenir : date_etat_lieux no futuro
    [*] --> enCours : date_etat_lieux hoje/passado

    aVenir --> enCours : chega a data
    enCours --> finalise : propriétaire clica "Finaliser"
    finalise --> finalise : aguarda assinatura

    note right of finalise
        date_finalisation só é gravada
        quando o LOCATAIRE aceita e assina
        (locataire_accepte = true)
    end note
```

| `SituationEdl` | `raw` (DB) | Label | Origem |
|---|---|---|---|
| `aVenir` | `a_venir` | À venir | `date_etat_lieux` futura |
| `enCours` | `en_cours` | En cours | data atingida, ainda editável |
| `finalise` | `finalise` | Finalisé | propriétaire finalizou |

---

## Ciclo de Vida — Propriétaire cria e finaliza

```mermaid
sequenceDiagram
    actor PR as Propriétaire
    participant FORM as Formulaire EDL
    participant EDS as EtatDesLieuxDatasource
    participant OBS as ObservationsEdlDatasource
    participant DB as Supabase

    PR->>FORM: Nouveau (entrée/sortie)
    FORM->>EDS: searchLocataires(query)  %% RPC
    EDS->>DB: rpc('search_locataires')
    DB-->>FORM: lista de locataires
    alt locataire não existe
        PR->>FORM: "Créer un locataire" (dialog)
        FORM->>EDS: inviteLocataire(fullName, email, proprietaireId, phone?, dob?)
        EDS->>DB: functions.invoke('invite-locataire')
        DB-->>FORM: { userId } → chip selecionado
    end
    PR->>FORM: escolhe lieu (immeuble + chambre), type_bail, type_edl, date, montant
    FORM->>EDS: create(EtatDesLieuxModel) → situation derivada da data
    EDS->>DB: insert etat_de_lieux (+ observations JSONB)
    DB-->>FORM: EDL com id

    PR->>FORM: Plan 2D — observations por mur (fond/gauche/droit/porte)
    FORM->>OBS: insertWall / updateById (description + photos)
    OBS->>DB: etat_de_lieux_observations

    PR->>FORM: "Finaliser"
    FORM->>EDS: finaliser(id) → situation = finalise
    Note over FORM,DB: date_finalisation continua null\naté o locataire assinar
```

---

## Ciclo de Vida — Locataire aceita e assina

```mermaid
sequenceDiagram
    actor LC as Locataire
    participant PROF as LocataireProfil (aba État des lieux)
    participant EDS as EtatDesLieuxDatasource
    participant DB as Supabase

    LC->>PROF: abre aba "État des lieux"
    PROF->>EDS: listByLocataire(uid)
    EDS->>DB: select etat_de_lieux (join proprietaire/immeuble/chambre)
    DB-->>PROF: lista

    Note over PROF: "Vision générale" destaca EDLs\nfinalisés ainda não aceitos (pending)

    LC->>PROF: "Accepter et signer"
    PROF->>EDS: locataireAccepter(id)
    EDS->>DB: update { locataire_accepte: true, date_finalisation: today }
    DB-->>PROF: ok → some da lista de pendências
```

---

## Tab "Vision générale" (Propriétaire — `EtatDesLieuxPage`)

```mermaid
graph TD
    VG["Vision générale"]
    VG --> URG["Card Urgents\n(EDLs com date_etat_lieux entre hoje e hoje+3)"]
    VG --> INV["Card Locataires invités\n(listInvitedLocataires — invited_by_proprietaire_id)"]
    VG --> TAB["_EdlTableCard\n(busca + chips de situation + lista)"]

    INV --> RES["Botão 'Renvoyer →'\n(invite-locataire em modo resend)"]
    TAB -->|"&lt; 900px"| CARDS["Cards verticais (responsivo)"]
    TAB -->|"&ge; 900px"| TABLE["Tabela com colunas"]
```

- **Urgents**: conta EDLs cuja `date_etat_lieux` cai entre hoje e hoje+3 dias.
- **Locataires invités**: vem de `list_invited_locataires` (RPC), filtrando por
  `invited_by_proprietaire_id`. Mostra coluna "E-mail envoyé" + botão "Renvoyer →".
- Após criar locataire pelo dialog, ele aparece como **chip** no formulário
  (avatar + nome + email + ×) e é imediatamente populado na tabela de invités.

---

## Observations (Plan 2D)

```mermaid
graph LR
    subgraph Murs["wall_key conhecidas"]
        F["fond — Mur du fond"]
        G["gauche — Mur gauche"]
        D["droit — Mur droit"]
        P["porte — Mur d'entrée / Porte"]
        N["null — Général"]
    end

    subgraph Persistencia["Persistência dupla"]
        J["etat_de_lieux.observations (JSONB)\n{ wall_key: { description, photos } }"]
        T["etat_de_lieux_observations (linhas)\n(id, wall_key, piece_id?, chambre_id?, description, photos)"]
    end

    Murs --> Persistencia
```

Cada observação tem `description` (texto livre) e `photos` (URLs do bucket `photos`).

### Plano de murs por pièce e por chambre (EDL collectif)

No fluxo **bail collectif**, o step **« État des pièces et chambres »** (após
« Composition ») mostra uma **lista expansível**: um item por **pièce** comum e um
por **chambre** do imóvel. Expandir um item revela o mesmo diagrama 2D de murs
(`_RoomDiagram`) daquela peça, com observações e fotos por mur + observação geral.

O escopo é feito por `etat_de_lieux_observations.piece_id` / `chambre_id`:

| Cenário | `piece_id` | `chambre_id` |
|---|---|---|
| Observação de uma pièce comum (collectif) | preenchido | null |
| Observação de uma chambre (collectif) | null | preenchido |
| EDL privatif (single-room) / observação geral | null | null |

O EDL **privatif** (bail individuel) mantém o step único « État de la chambre »
com observações de target null — comportamento inalterado.
