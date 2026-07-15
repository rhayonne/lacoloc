import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacoloc_front/data/datasources/chambre_charges.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/edl_details.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/datasources/immeuble_charges.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/pieces.dart';
import 'package:lacoloc_front/data/datasources/vetuste.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/piece.dart';
import 'package:lacoloc_front/data/models/chambre_charge.dart';
import 'package:lacoloc_front/data/datasources/garants.dart';
import 'package:lacoloc_front/data/models/edl_details.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/garant.dart';
import 'package:lacoloc_front/data/models/immeuble_charge.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/vetuste.dart';

// ─────────────────────────────────────────────────────────────────────────────

enum BailType {
  locationMeuble,
  locationNonMeuble,
  individuelleMeuble,
  individuelleNonMeuble,
}

extension BailTypeLabel on BailType {
  String get label => switch (this) {
        BailType.locationMeuble => 'Location meublée',
        BailType.locationNonMeuble => 'Location non meublée',
        BailType.individuelleMeuble => 'Bail individuel meublé (Colocation)',
        BailType.individuelleNonMeuble => 'Bail individuel non meublé (Colocation)',
      };

  bool get isColocation =>
      this == BailType.individuelleMeuble || this == BailType.individuelleNonMeuble;

  bool get isMeuble =>
      this == BailType.locationMeuble || this == BailType.individuelleMeuble;

  int get dureeLegaleDefaut => isMeuble ? 12 : 36;
  int get depotGarantieLegalMax => isMeuble ? 2 : 1;

  String get texteLegal => switch (this) {
        BailType.locationMeuble =>
          'Contrat de location meublée soumis à la loi n° 89-462 du 6 juillet 1989, titre Ier bis (art. 25-3 à 25-11) et au Décret n° 2015-587 du 29 mai 2015.',
        BailType.locationNonMeuble =>
          'Contrat de location nu soumis à la loi n° 89-462 du 6 juillet 1989 et au Décret n° 2015-587 du 29 mai 2015.',
        BailType.individuelleMeuble =>
          'Bail individuel meublé en colocation soumis à la loi n° 89-462 du 6 juillet 1989, art. 8-1, et au Décret n° 2015-587 du 29 mai 2015.',
        BailType.individuelleNonMeuble =>
          'Bail individuel non meublé en colocation soumis à la loi n° 89-462 du 6 juillet 1989, art. 8-1, et au Décret n° 2015-587 du 29 mai 2015.',
      };
}

// ─────────────────────────────────────────────────────────────────────────────

class BailUserInfo {
  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? address;

  const BailUserInfo({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.address,
  });

  String get displayName => fullName ?? email ?? id;
}

// ─────────────────────────────────────────────────────────────────────────────

class BailPdfData {
  final EtatDesLieuxModel edl;
  final ImmeublesModel immeuble;
  final ChambreModel? chambre;
  final BailUserInfo bailleur;
  final List<BailUserInfo> preneurs;
  final List<EdlPreneur> preneurDetails;
  final List<ImmeubleChargeModel> immeubleCharges;
  final List<ChambreChargeModel> chambreCharges;
  final List<GarantModel> garants;
  final BailType bailType;

  /// Barème de vétusté du bailleur (1 ligne par catégorie de meuble) — affiché
  /// dans l'article 8.4 « Décompte de fin de bail » du contrat.
  final List<VetusteBaremeModel> baremeVetuste;

  /// Pièces communes de l'immeuble (bail individuel/colocation) — utilisées pour
  /// la section « Parties communes » du bail (miroir de l'EDL collectif).
  final List<PieceModel> piecesCommunes;

  const BailPdfData({
    required this.edl,
    required this.immeuble,
    required this.chambre,
    required this.bailleur,
    required this.preneurs,
    required this.preneurDetails,
    required this.immeubleCharges,
    required this.chambreCharges,
    required this.garants,
    required this.bailType,
    this.piecesCommunes = const [],
    this.baremeVetuste = const [],
  });

  /// Vrai si le bail comporte une partie « parties communes » imprimable
  /// séparément (colocation avec des pièces communes renseignées).
  bool get hasPartiesCommunes => isColocation && piecesCommunes.isNotEmpty;

  // ── Accesseurs pratiques ──────────────────────────────────────────────────

  String get titreBail => bailType.label;
  String get texteLegal => bailType.texteLegal;
  bool get isColocation => bailType.isColocation;
  bool get isMeuble => bailType.isMeuble;

  /// Le bail a été marqué comme nécessitant un garant par le propriétaire.
  bool get bailAvecGarant => edl.bailAvecGarant ?? false;

  /// Un garant est requis mais aucun n'est encore enregistré → impression
  /// bloquée tant que le locataire n'a pas créé au moins un garant.
  bool get garantManquant => bailAvecGarant && garants.isEmpty;

