import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/facture.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FacturesDatasource {
  FacturesDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'Factures';
  static const String _select =
      '*, Immeubles!immeuble_id(id, name), Chambres!chambre_id(id, room_name)';

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.factures);

  static Future<List<FactureModel>> listByOwner(
    String ownerId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.factures}owner:$ownerId', () async {
      final rows = await _client
          .from(_table)
          .select(_select)
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);
      return _map(rows);
    }, refresh: refresh);
  }

  static Future<List<FactureModel>> listByImmeuble(
    int immeubleId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.factures}immeuble:$immeubleId', () async {
      final rows = await _client
          .from(_table)
          .select(_select)
          .eq('immeuble_id', immeubleId)
          .order('created_at', ascending: false);
      return _map(rows);
    }, refresh: refresh);
  }

  static Future<FactureModel> create(FactureModel input) async {
    final inserted = await _client
        .from(_table)
        .insert(input.toInsert())
        .select(_select)
        .single();
    _invalidate();
    return FactureModel.fromMap(inserted);
  }

  static Future<FactureModel> update(FactureModel input) async {
    final updated = await _client
        .from(_table)
        .update(input.toInsert())
        .eq('id', input.id)
        .select(_select)
        .single();
    _invalidate();
    return FactureModel.fromMap(updated);
  }

  static List<FactureModel> _map(List rows) =>
      rows.map((r) => FactureModel.fromMap(r as Map<String, dynamic>)).toList();
}
