import 'package:lacoloc_front/data/models/facture.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FacturesDatasource {
  FacturesDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'Factures';
  static const String _select = '*, Immeubles!immeuble_id(id, name)';

  static Future<List<FactureModel>> listByOwner(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return _map(rows);
  }

  static Future<List<FactureModel>> listByImmeuble(int immeubleId) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('immeuble_id', immeubleId)
        .order('created_at', ascending: false);
    return _map(rows);
  }

  static Future<FactureModel> create(FactureModel input) async {
    final inserted = await _client
        .from(_table)
        .insert(input.toInsert())
        .select(_select)
        .single();
    return FactureModel.fromMap(inserted);
  }

  static Future<FactureModel> update(FactureModel input) async {
    final updated = await _client
        .from(_table)
        .update(input.toInsert())
        .eq('id', input.id)
        .select(_select)
        .single();
    return FactureModel.fromMap(updated);
  }

  static List<FactureModel> _map(List rows) =>
      rows.map((r) => FactureModel.fromMap(r as Map<String, dynamic>)).toList();
}
