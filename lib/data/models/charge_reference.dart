import 'package:flutter/material.dart';

class ChargeReferenceModel {
  final int id;
  final String nom;
  final String icone;
  final String? description;
  final bool isActive;
  final int ordre;
  final DateTime? createdAt;

  const ChargeReferenceModel({
    required this.id,
    required this.nom,
    required this.icone,
    this.description,
    this.isActive = true,
    this.ordre = 0,
    this.createdAt,
  });

  factory ChargeReferenceModel.fromMap(Map<String, dynamic> map) =>
      ChargeReferenceModel(
        id: map['id'] as int,
        nom: (map['nom'] ?? '') as String,
        icone: (map['icone'] ?? 'receipt_long') as String,
        description: map['description'] as String?,
        isActive: (map['is_active'] as bool?) ?? true,
        ordre: (map['ordre'] as int?) ?? 0,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsert() => {
        'nom': nom,
        'icone': icone,
        if (description != null) 'description': description,
        'is_active': isActive,
        'ordre': ordre,
      };

  ChargeReferenceModel copyWith({
    String? nom,
    String? icone,
    String? description,
    bool? isActive,
    int? ordre,
  }) =>
      ChargeReferenceModel(
        id: id,
        nom: nom ?? this.nom,
        icone: icone ?? this.icone,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        ordre: ordre ?? this.ordre,
        createdAt: createdAt,
      );

  /// Retourne l'IconData Material correspondant au nom stocké en base.
  IconData get iconData => _kIconMap[icone] ?? Icons.receipt_long;

  static const Map<String, IconData> _kIconMap = {
    'water_drop':            Icons.water_drop,
    'thermostat':            Icons.thermostat,
    'local_fire_department': Icons.local_fire_department,
    'bolt':                  Icons.bolt,
    'wifi':                  Icons.wifi,
    'delete_outline':        Icons.delete_outline,
    'cleaning_services':     Icons.cleaning_services,
    'security':              Icons.security,
    'elevator':              Icons.elevator,
    'verified_user':         Icons.verified_user,
    'doorbell':              Icons.doorbell,
    'park':                  Icons.park,
    'storage':               Icons.storage,
    'local_parking':         Icons.local_parking,
    'receipt_long':          Icons.receipt_long,
  };

  /// Liste des icônes disponibles pour le formulaire du super admin.
  static const List<(String key, IconData icon, String label)> kAvailableIcons = [
    ('water_drop',            Icons.water_drop,            'Eau froide'),
    ('thermostat',            Icons.thermostat,            'Eau chaude'),
    ('local_fire_department', Icons.local_fire_department, 'Chauffage'),
    ('bolt',                  Icons.bolt,                  'Électricité'),
    ('wifi',                  Icons.wifi,                  'Internet'),
    ('delete_outline',        Icons.delete_outline,        'Ordures'),
    ('cleaning_services',     Icons.cleaning_services,     'Entretien'),
    ('security',              Icons.security,              'Sécurité'),
    ('elevator',              Icons.elevator,              'Ascenseur'),
    ('verified_user',         Icons.verified_user,         'Assurance'),
    ('doorbell',              Icons.doorbell,              'Interphone'),
    ('park',                  Icons.park,                  'Espaces verts'),
    ('storage',               Icons.storage,               'Cave'),
    ('local_parking',         Icons.local_parking,         'Parking'),
    ('receipt_long',          Icons.receipt_long,          'Autres'),
  ];
}
