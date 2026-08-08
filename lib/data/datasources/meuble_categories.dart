import 'package:habitafrance/data/cache/data_cache.dart';
import 'package:habitafrance/data/cache/realtime_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeubleCategoryModel {
  final int id;
  final String nom;
  final int ordre;

  const MeubleCategoryModel({
    required this.id,
    required this.nom,
    required this.ordre,
  });

  factory MeubleCategoryModel.fromMap(Map<String, dynamic> m) =>
      MeubleCategoryModel(
        id:    m['id'] as int,
        nom:   m['nom'] as String,
        ordre: (m['ordre'] as int?) ?? 0,
      );

  MeubleCategoryModel copyWith({String? nom, int? ordre}) =>
      MeubleCategoryModel(id: id, nom: nom ?? this.nom, ordre: ordre ?? this.ordre);
}

class MeubleCategoriesDatasource {
  static final _db = Supabase.instance.client;
  static final _cache = DataCache.instance;
  static const _table = 'Meuble_Categories_Reference';
  static const _ttl = Duration(minutes: 30);

  static void _invalidate() =>
      _cache.invalidatePrefix(CacheKeys.meubleCategories);

  static Future<List<MeubleCategoryModel>> listAll() {
    return _cache.get('${CacheKeys.meubleCategories}all', () async {
      final data = await _db
          .from(_table)
          .select()
          .order('ordre')
          .order('nom');
      return (data as List).map((m) => MeubleCategoryModel.fromMap(m)).toList();
    }, ttl: _ttl);
  }

  static Future<MeubleCategoryModel> create({
    required String nom,
    required int ordre,
  }) async {
    final data = await _db
        .from(_table)
        .insert({'nom': nom.trim(), 'ordre': ordre})
        .select()
        .single();
    _invalidate();
    return MeubleCategoryModel.fromMap(data);
  }

  static Future<MeubleCategoryModel> update(MeubleCategoryModel model) async {
    final data = await _db
        .from(_table)
        .update({'nom': model.nom.trim(), 'ordre': model.ordre})
        .eq('id', model.id)
        .select()
        .single();
    _invalidate();
    return MeubleCategoryModel.fromMap(data);
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }
}
