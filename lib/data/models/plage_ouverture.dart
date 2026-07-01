import 'package:flutter/material.dart';

/// Une plage de disponibilité du propriétaire, par jour de semaine.
/// [type] : `ouverture` (créneau disponible, blanc) ou `pause` (déjeuner /
/// indisponible, jaune). Tout ce qui est HORS d'une plage `ouverture` est
/// « hors plage » (hachuré) dans le calendrier.
class PlageOuverture {
  final int id;
  final String ownerId;
  final int jourSemaine; // 1 = lundi … 7 = dimanche (DateTime.weekday)
  final int debutMin; // minutes depuis minuit
  final int finMin;
  final String type; // 'ouverture' | 'pause'

  const PlageOuverture({
    required this.id,
    required this.ownerId,
    required this.jourSemaine,
    required this.debutMin,
    required this.finMin,
    required this.type,
  });

  bool get isPause => type == 'pause';

  TimeOfDay get debut => TimeOfDay(hour: debutMin ~/ 60, minute: debutMin % 60);
  TimeOfDay get fin => TimeOfDay(hour: finMin ~/ 60, minute: finMin % 60);

  static int _parseTime(String hms) {
    final parts = hms.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  static String _fmtTime(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:'
      '${(min % 60).toString().padLeft(2, '0')}:00';

  factory PlageOuverture.fromMap(Map<String, dynamic> map) => PlageOuverture(
        id: map['id'] as int,
        ownerId: map['owner_id'] as String,
        jourSemaine: map['jour_semaine'] as int,
        debutMin: _parseTime(map['heure_debut'] as String),
        finMin: _parseTime(map['heure_fin'] as String),
        type: (map['type'] as String?) ?? 'ouverture',
      );

  Map<String, dynamic> toInsert(String ownerId) => {
        'owner_id': ownerId,
        'jour_semaine': jourSemaine,
        'heure_debut': _fmtTime(debutMin),
        'heure_fin': _fmtTime(finMin),
        'type': type,
      };

  PlageOuverture copyWith({
    int? jourSemaine,
    int? debutMin,
    int? finMin,
    String? type,
  }) =>
      PlageOuverture(
        id: id,
        ownerId: ownerId,
        jourSemaine: jourSemaine ?? this.jourSemaine,
        debutMin: debutMin ?? this.debutMin,
        finMin: finMin ?? this.finMin,
        type: type ?? this.type,
      );
}

/// Plages par défaut proposées (Lun–Ven 9h–12h & 13h–18h, pause 12h–13h).
List<PlageOuverture> defaultPlagesTemplate() {
  final out = <PlageOuverture>[];
  for (var j = 1; j <= 5; j++) {
    out.add(PlageOuverture(
        id: 0, ownerId: '', jourSemaine: j, debutMin: 9 * 60, finMin: 12 * 60, type: 'ouverture'));
    out.add(PlageOuverture(
        id: 0, ownerId: '', jourSemaine: j, debutMin: 12 * 60, finMin: 13 * 60, type: 'pause'));
    out.add(PlageOuverture(
        id: 0, ownerId: '', jourSemaine: j, debutMin: 13 * 60, finMin: 18 * 60, type: 'ouverture'));
  }
  return out;
}
