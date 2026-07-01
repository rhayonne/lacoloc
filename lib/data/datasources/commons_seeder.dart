import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/pieces.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:lacoloc_front/data/models/piece.dart';
import 'package:lacoloc_front/data/pieces_communes_seed.dart';

/// Génère les parties communes standard d'un immeuble (pièces + inventaire).
class CommonsSeeder {
  CommonsSeeder._();

  /// Construit, pour un nom d'équipement du seed, l'article d'inventaire.
  /// Si le nom correspond à un meuble du catalogue (`Meubles_Reference`,
  /// p. ex. un électroménager comme « Four », « Micro-ondes »…), on le rattache
  /// via `meuble_ref_id` (qui porte la **catégorie**, donc « Électroménager »)
  /// au lieu d'un simple `nom_custom`. Ainsi l'électroménager est correctement
  /// catalogué dans l'inventaire au lieu d'un texte libre.
  static InventaireModel _articleFor(
    String nom, {
    required int immeubleId,
    int? pieceId,
    required Map<String, int> refByNom,
    required DateTime now,
  }) {
    final refId = refByNom[nom.trim().toLowerCase()];
    return InventaireModel(
      id: 0,
      immeubleId: immeubleId,
      pieceId: pieceId,
      meubleRefId: refId,
      nomCustom: refId == null ? nom : null,
      quantite: 1,
      photos: const [],
      createdAt: now,
    );
  }

  /// Charge le catalogue des meubles et l'indexe par nom (minuscules) → id.
  static Future<Map<String, int>> _loadRefByNom() async {
    try {
      final refs = await InventaireDatasource.listMeubleReferences();
      return {for (final r in refs) r.nom.trim().toLowerCase(): r.id};
    } catch (_) {
      return const {};
    }
  }

  /// Crée les 7 pièces communes du modèle. Si [meuble] est vrai, crée aussi
  /// l'inventaire (nom_custom) de chaque pièce, rattaché à la pièce.
  static Future<void> seed(int immeubleId, {required bool meuble}) async {
    final now = DateTime.now();

    // 1) Créer les pièces en lot (ordre conservé par le retour).
    final pieces = await PiecesDatasource.createMany([
      for (final seed in kPiecesCommunesSeed)
        PieceModel(
          id: 0,
          immeubleId: immeubleId,
          nom: seed.nom,
          photos: const [],
          createdAt: now,
        ),
    ]);

    if (!meuble) return;

    // 2) Associer les pièces créées à leur modèle (par nom) et créer l'inventaire.
    final refByNom = await _loadRefByNom();
    final byNom = {for (final p in pieces) p.nom: p};
    final articles = <InventaireModel>[];
    for (final seed in kPiecesCommunesSeed) {
      final piece = byNom[seed.nom];
      if (piece == null) continue;
      for (final nom in seed.equipements) {
        articles.add(_articleFor(
          nom,
          immeubleId: immeubleId,
          pieceId: piece.id,
          refByNom: refByNom,
          now: now,
        ));
      }
    }
    await InventaireDatasource.createMany(articles);
  }

  /// Développe une sélection (nom + quantité) en noms de pièces concrets :
  /// quantité 1 → « WC », quantité N>1 → « WC 1 »…« WC N ».
  static List<String> expandNoms(String nom, int quantite) {
    if (quantite <= 1) return [nom];
    return [for (var i = 1; i <= quantite; i++) '$nom $i'];
  }

  /// Map nom de pièce du modèle → ses équipements (inventaire) du seed.
  static final Map<String, List<String>> equipementsParNom = {
    for (final s in kPiecesCommunesSeed) s.nom: s.equipements,
  };

  /// Crée en base les pièces **sélectionnées** (avec quantité → noms numérotés)
  /// et, si [meuble], leur inventaire (issu du modèle, par nom de base).
  /// [selection] : couples (nom du modèle, quantité). Réutilise [expandNoms] et
  /// la même logique d'inventaire que [seed].
  static Future<void> seedSelection(
    int immeubleId, {
    required bool meuble,
    required List<({String nom, int quantite})> selection,
  }) async {
    if (selection.isEmpty) return;
    final now = DateTime.now();

    // 1) Développer la sélection en pièces concrètes (en gardant le nom de base
    //    pour retrouver l'inventaire du modèle).
    final aCreer = <({String nomConcret, String nomBase})>[];
    for (final sel in selection) {
      for (final nomConcret in expandNoms(sel.nom, sel.quantite)) {
        aCreer.add((nomConcret: nomConcret, nomBase: sel.nom));
      }
    }

    final pieces = await PiecesDatasource.createMany([
      for (final p in aCreer)
        PieceModel(
          id: 0,
          immeubleId: immeubleId,
          nom: p.nomConcret,
          photos: const [],
          createdAt: now,
        ),
    ]);

    if (!meuble) return;

    // 2) Associer chaque pièce créée (par nom concret) à l'inventaire du modèle
    //    (récupéré via son nom de base).
    final refByNom = await _loadRefByNom();
    final baseParNomConcret = {for (final p in aCreer) p.nomConcret: p.nomBase};
    final articles = <InventaireModel>[];
    for (final piece in pieces) {
      final nomBase = baseParNomConcret[piece.nom];
      final equipements = nomBase == null ? null : equipementsParNom[nomBase];
      if (equipements == null) continue;
      for (final nom in equipements) {
        articles.add(_articleFor(
          nom,
          immeubleId: immeubleId,
          pieceId: piece.id,
          refByNom: refByNom,
          now: now,
        ));
      }
    }
    await InventaireDatasource.createMany(articles);
  }
}
