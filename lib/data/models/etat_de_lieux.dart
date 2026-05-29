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
  final String? chambreNom;
  final String? proprietaireNom;

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
    this.chambreNom,
    this.proprietaireNom,
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
      chambreNom: chb?['room_name'] as String?,
      proprietaireNom: prop?['full_name'] as String?,
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

  String get dateEdlFormatted => _dateFmt.format(dateEtatLieux);
  String? get dateFinalisationFormatted =>
      dateFinalisation != null ? _dateFmt.format(dateFinalisation!) : null;
}
