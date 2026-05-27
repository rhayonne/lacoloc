class MeubleReferenceModel {
  final int id;
  final String nom;
  final String? categorie;

  const MeubleReferenceModel({
    required this.id,
    required this.nom,
    this.categorie,
  });

  factory MeubleReferenceModel.fromMap(Map<String, dynamic> map) =>
      MeubleReferenceModel(
        id: (map['id'] as num).toInt(),
        nom: map['nom'] as String,
        categorie: map['categorie'] as String?,
      );
}

class InventaireModel {
  final int id;
  final int immeubleId;
  final int? chambreId;
  final int? pieceId;
  final int? meubleRefId;
  final String? nomCustom;
  final double? valeur;
  final int quantite;
  final String? description;
  final List<String> photos;
  final DateTime createdAt;

  // Enrichis via join
  final String? meubleNom;
  final String? meubleCategorie;
  final String? chambreNom;
  final String? pieceNom;

  const InventaireModel({
    required this.id,
    required this.immeubleId,
    this.chambreId,
    this.pieceId,
    this.meubleRefId,
    this.nomCustom,
    this.valeur,
    this.quantite = 1,
    this.description,
    required this.photos,
    required this.createdAt,
    this.meubleNom,
    this.meubleCategorie,
    this.chambreNom,
    this.pieceNom,
  });

  String get displayNom => nomCustom ?? meubleNom ?? '—';

  String get displayLieu {
    if (chambreNom != null) return chambreNom!;
    if (pieceNom != null) return pieceNom!;
    return 'Commun';
  }

  factory InventaireModel.fromMap(Map<String, dynamic> map) {
    final ref = map['meuble_ref'] as Map<String, dynamic>?;
    final chb = map['chambre'] as Map<String, dynamic>?;
    final pce = map['piece'] as Map<String, dynamic>?;
    final rawPhotos = map['photos'];
    final photos = rawPhotos is List ? rawPhotos.cast<String>() : <String>[];

    return InventaireModel(
      id: (map['id'] as num).toInt(),
      immeubleId: (map['immeuble_id'] as num).toInt(),
      chambreId: map['chambre_id'] != null
          ? (map['chambre_id'] as num).toInt()
          : null,
      pieceId: map['piece_id'] != null
          ? (map['piece_id'] as num).toInt()
          : null,
      meubleRefId: map['meuble_ref_id'] != null
          ? (map['meuble_ref_id'] as num).toInt()
          : null,
      nomCustom: map['nom_custom'] as String?,
      valeur: (map['valeur'] as num?)?.toDouble(),
      quantite: (map['quantite'] as num?)?.toInt() ?? 1,
      description: map['description'] as String?,
      photos: photos,
      createdAt: DateTime.parse(map['created_at'] as String),
      meubleNom: ref?['nom'] as String?,
      meubleCategorie: ref?['categorie'] as String?,
      chambreNom: chb?['room_name'] as String?,
      pieceNom: pce?['nom'] as String?,
    );
  }

  Map<String, dynamic> toInsert() => {
    'immeuble_id': immeubleId,
    if (chambreId != null) 'chambre_id': chambreId,
    if (pieceId != null) 'piece_id': pieceId,
    if (meubleRefId != null) 'meuble_ref_id': meubleRefId,
    'nom_custom': (nomCustom?.isNotEmpty == true) ? nomCustom : null,
    if (valeur != null) 'valeur': valeur,
    'quantite': quantite,
    if (description != null && description!.isNotEmpty) 'description': description,
    'photos': photos,
  };
}
