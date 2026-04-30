import 'package:lacoloc_front/data/models/immeuble_type.dart';
import 'package:lacoloc_front/data/models/reference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tabelas de referência editáveis apenas pelo Super Admin.
/// Cacheado em memória após o primeiro fetch (mudam raramente).
class ReferenceDatasource {
  ReferenceDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;

  static List<ImmeubleTypeModel>? _typesCache;
  static List<ReferenceItem>? _optionsCache;

  static Future<List<ImmeubleTypeModel>> immeubleTypes({
    bool refresh = false,
  }) async {
    if (!refresh && _typesCache != null) return _typesCache!;
    final rows = await _client
        .from('Immeuble_Types_Reference')
        .select('id, name')
        .order('name');
    _typesCache = (rows as List)
        .map((r) => ImmeubleTypeModel.fromMap(r as Map<String, dynamic>))
        .toList();
    return _typesCache!;
  }

  static Future<List<ReferenceItem>> roomOptions({bool refresh = false}) async {
    if (!refresh && _optionsCache != null) return _optionsCache!;
    final rows = await _client
        .from('Options_Reference')
        .select('id, name')
        .order('name');
    _optionsCache = (rows as List)
        .map((r) => ReferenceItem.fromMap(r as Map<String, dynamic>))
        .toList();
    return _optionsCache!;
  }

  static void invalidate() {
    _typesCache = null;
    _optionsCache = null;
  }
}
