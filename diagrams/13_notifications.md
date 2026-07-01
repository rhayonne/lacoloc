# Notifications, badges & Realtime

> Notificações in-app para **proprietaire e locataire** (tabela `Notifications`,
> `recipient_id` = destinatário efetivo). Code :
> [notifications.dart](../lib/data/datasources/notifications.dart),
> [realtime_service.dart](../lib/data/cache/realtime_service.dart),
> [app_sidebar.dart](../lib/presentation/nav/app_sidebar.dart).

## Eventos

```mermaid
graph LR
    subgraph "→ Proprietaire"
        E1["edl_accepte\n(locataire aceita/assina)"]
        E2["edl_addition\n(locataire ajoute une addition)"]
    end
    subgraph "→ Locataire"
        E3["edl_a_signer\n(proprietaire finalise)"]
        E4["vetuste_a_recevoir\n(décompte → à recevoir)"]
        E5["bail_garant_requis\n(garant manquant)"]
    end
    subgraph "→ Audience (super admin)"
        E6["admin_message\n(diffusion)"]
    end

    E1 & E2 --> RPCp["RPC notify_edl_proprietaire\n(SECURITY DEFINER, recipient dérivé de l'EDL)"]
    E3 & E4 & E5 --> RPCl["RPC notify_edl_locataire"]
    E6 --> RPCa["RPC admin_broadcast_notification"]
    RPCp & RPCl & RPCa --> N[("Notifications\nrecipient_id, type, title, body,\netat_de_lieux_id?, media_*?, is_read")]
```

- **INSERT só via RPC** `SECURITY DEFINER` (o `recipient_id` é derivado do EDL / da audiência,
  não falsificável). RLS de SELECT/UPDATE/DELETE por `recipient_id = auth.uid()`.
- Eventos do proprietaire (`edl_accepte`, `edl_addition`) também disparam **e-mail** via edge
  function `notify-edl` ; `edl_a_signer`/`vetuste_a_recevoir` são in-app/realtime.

## Badges de menu + Realtime

```mermaid
sequenceDiagram
    participant DB as Supabase Realtime
    participant RT as RealtimeService (singleton)
    participant ST as State (RealtimeRefreshMixin)
    participant UI as SidebarX (badgedSidebarItem)

    DB-->>RT: change sur Notifications / Demandes_Contact
    RT->>RT: invalide le cache + incrémente revision (ValueNotifier)
    RT-->>ST: onRealtimeChange() (watchedEntities)
    ST->>ST: _refresh() (recharge + recalcule compteurs)
    ST-->>UI: badge mis à jour (count non lus)
```

- **Publicação realtime reduzida** a 2 tabelas leves : `Notifications` + `Demandes_Contact`.
  As demais entidades dependem de cache + recarregamento em ação/navegação.
- **Badges** (`badgedSidebarItem`) :
  - Proprietaire → **Interactions** = notifs não lidas + demandes não estabelecidas.
  - Locataire → **État des lieux** = EDL finalizados não assinados ; **Messages/Interactions** = notifs não lidas.
- O badge **só some quando o item é tratado** (assinar / ler / contato estabelecido).
- UI : aba **Notifications** na `InteractionsPage` (proprietaire) + « Notifications récentes »
  na `VueGeneralePage` ; menu **Interactions/Messages** do locataire (`NotificationCard`).
