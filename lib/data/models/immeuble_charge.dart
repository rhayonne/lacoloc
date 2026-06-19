import 'package:lacoloc_front/data/models/charge_reference.dart';

/// Charge associée à un immeuble (bail location).
class ImmeubleChargeModel {
  final int id;
  final int immeubleId;
  final int chargeRefId;
  final String type; // 'inclus' | 'fixe'
  final double? montant; // null si 'inclus'
  final ChargeReferenceModel? chargeRef;

  const ImmeubleChargeModel({
    required this.id,
    required this.immeubleId,
    required this.chargeRefId,
    required this.type,
    this.montant,
    this.chargeRef,
  });

  bool get isInclus => type == 'inclus';

  factory ImmeubleChargeModel.fromMap(Map<String, dynamic> map) {
    final rawRef = map['Charges_Reference'];
    return ImmeubleChargeModel(
      id: map['id'] as int,
      immeubleId: map['immeuble_id'] as int,
      chargeRefId: map['charge_ref_id'] as int,
      type: (map['type'] ?? 'inclus') as String,
      montant: (map['montant'] as num?)?.toDouble(),
      chargeRef: rawRef is Map
          ? ChargeReferenceModel.fromMap(Map<String, dynamic>.from(rawRef))
          : null,
    );
  }

  Map<String, dynamic> toInsert() => {
        'immeuble_id': immeubleId,
        'charge_ref_id': chargeRefId,
        'type': type,
        if (montant != null) 'montant': montant,
      };

  Map<String, dynamic> toUpdate() => {
        'type': type,
        'montant': montant,
      };
}
