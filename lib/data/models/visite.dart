import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_colors.dart';

const kTypesVisite = [
  'etat_des_lieux_entree',
  'etat_des_lieux_sortie',
  'visite_entree',
  'reparation',
];

String typeVisiteLabel(String type) => switch (type) {
      'etat_des_lieux_entree' => 'État des lieux entrée',
      'etat_des_lieux_sortie' => 'État des lieux sortie',
      'visite_entree' => 'Visite entrée',
      'reparation' => 'Réparation',
      _ => type,
    };

Color typeVisiteColor(String type) => switch (type) {
      'etat_des_lieux_entree' => AppColors.primary,
      'etat_des_lieux_sortie' => AppColors.error,
      'visite_entree' => const Color(0xFF9C27B0),
      'reparation' => const Color(0xFFFF9800),
      _ => AppColors.onSurfaceVariant,
    };

class VisiteModel {
  final int id;
  final String ownerId;
  final String typeVisite;
  final String nomVisiteur;
  final String? telephone;
  final DateTime dateVisite;
  final int? fournisseurId;
  final DateTime createdAt;

  const VisiteModel({
    required this.id,
    required this.ownerId,
    required this.typeVisite,
    required this.nomVisiteur,
    this.telephone,
    required this.dateVisite,
    this.fournisseurId,
    required this.createdAt,
  });

  factory VisiteModel.fromMap(Map<String, dynamic> map) => VisiteModel(
        id: map['id'] as int,
        ownerId: map['owner_id'] as String,
        typeVisite: map['type_visite'] as String,
        nomVisiteur: map['nom_visiteur'] as String,
        telephone: map['telephone'] as String?,
        dateVisite: DateTime.parse(map['date_visite'] as String),
        fournisseurId: map['fournisseur_id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsert() => {
        'owner_id': ownerId,
        'type_visite': typeVisite,
        'nom_visiteur': nomVisiteur,
        if (telephone != null && telephone!.isNotEmpty) 'telephone': telephone,
        'date_visite': '${dateVisite.year}-'
            '${dateVisite.month.toString().padLeft(2, '0')}-'
            '${dateVisite.day.toString().padLeft(2, '0')}',
        if (fournisseurId != null) 'fournisseur_id': fournisseurId,
      };

  VisiteModel copyWith({
    int? id,
    String? ownerId,
    String? typeVisite,
    String? nomVisiteur,
    String? telephone,
    DateTime? dateVisite,
    int? fournisseurId,
    DateTime? createdAt,
  }) =>
      VisiteModel(
        id: id ?? this.id,
        ownerId: ownerId ?? this.ownerId,
        typeVisite: typeVisite ?? this.typeVisite,
        nomVisiteur: nomVisiteur ?? this.nomVisiteur,
        telephone: telephone ?? this.telephone,
        dateVisite: dateVisite ?? this.dateVisite,
        fournisseurId: fournisseurId ?? this.fournisseurId,
        createdAt: createdAt ?? this.createdAt,
      );
}
