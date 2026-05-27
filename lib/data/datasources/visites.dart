import 'package:lacoloc_front/data/models/visite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VisitesDatasource {
  VisitesDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Visites';

  static Future<List<VisiteModel>> listByOwner() async {
    final rows = await _db
        .from(_table)
        .select()
        .order('date_visite', ascending: true);
    return rows
        .map((r) => VisiteModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  static Future<VisiteModel> create(VisiteModel v) async {
    final row =
        await _db.from(_table).insert(v.toInsert()).select().single();
    return VisiteModel.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<VisiteModel> update(VisiteModel v) async {
    final row = await _db
        .from(_table)
        .update(v.toInsert())
        .eq('id', v.id)
        .select()
        .single();
    return VisiteModel.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
  }
}
