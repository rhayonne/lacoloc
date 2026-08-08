import 'package:habitafrance/data/datasources/chambres.dart';
import 'package:habitafrance/data/datasources/edl_details.dart';
import 'package:habitafrance/data/datasources/etat_de_lieux.dart';
import 'package:habitafrance/data/datasources/observations_edl.dart';
import 'package:habitafrance/data/datasources/pieces.dart';
import 'package:habitafrance/data/models/chambre.dart';
import 'package:habitafrance/data/models/etat_de_lieux.dart';
import 'package:habitafrance/data/models/edl_details.dart';
import 'package:habitafrance/data/models/observation_edl.dart';
import 'package:habitafrance/data/models/piece.dart';

/// Mode d'impression d'un EDL de sortie.
enum EdlPdfMode {
  /// Le sortie seul.
  sortieSeul,

  /// Le sortie + l'état d'entrée en contrepoint (entrée vs sortie).
  contrepoint,
}

/// Portée du document (bail individuel uniquement) : tout, les parties communes
/// (collectif) ou la chambre (privatif).
enum EdlPdfScope { complet, communes, chambre }

/// Toutes les données nécessaires à la génération du PDF d'un EDL.
class EdlPdfData {
  final EtatDesLieuxModel edl;
  final List<EdlPreneur> preneurs;
  final List<EdlReleve> releves;
  final List<EdlCle> cles;
  final List<EdlSection> sections;
  final List<ObservationEdl> observations;
  final List<ObservationEdl> additions;

  /// EDL d'entrée couplé (si [edl] est un sortie), chargé pour le contrepoint.
  final EdlPdfData? entree;

  /// Noms des pièces/chambres (par id) pour grouper les observations + tables.
  final Map<int, String> pieceNames;
  final Map<int, String> chambreNames;

  /// Ids des EDL collectif/privatif (bail individuel) → permet de scoper le doc.
  final int? collectifEdlId;
  final int? privatifEdlId;

  const EdlPdfData({
    required this.edl,
    required this.preneurs,
    required this.releves,
    required this.cles,
    required this.sections,
    required this.observations,
    required this.additions,
    this.entree,
    this.pieceNames = const {},
    this.chambreNames = const {},
    this.collectifEdlId,
    this.privatifEdlId,
  });

  bool get isFinalise => edl.situation == SituationEdl.finalise;

  /// Vrai si c'est un sortie avec une entrée couplée disponible (contrepoint).
  bool get hasEntree => entree != null;

  /// Vrai si c'est un bail individuel (collectif + privatif) → permet le choix
  /// de portée (complet / communes / chambre).
  bool get isIndividuel => collectifEdlId != null && privatifEdlId != null;

  /// Vue filtrée selon la portée. Pour un bail non individuel ou [complet],
  /// renvoie `this`.
  EdlPdfData scoped(EdlPdfScope scope) {
    if (scope == EdlPdfScope.complet || !isIndividuel) return this;
    final keepId =
        scope == EdlPdfScope.communes ? collectifEdlId : privatifEdlId;
    return EdlPdfData(
      edl: edl,
      preneurs: preneurs,
      // Relevés = compteurs communs (collectif) ; clés = privatif.
      releves: scope == EdlPdfScope.communes ? releves : const [],
      cles: scope == EdlPdfScope.chambre ? cles : const [],
      sections: sections.where((s) => s.etatDesLieuxId == keepId).toList(),
      observations:
          observations.where((o) => o.etatDesLieuxId == keepId).toList(),
      additions: scope == EdlPdfScope.chambre ? additions : const [],
      entree: entree?.scoped(scope),
      pieceNames: pieceNames,
      chambreNames: chambreNames,
      collectifEdlId: collectifEdlId,
      privatifEdlId: privatifEdlId,
    );
  }

  static Future<({Map<int, String> pieces, Map<int, String> chambres})>
      _loadNames(int immeubleId) async {
    final res = await Future.wait([
      PiecesDatasource.listByImmeuble(immeubleId),
      ChambresDatasource.listByImmeuble(immeubleId),
    ]);
    final pieces = res[0] as List<PieceModel>;
    final chambres = res[1] as List<ChambreModel>;
    return (
      pieces: {for (final p in pieces) p.id: p.nom},
      chambres: {for (final c in chambres) c.id: c.roomName},
    );
  }

