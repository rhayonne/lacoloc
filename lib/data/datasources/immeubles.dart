import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImmeublesDatasource {
  ImmeublesDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'Immeubles';
  static const String _selectWithType =
      '*, Immeuble_Types_Reference!type_id(id, name)';

  /// Lista pública: apenas imóveis ativos.
  static Future<List<ImmeublesModel>> listAll() async {
    final rows = await _client
        .from(_table)
        .select(_selectWithType)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return _map(rows);
  }

  /// Lista do proprietário: todos os imóveis (ativos e inativos).
  static Future<List<ImmeublesModel>> listByOwner(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select(_selectWithType)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return _map(rows);
  }

  static Future<ImmeublesModel?> byId(int id) async {
    final row = await _client
        .from(_table)
        .select(_selectWithType)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ImmeublesModel.fromMap(row);
  }

  static Future<ImmeublesModel> create(ImmeublesModel input) async {
    final inserted = await _client
        .from(_table)
        .insert(input.toInsert())
        .select(_selectWithType)
        .single();
    return ImmeublesModel.fromMap(inserted);
  }

  static Future<ImmeublesModel> update(ImmeublesModel input) async {
    final updated = await _client
        .from(_table)
        .update(input.toInsert())
        .eq('id', input.id)
        .select(_selectWithType)
        .single();
    return ImmeublesModel.fromMap(updated);
  }

  static List<ImmeublesModel> _map(List rows) =>
      rows.map((r) => ImmeublesModel.fromMap(r as Map<String, dynamic>)).toList();
}
