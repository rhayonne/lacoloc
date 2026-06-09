import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Wall observation (plan 2D step of the EDL form)

class WallObservation {
  final String? description;
  final List<String> photos;

  const WallObservation({this.description, required this.photos});

  bool get hasContent =>
      (description != null && description!.isNotEmpty) || photos.isNotEmpty;

  WallObservation copyWith({String? description, List<String>? photos}) =>
      WallObservation(
        description: description ?? this.description,
        photos: photos ?? this.photos,
      );

  Map<String, dynamic> toJson() => {
    if (description != null && description!.isNotEmpty) 'description': description,
    'photos': photos,
  };

  factory WallObservation.fromJson(Map<String, dynamic> json) => WallObservation(
    description: json['description'] as String?,
    photos: (json['photos'] as List?)?.cast<String>() ?? [],
  );
}

// ─────────────────────────────────────────────────────────────────────────────

/// Partie do état des lieux: `commune` (collectif, parties communes do imóvel)
/// ou `privative` (individuel, chambre de um locataire ligado ao collectif).
enum PartieEdl {
  commune,
  privative;

  String get raw => switch (this) {
    PartieEdl.commune => 'commune',
    PartieEdl.privative => 'privative',
  };

  String get label => switch (this) {
    PartieEdl.commune => 'Parties communes',
    PartieEdl.privative => 'Parties privatives',
  };

  static PartieEdl fromRaw(String? raw) =>
      raw == 'privative' ? PartieEdl.privative : PartieEdl.commune;
}

enum SituationEdl {
  enCours,
  aVenir,
  finalise;

  String get label => switch (this) {
    SituationEdl.enCours => 'En cours',
    SituationEdl.aVenir => 'À venir',
    SituationEdl.finalise => 'Finalisé',
  };

  String get raw => switch (this) {
    SituationEdl.enCours => 'en_cours',
    SituationEdl.aVenir => 'a_venir',
    SituationEdl.finalise => 'finalise',
  };

  static SituationEdl fromRaw(String? raw) => switch (raw) {
    'a_venir' => SituationEdl.aVenir,
    'finalise' => SituationEdl.finalise,
    _ => SituationEdl.enCours,
  };

  static SituationEdl fromDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    return d.isAfter(today) ? SituationEdl.aVenir : SituationEdl.enCours;
  }
}

class EtatDesLieuxModel {
  final int id;
  final String proprietaireId;
  final String? locataireId;
  final int immeubleId;
  final int? chambreId;
  final String typeBail; // 'collectif' | 'individuel'
  final String typeEdl; // 'entree' | 'sortie'
  final DateTime dateEtatLieux;
  final DateTime? dateFinalisation;
  final SituationEdl situation;
  final bool locataireAccepte;
  final double? montant;
  final String? notes;
  final Map<String, WallObservation> observations;
  final DateTime createdAt;

  // ── Document complet (modèles "partie commune" / "partie privée") ──────────
  final PartieEdl partie;
  final int? edlCollectifId;

  /// Privatif créé **après** la finalisation du collectif (avenant). Le locataire
  /// est entré plus tard ; le collectif l'affiche dans sa section « Avenants ».
  final bool isAvenant;
  final DateTime? avenantDate;

  // ── Contrat de bail (privatif) — saisis à la finalisation ─────────────────
  final DateTime? dateDebutBail;
  final DateTime? dateFinBail;
  final int? dureeBailMois;
  final double? surfaceM2;
  final int? nombrePiecesPrincipales;
  final String? designation;
  final String? etage;
  final String? bailleurNom;
  final String? bailleurAdresse;
  final String? nouvelleAdresse;
  final String? lieuRedaction;
  final String? nombreExemplaires;

  // Champs enrichis via join
  final String? locataireNom;
  final String? locataireEmail;
  final String? locatairePhone;
  final bool locataireInvitationEmailSent;
  final DateTime? locataireInvitationSentAt;
  final String? immeubleNom;
  final String? immeubleAdresse;
  /// Type de l'immeuble (Appartement, Maison, Studio…) via `Immeuble_Types_Reference`.
  final String? immeubleTypeNom;
  /// Immeuble loué meublé ? (`location_meuble`) — null traité comme non meublé.
  final bool immeubleMeuble;
  final String? chambreNom;
  final String? proprietaireNom;
  // Noms des preneurs (embed `preneurs` — EDL collectif). Vide pour un privatif.
  final List<String> preneursNoms;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  const EtatDesLieuxModel({
    required this.id,
    required this.proprietaireId,
    this.locataireId,
    required this.immeubleId,
    this.chambreId,
    required this.typeBail,
    required this.typeEdl,
    required this.dateEtatLieux,
    this.dateFinalisation,
    required this.situation,
    this.locataireAccepte = false,
    this.montant,
    this.notes,
    this.observations = const {},
    required this.createdAt,
    this.partie = PartieEdl.commune,
    this.edlCollectifId,
    this.isAvenant = false,
    this.avenantDate,
    this.dateDebutBail,
    this.dateFinBail,
    this.dureeBailMois,
    this.surfaceM2,
    this.nombrePiecesPrincipales,
    this.designation,
    this.etage,
    this.bailleurNom,
    this.bailleurAdresse,
    this.nouvelleAdresse,
    this.lieuRedaction,
    this.nombreExemplaires,
    this.locataireNom,
    this.locataireEmail,
    this.locatairePhone,
    this.locataireInvitationEmailSent = false,
    this.locataireInvitationSentAt,
    this.immeubleNom,
    this.immeubleAdresse,
    this.immeubleTypeNom,
    this.immeubleMeuble = false,
    this.chambreNom,
    this.proprietaireNom,
    this.preneursNoms = const [],
  });

