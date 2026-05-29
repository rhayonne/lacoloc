import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/pieces.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:lacoloc_front/data/models/piece.dart';
import 'package:lacoloc_front/data/pieces_communes_seed.dart';

/// Génère les parties communes standard d'un immeuble (pièces + inventaire).
class CommonsSeeder {
  CommonsSeeder._();

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
    final byNom = {for (final p in pieces) p.nom: p};
    final articles = <InventaireModel>[];
    for (final seed in kPiecesCommunesSeed) {
      final piece = byNom[seed.nom];
      if (piece == null) continue;
      for (final nom in seed.equipements) {
        articles.add(InventaireModel(
          id: 0,
          immeubleId: immeubleId,
          pieceId: piece.id,
          nomCustom: nom,
          quantite: 1,
          photos: const [],
          createdAt: now,
        ));
      }
    }
    await InventaireDatasource.createMany(articles);
  }
}
