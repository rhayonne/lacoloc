# DataCache - Cache em Memória

```dart
DataCache.get('immeubles:owner:uid123', () async {
  return await ImmeublesDatasource.listByOwner(uid);
}, ttlMinutes: 5);

// Ao atualizar
DataCache.invalidatePrefix('immeubles:');
```

**TTL**: 5 min (padrão)
**Dedup**: Requisições concorrentes compartilham a mesma query