  factory EtatDesLieuxModel.fromMap(Map<String, dynamic> map) {
    final loc = map['locataire'] as Map<String, dynamic>?;
    final imm = map['immeuble'] as Map<String, dynamic>?;
    final chb = map['chambre'] as Map<String, dynamic>?;
    final prop = map['proprietaire'] as Map<String, dynamic>?;

    return EtatDesLieuxModel(
      id: map['id'] as int,
      proprietaireId: map['proprietaire_id'] as String,
      locataireId: map['locataire_id'] as String?,
      immeubleId: map['immeuble_id'] as int,
      chambreId: map['chambre_id'] as int?,
      typeBail: map['type_bail'] as String,
      typeEdl: map['type_edl'] as String? ?? 'entree',
      dateEtatLieux: DateTime.parse(map['date_etat_lieux'] as String),
      dateFinalisation: map['date_finalisation'] != null
          ? DateTime.parse(map['date_finalisation'] as String)
          : null,
      situation: SituationEdl.fromRaw(map['situation'] as String?),
      locataireAccepte: (map['locataire_accepte'] as bool?) ?? false,
      montant: (map['montant'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      observations: () {
        final raw = map['observations'];
        if (raw is! Map) return const <String, WallObservation>{};
        return raw.map(
          (k, v) => MapEntry(
            k as String,
            WallObservation.fromJson(v as Map<String, dynamic>),
          ),
        );
      }(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      partie: PartieEdl.fromRaw(map['partie'] as String?),
      edlCollectifId: map['edl_collectif_id'] as int?,
      isAvenant: (map['is_avenant'] as bool?) ?? false,
      avenantDate: map['avenant_date'] != null
          ? DateTime.parse(map['avenant_date'] as String)
          : null,
      dateDebutBail: map['date_debut_bail'] != null
          ? DateTime.parse(map['date_debut_bail'] as String)
          : null,
      dateFinBail: map['date_fin_bail'] != null
          ? DateTime.parse(map['date_fin_bail'] as String)
          : null,
      dureeBailMois: map['duree_bail_mois'] as int?,
      surfaceM2: (map['surface_m2'] as num?)?.toDouble(),
      nombrePiecesPrincipales: map['nombre_pieces_principales'] as int?,
      designation: map['designation'] as String?,
      etage: map['etage'] as String?,
      bailleurNom: map['bailleur_nom'] as String?,
      bailleurAdresse: map['bailleur_adresse'] as String?,
      nouvelleAdresse: map['nouvelle_adresse'] as String?,
      lieuRedaction: map['lieu_redaction'] as String?,
      nombreExemplaires: map['nombre_exemplaires'] as String?,
      locataireNom: loc?['full_name'] as String?,
      locataireEmail: loc?['email'] as String?,
      locatairePhone: loc?['phone'] as String?,
      locataireInvitationEmailSent:
          (loc?['invitation_email_sent'] as bool?) ?? false,
      locataireInvitationSentAt: loc?['invitation_sent_at'] != null
          ? DateTime.parse(loc!['invitation_sent_at'] as String)
          : null,
      immeubleNom: imm?['name'] as String?,
      immeubleAdresse: imm?['address'] as String?,
      immeubleTypeNom:
          (imm?['type'] as Map<String, dynamic>?)?['name'] as String?,
      immeubleMeuble: (imm?['location_meuble'] as bool?) ?? false,
      chambreNom: chb?['room_name'] as String?,
      proprietaireNom: prop?['full_name'] as String?,
      preneursNoms: () {
        final raw = map['preneurs'];
        if (raw is! List) return const <String>[];
        final names = <String>[];
        for (final p in raw) {
          if (p is! Map) continue;
          final loc = p['locataire'] as Map<String, dynamic>?;
          final nom = (loc?['full_name'] as String?) ?? (p['nom'] as String?);
          if (nom != null && nom.trim().isNotEmpty) names.add(nom.trim());
        }
        return names;
      }(),
    );
  }

  Map<String, dynamic> toInsert() => {
    'proprietaire_id': proprietaireId,
    if (locataireId != null) 'locataire_id': locataireId,
    'immeuble_id': immeubleId,
    if (chambreId != null) 'chambre_id': chambreId,
    'type_bail': typeBail,
    'type_edl': typeEdl,
    'date_etat_lieux': dateEtatLieux.toIso8601String().substring(0, 10),
    if (dateFinalisation != null)
      'date_finalisation': dateFinalisation!.toIso8601String().substring(0, 10),
    'situation': situation.raw,
    'locataire_accepte': locataireAccepte,
    if (montant != null) 'montant': montant,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    'observations': observations.map((k, v) => MapEntry(k, v.toJson())),
    'partie': partie.raw,
    if (edlCollectifId != null) 'edl_collectif_id': edlCollectifId,
    'is_avenant': isAvenant,
    if (avenantDate != null)
      'avenant_date': avenantDate!.toIso8601String().substring(0, 10),
    if (dateDebutBail != null)
      'date_debut_bail': dateDebutBail!.toIso8601String().substring(0, 10),
    if (dateFinBail != null)
      'date_fin_bail': dateFinBail!.toIso8601String().substring(0, 10),
    if (dureeBailMois != null) 'duree_bail_mois': dureeBailMois,
    if (surfaceM2 != null) 'surface_m2': surfaceM2,
    if (nombrePiecesPrincipales != null)
      'nombre_pieces_principales': nombrePiecesPrincipales,
    if (designation != null && designation!.isNotEmpty) 'designation': designation,
    if (etage != null && etage!.isNotEmpty) 'etage': etage,
    if (bailleurNom != null && bailleurNom!.isNotEmpty) 'bailleur_nom': bailleurNom,
    if (bailleurAdresse != null && bailleurAdresse!.isNotEmpty)
      'bailleur_adresse': bailleurAdresse,
    if (nouvelleAdresse != null && nouvelleAdresse!.isNotEmpty)
      'nouvelle_adresse': nouvelleAdresse,
    if (lieuRedaction != null && lieuRedaction!.isNotEmpty)
      'lieu_redaction': lieuRedaction,
    if (nombreExemplaires != null && nombreExemplaires!.isNotEmpty)
      'nombre_exemplaires': nombreExemplaires,
  };

  String get lieuLabel {
    final imm = immeubleNom ?? 'Immeuble';
    final chb = chambreNom;
    return chb != null ? '$imm — $chb' : imm;
  }

  /// Libellé du/des locataire(s) pour l'affichage : le locataire principal
  /// (privatif) ou, à défaut, la liste des preneurs (collectif). « — » si vide.
  String get displayLocataire {
    final principal = locataireNom ?? locataireEmail;
    if (principal != null && principal.isNotEmpty) return principal;
    if (preneursNoms.isNotEmpty) return preneursNoms.join(', ');
    return '—';
  }

  String get dateEdlFormatted => _dateFmt.format(dateEtatLieux);
  String? get dateFinalisationFormatted =>
      dateFinalisation != null ? _dateFmt.format(dateFinalisation!) : null;

  /// Type d'EDL pour l'affichage : « Collectif » (parties communes) ou
  /// « Individuel » (privatif d'une chambre).
  String get typeLabel =>
      partie == PartieEdl.commune ? 'Collectif' : 'Individuel';

  /// Sens de l'EDL : « Entrée » / « Sortie ».
  String get sensLabel => typeEdl == 'sortie' ? 'Sortie' : 'Entrée';

  /// Type de l'immeuble pour l'affichage (Appartement, Maison…) ; « — » si absent.
  String get immeubleTypeLabel =>
      (immeubleTypeNom != null && immeubleTypeNom!.isNotEmpty)
          ? immeubleTypeNom!
          : '—';

  /// Meublé ? — « Meublée » / « Non meublée » pour la colonne TYPE.
  String get meubleLabel => immeubleMeuble ? 'Meublée' : 'Non meublée';

  String? get avenantDateFormatted =>
      avenantDate != null ? _dateFmt.format(avenantDate!) : null;

  String? get dateDebutBailFormatted =>
      dateDebutBail != null ? _dateFmt.format(dateDebutBail!) : null;
  String? get dateFinBailFormatted =>
      dateFinBail != null ? _dateFmt.format(dateFinBail!) : null;

  /// Identifiant du « contrat » qui regroupe un EDL collectif et ses privatifs :
  /// l'id du collectif lui-même (partie commune) ou l'`edl_collectif_id` (privatif).
  /// `null` pour un EDL sans lien collectif↔privatif (legado).
  int? get contratId => partie == PartieEdl.commune ? id : edlCollectifId;
}
