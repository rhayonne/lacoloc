import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
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

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.inventaire);

  static Future<List<MeubleReferenceModel>> listMeubleReferences() {
    return _cache.get('${CacheKeys.inventaire}meuble_refs', () async {
      final rows = await _db
          .from(_refTable)
          .select()
          .order('categorie')
          .order('nom');
      return rows.map(MeubleReferenceModel.fromMap).toList();
    }, ttl: const Duration(minutes: 30));
  }

  static Future<List<InventaireModel>> listByImmeuble(
    int immeubleId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.inventaire}immeuble:$immeubleId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('immeuble_id', immeubleId)
          .order('created_at', ascending: false);
      return rows.map(InventaireModel.fromMap).toList();
    }, refresh: refresh);
  }

  static Future<List<InventaireModel>> listByChambre(
    int chambreId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.inventaire}chambre:$chambreId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('chambre_id', chambreId)
          .order('created_at', ascending: false);
      return rows.map(InventaireModel.fromMap).toList();
    }, refresh: refresh);
  }

  /// Noms des articles « affichés dans l'annonce » (dans_annonce=true) groupés
  /// par chambre — sert à la carte publique et au filtre « équipements ».
  /// Passe par la RPC `chambre_equipements_annonce` (SECURITY DEFINER) qui
  /// n'expose que les noms → lisible aussi par le public / un locataire.
  static Future<Map<int, List<String>>> annonceLabelsByChambre(
    List<int> chambreIds, {
    bool refresh = false,
  }) {
    if (chambreIds.isEmpty) return Future.value(<int, List<String>>{});
    final sorted = [...chambreIds]..sort();
    return _cache.get('${CacheKeys.inventaire}annonce:${sorted.join(",")}',
        () async {
      final rows = await _db.rpc('chambre_equipements_annonce',
          params: {'p_chambre_ids': sorted});
      final map = <int, List<String>>{};
      for (final r in (rows as List)) {
        final cid = (r['chambre_id'] as num?)?.toInt();
        final nom = r['nom'] as String?;
        if (cid == null || nom == null || nom.isEmpty) continue;
        (map[cid] ??= <String>[]).add(nom);
      }
      return map;
    }, refresh: refresh);
  }

  /// Liste distincte (triée) des noms d'équipements « dans l'annonce » — pour
  /// alimenter les chips du filtre. Lisible par le public via la RPC.
  static Future<List<String>> annonceEquipementNames({bool refresh = false}) {
    return _cache.get('${CacheKeys.inventaire}annonce_names', () async {
      final rows = await _db
          .rpc('chambre_equipements_annonce', params: {'p_chambre_ids': null});
      final set = <String>{};
      for (final r in (rows as List)) {
        final nom = r['nom'] as String?;
        if (nom != null && nom.isNotEmpty) set.add(nom);
      }
      final list = set.toList()..sort();
      return list;
    }, ttl: const Duration(minutes: 30), refresh: refresh);
  }

  static Future<InventaireModel> create(InventaireModel m) async {
    final row = await _db
        .from(_table)
        .insert(m.toInsert())
        .select(_select)
        .single();
    _invalidate();
    return InventaireModel.fromMap(row);
  }

  static Future<InventaireModel> update(int id, InventaireModel m) async {
    final row = await _db
        .from(_table)
        .update(m.toInsert())
        .eq('id', id)
        .select(_select)
        .single();
    _invalidate();
    return InventaireModel.fromMap(row);
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }

  /// Insère plusieurs articles en une requête.
  static Future<void> createMany(List<InventaireModel> items) async {
    if (items.isEmpty) return;
    await _db.from(_table).insert(items.map((m) => m.toInsert()).toList());
    _invalidate();
  }

  /// Supprime tous les articles liés à une pièce.
  static Future<void> deleteByPiece(int pieceId) async {
    await _db.from(_table).delete().eq('piece_id', pieceId);
    _invalidate();
  }

  /// Supprime tous les articles liés à une chambre.
  static Future<void> deleteByChambre(int chambreId) async {
    await _db.from(_table).delete().eq('chambre_id', chambreId);
    _invalidate();
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
    _invalidate();
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
    _invalidate();
    return MeubleReferenceModel.fromMap(row);
  }

  static Future<void> deleteRef(int id) async {
    await _db.from(_refTable).delete().eq('id', id);
    _invalidate();
  }
}
