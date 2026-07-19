import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/immeuble_lot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImmeubleLotsDatasource {
  ImmeubleLotsDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Immeuble_Lots';
  static const _select =
      '*, '
      'syndic:Fournisseurs!syndic_fournisseur_id(id, nom), '
      'immeuble:Immeubles!immeuble_id(id, name)';

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.immeubleLots);

  /// Catalogue complet des lots du propriétaire (rattachés ou non).
  static Future<List<ImmeubleLotModel>> listByOwner(
    String ownerId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.immeubleLots}owner:$ownerId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);
      return rows.map(ImmeubleLotModel.fromMap).toList();
    }, refresh: refresh);
  }

  /// Lots déjà rattachés à un immeuble donné.
  static Future<List<ImmeubleLotModel>> listByImmeuble(
    int immeubleId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.immeubleLots}immeuble:$immeubleId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('immeuble_id', immeubleId)
          .order('id');
      return rows.map(ImmeubleLotModel.fromMap).toList();
    }, refresh: refresh);
  }

  static Future<ImmeubleLotModel> create(ImmeubleLotModel m) async {
    final row = await _db
        .from(_table)
        .insert(m.toInsert())
        .select(_select)
        .single();
    _invalidate();
    return ImmeubleLotModel.fromMap(row);
  }

  static Future<ImmeubleLotModel> update(int id, ImmeubleLotModel m) async {
    final row = await _db
        .from(_table)
        .update(m.toUpdate())
        .eq('id', id)
        .select(_select)
        .single();
    _invalidate();
    return ImmeubleLotModel.fromMap(row);
  }

  /// Rattache un lot existant à un immeuble.
  static Future<void> assignToImmeuble(int lotId, int immeubleId) async {
    await _db
        .from(_table)
        .update({'immeuble_id': immeubleId})
        .eq('id', lotId);
    _invalidate();
  }

  /// Détache un lot de son immeuble (le lot reste dans le catalogue).
  static Future<void> unassignFromImmeuble(int lotId) async {
    await _db.from(_table).update({'immeuble_id': null}).eq('id', lotId);
    _invalidate();
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }
}
