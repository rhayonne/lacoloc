import 'dart:async';

/// Cache mémoire simple, partagé par les datasources.
///
/// - `get` mémorise le résultat d'un fetch sous une clé ; les appels suivants
///   renvoient la valeur en cache tant qu'elle n'a pas expiré (TTL).
/// - Les appels concurrents pour la même clé partagent le même Future (évite
///   les requêtes dupliquées au premier chargement).
/// - `invalidate` / `invalidatePrefix` vident le cache (après un write ou un
///   événement realtime).
///
/// Convention de clés : `"<entité>:<scope>"`, ex. `"immeubles:owner:<uid>"`,
/// `"chambres:immeuble:42"`. L'invalidation par préfixe (`"chambres:"`) purge
/// toutes les variantes d'une entité.
class DataCache {
  DataCache._();
  static final DataCache instance = DataCache._();

  final _entries = <String, _Entry>{};

  /// TTL par défaut. Realtime invalide déjà à chaud ; le TTL est un filet de
  /// sécurité contre les données obsolètes (ex. perte d'un événement).
  static const Duration defaultTtl = Duration(minutes: 5);

  /// Renvoie la valeur en cache pour [key] si présente et non expirée, sinon
  /// exécute [fetch], mémorise le résultat et le renvoie.
  Future<T> get<T>(
    String key,
    Future<T> Function() fetch, {
    Duration ttl = defaultTtl,
    bool refresh = false,
  }) {
    final existing = _entries[key];
    if (!refresh && existing != null && !existing.isExpired) {
      // Future en cours (dédup) ou valeur déjà résolue.
      return existing.future as Future<T>;
    }
    final future = fetch();
    _entries[key] = _Entry(future, ttl);
    // Si le fetch échoue, on retire l'entrée pour permettre une nouvelle tentative.
    future.catchError((Object e) {
      if (identical(_entries[key]?.future, future)) _entries.remove(key);
      throw e;
    });
    return future;
  }

  /// Valeur déjà résolue en cache (sans déclencher de fetch), ou null.
  T? peek<T>(String key) {
    final e = _entries[key];
    if (e == null || e.isExpired || !e.isResolved) return null;
    return e.resolved as T?;
  }

  void invalidate(String key) => _entries.remove(key);

  void invalidatePrefix(String prefix) {
    _entries.removeWhere((k, _) => k.startsWith(prefix));
  }

  void clear() => _entries.clear();
}

class _Entry {
  final Future<Object?> future;
  final DateTime _createdAt;
  final Duration ttl;
  Object? resolved;
  bool isResolved = false;

  _Entry(this.future, this.ttl) : _createdAt = DateTime.now() {
    future.then((v) {
      resolved = v;
      isResolved = true;
    }).catchError((_) {});
  }

  bool get isExpired => DateTime.now().difference(_createdAt) > ttl;
}
