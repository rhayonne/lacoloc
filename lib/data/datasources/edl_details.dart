import 'package:lacoloc_front/data/models/edl_details.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CRUD das tabelas filhas do état des lieux completo (preneurs, relevés,
/// clés, sections + lignes). Todas seguem o padrão estático dos datasources.
class EdlDetailsDatasource {
  EdlDetailsDatasource._();

  static final _db = Supabase.instance.client;

  static const _preneurs = 'etat_de_lieux_preneurs';
  static const _releves = 'etat_de_lieux_releves';
  static const _cles = 'etat_de_lieux_cles';
  static const _sections = 'etat_de_lieux_sections';
  static const _lignes = 'etat_de_lieux_lignes';

  // ── Preneurs ───────────────────────────────────────────────────────────────
  static Future<List<EdlPreneur>> listPreneurs(int edlId) async {
    final rows = await _db
        .from(_preneurs)
        .select()
        .eq('etat_de_lieux_id', edlId)
        .order('ordre');
    return rows.map(EdlPreneur.fromMap).toList();
  }

  static Future<EdlPreneur> createPreneur(EdlPreneur p) async {
    final row = await _db.from(_preneurs).insert(p.toInsert()).select().single();
    return EdlPreneur.fromMap(row);
  }

  static Future<void> updatePreneur(int id, EdlPreneur p) async {
    await _db.from(_preneurs).update(p.toInsert()).eq('id', id);
  }

  static Future<void> deletePreneur(int id) async {
    await _db.from(_preneurs).delete().eq('id', id);
  }

  // ── Relevés (compteurs / chauffage / eau chaude) ─────────────────────────────
  static Future<List<EdlReleve>> listReleves(int edlId) async {
    final rows = await _db
        .from(_releves)
        .select()
        .eq('etat_de_lieux_id', edlId)
        .order('categorie')
        .order('ordre');
    return rows.map(EdlReleve.fromMap).toList();
  }

  static Future<EdlReleve> createReleve(EdlReleve r) async {
    final row = await _db.from(_releves).insert(r.toInsert()).select().single();
    return EdlReleve.fromMap(row);
  }

  static Future<void> updateReleve(int id, EdlReleve r) async {
    await _db.from(_releves).update(r.toInsert()).eq('id', id);
  }

  static Future<void> deleteReleve(int id) async {
    await _db.from(_releves).delete().eq('id', id);
  }

  // ── Clés ─────────────────────────────────────────────────────────────────────
  static Future<List<EdlCle>> listCles(int edlId) async {
    final rows = await _db
        .from(_cles)
        .select()
        .eq('etat_de_lieux_id', edlId)
        .order('ordre');
    return rows.map(EdlCle.fromMap).toList();
  }

  static Future<EdlCle> createCle(EdlCle c) async {
    final row = await _db.from(_cles).insert(c.toInsert()).select().single();
    return EdlCle.fromMap(row);
  }

  static Future<void> updateCle(int id, EdlCle c) async {
    await _db.from(_cles).update(c.toInsert()).eq('id', id);
  }

  static Future<void> deleteCle(int id) async {
    await _db.from(_cles).delete().eq('id', id);
  }

  // ── Sections + lignes ────────────────────────────────────────────────────────
  /// Carrega as sections de um EDL já com as `lignes` embarcadas (ordenadas).
  static Future<List<EdlSection>> listSections(int edlId) async {
    final rows = await _db
        .from(_sections)
        .select('*, etat_de_lieux_lignes(*)')
        .eq('etat_de_lieux_id', edlId)
        .order('ordre');
    final sections = rows.map(EdlSection.fromMap).toList();
    return sections;
  }

  static Future<EdlSection> createSection(EdlSection s) async {
    final row = await _db.from(_sections).insert(s.toInsert()).select().single();
    return EdlSection.fromMap(row);
  }

  static Future<void> updateSection(int id, EdlSection s) async {
    await _db.from(_sections).update(s.toInsert()).eq('id', id);
  }

  static Future<void> deleteSection(int id) async {
    await _db.from(_sections).delete().eq('id', id);
  }

  static Future<EdlLigne> createLigne(EdlLigne l) async {
    final row = await _db.from(_lignes).insert(l.toInsert()).select().single();
    return EdlLigne.fromMap(row);
  }

  static Future<void> updateLigne(int id, EdlLigne l) async {
    await _db.from(_lignes).update(l.toInsert()).eq('id', id);
  }

  static Future<void> deleteLigne(int id) async {
    await _db.from(_lignes).delete().eq('id', id);
  }

  /// Cria uma section completa (com suas lignes) numa só sequência.
  static Future<EdlSection> createSectionWithLignes(
    EdlSection section,
    List<EdlLigne> lignes,
  ) async {
    final created = await createSection(section);
    final sid = created.id!;
    for (var i = 0; i < lignes.length; i++) {
      final l = lignes[i];
      await createLigne(
        EdlLigne(
          sectionId: sid,
          equipement: l.equipement,
          natureNombre: l.natureNombre,
          etatUsure: l.etatUsure,
          fonctionnement: l.fonctionnement,
          commentaires: l.commentaires,
          ordre: i,
        ),
      );
    }
    return (await listSections(section.etatDesLieuxId))
        .firstWhere((s) => s.id == sid, orElse: () => created);
  }
}
