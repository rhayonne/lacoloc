class ObservationEdl {
  final int? id;
  final int etatDesLieuxId;
  final String? wallKey; // null = observation générale
  final String? description;
  final List<String> photos;
  final DateTime? createdAt;

  const ObservationEdl({
    this.id,
    required this.etatDesLieuxId,
    this.wallKey,
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
    description: map['description'] as String?,
    photos: (map['photos'] as List?)?.cast<String>() ?? [],
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toInsert() => {
    'etat_de_lieux_id': etatDesLieuxId,
    if (wallKey != null) 'wall_key': wallKey,
    if (description != null && description!.isNotEmpty) 'description': description,
    'photos': photos,
  };
}
