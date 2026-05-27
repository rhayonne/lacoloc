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
  });

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
  );
}
