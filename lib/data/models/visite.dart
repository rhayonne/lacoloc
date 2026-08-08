import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_colors.dart';

/// Types de rendez-vous de l'agenda (ordre d'affichage dans les menus).
const kTypesVisite = [
  'visite_entree',
  'etat_des_lieux_entree',
  'etat_des_lieux_sortie',
  'reparation',
  'autre',
];

String typeVisiteLabel(String type) => switch (type) {
      'etat_des_lieux_entree' => 'État des lieux entrée',
      'etat_des_lieux_sortie' => 'État des lieux sortie',
      'visite_entree' => 'Visite',
      'reparation' => 'Réparation',
      'autre' => 'Autre',
      _ => type,
    };

Color typeVisiteColor(String type) => switch (type) {
      'etat_des_lieux_entree' => AppColors.primary,
      'etat_des_lieux_sortie' => AppColors.error,
      'visite_entree' => const Color(0xFF9C27B0),
      'reparation' => const Color(0xFFFF9800),
      'autre' => const Color(0xFF607D8B),
      _ => AppColors.onSurfaceVariant,
    };

class VisiteModel {
  final int id;
  final String ownerId;
  final String typeVisite;
  final String nomVisiteur;
  final String? telephone;

  /// Début / fin du créneau. Source de vérité de l'agenda.
  final DateTime dateVisite; // = date de heureDebut (compat héritée)
  final DateTime? heureDebut;
  final DateTime? heureFin;

  /// Contact lié : un locataire existant (id) OU un invité hors système
  /// (inviteEmail / inviteNom). Les deux sont mutuellement exclusifs côté UI.
  final String? locataireId;
  final String? inviteEmail;
  final String? inviteNom;

  /// Lieu du rendez-vous.
  final int? immeubleId;

  final String? notes;
  final int? fournisseurId;
  final DateTime createdAt;

  const VisiteModel({
    required this.id,
    required this.ownerId,
    required this.typeVisite,
    required this.nomVisiteur,
    this.telephone,
    required this.dateVisite,
    this.heureDebut,
    this.heureFin,
    this.locataireId,
    this.inviteEmail,
    this.inviteNom,
    this.immeubleId,
    this.notes,
    this.fournisseurId,
    required this.createdAt,
  });

  /// Début effectif du créneau (fallback sur dateVisite 09:00 pour l'ancien).
  DateTime get debut =>
      heureDebut ??
      DateTime(dateVisite.year, dateVisite.month, dateVisite.day, 9);

  /// Fin effective (fallback : début + 1 h).
  DateTime get fin => heureFin ?? debut.add(const Duration(hours: 1));

  factory VisiteModel.fromMap(Map<String, dynamic> map) {
    final heureDebut = map['heure_debut'] != null
        ? DateTime.parse(map['heure_debut'] as String).toLocal()
        : null;
    final heureFin = map['heure_fin'] != null
        ? DateTime.parse(map['heure_fin'] as String).toLocal()
        : null;
    final dateStr = map['date_visite'] as String?;
    final dateVisite = dateStr != null
        ? DateTime.parse(dateStr)
        : (heureDebut ?? DateTime.now());
    return VisiteModel(
      id: map['id'] as int,
      ownerId: map['owner_id'] as String,
      typeVisite: map['type_visite'] as String,
      nomVisiteur: (map['nom_visiteur'] as String?) ?? '',
      telephone: map['telephone'] as String?,
      dateVisite: dateVisite,
      heureDebut: heureDebut,
      heureFin: heureFin,
      locataireId: map['locataire_id'] as String?,
      inviteEmail: map['invite_email'] as String?,
      inviteNom: map['invite_nom'] as String?,
      immeubleId: map['immeuble_id'] as int?,
      notes: map['notes'] as String?,
      fournisseurId: map['fournisseur_id'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toInsert() {
    final d = debut;
    return {
      'owner_id': ownerId,
      'type_visite': typeVisite,
      'nom_visiteur': nomVisiteur,
      if (telephone != null && telephone!.isNotEmpty) 'telephone': telephone,
      // date_visite (compat) = jour du créneau.
      'date_visite': '${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}',
      'heure_debut': debut.toUtc().toIso8601String(),
      'heure_fin': fin.toUtc().toIso8601String(),
      'locataire_id': locataireId,
      'invite_email': inviteEmail,
      'invite_nom': inviteNom,
      'immeuble_id': immeubleId,
      'notes': notes,
      if (fournisseurId != null) 'fournisseur_id': fournisseurId,
    };
  }

  VisiteModel copyWith({
    int? id,
    String? ownerId,
    String? typeVisite,
    String? nomVisiteur,
    String? telephone,
    DateTime? dateVisite,
    DateTime? heureDebut,
    DateTime? heureFin,
    String? locataireId,
    String? inviteEmail,
    String? inviteNom,
    int? immeubleId,
    String? notes,
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
        heureDebut: heureDebut ?? this.heureDebut,
        heureFin: heureFin ?? this.heureFin,
        locataireId: locataireId ?? this.locataireId,
        inviteEmail: inviteEmail ?? this.inviteEmail,
        inviteNom: inviteNom ?? this.inviteNom,
        immeubleId: immeubleId ?? this.immeubleId,
        notes: notes ?? this.notes,
        fournisseurId: fournisseurId ?? this.fournisseurId,
        createdAt: createdAt ?? this.createdAt,
      );
}
