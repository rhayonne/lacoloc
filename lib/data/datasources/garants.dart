import 'package:habitafrance/data/cache/data_cache.dart';
import 'package:habitafrance/data/cache/realtime_service.dart';
import 'package:habitafrance/data/models/garant.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GarantsDatasource {
  static final _db = Supabase.instance.client;
  static final _cache = DataCache.instance;
  static const _table = 'Garants';

  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.garants);

  /// Garants par ids (garants rattachés à un EDL via `etat_de_lieux_garants`).
  /// Retourne les lignes existantes (RLS-scopées).
  static Future<List<GarantModel>> byIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _db.from(_table).select().inFilter('id', ids);
    return (rows as List)
        .map((r) => GarantModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<List<GarantModel>> listByLocataire(String locataireId) {
    return _cache.get('${CacheKeys.garants}loc:$locataireId', () async {
      final rows = await _db
          .from(_table)
          .select()
          .eq('locataire_id', locataireId)
          .order('created_at', ascending: true);
      return rows.map((r) => GarantModel.fromMap(r)).toList();
    });
  }

  static Future<GarantModel> create(GarantModel garant) async {
    final row = await _db
        .from(_table)
        .insert(garant.toInsertMap())
        .select()
        .single();
    _invalidate();
    return GarantModel.fromMap(row);
  }

  static Future<GarantModel> update(GarantModel garant) async {
    final map = garant.toInsertMap()..remove('locataire_id');
    final row = await _db
        .from(_table)
        .update(map)
        .eq('id', garant.id)
        .select()
        .single();
    _invalidate();
    return GarantModel.fromMap(row);
  }

  static Future<void> setActive(int id, {required bool active}) async {
    await _db.from(_table).update({'is_active': active}).eq('id', id);
    _invalidate();
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }

  /// Garants **actifs** de plusieurs locataires en UNE requête (évite le N+1
  /// « 1 requête par preneur » du bail location). Retourne un map
  /// `locataire_id → garants` (clé absente = aucun garant actif).
  static Future<Map<String, List<GarantModel>>> activeByLocataires(
      Iterable<String> locataireIds) async {
    final ids = locataireIds.toSet().toList();
    if (ids.isEmpty) return {};
    final rows = await _db
        .from(_table)
        .select()
        .inFilter('locataire_id', ids)
        .eq('is_active', true)
        .order('created_at', ascending: true);
    final byLoc = <String, List<GarantModel>>{};
    for (final r in (rows as List)) {
      final g = GarantModel.fromMap(r as Map<String, dynamic>);
      (byLoc[g.locataireId] ??= []).add(g);
    }
    return byLoc;
  }

  /// Retourne les garants actifs d'un locataire (utilisé lors de la génération du bail).
  static Future<List<GarantModel>> activeByLocataire(String locataireId) {
    return _cache.get('${CacheKeys.garants}active:$locataireId', () async {
      final rows = await _db
          .from(_table)
          .select()
          .eq('locataire_id', locataireId)
          .eq('is_active', true)
          .order('created_at', ascending: true);
      return rows.map((r) => GarantModel.fromMap(r)).toList();
    });
  }
}
