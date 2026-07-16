/// Type d'un lot de copropriété (règlement de copropriété).
enum LotType {
  habitation,
  cave,
  parking,
  grenier,
  autre;

  static LotType fromCode(String? code) => LotType.values.firstWhere(
        (t) => t.name == code,
        orElse: () => LotType.habitation,
      );

  String get label => switch (this) {
        LotType.habitation => 'Habitation',
        LotType.cave => 'Cave',
        LotType.parking => 'Parking',
        LotType.grenier => 'Grenier',
        LotType.autre => 'Autre',
      };
}

/// Un lot de copropriété : appartient au **propriétaire** (existe indépendamment
/// d'un immeuble — un catalogue) et peut être **rattaché** à un [Immeuble]
/// (`immeubleId` nullable). Regroupe toutes les mentions légales usuelles d'un
/// descriptif de lot (règlement de copropriété, désignation, tantièmes) ainsi
/// que les infos de la copropriété elle-même (nom, adresse, syndic).
class ImmeubleLotModel {
  final int id;
  final String ownerId;
  final int? immeubleId;

  // Identification du lot (règlement de copropriété)
  final String numeroLot;
  final LotType typeLot;
  final String? batiment;
  final String? etage;
  final String? porte;
  final String? referenceCadastrale;

  // Quote-part de charges
  final double? tantiemes;
  final double? tantiemesTotal;

  // La copropriété à laquelle appartient le lot
  final String? nomCopropriete;
  final String? adresseCopropriete;
  final int? syndicFournisseurId;

  final String? description;

  // Enrichis via join (affichage seulement)
  final String? syndicNom;
  final String? immeubleNom;

  const ImmeubleLotModel({
    required this.id,
    required this.ownerId,
    this.immeubleId,
    required this.numeroLot,
    this.typeLot = LotType.habitation,
    this.batiment,
    this.etage,
    this.porte,
    this.referenceCadastrale,
    this.tantiemes,
    this.tantiemesTotal,
    this.nomCopropriete,
    this.adresseCopropriete,
    this.syndicFournisseurId,
    this.description,
    this.syndicNom,
    this.immeubleNom,
  });

  /// Désignation courte affichée dans les listes/recherches.
  String get displayLabel {
    final copro = nomCopropriete?.isNotEmpty == true ? nomCopropriete : null;
    return copro != null ? 'Lot $numeroLot — $copro' : 'Lot $numeroLot';
  }

  factory ImmeubleLotModel.fromMap(Map<String, dynamic> map) {
    final syndic = map['syndic'] as Map<String, dynamic>?;
    final immeuble = map['immeuble'] as Map<String, dynamic>?;
    return ImmeubleLotModel(
      id: (map['id'] as num).toInt(),
      ownerId: map['owner_id'] as String,
      immeubleId: (map['immeuble_id'] as num?)?.toInt(),
      numeroLot: map['numero_lot'] as String,
      typeLot: LotType.fromCode(map['type_lot'] as String?),
      batiment: map['batiment'] as String?,
      etage: map['etage'] as String?,
      porte: map['porte'] as String?,
      referenceCadastrale: map['reference_cadastrale'] as String?,
      tantiemes: (map['tantiemes'] as num?)?.toDouble(),
      tantiemesTotal: (map['tantiemes_total'] as num?)?.toDouble(),
      nomCopropriete: map['nom_copropriete'] as String?,
      adresseCopropriete: map['adresse_copropriete'] as String?,
      syndicFournisseurId: (map['syndic_fournisseur_id'] as num?)?.toInt(),
      description: map['description'] as String?,
      syndicNom: syndic?['nom'] as String?,
      immeubleNom: immeuble?['name'] as String?,
    );
  }

  /// Pour la création : `owner_id` est requis, `immeuble_id` est envoyé
  /// seulement si déjà rattaché.
  Map<String, dynamic> toInsert() => {
        'owner_id': ownerId,
        if (immeubleId != null) 'immeuble_id': immeubleId,
        'numero_lot': numeroLot,
        'type_lot': typeLot.name,
        if (batiment != null && batiment!.isNotEmpty) 'batiment': batiment,
        if (etage != null && etage!.isNotEmpty) 'etage': etage,
        if (porte != null && porte!.isNotEmpty) 'porte': porte,
        if (referenceCadastrale != null && referenceCadastrale!.isNotEmpty)
          'reference_cadastrale': referenceCadastrale,
        if (tantiemes != null) 'tantiemes': tantiemes,
        if (tantiemesTotal != null) 'tantiemes_total': tantiemesTotal,
        if (nomCopropriete != null && nomCopropriete!.isNotEmpty)
          'nom_copropriete': nomCopropriete,
        if (adresseCopropriete != null && adresseCopropriete!.isNotEmpty)
          'adresse_copropriete': adresseCopropriete,
        if (syndicFournisseurId != null)
          'syndic_fournisseur_id': syndicFournisseurId,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };

  /// Pour la mise à jour : envoie tout (y compris les null), pour permettre
  /// d'effacer un champ ou de détacher l'immeuble (`immeubleId = null`).
  Map<String, dynamic> toUpdate() => {
        'immeuble_id': immeubleId,
        'numero_lot': numeroLot,
        'type_lot': typeLot.name,
        'batiment': batiment,
        'etage': etage,
        'porte': porte,
        'reference_cadastrale': referenceCadastrale,
        'tantiemes': tantiemes,
        'tantiemes_total': tantiemesTotal,
        'nom_copropriete': nomCopropriete,
        'adresse_copropriete': adresseCopropriete,
        'syndic_fournisseur_id': syndicFournisseurId,
        'description': description,
      };
}
