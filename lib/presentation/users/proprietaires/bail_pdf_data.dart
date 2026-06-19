import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacoloc_front/data/datasources/chambre_charges.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/edl_details.dart';
import 'package:lacoloc_front/data/datasources/immeuble_charges.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/chambre_charge.dart';
import 'package:lacoloc_front/data/models/edl_details.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/immeuble_charge.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';

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
  final BailType bailType;

  const BailPdfData({
    required this.edl,
    required this.immeuble,
    required this.chambre,
    required this.bailleur,
    required this.preneurs,
    required this.preneurDetails,
    required this.immeubleCharges,
    required this.chambreCharges,
    required this.bailType,
  });

  // ── Accesseurs pratiques ──────────────────────────────────────────────────

  String get titreBail => bailType.label;
  String get texteLegal => bailType.texteLegal;
  bool get isColocation => bailType.isColocation;
  bool get isMeuble => bailType.isMeuble;

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

  /// Charges mensuelles fixes (somme des charges « fixe »).
  double get chargesFixesMensuelles {
    if (isColocation) {
      return chambreCharges
          .where((c) => c.type == 'fixe')
          .fold(0, (s, c) => s + (c.montant ?? 0));
    }
    return immeubleCharges
        .where((c) => c.type == 'fixe')
        .fold(0, (s, c) => s + (c.montant ?? 0));
  }

  bool get hasChargesIncluses {
    if (isColocation) return chambreCharges.any((c) => c.type == 'inclus');
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

    // Preneurs
    final preneurDetails = await EdlDetailsDatasource.listPreneurs(edl.id);
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

    // Charges
    final immCharges = await ImmeubleChargesDatasource.listByImmeuble(immeuble.id);
    final chamCharges = chambre != null
        ? await ChambreChargesDatasource.listByChambre(chambre.id)
        : <ChambreChargeModel>[];

    // Type de bail
    final meuble = immeuble.locationMeuble ?? false;
    final BailType bailType;
    if (edl.typeBail == 'location') {
      bailType = meuble ? BailType.locationMeuble : BailType.locationNonMeuble;
    } else {
      bailType = meuble ? BailType.individuelleMeuble : BailType.individuelleNonMeuble;
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
      bailType: bailType,
    );
  }
}
