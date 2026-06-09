import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/piece.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PiecesDatasource {
  PiecesDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Pieces';

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.pieces);

  static Future<List<PieceModel>> listByImmeuble(
    int immeubleId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.pieces}immeuble:$immeubleId', () async {
      final rows = await _db
          .from(_table)
          .select()
          .eq('immeuble_id', immeubleId)
          .order('created_at', ascending: true);
      return rows
          .map((r) => PieceModel.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    }, refresh: refresh);
  }

  static Future<PieceModel> create(PieceModel piece) async {
    final row = await _db
        .from(_table)
        .insert(piece.toInsert())
        .select()
        .single();
    _invalidate();
    return PieceModel.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> update(int id, PieceModel piece) async {
    await _db.from(_table).update(piece.toInsert()).eq('id', id);
    _invalidate();
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }

  /// Insère plusieurs pièces en une requête. Retourne les modèles créés (avec id).
  static Future<List<PieceModel>> createMany(List<PieceModel> pieces) async {
    if (pieces.isEmpty) return [];
    final rows = await _db
        .from(_table)
        .insert(pieces.map((p) => p.toInsert()).toList())
        .select();
    _invalidate();
    return rows
        .map((r) => PieceModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }
}
