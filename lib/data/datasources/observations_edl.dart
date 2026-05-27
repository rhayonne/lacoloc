import 'package:lacoloc_front/data/models/observation_edl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ObservationsEdlDatasource {
  ObservationsEdlDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'etat_de_lieux_observations';

  static Future<List<ObservationEdl>> listByEdl(int edlId) async {
    final rows = await _db
        .from(_table)
        .select()
        .eq('etat_de_lieux_id', edlId)
        .order('created_at');
    return rows.map(ObservationEdl.fromMap).toList();
  }

  /// Insère une nouvelle observation pour un mur (plusieurs obs par mur possibles).
  static Future<ObservationEdl> insertWall(ObservationEdl obs) async {
    final row = await _db
        .from(_table)
        .insert(obs.toInsert())
        .select()
        .single();
    return ObservationEdl.fromMap(row);
  }

  static Future<ObservationEdl> insertGeneral(ObservationEdl obs) async {
    final row = await _db
        .from(_table)
        .insert(obs.toInsert())
        .select()
        .single();
    return ObservationEdl.fromMap(row);
  }

  static Future<ObservationEdl> updateById(int id, ObservationEdl obs) async {
    final row = await _db
        .from(_table)
        .update(obs.toInsert())
        .eq('id', id)
        .select()
        .single();
    return ObservationEdl.fromMap(row);
  }

  static Future<void> deleteById(int id) async {
    await _db.from(_table).delete().eq('id', id);
  }
}
