import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImmeublesDatasource {
  ImmeublesDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'Immeubles';
  static const String _selectWithType =
      '*, Immeuble_Types_Reference!type_id(id, name)';

  static final _cache = DataCache.instance;

  /// Vide tout le cache des immeubles (après un write).
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.immeubles);

  /// Lista pública: apenas imóveis ativos.
  static Future<List<ImmeublesModel>> listAll({bool refresh = false}) {
    return _cache.get(
      '${CacheKeys.immeubles}all',
      () async {
        final rows = await _client
            .from(_table)
            .select(_selectWithType)
            .eq('is_active', true)
            .order('created_at', ascending: false);
        return _map(rows);
      },
      refresh: refresh,
    );
  }

  /// Lista do proprietário: todos os imóveis (ativos e inativos).
  static Future<List<ImmeublesModel>> listByOwner(
    String ownerId, {
    bool refresh = false,
  }) {
    return _cache.get(
      '${CacheKeys.immeubles}owner:$ownerId',
      () async {
        final rows = await _client
            .from(_table)
            .select(_selectWithType)
            .eq('owner_id', ownerId)
            .order('created_at', ascending: false);
        return _map(rows);
      },
      refresh: refresh,
    );
  }

  static Future<ImmeublesModel?> byId(int id, {bool refresh = false}) {
    return _cache.get(
      '${CacheKeys.immeubles}id:$id',
      () async {
        final row = await _client
            .from(_table)
            .select(_selectWithType)
            .eq('id', id)
            .maybeSingle();
        return row == null ? null : ImmeublesModel.fromMap(row);
      },
      refresh: refresh,
    );
  }

  static Future<ImmeublesModel> create(ImmeublesModel input) async {
    final inserted = await _client
        .from(_table)
        .insert(input.toInsert())
        .select(_selectWithType)
        .single();
    _invalidate();
    return ImmeublesModel.fromMap(inserted);
  }

  static Future<ImmeublesModel> update(ImmeublesModel input) async {
    final updated = await _client
        .from(_table)
        .update(input.toInsert())
        .eq('id', input.id)
        .select(_selectWithType)
        .single();
    _invalidate();
    return ImmeublesModel.fromMap(updated);
  }

  static List<ImmeublesModel> _map(List rows) =>
      rows.map((r) => ImmeublesModel.fromMap(r as Map<String, dynamic>)).toList();
}
