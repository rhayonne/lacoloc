# Notifications - Datasource

```dart
NotificationsDatasource.listByOwner(uid)  // RLS: recipient_id
NotificationsDatasource.markRead(notifId)
NotificationsDatasource.unreadCount(uid)

// RPC chamadas automaticamente
NotificationsDatasource.notifyEdlProprietaire(edlId, type, title, body)
NotificationsDatasource.notifyEdlLocataire(edlId, type, title, body)
```

**Tipos**: edl_accepte, edl_addition, edl_a_signer, nouvelle_demande, bail_garant_requis
