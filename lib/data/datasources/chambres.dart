import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChambresDatasource {
  ChambresDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'Chambres';
  static const String _selectWithImmeuble =
      '*, Immeubles!immeuble_id(id, name, address, city, region, department, bail_collectif, bail_individuel, location_meuble, type_id)';

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.chambres);

  /// Lista pública: apenas chambres ativas.
  static Future<List<ChambreModel>> listAll({bool refresh = false}) {
    return _cache.get('${CacheKeys.chambres}all', () async {
      final rows = await _client
          .from(_table)
          .select(_selectWithImmeuble)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return _map(rows);
    }, refresh: refresh);
  }

  static Future<List<ChambreModel>> listByImmeuble(
    int immeubleId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.chambres}immeuble:$immeubleId', () async {
      final rows = await _client
          .from(_table)
          .select(_selectWithImmeuble)
          .eq('immeuble_id', immeubleId)
          .order('created_at', ascending: false);
      return _map(rows);
    }, refresh: refresh);
  }

  /// Todas as chambres de uma lista de imóveis (sem filtro de is_active —
  /// usado no dashboard do proprietário que precisa ver as inativas também).
  static Future<List<ChambreModel>> listByImmeubles(
    List<int> ids, {
    bool refresh = false,
  }) {
    if (ids.isEmpty) return Future.value([]);
    final key = '${CacheKeys.chambres}immeubles:${(ids.toList()..sort()).join(",")}';
    return _cache.get(key, () async {
      final rows = await _client
          .from(_table)
          .select(_selectWithImmeuble)
          .inFilter('immeuble_id', ids)
          .order('created_at', ascending: false);
      return _map(rows);
    }, refresh: refresh);
  }

  static Future<ChambreModel?> byId(int id, {bool refresh = false}) {
    return _cache.get('${CacheKeys.chambres}id:$id', () async {
      final row = await _client
          .from(_table)
          .select(_selectWithImmeuble)
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : ChambreModel.fromMap(row);
    }, refresh: refresh);
  }

  static Future<ChambreModel> create(ChambreModel input) async {
    final inserted = await _client
        .from(_table)
        .insert(input.toInsert())
        .select(_selectWithImmeuble)
        .single();
    _invalidate();
    return ChambreModel.fromMap(inserted);
  }

  static Future<ChambreModel> update(ChambreModel input) async {
    final updated = await _client
        .from(_table)
        .update(input.toInsert())
        .eq('id', input.id)
        .select(_selectWithImmeuble)
        .single();
    _invalidate();
    return ChambreModel.fromMap(updated);
  }

  /// Marca ou desmarca a chambre como ocupada sem carregar o modelo completo.
  static Future<void> setOccupied(int chambreId, {required bool occupied}) async {
    await _client.from(_table).update({'est_loue': occupied}).eq('id', chambreId);
    _invalidate();
  }

  /// Retorna { immeubleId → quantidade de chambres } para uma lista de ids.
  static Future<Map<int, int>> countsByImmeubles(List<int> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from(_table)
        .select('immeuble_id')
        .inFilter('immeuble_id', ids);
    final counts = <int, int>{};
    for (final r in rows as List) {
      final id = (r as Map<String, dynamic>)['immeuble_id'] as int;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  /// IDs dos imóveis que têm pelo menos uma chambre activa (para filtrar
  /// a listagem pública de imóveis).
  static Future<Set<int>> activeImmeubleIds() async {
    final rows = await _client
        .from(_table)
        .select('immeuble_id')
        .eq('is_active', true);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['immeuble_id'] as int)
        .toSet();
  }

  static List<ChambreModel> _map(List rows) =>
      rows.map((r) => ChambreModel.fromMap(r as Map<String, dynamic>)).toList();
}
