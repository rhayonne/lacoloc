# Finances — Factures & Recettes (à recevoir)

> Seção **Finances** do proprietaire (`FacturesListPage`: factures + recettes) e
> menu **Finances** do locataire (`_FinancesSection` — recettes que lhe concernem).
> Code : [recettes.dart](../lib/data/datasources/recettes.dart),
> [factures.dart](../lib/data/datasources/factures.dart).

## Visão geral

```mermaid
graph TD
    FIN["Finances"]
    FIN --> FAC["Factures (dépenses)\nmontant_ht · taux_tva · montant_ttc · statut"]
    FIN --> REC["Recettes (à recevoir)\nloyers + caution + décompte de vétusté"]
    REC --> SRC1["generateFromBail(edlId)\n→ échéances mensuelles (loyer)\n+ échéance caution/dépôt de garantie"]
    REC --> SRC2["createManual(...)\n(décompte de vétusté, etc.)"]
    REC --> LOC["Visible côté locataire\n(listByLocataire / RLS locataire_select_recettes)"]
```

## Origem das recettes

- **`generateFromBail(edlId)`** — a partir de um EDL d'**entrée finalisé + accepté**, gera
  as **échéances mensuelles** do loyer (idempotente : não duplica se já existirem) e a
  **échéance de caution** (dépôt de garantie, `depot_garantie_mois × loyer`).
- **`createManual(...)`** — échéance avulsa ; usada pelo **décompte de vétusté**
  (« Générer l'à recevoir », ver [11_vetuste.md](11_vetuste.md)) e por ajustes manuais.
- **`deleteFutureInstallments(...)`** — limpa échéances futuras (ex. ao refazer o bail).

## Ciclo de vida de uma recette (`statut`)

```mermaid
stateDiagram-v2
    [*] --> a_recevoir : création (échéance future)
    a_recevoir --> recu : markPaid(date_paiement)
    a_recevoir --> en_retard : markLate (échéance dépassée)
    en_retard --> recu : markPaid
    recu --> a_recevoir : markUnpaid (correction)
    en_retard --> a_recevoir : markUnpaid
```

- `a_recevoir` (défaut) · `recu` (com `date_paiement`) · `en_retard`.
- Leituras: `listByOwner(ownerId)` (proprietaire), `listByLocataire(locataireId)` e
  `listByEdl(edlId)`. Cache via `CacheKeys.recettes`.

## RLS

- `owner_all_recettes` : tudo onde `owner_id = auth.uid()`.
- `locataire_select_recettes` : leitura onde `locataire_id = auth.uid()` **ou**
  `is_edl_preneur(etat_de_lieux_id)` — assim a somme à recevoir (loyer/caution/vétusté)
  aparece automaticamente em **Finances** do locataire.
