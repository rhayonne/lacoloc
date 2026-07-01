import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/datasources/edl_details.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/meuble_categories.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:lacoloc_front/data/models/vetuste.dart';
import 'package:lacoloc_front/utils/vetuste_calc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Accès aux données de vétusté : barème (par proprietaire) et décomptes de
/// réparations locatives (+ leurs lignes). Convention statique + DataCache.
class VetusteDatasource {
  VetusteDatasource._();

  static final _db = Supabase.instance.client;
  static final _cache = DataCache.instance;
  static const _prefix = CacheKeys.vetuste;

  static void _invalidate() => _cache.invalidatePrefix(_prefix);

  static const _decompteSelect =
      '*, Immeubles!immeuble_id(name), Chambres!chambre_id(room_name), '
      'Users_Client!locataire_id(full_name), vetuste_decompte_ligne(*)';

  // ── Barème ─────────────────────────────────────────────────────────────────

  /// Valeurs par défaut par catégorie : (durée de vie, franchise, coef/an, résiduel %).
  static const Map<String, (int, int, double, double)> _defaults = {
    'Électroménager': (7, 1, 10, 10),
    'Mobilier': (10, 1, 8, 15),
    'Literie': (7, 0, 12, 10),
    'Rangement': (12, 1, 7, 15),
    'Cuisine': (10, 1, 8, 10),
    'Salle de bain': (12, 1, 7, 10),
    'Éclairage': (8, 0, 10, 10),
    'Décoration': (6, 0, 14, 10),
    'Électronique': (5, 1, 18, 10),
    'Autre': (10, 1, 10, 10),
  };
  static const (int, int, double, double) _fallback = (10, 1, 10, 10);

  /// Liste le barème du proprietaire ; crée les lignes manquantes (une par
  /// catégorie de référence) à la première lecture.
  static Future<List<VetusteBaremeModel>> listBareme(
    String ownerId, {
    bool refresh = false,
  }) {
    return _cache.get('${_prefix}bareme:$ownerId', () async {
      await _seedDefaults(ownerId);
      final rows = await _db
          .from('vetuste_bareme')
          .select()
          .eq('owner_id', ownerId)
          .order('categorie');
      return (rows as List)
          .map((r) => VetusteBaremeModel.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    }, refresh: refresh);
  }

  /// Insère, pour les catégories de référence absentes, une ligne de barème.
  static Future<void> _seedDefaults(String ownerId) async {
    final cats = await MeubleCategoriesDatasource.listAll();
    final existing = await _db
        .from('vetuste_bareme')
        .select('categorie')
        .eq('owner_id', ownerId);
    final have = {
      for (final r in (existing as List)) (r as Map)['categorie'] as String
    };
    final manquantes =
        cats.map((c) => c.nom).where((n) => !have.contains(n)).toList();
    if (manquantes.isEmpty) return;
    final toInsert = manquantes.map((cat) {
      final d = _defaults[cat] ?? _fallback;
      return {
        'owner_id': ownerId,
        'categorie': cat,
        'duree_vie_annees': d.$1,
        'franchise_annees': d.$2,
        'coefficient_annuel': d.$3,
        'residuel_min_pct': d.$4,
      };
    }).toList();
    await _db.from('vetuste_bareme').insert(toInsert);
  }

  static Future<void> upsertBareme(VetusteBaremeModel model) async {
    await _db.from('vetuste_bareme').update({
      'duree_vie_annees': model.dureeVieAnnees,
      'franchise_annees': model.franchiseAnnees,
      'coefficient_annuel': model.coefficientAnnuel,
      'residuel_min_pct': model.residuelMinPct,
    }).eq('id', model.id);
    _invalidate();
  }

  // ── Décomptes ────────────────────────────────────────────────────────────

  static Future<List<VetusteDecompteModel>> listDecomptes(
    String ownerId, {
    bool refresh = false,
  }) {
    return _cache.get('${_prefix}decomptes:$ownerId', () async {
      final rows = await _db
          .from('vetuste_decompte')
          .select(_decompteSelect)
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) =>
              VetusteDecompteModel.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    }, refresh: refresh);
  }

