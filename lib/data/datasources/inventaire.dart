import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventaireDatasource {
  InventaireDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Inventaire';
  static const _refTable = 'Meubles_Reference';
  static const _select =
      '*, '
      'meuble_ref:Meubles_Reference!meuble_ref_id(id, nom, categorie), '
      'chambre:Chambres!chambre_id(id, room_name), '
      'piece:Pieces!piece_id(id, nom)';

  static Future<List<MeubleReferenceModel>> listMeubleReferences() async {
    final rows = await _db
        .from(_refTable)
        .select()
        .order('categorie')
        .order('nom');
    return rows.map(MeubleReferenceModel.fromMap).toList();
  }

  static Future<List<InventaireModel>> listByImmeuble(int immeubleId) async {
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('immeuble_id', immeubleId)
        .order('created_at', ascending: false);
    return rows.map(InventaireModel.fromMap).toList();
  }

  static Future<List<InventaireModel>> listByChambre(int chambreId) async {
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('chambre_id', chambreId)
        .order('created_at', ascending: false);
    return rows.map(InventaireModel.fromMap).toList();
  }

  static Future<InventaireModel> create(InventaireModel m) async {
    final row = await _db
        .from(_table)
        .insert(m.toInsert())
        .select(_select)
        .single();
    return InventaireModel.fromMap(row);
  }

  static Future<InventaireModel> update(int id, InventaireModel m) async {
    final row = await _db
        .from(_table)
        .update(m.toInsert())
        .eq('id', id)
        .select(_select)
        .single();
    return InventaireModel.fromMap(row);
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
  }

  static Future<MeubleReferenceModel> createRef({
    required String nom,
    String? categorie,
  }) async {
    final row = await _db
        .from(_refTable)
        .insert({
          'nom': nom,
          if (categorie != null && categorie.isNotEmpty) 'categorie': categorie,
        })
        .select()
        .single();
    return MeubleReferenceModel.fromMap(row);
  }

  static Future<MeubleReferenceModel> updateRef(
    int id, {
    required String nom,
    String? categorie,
  }) async {
    final row = await _db
        .from(_refTable)
        .update({
          'nom': nom,
          'categorie': (categorie?.isEmpty ?? true) ? null : categorie,
        })
        .eq('id', id)
        .select()
        .single();
    return MeubleReferenceModel.fromMap(row);
  }

  static Future<void> deleteRef(int id) async {
    await _db.from(_refTable).delete().eq('id', id);
  }
}