  /// Durée effective du bail en mois (valeur enregistrée ou légale).
  int get dureeMois {
    if (isColocation) {
      return chambre?.dureeBailMois ?? immeuble.dureeBailMois ?? bailType.dureeLegaleDefaut;
    }
    return immeuble.dureeBailMois ?? bailType.dureeLegaleDefaut;
  }

  /// Dépôt de garantie en nombre de mois.
  double get depotGarantieMois {
    if (isColocation) {
      return chambre?.depotGarantieMois ?? immeuble.depotGarantieMois ?? bailType.depotGarantieLegalMax.toDouble();
    }
    return immeuble.depotGarantieMois ?? bailType.depotGarantieLegalMax.toDouble();
  }

  /// Loyer mensuel hors charges.
  double? get loyerHorsCharges {
    if (isColocation) return chambre?.prixLoyer;
    return immeuble.prixLoyer;
  }

  /// Les charges sont désormais gérées au niveau de l'immeuble. Pour une
  /// colocation, on n'utilise les charges spécifiques de la chambre que si
  /// elles existent (legacy) ; sinon on hérite de celles de l'immeuble.
  bool get useChambreCharges => isColocation && chambreCharges.isNotEmpty;

  /// Charges mensuelles fixes (somme des charges « fixe »).
  double get chargesFixesMensuelles {
    if (useChambreCharges) {
      return chambreCharges
          .where((c) => c.type == 'fixe')
          .fold(0, (s, c) => s + (c.montant ?? 0));
    }
    return immeubleCharges
        .where((c) => c.type == 'fixe')
        .fold(0, (s, c) => s + (c.montant ?? 0));
  }

  bool get hasChargesIncluses {
    if (useChambreCharges) return chambreCharges.any((c) => c.type == 'inclus');
    return immeubleCharges.any((c) => c.type == 'inclus');
  }

  List<ImmeubleChargeModel> get chargesIncluses =>
      immeubleCharges.where((c) => c.type == 'inclus').toList();
  List<ImmeubleChargeModel> get chargesFixesImmeuble =>
      immeubleCharges.where((c) => c.type == 'fixe').toList();

  List<ChambreChargeModel> get chambreChargesIncluses =>
      chambreCharges.where((c) => c.type == 'inclus').toList();
  List<ChambreChargeModel> get chambreChargesFixes =>
      chambreCharges.where((c) => c.type == 'fixe').toList();