  static Future<VetusteDecompteModel?> findByEdl(int edlId) async {
    final rows = await _db
        .from('vetuste_decompte')
        .select(_decompteSelect)
        .eq('etat_de_lieux_id', edlId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return VetusteDecompteModel.fromMap(
        Map<String, dynamic>.from(list.first as Map));
  }

  /// Crée un décompte + ses lignes. Retourne l'id du décompte.
  static Future<int> createDecompte(
    VetusteDecompteModel decompte,
    List<VetusteDecompteLigneModel> lignes,
  ) async {
    final row = await _db
        .from('vetuste_decompte')
        .insert(decompte.toInsert())
        .select('id')
        .single();
    final id = ((row as Map)['id'] as num).toInt();
    if (lignes.isNotEmpty) {
      await _db.from('vetuste_decompte_ligne').insert([
        for (final l in lignes)
          {...l.toInsert(), 'decompte_id': id},
      ]);
    }
    _invalidate();
    return id;
  }

  /// Remplace toutes les lignes d'un décompte (édition de la fiche).
  static Future<void> replaceLignes(
    int decompteId,
    List<VetusteDecompteLigneModel> lignes,
  ) async {
    await _db.from('vetuste_decompte_ligne').delete().eq('decompte_id', decompteId);
    if (lignes.isNotEmpty) {
      await _db.from('vetuste_decompte_ligne').insert([
        for (final l in lignes) {...l.toInsert(), 'decompte_id': decompteId},
      ]);
    }
    _invalidate();
  }

  static Future<void> updateDecompte(
    int id, {
    double? totalMontant,
    String? statut,
    int? recetteId,
  }) async {
    final patch = <String, dynamic>{
      'total_montant': ?totalMontant,
      'statut': ?statut,
      'recette_id': ?recetteId,
    };
    if (patch.isEmpty) return;
    await _db.from('vetuste_decompte').update(patch).eq('id', id);
    _invalidate();
  }

  static Future<void> deleteDecompte(int id) async {
    await _db.from('vetuste_decompte').delete().eq('id', id);
    _invalidate();
  }

  // ── Détection des dégradations (entrée → sortie) ───────────────────────────

  /// Compare les lignes de l'EDL de **sortie** à celles de l'EDL d'**entrée**
  /// couplé (`edl_entree_id`) et construit les lignes candidates du décompte
  /// pour celles dont l'état d'usure a empiré. Préremplit valeur d'achat / date
  /// / catégorie depuis l'inventaire de l'immeuble (appariement par nom).
  /// Retourne une liste vide si pas d'entrée couplée ou aucune dégradation.
  static Future<List<VetusteDecompteLigneModel>> buildCandidatesForSortie(
    EtatDesLieuxModel sortie, {
    required List<VetusteBaremeModel> bareme,
    required List<InventaireModel> inventaire,
  }) async {
    if (sortie.edlEntreeId == null) return const [];
    final sortieSections = await EdlDetailsDatasource.listSections(sortie.id);
    final entreeSections =
        await EdlDetailsDatasource.listSections(sortie.edlEntreeId!);

    // Index entrée : (section, équipement) → état d'usure.
    final entreeIndex = <String, String?>{};
    for (final s in entreeSections) {
      for (final l in s.lignes) {
        entreeIndex['${s.nom}|${l.equipement}'] = l.etatUsure;
      }
    }

    final baremeParCat = {for (final b in bareme) b.categorie: b};
    final candidats = <VetusteDecompteLigneModel>[];
    var ordre = 0;
    for (final s in sortieSections) {
      for (final l in s.lignes) {
        final etatEntree = entreeIndex['${s.nom}|${l.equipement}'];
        if (!VetusteCalc.estDegrade(etatEntree, l.etatUsure)) continue;

        // Appariement inventaire par nom (et lieu si possible).
        final inv = inventaire
            .where((it) =>
                it.displayNom.toLowerCase().trim() ==
                l.equipement.toLowerCase().trim())
            .firstOrNull;
        final categorie = inv?.categorieVetuste;
        final valeurAchat = inv?.valeurAchat ?? 0;
        final dateAcq = inv?.dateAcquisition;
        final age = VetusteCalc.ageAnnees(dateAcq, ref: sortie.dateEtatLieux);
        final b = categorie == null ? null : baremeParCat[categorie];
        final abattement = VetusteCalc.abattementPct(b, age);
        final residuelle = VetusteCalc.valeurResiduelle(valeurAchat, abattement);

        candidats.add(VetusteDecompteLigneModel(
          id: 0,
          decompteId: 0,
          equipement: '${s.nom} — ${l.equipement}',
          categorie: categorie,
          valeurAchat: valeurAchat,
          dateAcquisition: dateAcq,
          ageAnnees: age,
          etatEntree: etatEntree,
          etatSortie: l.etatUsure,
          abattementPct: abattement,
          valeurResiduelle: residuelle,
          imputable: true,
          ordre: ordre++,
        ));
      }
    }
    return candidats;
  }

  /// Crée (idempotent) un décompte rattaché à un EDL de sortie à partir des
  /// candidates. Retourne l'id du décompte (existant ou nouveau).
  static Future<int> createDecompteFromSortie(
    EtatDesLieuxModel sortie,
    List<VetusteDecompteLigneModel> candidats,
  ) async {
    final existing = await findByEdl(sortie.id);
    if (existing != null) return existing.id;
    final total = candidats
        .where((l) => l.imputable)
        .fold<double>(0, (s, l) => s + l.valeurResiduelle);
    final decompte = VetusteDecompteModel(
      id: 0,
      ownerId: sortie.proprietaireId,
      immeubleId: sortie.immeubleId,
      chambreId: sortie.chambreId,
      locataireId: sortie.locataireId,
      etatDeLieuxId: sortie.id,
      titre: 'Décompte de réparations — sortie',
      statut: 'brouillon',
      totalMontant: total,
      createdAt: DateTime.now(),
    );
    return createDecompte(decompte, candidats);
  }

  /// Charge l'inventaire d'un immeuble (pour le préremplissage du décompte).
  static Future<List<InventaireModel>> inventairePourImmeuble(int immeubleId) =>
      InventaireDatasource.listByImmeuble(immeubleId);
}
