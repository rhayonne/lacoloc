import 'package:intl/intl.dart';

class RecetteModel {
  final int id;
  final String ownerId;
  final String? locataireId;
  final int? edlId;
  final int? immeubleId;
  final int? chambreId;
  final double montant;
  final DateTime dateEcheance;
  final DateTime? datePaiement;

  /// 'a_recevoir' | 'recu' | 'en_retard'
  final String statut;
  final String? notes;
  final DateTime createdAt;

  // Champs joints (lecture seule)
  final String? immeubleNom;
  final String? chambreNom;
  final String? locataireNom;

  const RecetteModel({
    required this.id,
    required this.ownerId,
    this.locataireId,
    this.edlId,
    this.immeubleId,
    this.chambreId,
    required this.montant,
    required this.dateEcheance,
    this.datePaiement,
    this.statut = 'a_recevoir',
    this.notes,
    required this.createdAt,
    this.immeubleNom,
    this.chambreNom,
    this.locataireNom,
  });

  static final _fmt = DateFormat('MMMM yyyy', 'fr_FR');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  String get moisLabel => _fmt.format(dateEcheance);
  String get echeanceLabel => _dateFmt.format(dateEcheance);
  String? get paiementLabel =>
      datePaiement != null ? _dateFmt.format(datePaiement!) : null;
  bool get isPaid => statut == 'recu';
  bool get isLate => statut == 'en_retard';
  String get lieuLabel =>
      [immeubleNom, chambreNom].whereType<String>().join(' · ');

  factory RecetteModel.fromMap(Map<String, dynamic> m) {
    final imm = m['Immeubles'] as Map<String, dynamic>?;
    final ch = m['Chambres'] as Map<String, dynamic>?;
    final loc = m['Users_Client'] as Map<String, dynamic>?;
    return RecetteModel(
      id: m['id'] as int,
      ownerId: m['owner_id'] as String,
      locataireId: m['locataire_id'] as String?,
      edlId: m['etat_de_lieux_id'] as int?,
      immeubleId: m['immeuble_id'] as int?,
      chambreId: m['chambre_id'] as int?,
      montant: (m['montant'] as num).toDouble(),
      dateEcheance: DateTime.parse(m['date_echeance'] as String),
      datePaiement: m['date_paiement'] != null
          ? DateTime.parse(m['date_paiement'] as String)
          : null,
      statut: m['statut'] as String? ?? 'a_recevoir',
      notes: m['notes'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      immeubleNom: imm?['name'] as String?,
      chambreNom: ch?['room_name'] as String?,
      locataireNom: loc?['full_name'] as String?,
    );
  }

  RecetteModel copyWith({
    String? statut,
    DateTime? datePaiement,
    bool clearPaiement = false,
  }) {
    return RecetteModel(
      id: id,
      ownerId: ownerId,
      locataireId: locataireId,
      edlId: edlId,
      immeubleId: immeubleId,
      chambreId: chambreId,
      montant: montant,
      dateEcheance: dateEcheance,
      datePaiement: clearPaiement ? null : (datePaiement ?? this.datePaiement),
      statut: statut ?? this.statut,
      notes: notes,
      createdAt: createdAt,
      immeubleNom: immeubleNom,
      chambreNom: chambreNom,
      locataireNom: locataireNom,
    );
  }
}
