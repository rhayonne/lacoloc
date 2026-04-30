class ChambreModel {
  final int id;
  final int immeubleId;
  final String roomName;
  final double? m2;
  final String? description;
  final List<String> roomPhotos;
  final List<int> selectedOptionIds;
  final bool isActive;
  final double? prixLoyer;
  final bool estLoue;
  final String? mainPhoto;
  final DateTime? createdAt;

  // Campos enriquecidos via join (opcionais).
  final String? immeubleName;
  final String? immeubleAddress;
  final String? immeubleCity;
  final String? immeubleRegion;
  final String? immeubleDepartment;

  ChambreModel({
    required this.id,
    required this.immeubleId,
    required this.roomName,
    this.m2,
    this.description,
    this.roomPhotos = const [],
    this.selectedOptionIds = const [],
    this.isActive = true,
    this.prixLoyer,
    this.estLoue = false,
    this.mainPhoto,
    this.createdAt,
    this.immeubleName,
    this.immeubleAddress,
    this.immeubleCity,
    this.immeubleRegion,
    this.immeubleDepartment,
  });

  factory ChambreModel.fromMap(Map<String, dynamic> map) {
    final immeuble = map['Immeubles'];
    return ChambreModel(
      id: map['id'] as int,
      immeubleId: map['immeuble_id'] as int,
      roomName: (map['room_name'] ?? '') as String,
      m2: (map['m2'] as num?)?.toDouble(),
      description: map['description'] as String?,
      roomPhotos: _photosFromAny(map['room_photos']),
      selectedOptionIds: _intsFromAny(map['selected_options']),
      isActive: (map['is_active'] as bool?) ?? true,
      prixLoyer: (map['prix_loyer'] as num?)?.toDouble(),
      estLoue: (map['est_loue'] as bool?) ?? false,
      mainPhoto: map['main_photo'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      immeubleName: immeuble is Map ? immeuble['name'] as String? : null,
      immeubleAddress: immeuble is Map ? immeuble['address'] as String? : null,
      immeubleCity: immeuble is Map ? immeuble['city'] as String? : null,
      immeubleRegion: immeuble is Map ? immeuble['region'] as String? : null,
      immeubleDepartment:
          immeuble is Map ? immeuble['department'] as String? : null,
    );
  }

  Map<String, dynamic> toInsert() => {
        'immeuble_id': immeubleId,
        'room_name': roomName,
        if (m2 != null) 'm2': m2,
        if (description != null) 'description': description,
        'room_photos': roomPhotos,
        'selected_options': selectedOptionIds,
        'is_active': isActive,
        if (prixLoyer != null) 'prix_loyer': prixLoyer,
        'est_loue': estLoue,
        'main_photo': mainPhoto,
      };

  static List<String> _photosFromAny(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  static List<int> _intsFromAny(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .where((e) => e != 0)
          .toList();
    }
    return const [];
  }
}
