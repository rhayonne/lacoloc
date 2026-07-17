class DemandeContactModel {
  final int id;
  final DateTime createdAt;
  final String locataireId;
  final int? chambreId;
  final int? immeubleId;
  final bool contactEtabli;

  // Dados do locataire (join)
  final String? locataireFullName;
  final String? locataireEmail;
  final String? locatairePhone;
  final int? locataireAge;
  final DateTime? locataireDateOfBirth;

  // Dados da chambre/immeuble (join)
  final String? chambreName;
  final String? immeubleName;

  /// `Immeubles.owner_id` — l'autre partie du fil de discussion vue du locataire.
  final String? proprietaireId;

  /// `Users_Client` du proprietaire (join sur Immeubles → owner).
  final String? proprietaireFullName;

  const DemandeContactModel({
    required this.id,
    required this.createdAt,
    required this.locataireId,
    this.chambreId,
    this.immeubleId,
    required this.contactEtabli,
    this.locataireFullName,
    this.locataireEmail,
    this.locatairePhone,
    this.locataireAge,
    this.locataireDateOfBirth,
    this.chambreName,
    this.immeubleName,
    this.proprietaireId,
    this.proprietaireFullName,
  });

  /// L'interlocuteur de [userId] dans ce fil : si je suis le locataire, c'est le
  /// proprietaire, et inversement. `null` si l'info manque (embed non demandé).
  String? interlocuteurId(String? userId) {
    if (userId == null) return null;
    if (userId == locataireId) return proprietaireId;
    if (userId == proprietaireId) return locataireId;
    return null;
  }

  /// Nom affichable de l'interlocuteur de [userId].
  String interlocuteurNom(String? userId) {
    if (userId != null && userId == locataireId) {
      return proprietaireFullName ?? 'Le propriétaire';
    }
    return locataireFullName ?? 'Le locataire';
  }

  /// Le fil de discussion est-il ouvert ? (le proprietaire a accepté)
  bool get discussionOuverte => contactEtabli;

  /// Idade calculada a partir da data de nascimento; fallback para o campo age.
  int? get calculatedAge {
    final dob = locataireDateOfBirth;
    if (dob == null) return locataireAge;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  factory DemandeContactModel.fromJson(Map<String, dynamic> json) {
    final locataire = json['Users_Client'] as Map<String, dynamic>?;
    final chambre = json['Chambres'] as Map<String, dynamic>?;
    final immeuble = json['Immeubles'] as Map<String, dynamic>?;
    final proprio = immeuble?['owner'] as Map<String, dynamic>?;

    return DemandeContactModel(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      locataireId: json['locataire_id'] as String,
      chambreId: json['chambre_id'] as int?,
      immeubleId: json['immeuble_id'] as int?,
      contactEtabli: (json['contact_etabli'] as bool?) ?? false,
      locataireFullName: locataire?['full_name'] as String?,
      locataireEmail: locataire?['email'] as String?,
      locatairePhone: locataire?['phone'] as String?,
      locataireAge: locataire?['age'] as int?,
      locataireDateOfBirth: locataire?['date_of_birth'] != null
          ? DateTime.parse(locataire!['date_of_birth'] as String)
          : null,
      chambreName: chambre?['room_name'] as String?,
      immeubleName: immeuble?['name'] as String?,
      proprietaireId: immeuble?['owner_id'] as String?,
      proprietaireFullName: proprio?['full_name'] as String?,
    );
  }

  DemandeContactModel copyWith({bool? contactEtabli}) => DemandeContactModel(
    id: id,
    createdAt: createdAt,
    locataireId: locataireId,
    chambreId: chambreId,
    immeubleId: immeubleId,
    contactEtabli: contactEtabli ?? this.contactEtabli,
    locataireFullName: locataireFullName,
    locataireEmail: locataireEmail,
    locatairePhone: locatairePhone,
    locataireAge: locataireAge,
    locataireDateOfBirth: locataireDateOfBirth,
    chambreName: chambreName,
    immeubleName: immeubleName,
    proprietaireId: proprietaireId,
    proprietaireFullName: proprietaireFullName,
  );
}
