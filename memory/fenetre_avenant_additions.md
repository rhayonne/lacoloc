---
name: fenetre-avenant-additions
description: Fenêtre configurável (dias) p/ avenant e additions após finalização do EDL
metadata:
  type: project
---

A janela de « avenant / additions » após a finalização de um EDL passou a ser **configurável pelo proprietaire** (antes era 1 mês fixo).

- **Preferência do proprietaire:** coluna `Users_Client.avenant_window_days` (int, default 30). UI: card « Fenêtre d'avenant / additions » (`_AvenantWindowCard`) na aba **Vision générale** do `EtatDesLieuxPage` (ChoiceChips 7/15/30/60/90 jours). Get/set via `EtatDesLieuxDatasource.getAvenantWindowDays()` / `setAvenantWindowDays()`.
- **Snapshot na finalização:** `etat_de_lieux.avenant_window_days` é gravado no `finaliser` a partir da preferência do proprietaire — fica estável e legível pelo locataire. Null = fallback `kDefaultAvenantWindowDays` (30) em [lib/data/models/etat_de_lieux.dart](lib/data/models/etat_de_lieux.dart).
- **Helpers no model:** `avenantWindowDaysOrDefault` e `isAvenantWindowOpen` (true se finalisé e `now < date_finalisation + windowDays`; se `date_finalisation` null → janela aberta). `_additionsOpen` na `EdlIndividuelMeubleePage` usa esse window.
- **Botão Avenant:** agora SÓ aparece na fiche de um EDL **individuel privatif** finalisé, **dentro da janela** (`isAvenantWindowOpen`). Removido do collectif/commune (o collectif agrupa os individuels). `_startAvenantDirect` resolve o collectif via `edlCollectifId` do privatif.

**Notificação ao assinar:** quando o locataire assina/aceita um EDL, o proprietaire recebe notificação in-app (RPC `notify_edl_proprietaire`) + e-mail (`notify-edl` event `accepte`) — já funcionava; o destinatário é derivado do `proprietaire_id` do EDL (qualquer tipo de perfil que possua/assine o EDL). Ver [[permissions-groups]] e [[ui-conventions]].