  String get adresseBien {
    final imm = immeuble;
    final parts = [
      imm.address,
      imm.codePostal,
      imm.city,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  // ── Chargement ────────────────────────────────────────────────────────────

  /// Garants actifs liés à un bail : ceux du locataire du privatif (individuel)
  /// + ceux de chaque preneur identifié (colocation). Dédupliqués par id.
  /// Best-effort (la RLS peut filtrer un preneur non rattaché au propriétaire).
  static Future<List<GarantModel>> garantsForEdl(
    EtatDesLieuxModel edl, {
    List<EdlPreneur>? preneurDetails,
  }) async {
    // 1) Garants explicitement rattachés à l'EDL (onglet « Garant »).
    try {
      final linkedIds =
          await EtatDesLieuxDatasource.listGarantIdsForEdl(edl.id);
      if (linkedIds.isNotEmpty) {
        return await GarantsDatasource.byIds(linkedIds);
      }
    } catch (_) {
      // best-effort → fallback ci-dessous
    }
    // 2) Fallback (EDL sans rattachement explicite) : garants actifs du/des
    //    locataire(s), comportement historique.
    final preneurs =
        preneurDetails ?? await EdlDetailsDatasource.listPreneurs(edl.id);
    final ids = <String>{
      if (edl.locataireId != null) edl.locataireId!,
      ...preneurs.map((p) => p.locataireId).whereType<String>(),
    };
    final out = <GarantModel>[];
    final seen = <int>{};
    for (final uid in ids) {
      try {
        for (final g in await GarantsDatasource.activeByLocataire(uid)) {
          if (seen.add(g.id)) out.add(g);
        }
      } catch (_) {
        // best-effort
      }
    }
    return out;
  }

  static Future<BailPdfData> fromEdl(EtatDesLieuxModel edl) async {
    final db = Supabase.instance.client;

    // Immeuble
    final immeuble = await ImmeublesDatasource.byId(edl.immeubleId);
    if (immeuble == null) throw Exception("Immeuble #${edl.immeubleId} introuvable");

    // Chambre (si bail individuel)
    ChambreModel? chambre;
    if (edl.chambreId != null) {
      chambre = await ChambresDatasource.byId(edl.chambreId!);
    }

    // Bailleur
    final bailleurRow = await db
        .from('Users_Client')
        .select('id, full_name, email, phone')
        .eq('id', edl.proprietaireId)
        .maybeSingle();
    final bailleur = bailleurRow != null
        ? BailUserInfo(
            id: edl.proprietaireId,
            fullName: bailleurRow['full_name'] as String?,
            email: bailleurRow['email'] as String?,
            phone: bailleurRow['phone'] as String?,
          )
        : BailUserInfo(id: edl.proprietaireId);

    // Preneurs.
    // Pour un bail individuel, l'EDL passé est le privatif : ses preneurs sont
    // portés par le collectif (le privatif n'a qu'un `locataire_id`). On lit
    // donc les preneurs du collectif (filtrés au locataire de CE privatif) et,
    // à défaut, on retombe sur `edl.locataireId`.
    var preneurDetails = await EdlDetailsDatasource.listPreneurs(edl.id);
    if (edl.typeBail == 'individuel' && edl.edlCollectifId != null) {
      final collPreneurs =
          await EdlDetailsDatasource.listPreneurs(edl.edlCollectifId!);
      final scoped = edl.locataireId != null
          ? collPreneurs
              .where((p) => p.locataireId == edl.locataireId)
              .toList()
          : collPreneurs;
      if (scoped.isNotEmpty) preneurDetails = scoped;
    }

    final List<BailUserInfo> preneurs = [];
    for (final p in preneurDetails) {
      if (p.locataireId != null) {
        final row = await db
            .from('Users_Client')
            .select('id, full_name, email, phone')
            .eq('id', p.locataireId!)
            .maybeSingle();
        preneurs.add(row != null
            ? BailUserInfo(
                id: p.locataireId!,
                fullName: row['full_name'] as String? ?? p.nom,
                email: row['email'] as String?,
                phone: row['phone'] as String?,
              )
            : BailUserInfo(id: p.locataireId!, fullName: p.nom));
      } else if (p.nom?.isNotEmpty == true) {
        preneurs.add(BailUserInfo(id: '', fullName: p.nom, address: p.adresse));
      }
    }

    // Dernier filet de sécurité : aucun preneur mais l'EDL référence un
    // locataire (privatif fraîchement créé, preneur pas encore propagé).
    if (preneurs.isEmpty && edl.locataireId != null) {
      final row = await db
          .from('Users_Client')
          .select('id, full_name, email, phone')
          .eq('id', edl.locataireId!)
          .maybeSingle();
      if (row != null) {
        preneurs.add(BailUserInfo(
          id: edl.locataireId!,
          fullName: row['full_name'] as String? ?? edl.locataireNom,
          email: row['email'] as String?,
          phone: row['phone'] as String?,
        ));
      } else if (edl.locataireNom?.isNotEmpty == true) {
        preneurs.add(BailUserInfo(id: edl.locataireId!, fullName: edl.locataireNom));
      }
    }

    // Charges
    final immCharges = await ImmeubleChargesDatasource.listByImmeuble(immeuble.id);
    final chamCharges = chambre != null
        ? await ChambreChargesDatasource.listByChambre(chambre.id)
        : <ChambreChargeModel>[];

    // Garants actifs du bail (locataire + preneurs).
    final garants = await garantsForEdl(edl, preneurDetails: preneurDetails);

    // Barème de vétusté du bailleur (pour l'article 8.4). Best-effort.
    List<VetusteBaremeModel> baremeVetuste = const [];
    try {
      baremeVetuste = await VetusteDatasource.listBareme(edl.proprietaireId);
    } catch (_) {
      // best-effort : un bail reste imprimable sans barème.
    }

    // Type de bail
    final meuble = immeuble.locationMeuble ?? false;
    final BailType bailType;
    if (edl.typeBail == 'location') {
      bailType = meuble ? BailType.locationMeuble : BailType.locationNonMeuble;
    } else {
      bailType = meuble ? BailType.individuelleMeuble : BailType.individuelleNonMeuble;
    }

    // Pièces communes (pour la section « Parties communes » du bail individuel).
    List<PieceModel> piecesCommunes = const [];
    if (edl.typeBail == 'individuel') {
      try {
        piecesCommunes = await PiecesDatasource.listByImmeuble(immeuble.id);
      } catch (_) {
        // best-effort
      }
    }

    return BailPdfData(
      edl: edl,
      immeuble: immeuble,
      chambre: chambre,
      bailleur: bailleur,
      preneurs: preneurs,
      preneurDetails: preneurDetails,
      immeubleCharges: immCharges,
      chambreCharges: chamCharges,
      garants: garants,
      bailType: bailType,
      piecesCommunes: piecesCommunes,
      baremeVetuste: baremeVetuste,
    );
  }
}

/// Portée d'impression du bail individuel (miroir de l'EDL) :
/// tout, la chambre (privatif) ou les parties communes (collectif).
enum BailPdfScope { complet, chambre, communes }
