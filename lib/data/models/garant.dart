import 'package:intl/intl.dart';

class GarantModel {
  final int id;
  final String locataireId;
  final String typeGarant; // 'physique' | 'morale'
  final String typeCaution; // 'simple' | 'solidaire'
  final bool isActive;
  // Identité
  final String nom;
  final String? prenom;
  final DateTime? dateNaissance;
  final String? lieuNaissance;
  final String? nationalite;
  // Adresse
  final String? adresse;
  final String? codePostal;
  final String? ville;
  // Contact
  final String? email;
  final String? telephone;
  // Situation professionnelle
  final String? profession;
  final String? employeur;
  final double? revenuMensuelNet;
  // Données bancaires
  final String? iban;
  final String? bic;
  final String? titulaireCompte;
  // Personne morale
  final String? raisonSociale;
  final String? siret;
  final String? representantLegal;
  // Divers
  final String? notes;
  final DateTime createdAt;

  const GarantModel({
    required this.id,
    required this.locataireId,
    required this.typeGarant,
    required this.typeCaution,
    required this.isActive,
    required this.nom,
    this.prenom,
    this.dateNaissance,
    this.lieuNaissance,
    this.nationalite,
    this.adresse,
    this.codePostal,
    this.ville,
    this.email,
    this.telephone,
    this.profession,
    this.employeur,
    this.revenuMensuelNet,
    this.iban,
    this.bic,
    this.titulaireCompte,
    this.raisonSociale,
    this.siret,
    this.representantLegal,
    this.notes,
    required this.createdAt,
  });

  String get displayName {
    if (typeGarant == 'morale') return raisonSociale ?? nom;
    return [prenom, nom].where((s) => s?.isNotEmpty == true).join(' ');
  }

  String get typeCautionLabel =>
      typeCaution == 'solidaire' ? 'Caution solidaire' : 'Caution simple';

  String get typeGarantLabel =>
      typeGarant == 'morale' ? 'Personne morale' : 'Personne physique';

  String? get dateNaissanceFormatted => dateNaissance != null
      ? DateFormat('dd/MM/yyyy').format(dateNaissance!)
      : null;

  factory GarantModel.fromMap(Map<String, dynamic> m) => GarantModel(
        id: m['id'] as int,
        locataireId: m['locataire_id'] as String,
        typeGarant: (m['type_garant'] as String?) ?? 'physique',
        typeCaution: (m['type_caution'] as String?) ?? 'solidaire',
        isActive: (m['is_active'] as bool?) ?? true,
        nom: m['nom'] as String,
        prenom: m['prenom'] as String?,
        dateNaissance: m['date_naissance'] != null
            ? DateTime.tryParse(m['date_naissance'] as String)
            : null,
        lieuNaissance: m['lieu_naissance'] as String?,
        nationalite: m['nationalite'] as String?,
        adresse: m['adresse'] as String?,
        codePostal: m['code_postal'] as String?,
        ville: m['ville'] as String?,
        email: m['email'] as String?,
        telephone: m['telephone'] as String?,
        profession: m['profession'] as String?,
        employeur: m['employeur'] as String?,
        revenuMensuelNet: (m['revenu_mensuel_net'] as num?)?.toDouble(),
        iban: m['iban'] as String?,
        bic: m['bic'] as String?,
        titulaireCompte: m['titulaire_compte'] as String?,
        raisonSociale: m['raison_sociale'] as String?,
        siret: m['siret'] as String?,
        representantLegal: m['representant_legal'] as String?,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'locataire_id': locataireId,
        'type_garant': typeGarant,
        'type_caution': typeCaution,
        'is_active': isActive,
        'nom': nom,
        if (prenom != null) 'prenom': prenom,
        if (dateNaissance != null)
          'date_naissance': dateNaissance!.toIso8601String().substring(0, 10),
        if (lieuNaissance != null) 'lieu_naissance': lieuNaissance,
        if (nationalite != null) 'nationalite': nationalite,
        if (adresse != null) 'adresse': adresse,
        if (codePostal != null) 'code_postal': codePostal,
        if (ville != null) 'ville': ville,
        if (email != null) 'email': email,
        if (telephone != null) 'telephone': telephone,
        if (profession != null) 'profession': profession,
        if (employeur != null) 'employeur': employeur,
        if (revenuMensuelNet != null) 'revenu_mensuel_net': revenuMensuelNet,
        if (iban != null) 'iban': iban,
        if (bic != null) 'bic': bic,
        if (titulaireCompte != null) 'titulaire_compte': titulaireCompte,
        if (raisonSociale != null) 'raison_sociale': raisonSociale,
        if (siret != null) 'siret': siret,
        if (representantLegal != null) 'representant_legal': representantLegal,
        if (notes != null) 'notes': notes,
      };

  GarantModel copyWith({
    bool? isActive,
    String? nom,
    String? prenom,
    DateTime? dateNaissance,
    String? lieuNaissance,
    String? nationalite,
    String? adresse,
    String? codePostal,
    String? ville,
    String? email,
    String? telephone,
    String? profession,
    String? employeur,
    double? revenuMensuelNet,
    String? iban,
    String? bic,
    String? titulaireCompte,
    String? raisonSociale,
    String? siret,
    String? representantLegal,
    String? typeGarant,
    String? typeCaution,
    String? notes,
  }) =>
      GarantModel(
        id: id,
        locataireId: locataireId,
        typeGarant: typeGarant ?? this.typeGarant,
        typeCaution: typeCaution ?? this.typeCaution,
        isActive: isActive ?? this.isActive,
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        dateNaissance: dateNaissance ?? this.dateNaissance,
        lieuNaissance: lieuNaissance ?? this.lieuNaissance,
        nationalite: nationalite ?? this.nationalite,
        adresse: adresse ?? this.adresse,
        codePostal: codePostal ?? this.codePostal,
        ville: ville ?? this.ville,
        email: email ?? this.email,
        telephone: telephone ?? this.telephone,
        profession: profession ?? this.profession,
        employeur: employeur ?? this.employeur,
        revenuMensuelNet: revenuMensuelNet ?? this.revenuMensuelNet,
        iban: iban ?? this.iban,
        bic: bic ?? this.bic,
        titulaireCompte: titulaireCompte ?? this.titulaireCompte,
        raisonSociale: raisonSociale ?? this.raisonSociale,
        siret: siret ?? this.siret,
        representantLegal: representantLegal ?? this.representantLegal,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
