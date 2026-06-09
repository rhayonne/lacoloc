import 'package:intl/intl.dart';

class ObservationEdl {
  final int? id;
  final int etatDesLieuxId;
  final String? wallKey; // null = observation générale
  final int? pieceId; // EDL collectif : observation rattachée à une pièce
  final int? chambreId; // EDL collectif : observation rattachée à une chambre
  final String? description;
  final List<String> photos;
  final DateTime? createdAt;
  // 'proprietaire' | 'locataire' (null = proprietaire/legado). Define o autor
  // da observação — usado para o selo "Ajouté par le locataire".
  final String? authorRole;
  // Ajout (« addition ») fait APRÈS finalisation, dans la fenêtre d'1 mois.
  // Sa date/heure (createdAt) est enregistrée automatiquement.
  final bool isAddition;

  const ObservationEdl({
    this.id,
    required this.etatDesLieuxId,
    this.wallKey,
    this.pieceId,
    this.chambreId,
    this.description,
    this.photos = const [],
    this.createdAt,
    this.authorRole,
    this.isAddition = false,
  });

  static final _stampFmt = DateFormat("dd/MM/yyyy 'à' HH:mm", 'fr');

  bool get hasContent =>
      (description != null && description!.isNotEmpty) || photos.isNotEmpty;

  bool get isLocataire => authorRole == 'locataire';

  /// Date + heure de l'ajout (« Ajouté le 06/06/2026 à 14:30 »).
  String? get createdAtLabel =>
      createdAt != null ? _stampFmt.format(createdAt!.toLocal()) : null;

  String get wallLabel => switch (wallKey) {
    'fond'    => 'Mur du fond',
    'gauche'  => 'Mur gauche',
    'droit'   => 'Mur droit',
    'porte'   => "Mur d'entrée / Porte",
    'sol'     => 'Sol',
    'plafond' => 'Plafond',
    _         => 'Général',
  };

  factory ObservationEdl.fromMap(Map<String, dynamic> map) => ObservationEdl(
    id: map['id'] as int?,
    etatDesLieuxId: map['etat_de_lieux_id'] as int,
    wallKey: map['wall_key'] as String?,
    pieceId: map['piece_id'] as int?,
    chambreId: map['chambre_id'] as int?,
    description: map['description'] as String?,
    photos: (map['photos'] as List?)?.cast<String>() ?? [],
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at'] as String)
        : null,
    authorRole: map['author_role'] as String?,
    isAddition: (map['is_addition'] as bool?) ?? false,
  );

  Map<String, dynamic> toInsert() => {
    'etat_de_lieux_id': etatDesLieuxId,
    if (wallKey != null) 'wall_key': wallKey,
    if (pieceId != null) 'piece_id': pieceId,
    if (chambreId != null) 'chambre_id': chambreId,
    if (description != null && description!.isNotEmpty) 'description': description,
    'photos': photos,
    if (authorRole != null) 'author_role': authorRole,
    'is_addition': isAddition,
  };
}
