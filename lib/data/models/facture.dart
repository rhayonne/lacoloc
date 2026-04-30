class FactureModel {
  final int id;
  final String ownerId;
  final int? immeubleId;
  final String? immeubleName; // join only
  final String? codeFacture;
  final String fournisseur;
  final String typeFacture;
  final DateTime? periodeDebut;
  final DateTime? periodeFin;
  final DateTime? dateEmission;
  final DateTime? dateEcheance;
  final double? montantHt;
  final double tauxTva;
  final double? montantTtc;
  final String statut;
  final String? notes;
  final DateTime? createdAt;

  const FactureModel({
    required this.id,
    required this.ownerId,
    this.immeubleId,
    this.immeubleName,
    this.codeFacture,
    required this.fournisseur,
    required this.typeFacture,
    this.periodeDebut,
    this.periodeFin,
    this.dateEmission,
    this.dateEcheance,
    this.montantHt,
    this.tauxTva = 20,
    this.montantTtc,
    this.statut = 'Non payée',
    this.notes,
    this.createdAt,
  });

  factory FactureModel.fromMap(Map<String, dynamic> map) {
    final rawImm = map['Immeubles'];
    return FactureModel(
      id: map['id'] as int,
      ownerId: map['owner_id'] as String,
      immeubleId: map['immeuble_id'] as int?,
      immeubleName: rawImm is Map ? rawImm['name'] as String? : null,
      codeFacture: map['code_facture'] as String?,
      fournisseur: map['fournisseur'] as String,
      typeFacture: map['type_facture'] as String,
      periodeDebut: _date(map['periode_debut']),
      periodeFin: _date(map['periode_fin']),
      dateEmission: _date(map['date_emission']),
      dateEcheance: _date(map['date_echeance']),
      montantHt: (map['montant_ht'] as num?)?.toDouble(),
      tauxTva: (map['taux_tva'] as num?)?.toDouble() ?? 20,
      montantTtc: (map['montant_ttc'] as num?)?.toDouble(),
      statut: map['statut'] as String? ?? 'Non payée',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsert() => {
        'owner_id': ownerId,
        if (immeubleId != null) 'immeuble_id': immeubleId,
        if (codeFacture != null) 'code_facture': codeFacture,
        'fournisseur': fournisseur,
        'type_facture': typeFacture,
        if (periodeDebut != null)
          'periode_debut': periodeDebut!.toIso8601String().substring(0, 10),
        if (periodeFin != null)
          'periode_fin': periodeFin!.toIso8601String().substring(0, 10),
        if (dateEmission != null)
          'date_emission': dateEmission!.toIso8601String().substring(0, 10),
        if (dateEcheance != null)
          'date_echeance': dateEcheance!.toIso8601String().substring(0, 10),
        if (montantHt != null) 'montant_ht': montantHt,
        'taux_tva': tauxTva,
        if (montantTtc != null) 'montant_ttc': montantTtc,
        'statut': statut,
        if (notes != null) 'notes': notes,
      };

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v as String);
  }
}

const kTypesFacture = [
  'Eau',
  'Électricité',
  'Gaz',
  'Téléphone',
  'Internet',
  'Box TV + Internet',
  'Assurance',
  'Charges de copropriété',
  'Taxe foncière',
  'Divers',
];

const kStatutsFacture = ['Non payée', 'Payée', 'En litige'];
