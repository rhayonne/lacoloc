import 'package:lacoloc_front/data/models/charge_reference.dart';

/// Charge associée à une chambre (bail individuel / colocation).
class ChambreChargeModel {
  final int id;
  final int chambreId;
  final int chargeRefId;
  final String type; // 'inclus' | 'fixe'
  final double? montant;
  final ChargeReferenceModel? chargeRef;

  const ChambreChargeModel({
    required this.id,
    required this.chambreId,
    required this.chargeRefId,
    required this.type,
    this.montant,
    this.chargeRef,
  });

  bool get isInclus => type == 'inclus';

  factory ChambreChargeModel.fromMap(Map<String, dynamic> map) {
    final rawRef = map['Charges_Reference'];
    return ChambreChargeModel(
      id: map['id'] as int,
      chambreId: map['chambre_id'] as int,
      chargeRefId: map['charge_ref_id'] as int,
      type: (map['type'] ?? 'inclus') as String,
      montant: (map['montant'] as num?)?.toDouble(),
      chargeRef: rawRef is Map
          ? ChargeReferenceModel.fromMap(Map<String, dynamic>.from(rawRef))
          : null,
    );
  }

  Map<String, dynamic> toInsert() => {
        'chambre_id': chambreId,
        'charge_ref_id': chargeRefId,
        'type': type,
        if (montant != null) 'montant': montant,
      };

  Map<String, dynamic> toUpdate() => {
        'type': type,
        'montant': montant,
      };
}
