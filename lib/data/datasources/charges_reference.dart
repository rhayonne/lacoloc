import 'package:habitafrance/data/cache/data_cache.dart';
import 'package:habitafrance/data/cache/realtime_service.dart';
import 'package:habitafrance/data/models/charge_reference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChargesReferenceDatasource {
  static final _db = Supabase.instance.client;
  static final _cache = DataCache.instance;
  static const _table = 'Charges_Reference';
  static const _ttl = Duration(minutes: 30);

  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.chargesRef);

  static Future<List<ChargeReferenceModel>> listAll({bool activeOnly = false}) {
    final key = activeOnly
        ? '${CacheKeys.chargesRef}active'
        : '${CacheKeys.chargesRef}all';
    return _cache.get(key, () async {
      var q = _db.from(_table).select().order('ordre').order('nom');
      if (activeOnly) q = _db.from(_table).select().eq('is_active', true).order('ordre').order('nom');
      final rows = await q;
      return (rows as List).map((r) => ChargeReferenceModel.fromMap(Map<String, dynamic>.from(r as Map))).toList();
    }, ttl: _ttl);
  }

  static Future<ChargeReferenceModel> create(ChargeReferenceModel model) async {
    final row = await _db.from(_table).insert(model.toInsert()).select().single();
    _invalidate();
    return ChargeReferenceModel.fromMap(Map<String, dynamic>.from(row as Map));
  }

  static Future<ChargeReferenceModel> update(ChargeReferenceModel model) async {
    final row = await _db
        .from(_table)
        .update(model.toInsert())
        .eq('id', model.id)
        .select()
        .single();
    _invalidate();
    return ChargeReferenceModel.fromMap(Map<String, dynamic>.from(row as Map));
  }

  static Future<void> toggleActive(int id, bool value) async {
    await _db.from(_table).update({'is_active': value}).eq('id', id);
    _invalidate();
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }
}
