import 'package:flutter/foundation.dart';
import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Écoute les changements Postgres (Supabase Realtime) sur les tables suivies
/// et invalide le cache correspondant. Expose aussi un compteur de révision
/// par entité, pour que l'UI sache « il y a du nouveau » et se rafraîchisse.
///
/// Cycle de vie : `start()` après login, `stop()` au logout.
///
/// Mapping table → préfixe de cache invalidé (voir [CacheKeys]).
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  final _client = Supabase.instance.client;
  final _channels = <RealtimeChannel>[];

  /// Révision globale (incrémentée à chaque événement reçu). Les pages peuvent
  /// écouter ce notifier pour se rafraîchir.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Révision par entité (clé = préfixe sans « : », ex. `immeubles`).
  final Map<String, ValueNotifier<int>> _byEntity = {};

  bool _started = false;

  /// Interrupteur global. **Réactivé** : la publication `supabase_realtime` a été
  /// réduite à 2 tables légères ([_tables] : Notifications + Demandes_Contact),
  /// aux RLS simples et indexées, donc `realtime.list_changes` redevient rapide
  /// (plus de gel côté web). Les tables aux RLS coûteuses (etat_de_lieux via
  /// `is_edl_preneur`, Pieces, Inventaire) **ne sont plus publiées** ; le signal
  /// cross-user pour les EDL passe désormais par une **Notification** (table
  /// publiée). Les autres entités s'appuient sur le cache + rechargement à
  /// l'action/navigation.
  static bool enabled = true;

  /// Tables suivies (DOIVENT correspondre à la publication `supabase_realtime`).
  /// On garde seulement le cross-user léger : Notifications + Demandes_Contact.
  static const Map<String, String> _tables = {
    'Demandes_Contact': CacheKeys.demandes,
    'Notifications': CacheKeys.notifications,
  };

  ValueNotifier<int> entityRevision(String entity) =>
      _byEntity.putIfAbsent(entity, () => ValueNotifier<int>(0));

  void start() {
    if (!enabled) return; // realtime désactivé (voir [enabled])
    if (_started) return;
    _started = true;
    for (final entry in _tables.entries) {
      final table = entry.key;
      final prefix = entry.value;
      final channel = _client
          .channel('rt:$table')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (payload) => _onChange(prefix),
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  void _onChange(String prefix) {
    // Invalide le cache de l'entité ; la prochaine lecture refera le fetch.
    DataCache.instance.invalidatePrefix(prefix);
    revision.value++;
    final entity = prefix.replaceAll(':', '');
    entityRevision(entity).value++;
  }

  Future<void> stop() async {
    _started = false;
    for (final c in _channels) {
      await _client.removeChannel(c);
    }
    _channels.clear();
    DataCache.instance.clear();
  }
}

/// Préfixes de clés de cache (une source de vérité pour datasources + realtime).
class CacheKeys {
  CacheKeys._();
  static const immeubles = 'immeubles:';
  static const chambres = 'chambres:';
  static const pieces = 'pieces:';
  static const inventaire = 'inventaire:';
  static const factures = 'factures:';
  static const fournisseurs = 'fournisseurs:';
  static const demandes = 'demandes:';
  static const edl = 'edl:';
  static const notifications = 'notifications:';
  static const visites = 'visites:';
}
