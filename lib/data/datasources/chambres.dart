import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChambresDatasource {
  ChambresDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'Chambres';
  static const String _selectWithImmeuble =
      '*, Immeubles!immeuble_id(id, name, address, city, region, department, bail_collectif, bail_individuel)';

  /// Lista pública: apenas chambres ativas.
  static Future<List<ChambreModel>> listAll() async {
    final rows = await _client
        .from(_table)
        .select(_selectWithImmeuble)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return _map(rows);
  }

  static Future<List<ChambreModel>> listByImmeuble(int immeubleId) async {
    final rows = await _client
        .from(_table)
        .select(_selectWithImmeuble)
        .eq('immeuble_id', immeubleId)
        .order('created_at', ascending: false);
    return _map(rows);
  }

  /// Todas as chambres de uma lista de imóveis (sem filtro de is_active —
  /// usado no dashboard do proprietário que precisa ver as inativas também).
  static Future<List<ChambreModel>> listByImmeubles(List<int> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _client
        .from(_table)
        .select(_selectWithImmeuble)
        .inFilter('immeuble_id', ids)
        .order('created_at', ascending: false);
    return _map(rows);
  }

  static Future<ChambreModel?> byId(int id) async {
    final row = await _client
        .from(_table)
        .select(_selectWithImmeuble)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ChambreModel.fromMap(row);
  }

  static Future<ChambreModel> create(ChambreModel input) async {
    final inserted = await _client
        .from(_table)
        .insert(input.toInsert())
        .select(_selectWithImmeuble)
        .single();
    return ChambreModel.fromMap(inserted);
  }

  static Future<ChambreModel> update(ChambreModel input) async {
    final updated = await _client
        .from(_table)
        .update(input.toInsert())
        .eq('id', input.id)
        .select(_selectWithImmeuble)
        .single();
    return ChambreModel.fromMap(updated);
  }

  /// Retorna { immeubleId → quantidade de chambres } para uma lista de ids.
  static Future<Map<int, int>> countsByImmeubles(List<int> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from(_table)
        .select('immeuble_id')
        .inFilter('immeuble_id', ids);
    final counts = <int, int>{};
    for (final r in rows as List) {
      final id = (r as Map<String, dynamic>)['immeuble_id'] as int;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  /// IDs dos imóveis que têm pelo menos uma chambre activa (para filtrar
  /// a listagem pública de imóveis).
  static Future<Set<int>> activeImmeubleIds() async {
    final rows = await _client
        .from(_table)
        .select('immeuble_id')
        .eq('is_active', true);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['immeuble_id'] as int)
        .toSet();
  }

  static List<ChambreModel> _map(List rows) =>
      rows.map((r) => ChambreModel.fromMap(r as Map<String, dynamic>)).toList();
}