  /// Charge les données pour un EDL individuel (collectif + privatif).
  /// Si [withEntree] et que c'est un sortie, charge aussi l'entrée couplée.
  static Future<EdlPdfData> loadIndividuel({
    required int collectifId,
    required int privatifId,
    bool withEntree = true,
  }) async {
    final edlFuture = EtatDesLieuxDatasource.findById(privatifId);
    final subResults = await Future.wait([
      EdlDetailsDatasource.listPreneurs(collectifId),
      EdlDetailsDatasource.listReleves(collectifId),
      EdlDetailsDatasource.listCles(privatifId),
      EdlDetailsDatasource.listSections(collectifId),
      EdlDetailsDatasource.listSections(privatifId),
      ObservationsEdlDatasource.listByEdl(collectifId),
      ObservationsEdlDatasource.listByEdl(privatifId),
      // Relevé d'entrée individuel (index propres à ce locataire) → privatif.
      EdlDetailsDatasource.listReleves(privatifId),
    ]);

    final edl = await edlFuture;
    if (edl == null) throw Exception('EDL privatif introuvable ($privatifId)');
    final names = await _loadNames(edl.immeubleId);

    final collectifSections = subResults[3] as List<EdlSection>;
    final privatifSections = subResults[4] as List<EdlSection>;
    final allObs = [
      ...(subResults[5] as List<ObservationEdl>),
      ...(subResults[6] as List<ObservationEdl>),
    ];

    // Document individuel = celui du locataire de CE privatif : on ne liste que
    // SON preneur (pas les colocataires du collectif). Les signatures viennent
    // déjà du privatif (locataire de la chambre + propriétaire).
    final allPreneurs = subResults[0] as List<EdlPreneur>;
    var scopedPreneurs = edl.locataireId != null
        ? allPreneurs.where((p) => p.locataireId == edl.locataireId).toList()
        : allPreneurs;
    if (scopedPreneurs.isEmpty && (edl.locataireNom?.isNotEmpty ?? false)) {
      scopedPreneurs = [
        EdlPreneur(
          etatDesLieuxId: privatifId,
          locataireId: edl.locataireId,
          nom: edl.locataireNom,
          ordre: 0,
        ),
      ];
    }

    var data = EdlPdfData(
      edl: edl,
      preneurs: scopedPreneurs,
      // Compteurs de l'immeuble (collectif) + relevé d'entrée individuel (privatif).
      releves: [
        ...(subResults[1] as List<EdlReleve>),
        ...(subResults[7] as List<EdlReleve>),
      ],
      cles: subResults[2] as List<EdlCle>,
      sections: [...collectifSections, ...privatifSections],
      observations: allObs.where((o) => !o.isAddition).toList(),
      additions: allObs.where((o) => o.isAddition).toList(),
      pieceNames: names.pieces,
      chambreNames: names.chambres,
      collectifEdlId: collectifId,
      privatifEdlId: privatifId,
    );

    if (withEntree && edl.edlEntreeId != null) {
      final entreePriv =
          await EtatDesLieuxDatasource.findById(edl.edlEntreeId!);
      final entreeCollId = entreePriv?.edlCollectifId;
      if (entreePriv != null && entreeCollId != null) {
        final entree = await loadIndividuel(
          collectifId: entreeCollId,
          privatifId: entreePriv.id,
          withEntree: false,
        );
        data = data._copyWith(entree: entree);
      }
    }
    return data;
  }

  /// Charge les données pour un EDL collectif (parties communes).
  /// Si [withEntree] et que c'est un sortie, charge aussi l'entrée couplée.
  static Future<EdlPdfData> loadCollectif(
    int edlId, {
    bool withEntree = true,
  }) async {
    final edlFuture = EtatDesLieuxDatasource.findById(edlId);
    final subResults = await Future.wait([
      EdlDetailsDatasource.listPreneurs(edlId),
      EdlDetailsDatasource.listReleves(edlId),
      EdlDetailsDatasource.listSections(edlId),
      ObservationsEdlDatasource.listByEdl(edlId),
    ]);

    final edl = await edlFuture;
    if (edl == null) throw Exception('EDL collectif introuvable ($edlId)');
    final names = await _loadNames(edl.immeubleId);

    final allObs = subResults[3] as List<ObservationEdl>;

    var data = EdlPdfData(
      edl: edl,
      preneurs: subResults[0] as List<EdlPreneur>,
      releves: subResults[1] as List<EdlReleve>,
      cles: const [],
      sections: subResults[2] as List<EdlSection>,
      observations: allObs.where((o) => !o.isAddition).toList(),
      additions: allObs.where((o) => o.isAddition).toList(),
      pieceNames: names.pieces,
      chambreNames: names.chambres,
    );

    if (withEntree && edl.edlEntreeId != null) {
      final entree = await loadCollectif(edl.edlEntreeId!, withEntree: false);
      data = data._copyWith(entree: entree);
    }
    return data;
  }

  EdlPdfData _copyWith({EdlPdfData? entree}) => EdlPdfData(
        edl: edl,
        preneurs: preneurs,
        releves: releves,
        cles: cles,
        sections: sections,
        observations: observations,
        additions: additions,
        entree: entree ?? this.entree,
        pieceNames: pieceNames,
        chambreNames: chambreNames,
        collectifEdlId: collectifEdlId,
        privatifEdlId: privatifEdlId,
      );
}
