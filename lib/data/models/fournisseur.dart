class PaymentTypeRef {
  final int id;
  final String code;
  final String label;
  final String? description;

  const PaymentTypeRef({
    required this.id,
    required this.code,
    required this.label,
    this.description,
  });

  factory PaymentTypeRef.fromMap(Map<String, dynamic> map) => PaymentTypeRef(
        id: map['id'] as int,
        code: map['code'] as String,
        label: map['label'] as String,
        description: map['description'] as String?,
      );
}

class FournisseurModel {
  final int id;
  final String ownerId;
  final String nom;
  final String? categorie;
  final String? telephone;
  final String? email;
  final String? siteWeb;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;

  // Informações bancárias
  final String? iban;
  final String? bic;
  final String? titulaireCompte;

  // Pagamento digital
  final String? telephoneWero;
  final bool weroActif;
  final String? emailPaypal;
  final bool paypalActif;

  // Tipos de pagamento aceitos (lista de codes)
  final List<String> typesPaiement;

  const FournisseurModel({
    required this.id,
    required this.ownerId,
    required this.nom,
    this.categorie,
    this.telephone,
    this.email,
    this.siteWeb,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.iban,
    this.bic,
    this.titulaireCompte,
    this.telephoneWero,
    this.weroActif = false,
    this.emailPaypal,
    this.paypalActif = false,
    this.typesPaiement = const [],
  });

  factory FournisseurModel.fromMap(Map<String, dynamic> map) {
    final rawTypes = map['types_paiement'];
    final List<String> types = rawTypes is List
        ? rawTypes.map((e) => e.toString()).toList()
        : <String>[];

    return FournisseurModel(
      id: map['id'] as int,
      ownerId: map['owner_id'] as String,
      nom: map['nom'] as String,
      categorie: map['categorie'] as String?,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      siteWeb: map['site_web'] as String?,
      notes: map['notes'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      iban: map['iban'] as String?,
      bic: map['bic'] as String?,
      titulaireCompte: map['titulaire_compte'] as String?,
      telephoneWero: map['telephone_wero'] as String?,
      weroActif: map['wero_actif'] as bool? ?? false,
      emailPaypal: map['email_paypal'] as String?,
      paypalActif: map['paypal_actif'] as bool? ?? false,
      typesPaiement: types,
    );
  }

  Map<String, dynamic> toInsert() => {
        'owner_id': ownerId,
        'nom': nom,
        if (categorie != null) 'categorie': categorie,
        if (telephone != null) 'telephone': telephone,
        if (email != null) 'email': email,
        if (siteWeb != null) 'site_web': siteWeb,
        if (notes != null) 'notes': notes,
        'is_active': isActive,
        if (iban != null) 'iban': iban,
        if (bic != null) 'bic': bic,
        if (titulaireCompte != null) 'titulaire_compte': titulaireCompte,
        if (telephoneWero != null) 'telephone_wero': telephoneWero,
        'wero_actif': weroActif,
        if (emailPaypal != null) 'email_paypal': emailPaypal,
        'paypal_actif': paypalActif,
        'types_paiement': typesPaiement,
      };

  FournisseurModel copyWith({
    int? id,
    String? ownerId,
    String? nom,
    String? categorie,
    String? telephone,
    String? email,
    String? siteWeb,
    String? notes,
    bool? isActive,
    String? iban,
    String? bic,
    String? titulaireCompte,
    String? telephoneWero,
    bool? weroActif,
    String? emailPaypal,
    bool? paypalActif,
    List<String>? typesPaiement,
  }) {
    return FournisseurModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      nom: nom ?? this.nom,
      categorie: categorie ?? this.categorie,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      siteWeb: siteWeb ?? this.siteWeb,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      titulaireCompte: titulaireCompte ?? this.titulaireCompte,
      telephoneWero: telephoneWero ?? this.telephoneWero,
      weroActif: weroActif ?? this.weroActif,
      emailPaypal: emailPaypal ?? this.emailPaypal,
      paypalActif: paypalActif ?? this.paypalActif,
      typesPaiement: typesPaiement ?? this.typesPaiement,
    );
  }
}

const kCategoriesFournisseur = [
  'Eau',
  'Électricité',
  'Gaz',
  'Téléphone / Internet',
  'Assurance',
  'Entretien / Réparation',
  'Syndic / Copropriété',
  'Impôts / Taxes',
  'Divers',
];
