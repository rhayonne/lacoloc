import 'package:lacoloc_front/data/models/piece.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PiecesDatasource {
  PiecesDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Pieces';

  static Future<List<PieceModel>> listByImmeuble(int immeubleId) async {
    final rows = await _db
        .from(_table)
        .select()
        .eq('immeuble_id', immeubleId)
        .order('created_at', ascending: true);
    return rows
        .map((r) => PieceModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  static Future<PieceModel> create(PieceModel piece) async {
    final row = await _db
        .from(_table)
        .insert(piece.toInsert())
        .select()
        .single();
    return PieceModel.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> update(int id, PieceModel piece) async {
    await _db.from(_table).update(piece.toInsert()).eq('id', id);
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
  }
}
