/// Disponibilité d'une chambre (RPC `chambre_disponibilite`).
///
/// `dateDisponible` : date de libération connue (`today` si déjà libre,
/// `null` si occupée sans date de fin de bail connue — ex. marquée « louée »
/// manuellement, sans EDL lié).
class ChambreDisponibiliteModel {
  final int chambreId;
  final bool disponible;
  final DateTime? dateDisponible;

  const ChambreDisponibiliteModel({
    required this.chambreId,
    required this.disponible,
    this.dateDisponible,
  });

  /// Sera libre au plus tard le [date] donné (déjà libre ou date connue ≤ date).
  bool disponibleAvant(DateTime date) {
    final d = dateDisponible;
    if (d == null) return false;
    return !d.isAfter(date);
  }

  factory ChambreDisponibiliteModel.fromMap(Map<String, dynamic> map) {
    final raw = map['date_disponible'] as String?;
    return ChambreDisponibiliteModel(
      chambreId: (map['chambre_id'] as num).toInt(),
      disponible: map['disponible'] as bool? ?? false,
      dateDisponible: raw != null ? DateTime.parse(raw) : null,
    );
  }
}
