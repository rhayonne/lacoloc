import 'package:habitafrance/data/cache/data_cache.dart';
import 'package:habitafrance/data/cache/realtime_service.dart';
import 'package:habitafrance/data/models/edl_details.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CRUD das tabelas filhas do état des lieux completo (preneurs, relevés,
/// clés, sections + lignes). Todas seguem o padrão estático dos datasources.
class EdlDetailsDatasource {
  EdlDetailsDatasource._();

  static final _db = Supabase.instance.client;
  static final _cache = DataCache.instance;

  /// Invalide tout le cache EDL (prefixe `edl:`). Appelé après chaque write
  /// qui modifie une table fille (preneur, relevé, clé, section, ligne).
  static void _invalidateEdl() =>
      _cache.invalidatePrefix(CacheKeys.edl);

  static const _preneurs = 'etat_de_lieux_preneurs';
  static const _releves = 'etat_de_lieux_releves';
  static const _cles = 'etat_de_lieux_cles';
  static const _sections = 'etat_de_lieux_sections';
  static const _lignes = 'etat_de_lieux_lignes';

  // ── Preneurs ───────────────────────────────────────────────────────────────
  static Future<List<EdlPreneur>> listPreneurs(int edlId) {
    return _cache.get('${CacheKeys.edl}preneurs:$edlId', () async {
      final rows = await _db
          .from(_preneurs)
          .select('*, locataire:Users_Client!locataire_id(email)')
          .eq('etat_de_lieux_id', edlId)
          .order('ordre');
      return rows.map(EdlPreneur.fromMap).toList();
    });
  }

  static Future<EdlPreneur> createPreneur(EdlPreneur p) async {
    final row = await _db.from(_preneurs).insert(p.toInsert()).select().single();
    _invalidateEdl();
    return EdlPreneur.fromMap(row);
  }

  static Future<void> updatePreneur(int id, EdlPreneur p) async {
    await _db.from(_preneurs).update(p.toInsert()).eq('id', id);
    _invalidateEdl();
  }

  static Future<void> deletePreneur(int id) async {
    await _db.from(_preneurs).delete().eq('id', id);
    _invalidateEdl();
  }

  /// Supprime le preneur d'un EDL (collectif) correspondant à un `locataire_id`.
  /// Utilisé quand on supprime l'EDL individuel d'une chambre : le locataire est
  /// retiré du collectif lié.
  static Future<void> deletePreneurByLocataire(
    int collectifId,
    String locataireId,
  ) async {
    await _db
        .from(_preneurs)
        .delete()
        .eq('etat_de_lieux_id', collectifId)
        .eq('locataire_id', locataireId);
    _invalidateEdl();
  }

  // ── Relevés (compteurs / chauffage / eau chaude) ─────────────────────────────
  static Future<List<EdlReleve>> listReleves(int edlId) {
    return _cache.get('${CacheKeys.edl}releves:$edlId', () async {
      final rows = await _db
          .from(_releves)
          .select()
          .eq('etat_de_lieux_id', edlId)
          .order('categorie')
          .order('ordre');
      return rows.map(EdlReleve.fromMap).toList();
    });
  }

  static Future<EdlReleve> createReleve(EdlReleve r) async {
    final row = await _db.from(_releves).insert(r.toInsert()).select().single();
    _invalidateEdl();
    return EdlReleve.fromMap(row);
  }

  static Future<void> updateReleve(int id, EdlReleve r) async {
    await _db.from(_releves).update(r.toInsert()).eq('id', id);
    _invalidateEdl();
  }

  static Future<void> deleteReleve(int id) async {
    await _db.from(_releves).delete().eq('id', id);
    _invalidateEdl();
  }

  // ── Clés ─────────────────────────────────────────────────────────────────────
  static Future<List<EdlCle>> listCles(int edlId) {
    return _cache.get('${CacheKeys.edl}cles:$edlId', () async {
      final rows = await _db
          .from(_cles)
          .select()
          .eq('etat_de_lieux_id', edlId)
          .order('ordre');
      return rows.map(EdlCle.fromMap).toList();
    });
  }

  static Future<EdlCle> createCle(EdlCle c) async {
    final row = await _db.from(_cles).insert(c.toInsert()).select().single();
    _invalidateEdl();
    return EdlCle.fromMap(row);
  }

  static Future<void> updateCle(int id, EdlCle c) async {
    await _db.from(_cles).update(c.toInsert()).eq('id', id);
    _invalidateEdl();
  }

  static Future<void> deleteCle(int id) async {
    await _db.from(_cles).delete().eq('id', id);
    _invalidateEdl();
  }

  // ── Sections + lignes ────────────────────────────────────────────────────────
  /// Carrega as sections de um EDL já com as `lignes` embarcadas (ordenadas).
  static Future<List<EdlSection>> listSections(int edlId) {
    return _cache.get('${CacheKeys.edl}sections:$edlId', () async {
      final rows = await _db
          .from(_sections)
          .select('*, etat_de_lieux_lignes(*)')
          .eq('etat_de_lieux_id', edlId)
          .order('ordre');
      return rows.map(EdlSection.fromMap).toList();
    });
  }

