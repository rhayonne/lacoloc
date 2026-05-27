class PiecePhoto {
  final String url;
  final bool dansAnnonce;

  const PiecePhoto({required this.url, this.dansAnnonce = false});

  PiecePhoto copyWith({bool? dansAnnonce}) =>
      PiecePhoto(url: url, dansAnnonce: dansAnnonce ?? this.dansAnnonce);

  Map<String, dynamic> toJson() => {'url': url, 'dans_annonce': dansAnnonce};

  factory PiecePhoto.fromJson(Map<String, dynamic> json) => PiecePhoto(
    url: json['url'] as String,
    dansAnnonce: (json['dans_annonce'] as bool?) ?? false,
  );
}

class PieceModel {
  final int id;
  final int immeubleId;
  final String nom;
  final double? m2;
  final String? description;
  final List<PiecePhoto> photos;
  final DateTime createdAt;

  const PieceModel({
    required this.id,
    required this.immeubleId,
    required this.nom,
    this.m2,
    this.description,
    required this.photos,
    required this.createdAt,
  });

  int get photosAnnonce => photos.where((p) => p.dansAnnonce).length;

  factory PieceModel.fromMap(Map<String, dynamic> map) {
    final raw = map['photos'];
    final photos = raw is List
        ? raw
            .cast<Map<String, dynamic>>()
            .map(PiecePhoto.fromJson)
            .toList()
        : <PiecePhoto>[];
    return PieceModel(
      id: map['id'] as int,
      immeubleId: map['immeuble_id'] as int,
      nom: map['nom'] as String,
      m2: (map['m2'] as num?)?.toDouble(),
      description: map['description'] as String?,
      photos: photos,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsert() {
    final data = <String, dynamic>{
      'immeuble_id': immeubleId,
      'nom': nom,
      'photos': photos.map((p) => p.toJson()).toList(),
    };
    if (m2 != null) data['m2'] = m2;
    if (description != null && description!.isNotEmpty) {
      data['description'] = description;
    }
    return data;
  }

  PieceModel copyWith({
    String? nom,
    double? m2,
    String? description,
    List<PiecePhoto>? photos,
  }) => PieceModel(
    id: id,
    immeubleId: immeubleId,
    nom: nom ?? this.nom,
    m2: m2 ?? this.m2,
    description: description ?? this.description,
    photos: photos ?? this.photos,
    createdAt: createdAt,
  );
}
