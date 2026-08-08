# État des Lieux (EDL) - Formulários

## Overview

Sistema completo de formulários para documentação de estado de imóvel/quarto.

### Tipos de EDL

| Tipo | Partie | Escopo | Preneurs |
|------|--------|--------|----------|
| **Entrée** | comune | Bail location (imóvel completo) | Múltiplos |
| **Entrée Collectif** | commune | Bail individuel (parties comuns) | Derivado dos privativos |
| **Entrée Privatif** | privative | Bail individuel (uma chambre) | 1 locataire |
| **Sortie** | commune/privative | Couplé à entrée | Mesmo dos privatifs |
| **Avenant** | privative | Novo contrato após collectif finalizado | 1 locataire |

### Fluxo Principal

```
Novo EDL
  ↓
Seleção de imóvel/chambre
  ↓
Formulário (steps)
  ├─ Informações (bem, preneurs, datas)
  ├─ Pièces/Chambres (composição)
  ├─ Relevés (compteurs)
  ├─ Clés (privatif only)
  ├─ Observations (plano de murs)
  ├─ Composition (equipamentos)
  └─ (Additions - após finalizar)
  ↓
Finaliser (proprietaire)
  ↓
Accepter + Signer (locataire)
  ↓
Bail gerado
```

### Estados (situation)

- `a_venir` — data futura
- `en_cours` — hoje ou passado não-finalizado
- `finalise` — proprietaire clicou "Finaliser"

### Status Locataire

- `locataire_accepte = false` — Aguardando assinatura
- `locataire_accepte = true` + `date_finalisation` preenchida — Aceito

---

## 🔗 Relacionados

- **DATASOURCES.md** — EtatDesLieuxDatasource, EdlDetailsDatasource, ObservationsEdlDatasource
- **DATA_MODEL.md** — Tabelas: etat_de_lieux, etat_de_lieux_observations, preneurs, releves, cles, sections, lignes
- **FLOWS.md** — Detalhes de cada fluxo (create, edit, sortie, avenant, additions)
- **RLS.md** — Políticas (proprietaire, locataire preneur, super admin)
- **CONVENTIONS.md** — Padrões do projeto específicos a EDL
- **BAIL.md** (módulo) — Geração do contrato a partir de EDL
- **VETUSTE.md** (módulo) — Desgaste detectado na sortie
- **NOTIFICATIONS.md** (módulo) — Eventos: edl_a_signer, edl_accepte, edl_addition

---

## 🚀 Atalhos

- **Criar novo**: `showSelectImmeubleDialog` → `showSelectChambreDialog` → `EdlCollectifNonMeubleePage` ou `EdlIndividuelMeubleePage`
- **Finaliser**: `finaliser(id)` muda `situation = 'finalise'`
- **Aceitar**: `locataireAccepter(id)` muda `locataire_accepte = true, date_finalisation = today`
- **Faire addition**: Só durante `isAvenantWindowOpen` (entre finalise + N dias)
- **PDF**: `DocumentPdfButton` → `EdlPdfPreviewPage` → `edl_pdf_builder.dart`

---

## ⚠️ Cuidado

- **Collectif invisible**: Bail individuel tem collectif (`partie=commune`) que não aparece na UI (detalhe de implementação)
- **Soft-delete de privatif**: Deletar último privatif deleta o collectif órfão atomicamente (trigger DB)
- **RLS por EDL**: Use `can_access_edl(edl_id)` nas queries — ela valida se o usuário pode ver
- **Realtime não publicado**: EDL não está em `RealtimeService` (RLS muito cara); usa cache + refresh manual

---

**Veja também**: `CLAUDE.md` seção "État des Lieux (EDL)"
