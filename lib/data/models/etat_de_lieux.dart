import 'package:intl/intl.dart';

/// Durée par défaut (en jours) de la fenêtre « avenant / additions » ouverte
/// après la finalisation d'un EDL, quand aucune préférence n'est définie.
const int kDefaultAvenantWindowDays = 30;

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
  /// Code de référence lisible (ex. « EDL-E-CAEN-NL-260605-7F3K »). Généré côté
  /// base à la création ; sert à localiser l'EDL (recherche locataire/proprio).
  final String? code;
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

  /// Soft-delete : `false` = EDL désactivé par le super admin. Invisible pour
  /// proprietaire/locataire (filtré côté datasource), réactivable dans le menu
  /// super admin. Toujours `true` par défaut.
  final bool actif;

  // ── Document complet (modèles "partie commune" / "partie privée") ──────────
  final PartieEdl partie;
  final int? edlCollectifId;

  /// Privatif créé **après** la finalisation du collectif (avenant). Le locataire
  /// est entré plus tard ; le collectif l'affiche dans sa section « Avenants ».
  final bool isAvenant;
  final DateTime? avenantDate;

  /// EDL d'**entrée** source auquel ce **sortie** est couplé (copie de structure
  /// + contrepoint à l'impression). Null pour une entrée. Vaut pour le collectif
  /// (commune) comme pour le privatif.
  final int? edlEntreeId;

  /// Durée (en jours) de la fenêtre « avenant / additions » ouverte après la
  /// finalisation. Snapshot pris à la finalisation depuis la préférence du
  /// propriétaire (Vision générale). Null = fallback [kDefaultAvenantWindowDays].
  final int? avenantWindowDays;

  // ── Contrat de bail (privatif) — saisis à la finalisation ─────────────────
  final DateTime? dateDebutBail;
  final DateTime? dateFinBail;
  final int? dureeBailMois;
  // Configuration/résiliation du bail (posées par le propriétaire).
  final int? preavisMois;
  final DateTime? bailCongeDate;
  final DateTime? bailFinEffective;
  final String? bailResilieMotif;
  final DateTime? bailResilieAt;
  // Règlement de la caution (choisi par le locataire) : mode + détails.
  final String? cautionMode; // cheque | virement | especes | wero_paypal
  final Map<String, dynamic>? cautionDetails;
  /// Le bail nécessite-t-il un garant ? null = non décidé, true = requis,
  /// false = sans garant. Décidé par le propriétaire à la génération du bail.
  final bool? bailAvecGarant;
  final double? surfaceM2;
  final int? nombrePiecesPrincipales;
  final String? designation;
  final String? etage;
  final String? bailleurNom;
  final String? bailleurAdresse;
  final String? nouvelleAdresse;
  final String? lieuRedaction;
  final String? nombreExemplaires;

  // ── Signatures ─────────────────────────────────────────────────────────────
  // Signatures de l'EDL (document « état des lieux »).
  final DateTime? proprietaireSignedAt;
  final String? proprietaireSignatureUrl;
  final DateTime? locataireSignedAt;
  final String? locataireSignatureUrl;

  // Signatures du BAIL (document « contrat de location ») — distinctes de l'EDL.
  // L'EDL et le bail sont deux documents signés séparément (loi 89-462).
  final DateTime? bailProprietaireSignedAt;
  final String? bailProprietaireSignatureUrl;
  final DateTime? bailLocataireSignedAt;
  final String? bailLocataireSignatureUrl;

  /// Dernière demande de signature envoyée au locataire (anti-spam 5 jours).
  final DateTime? lastSignatureRequestAt;

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
  final String? proprietairePhone;
  // Noms des preneurs (embed `preneurs` — EDL collectif). Vide pour un privatif.
  final List<String> preneursNoms;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  const EtatDesLieuxModel({
    required this.id,
    this.code,
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
    this.actif = true,
    this.partie = PartieEdl.commune,
    this.edlCollectifId,
    this.isAvenant = false,
    this.avenantDate,
    this.edlEntreeId,
    this.avenantWindowDays,
    this.dateDebutBail,
    this.dateFinBail,
    this.dureeBailMois,
    this.preavisMois,
    this.bailCongeDate,
    this.bailFinEffective,
    this.bailResilieMotif,
    this.bailResilieAt,
    this.cautionMode,
    this.cautionDetails,
    this.bailAvecGarant,
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
    this.proprietairePhone,
    this.preneursNoms = const [],
    this.proprietaireSignedAt,
    this.proprietaireSignatureUrl,
    this.locataireSignedAt,
    this.locataireSignatureUrl,
    this.bailProprietaireSignedAt,
    this.bailProprietaireSignatureUrl,
    this.bailLocataireSignedAt,
    this.bailLocataireSignatureUrl,
    this.lastSignatureRequestAt,
  });

  /// Le propriétaire peut (re)demander une signature ? Vrai si jamais demandé
  /// ou si la dernière demande date de plus de 5 jours.
  bool get canRequestSignature {
    final last = lastSignatureRequestAt;
    if (last == null) return true;
    return DateTime.now().difference(last).inDays >= 5;
  }

  /// Jours restants avant de pouvoir re-demander une signature (0 si possible).
  int get signatureRequestCooldownDays {
    final last = lastSignatureRequestAt;
    if (last == null) return 0;
    final remaining = 5 - DateTime.now().difference(last).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// Un bail peut être généré pour cet EDL (entrée privative individuelle ou
  /// commune d'un bail location).
  bool get isBailEligible =>
      typeEdl == 'entree' &&
      (partie == PartieEdl.privative ||
          (partie == PartieEdl.commune && typeBail == 'location'));

  /// Préavis légal par défaut selon la modalité : **1 mois** en meublé,
  /// **3 mois** en location vide (loi du 6 juillet 1989). Surchargé par
  /// `preavis_mois` si le propriétaire l'a configuré.
  int get preavisMoisDefaut => immeubleMeuble ? 1 : 3;

  /// Préavis effectif = valeur configurée, sinon le défaut légal.
  int get preavisMoisEffectif => preavisMois ?? preavisMoisDefaut;

  /// Le bail a-t-il été résilié (congé enregistré) ?
  bool get bailResilie => bailCongeDate != null;

  /// Calcule la fin effective = [conge] + [mois] de préavis (même quantième).
  static DateTime finPreavis(DateTime conge, int mois) =>
      DateTime(conge.year, conge.month + mois, conge.day);

  // ── EDL (document « état des lieux ») ──────────────────────────────────────
  /// L'EDL porte-t-il déjà la signature du [role] (`proprietaire`/`locataire`) ?
  bool edlSignedBy(String role) => role == 'locataire'
      ? locataireSignatureUrl != null
      : proprietaireSignatureUrl != null;

  /// L'EDL est-il signé par les DEUX parties ? Condition pour ouvrir « Signer
  /// bail » (l'EDL est l'annexe du bail : il doit être complet avant).
  bool get edlFullySigned =>
      proprietaireSignatureUrl != null && locataireSignatureUrl != null;

  // ── BAIL (document « contrat de location ») — signatures distinctes ────────
  /// Le bail porte-t-il déjà la signature du [role] ? Utilise les colonnes
  /// **bail_** (indépendantes de la signature de l'EDL).
  bool bailSignedBy(String role) => role == 'locataire'
      ? bailLocataireSignatureUrl != null
      : bailProprietaireSignatureUrl != null;

  /// Le bail est entièrement signé (les deux parties) → il est verrouillé :
  /// plus aucune modification, le bouton « Bail » devient « Visualiser ».
  bool get bailFullySigned =>
      bailProprietaireSignatureUrl != null &&
      bailLocataireSignatureUrl != null;

  /// Date de signature du bail (la plus récente des deux parties), pour l'affichage.
  DateTime? get bailSignedAt {
    final a = bailProprietaireSignedAt, b = bailLocataireSignedAt;
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  factory EtatDesLieuxModel.fromMap(Map<String, dynamic> map) {
    final loc = map['locataire'] as Map<String, dynamic>?;
    final imm = map['immeuble'] as Map<String, dynamic>?;
    final chb = map['chambre'] as Map<String, dynamic>?;
    final prop = map['proprietaire'] as Map<String, dynamic>?;

    return EtatDesLieuxModel(
      id: map['id'] as int,
      code: map['code'] as String?,
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
      actif: (map['actif'] as bool?) ?? true,
      partie: PartieEdl.fromRaw(map['partie'] as String?),
      edlCollectifId: map['edl_collectif_id'] as int?,
      isAvenant: (map['is_avenant'] as bool?) ?? false,
      avenantDate: map['avenant_date'] != null
          ? DateTime.parse(map['avenant_date'] as String)
          : null,
      edlEntreeId: map['edl_entree_id'] as int?,
      avenantWindowDays: map['avenant_window_days'] as int?,
      dateDebutBail: map['date_debut_bail'] != null
          ? DateTime.parse(map['date_debut_bail'] as String)
          : null,
      dateFinBail: map['date_fin_bail'] != null
          ? DateTime.parse(map['date_fin_bail'] as String)
          : null,
      dureeBailMois: map['duree_bail_mois'] as int?,
      preavisMois: map['preavis_mois'] as int?,
      bailCongeDate: map['bail_conge_date'] != null
          ? DateTime.parse(map['bail_conge_date'] as String)
          : null,
      bailFinEffective: map['bail_fin_effective'] != null
          ? DateTime.parse(map['bail_fin_effective'] as String)
          : null,
      bailResilieMotif: map['bail_resilie_motif'] as String?,
      bailResilieAt: map['bail_resilie_at'] != null
          ? DateTime.parse(map['bail_resilie_at'] as String)
          : null,
      cautionMode: map['caution_mode'] as String?,
      cautionDetails: (map['caution_details'] as Map?)?.cast<String, dynamic>(),
      bailAvecGarant: map['bail_avec_garant'] as bool?,
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
      proprietairePhone: prop?['phone'] as String?,
      proprietaireSignedAt: map['proprietaire_signed_at'] != null
          ? DateTime.parse(map['proprietaire_signed_at'] as String)
          : null,
      proprietaireSignatureUrl: map['proprietaire_signature_url'] as String?,
      bailProprietaireSignedAt: map['bail_proprietaire_signed_at'] != null
          ? DateTime.parse(map['bail_proprietaire_signed_at'] as String)
          : null,
      bailProprietaireSignatureUrl:
          map['bail_proprietaire_signature_url'] as String?,
      bailLocataireSignedAt: map['bail_locataire_signed_at'] != null
          ? DateTime.parse(map['bail_locataire_signed_at'] as String)
          : null,
      bailLocataireSignatureUrl:
          map['bail_locataire_signature_url'] as String?,
      locataireSignedAt: map['locataire_signed_at'] != null
          ? DateTime.parse(map['locataire_signed_at'] as String)
          : null,
      locataireSignatureUrl: map['locataire_signature_url'] as String?,
      lastSignatureRequestAt: map['last_signature_request_at'] != null
          ? DateTime.parse(map['last_signature_request_at'] as String)
          : null,
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
    if (edlEntreeId != null) 'edl_entree_id': edlEntreeId,
    if (dateDebutBail != null)
      'date_debut_bail': dateDebutBail!.toIso8601String().substring(0, 10),
    if (dateFinBail != null)
      'date_fin_bail': dateFinBail!.toIso8601String().substring(0, 10),
    if (dureeBailMois != null) 'duree_bail_mois': dureeBailMois,
    if (bailAvecGarant != null) 'bail_avec_garant': bailAvecGarant,
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

  /// Nombre de jours effectif de la fenêtre avenant/additions (fallback défaut).
  int get avenantWindowDaysOrDefault =>
      avenantWindowDays ?? kDefaultAvenantWindowDays;

  /// La fenêtre « avenant / additions » est-elle encore ouverte ?
  ///
  /// Vraie seulement si l'EDL est **finalisé**. Si `date_finalisation` est null
  /// (finalisé mais pas encore accepté/signé par le locataire), la fenêtre est
  /// considérée ouverte. Sinon : `now < date_finalisation + windowDays`.
  bool get isAvenantWindowOpen {
    if (situation != SituationEdl.finalise) return false;
    // 0 (ou moins) = « Sans avenant » : aucune fenêtre.
    if (avenantWindowDaysOrDefault <= 0) return false;
    final ref = dateFinalisation;
    if (ref == null) return true;
    return DateTime.now()
        .isBefore(ref.add(Duration(days: avenantWindowDaysOrDefault)));
  }

  /// Type d'EDL pour l'affichage :
  ///  • « Location » : bail simple (plusieurs preneurs, un contrat partagé) ;
  ///  • « Collectif » : parties communes d'un bail individuel ;
  ///  • « Individuel » : privatif d'une chambre (bail individuel).
  String get typeLabel {
    if (typeBail == 'location') return 'Location';
    return partie == PartieEdl.commune ? 'Collectif' : 'Individuel';
  }

  /// Sens de l'EDL : « Entrée » / « Sortie ».
  String get sensLabel => typeEdl == 'sortie' ? 'Sortie' : 'Entrée';

  /// Vrai si c'est un EDL de sortie.
  bool get isSortie => typeEdl == 'sortie';

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

  /// Date de signature du bail par le propriétaire (= « Fait à …, le … » du
  /// contrat). `null` tant que le bailleur n'a pas signé.
  String? get proprietaireSignedAtFormatted =>
      proprietaireSignedAt != null ? _dateFmt.format(proprietaireSignedAt!) : null;
  String? get locataireSignedAtFormatted =>
      locataireSignedAt != null ? _dateFmt.format(locataireSignedAt!) : null;

  /// Date de signature du BAIL (la plus récente des deux parties). `null` tant
  /// que le bail n'est pas signé.
  String? get bailSignedAtFormatted =>
      bailSignedAt != null ? _dateFmt.format(bailSignedAt!) : null;
  String? get bailProprietaireSignedAtFormatted =>
      bailProprietaireSignedAt != null
          ? _dateFmt.format(bailProprietaireSignedAt!)
          : null;
  String? get bailLocataireSignedAtFormatted => bailLocataireSignedAt != null
      ? _dateFmt.format(bailLocataireSignedAt!)
      : null;

  /// Identifiant du « contrat » qui regroupe un EDL collectif et ses privatifs :
  /// l'id du collectif lui-même (partie commune) ou l'`edl_collectif_id` (privatif).
  /// `null` pour un EDL sans lien collectif↔privatif (legado).
  int? get contratId => partie == PartieEdl.commune ? id : edlCollectifId;
}
