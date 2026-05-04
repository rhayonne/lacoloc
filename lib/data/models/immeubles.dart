import 'package:lacoloc_front/data/models/immeuble_type.dart';

class ImmeublesModel {
  final int id;
  final String? ownerId;
  final int? typeId;
  final ImmeubleTypeModel? type;
  final String name;
  final String? address;
  final double? totalM2;
  final String? description;
  final List<String> commonPhotos;
  final bool isActive;
  final String? mainPhoto;
  final String? city;
  final String? region;
  final String? department;
  final DateTime? createdAt;
  final bool bailCollectif;
  final bool bailIndividuel;

  ImmeublesModel({
    required this.id,
    required this.name,
    this.ownerId,
    this.typeId,
    this.type,
    this.address,
    this.totalM2,
    this.description,
    this.commonPhotos = const [],
    this.isActive = true,
    this.mainPhoto,
    this.city,
    this.region,
    this.department,
    this.createdAt,
    this.bailCollectif = false,
    this.bailIndividuel = false,
  });

  String? get bailLabel {
    if (bailCollectif) return 'Bail collectif';
    if (bailIndividuel) return 'Bail individuel';
    return null;
  }

  String get nome => name;

  factory ImmeublesModel.fromMap(Map<String, dynamic> map) {
    final rawType = map['Immeuble_Types_Reference'];
    return ImmeublesModel(
      id: map['id'] as int,
      name: (map['name'] ?? map['nome'] ?? '') as String,
      ownerId: map['owner_id'] as String?,
      typeId: map['type_id'] as int?,
      type: rawType is Map
          ? ImmeubleTypeModel.fromMap(Map<String, dynamic>.from(rawType))
          : null,
      address: map['address'] as String?,
      totalM2: (map['total_m2'] as num?)?.toDouble(),
      description: map['description'] as String?,
      commonPhotos: _photosFromAny(map['common_photos']),
      isActive: (map['is_active'] as bool?) ?? true,
      mainPhoto: map['main_photo'] as String?,
      city: map['city'] as String?,
      region: map['region'] as String?,
      department: map['department'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      bailCollectif: (map['bail_collectif'] as bool?) ?? false,
      bailIndividuel: (map['bail_individuel'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toInsert() => {
        if (ownerId != null) 'owner_id': ownerId,
        if (typeId != null) 'type_id': typeId,
        'name': name,
        if (address != null) 'address': address,
        if (totalM2 != null) 'total_m2': totalM2,
        if (description != null) 'description': description,
        'common_photos': commonPhotos,
        'is_active': isActive,
        'main_photo': mainPhoto,
        if (city != null) 'city': city,
        if (region != null) 'region': region,
        if (department != null) 'department': department,
        'bail_collectif': bailCollectif,
        'bail_individuel': bailIndividuel,
      };

  static List<String> _photosFromAny(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }
}
