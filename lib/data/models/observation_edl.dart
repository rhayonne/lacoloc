class ObservationEdl {
  final int? id;
  final int etatDesLieuxId;
  final String? wallKey; // null = observation générale
  final int? pieceId; // EDL collectif : observation rattachée à une pièce
  final int? chambreId; // EDL collectif : observation rattachée à une chambre
  final String? description;
  final List<String> photos;
  final DateTime? createdAt;

  const ObservationEdl({
    this.id,
    required this.etatDesLieuxId,
    this.wallKey,
    this.pieceId,
    this.chambreId,
    this.description,
    this.photos = const [],
    this.createdAt,
  });

  bool get hasContent =>
      (description != null && description!.isNotEmpty) || photos.isNotEmpty;

  String get wallLabel => switch (wallKey) {
    'fond'   => 'Mur du fond',
    'gauche' => 'Mur gauche',
    'droit'  => 'Mur droit',
    'porte'  => "Mur d'entrée / Porte",
    _        => 'Général',
  };

  factory ObservationEdl.fromMap(Map<String, dynamic> map) => ObservationEdl(
    id: map['id'] as int?,
    etatDesLieuxId: map['etat_de_lieux_id'] as int,
    wallKey: map['wall_key'] as String?,
    pieceId: map['piece_id'] as int?,
    chambreId: map['chambre_id'] as int?,
    description: map['description'] as String?,
    photos: (map['photos'] as List?)?.cast<String>() ?? [],
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toInsert() => {
    'etat_de_lieux_id': etatDesLieuxId,
    if (wallKey != null) 'wall_key': wallKey,
    if (pieceId != null) 'piece_id': pieceId,
    if (chambreId != null) 'chambre_id': chambreId,
    if (description != null && description!.isNotEmpty) 'description': description,
    'photos': photos,
  };
}