  static Future<EdlSection> createSection(EdlSection s) async {
    final row = await _db.from(_sections).insert(s.toInsert()).select().single();
    _invalidateEdl();
    return EdlSection.fromMap(row);
  }

  static Future<void> updateSection(int id, EdlSection s) async {
    await _db.from(_sections).update(s.toInsert()).eq('id', id);
    _invalidateEdl();
  }

  static Future<void> deleteSection(int id) async {
    await _db.from(_sections).delete().eq('id', id);
    _invalidateEdl();
  }

  static Future<EdlLigne> createLigne(EdlLigne l) async {
    final row = await _db.from(_lignes).insert(l.toInsert()).select().single();
    _invalidateEdl();
    return EdlLigne.fromMap(row);
  }

  static Future<void> updateLigne(int id, EdlLigne l) async {
    await _db.from(_lignes).update(l.toInsert()).eq('id', id);
    _invalidateEdl();
  }

  static Future<void> deleteLigne(int id) async {
    await _db.from(_lignes).delete().eq('id', id);
    _invalidateEdl();
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

  // ── Copie (EDL de sortie créé à partir d'une entrée) ─────────────────────────
  // Toutes idempotentes : ne copient que si la cible est vide.

  /// Copie la STRUCTURE (sections + lignes : nom de l'équipement / nature) de
  /// `fromEdlId` vers `toEdlId`. Les états d'usure / fonctionnement /
  /// commentaires ne sont PAS copiés : le sortie consigne l'état de sortie.
  static Future<void> copyStructure(int fromEdlId, int toEdlId) async {
    if ((await listSections(toEdlId)).isNotEmpty) return;
    final src = await listSections(fromEdlId);
    for (var i = 0; i < src.length; i++) {
      final s = src[i];
      await createSectionWithLignes(
        EdlSection(etatDesLieuxId: toEdlId, nom: s.nom, ordre: i),
        s.lignes
            .map((l) => EdlLigne(
                  sectionId: 0,
                  equipement: l.equipement,
                  natureNombre: l.natureNombre,
                  ordre: l.ordre,
                ))
            .toList(),
      );
    }
  }

  /// Copie les sections/lignes **avec leur état** (état d'usure, fonctionnement,
  /// commentaires) de `fromEdlId` vers `toEdlId`. Contrairement à [copyStructure]
  /// (qui repart d'un état vierge pour un sortie), on reprend ici l'état tel quel
  /// — sert au modèle « chaque EDL individuel reprend les parties communes du
  /// dernier EDL et reste modifiable indépendamment ». Idempotent.
  static Future<void> copyStructureWithState(int fromEdlId, int toEdlId) async {
    if ((await listSections(toEdlId)).isNotEmpty) return;
    final src = await listSections(fromEdlId);
    for (var i = 0; i < src.length; i++) {
      final s = src[i];
      await createSectionWithLignes(
        EdlSection(
          etatDesLieuxId: toEdlId,
          nom: s.nom,
          ordre: i,
          commentaireGlobal: s.commentaireGlobal,
        ),
        s.lignes
            .map((l) => EdlLigne(
                  sectionId: 0,
                  equipement: l.equipement,
                  natureNombre: l.natureNombre,
                  etatUsure: l.etatUsure,
                  fonctionnement: l.fonctionnement,
                  commentaires: l.commentaires,
                  ordre: l.ordre,
                ))
            .toList(),
      );
    }
  }

  /// Copie les preneurs de `fromEdlId` vers `toEdlId`.
  static Future<void> copyPreneurs(int fromEdlId, int toEdlId) async {
    if ((await listPreneurs(toEdlId)).isNotEmpty) return;
    for (final p in await listPreneurs(fromEdlId)) {
      await createPreneur(EdlPreneur(
        etatDesLieuxId: toEdlId,
        locataireId: p.locataireId,
        nom: p.nom,
        adresse: p.adresse,
        ordre: p.ordre,
      ));
    }
  }

  /// Copie les relevés (type/numéro de série/unité) ; l'index est relu à la
  /// sortie → laissé vide.
  static Future<void> copyReleves(int fromEdlId, int toEdlId) async {
    if ((await listReleves(toEdlId)).isNotEmpty) return;
    for (final r in await listReleves(fromEdlId)) {
      await createReleve(EdlReleve(
        etatDesLieuxId: toEdlId,
        categorie: r.categorie,
        type: r.type,
        numeroSerie: r.numeroSerie,
        unite: r.unite,
        ordre: r.ordre,
      ));
    }
  }

  /// Copie la liste des clés (type/nombre) ; la remise est ressaisie à la sortie.
  static Future<void> copyCles(int fromEdlId, int toEdlId) async {
    if ((await listCles(toEdlId)).isNotEmpty) return;
    for (final c in await listCles(fromEdlId)) {
      await createCle(EdlCle(
        etatDesLieuxId: toEdlId,
        typeCle: c.typeCle,
        nombre: c.nombre,
        ordre: c.ordre,
      ));
    }
  }
}
