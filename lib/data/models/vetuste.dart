// Modèles de la vétusté (Option B) : barème par proprietaire + décomptes
// de réparations locatives (groupés par EDL ou rattachés à un immeuble/chambre).

/// Une ligne du barème de vétusté du proprietaire, pour une catégorie de meuble.
class VetusteBaremeModel {
  final int id;
  final String ownerId;
  final String categorie;
  final int dureeVieAnnees;
  final int franchiseAnnees;
  final double coefficientAnnuel; // %/an
  final double residuelMinPct; // %

  const VetusteBaremeModel({
    required this.id,
    required this.ownerId,
    required this.categorie,
    this.dureeVieAnnees = 10,
    this.franchiseAnnees = 0,
    this.coefficientAnnuel = 10,
    this.residuelMinPct = 10,
  });

  factory VetusteBaremeModel.fromMap(Map<String, dynamic> m) => VetusteBaremeModel(
        id: (m['id'] as num).toInt(),
        ownerId: m['owner_id'] as String,
        categorie: m['categorie'] as String,
        dureeVieAnnees: (m['duree_vie_annees'] as num?)?.toInt() ?? 10,
        franchiseAnnees: (m['franchise_annees'] as num?)?.toInt() ?? 0,
        coefficientAnnuel: (m['coefficient_annuel'] as num?)?.toDouble() ?? 10,
        residuelMinPct: (m['residuel_min_pct'] as num?)?.toDouble() ?? 10,
      );

  Map<String, dynamic> toUpsert() => {
        'owner_id': ownerId,
        'categorie': categorie,
        'duree_vie_annees': dureeVieAnnees,
        'franchise_annees': franchiseAnnees,
        'coefficient_annuel': coefficientAnnuel,
        'residuel_min_pct': residuelMinPct,
      };

  VetusteBaremeModel copyWith({
    int? dureeVieAnnees,
    int? franchiseAnnees,
    double? coefficientAnnuel,
    double? residuelMinPct,
  }) =>
      VetusteBaremeModel(
        id: id,
        ownerId: ownerId,
        categorie: categorie,
        dureeVieAnnees: dureeVieAnnees ?? this.dureeVieAnnees,
        franchiseAnnees: franchiseAnnees ?? this.franchiseAnnees,
        coefficientAnnuel: coefficientAnnuel ?? this.coefficientAnnuel,
        residuelMinPct: residuelMinPct ?? this.residuelMinPct,
      );
}

/// Un décompte de réparations locatives (vétusté), rattaché à un immeuble
/// (+ chambre/locataire/EDL optionnels). Groupé par EDL dans l'onglet Vétusté.
class VetusteDecompteModel {
  final int id;
  final String ownerId;
  final int immeubleId;
  final int? chambreId;
  final String? locataireId;
  final int? etatDeLieuxId;
  final String? titre;
  final String statut; // 'brouillon' | 'genere'
  final double totalMontant;
  final int? recetteId;
  final DateTime createdAt;

  // Joints (lecture)
  final String? immeubleNom;
  final String? chambreNom;
  final String? locataireNom;
  final List<VetusteDecompteLigneModel> lignes;

  const VetusteDecompteModel({
    required this.id,
    required this.ownerId,
    required this.immeubleId,
    this.chambreId,
    this.locataireId,
    this.etatDeLieuxId,
    this.titre,
    this.statut = 'brouillon',
    this.totalMontant = 0,
    this.recetteId,
    required this.createdAt,
    this.immeubleNom,
    this.chambreNom,
    this.locataireNom,
    this.lignes = const [],
  });

  bool get isGenere => statut == 'genere';

  factory VetusteDecompteModel.fromMap(Map<String, dynamic> m) {
    final imm = m['Immeubles'] as Map<String, dynamic>?;
    final ch = m['Chambres'] as Map<String, dynamic>?;
    final loc = m['Users_Client'] as Map<String, dynamic>?;
    final rawLignes = m['vetuste_decompte_ligne'] as List?;
    return VetusteDecompteModel(
      id: (m['id'] as num).toInt(),
      ownerId: m['owner_id'] as String,
      immeubleId: (m['immeuble_id'] as num).toInt(),
      chambreId: (m['chambre_id'] as num?)?.toInt(),
      locataireId: m['locataire_id'] as String?,
      etatDeLieuxId: (m['etat_de_lieux_id'] as num?)?.toInt(),
      titre: m['titre'] as String?,
      statut: (m['statut'] as String?) ?? 'brouillon',
      totalMontant: (m['total_montant'] as num?)?.toDouble() ?? 0,
      recetteId: (m['recette_id'] as num?)?.toInt(),
      createdAt: DateTime.parse(m['created_at'] as String),
      immeubleNom: imm?['name'] as String?,
      chambreNom: ch?['room_name'] as String?,
      locataireNom: loc?['full_name'] as String?,
      lignes: rawLignes == null
          ? const []
          : rawLignes
              .map((l) => VetusteDecompteLigneModel.fromMap(
                  Map<String, dynamic>.from(l as Map)))
              .toList(),
    );
  }

  Map<String, dynamic> toInsert() => {
        'owner_id': ownerId,
        'immeuble_id': immeubleId,
        if (chambreId != null) 'chambre_id': chambreId,
        if (locataireId != null) 'locataire_id': locataireId,
        if (etatDeLieuxId != null) 'etat_de_lieux_id': etatDeLieuxId,
        if (titre != null) 'titre': titre,
        'statut': statut,
        'total_montant': totalMontant,
        if (recetteId != null) 'recette_id': recetteId,
      };
}

/// Une ligne d'un décompte : un équipement dégradé, avec sa valeur résiduelle
/// calculée (snapshot indépendant de l'inventaire).
class VetusteDecompteLigneModel {
  final int id;
  final int decompteId;
  final String equipement;
  final String? categorie;
  final double valeurAchat;
  final DateTime? dateAcquisition;
  final double ageAnnees;
  final String? etatEntree;
  final String? etatSortie;
  final double abattementPct;
  final double valeurResiduelle;
  final bool imputable;
  final String? notes;
  final int ordre;

  const VetusteDecompteLigneModel({
    required this.id,
    required this.decompteId,
    required this.equipement,
    this.categorie,
    this.valeurAchat = 0,
    this.dateAcquisition,
    this.ageAnnees = 0,
    this.etatEntree,
    this.etatSortie,
    this.abattementPct = 0,
    this.valeurResiduelle = 0,
    this.imputable = true,
    this.notes,
    this.ordre = 0,
  });

  factory VetusteDecompteLigneModel.fromMap(Map<String, dynamic> m) =>
      VetusteDecompteLigneModel(
        id: (m['id'] as num).toInt(),
        decompteId: (m['decompte_id'] as num).toInt(),
        equipement: (m['equipement'] as String?) ?? '',
        categorie: m['categorie'] as String?,
        valeurAchat: (m['valeur_achat'] as num?)?.toDouble() ?? 0,
        dateAcquisition: m['date_acquisition'] != null
            ? DateTime.parse(m['date_acquisition'] as String)
            : null,
        ageAnnees: (m['age_annees'] as num?)?.toDouble() ?? 0,
        etatEntree: m['etat_entree'] as String?,
        etatSortie: m['etat_sortie'] as String?,
        abattementPct: (m['abattement_pct'] as num?)?.toDouble() ?? 0,
        valeurResiduelle: (m['valeur_residuelle'] as num?)?.toDouble() ?? 0,
        imputable: (m['imputable'] as bool?) ?? true,
        notes: m['notes'] as String?,
        ordre: (m['ordre'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toInsert() => {
        'decompte_id': decompteId,
        'equipement': equipement,
        if (categorie != null) 'categorie': categorie,
        'valeur_achat': valeurAchat,
        'date_acquisition': dateAcquisition?.toIso8601String(),
        'age_annees': ageAnnees,
        if (etatEntree != null) 'etat_entree': etatEntree,
        if (etatSortie != null) 'etat_sortie': etatSortie,
        'abattement_pct': abattementPct,
        'valeur_residuelle': valeurResiduelle,
        'imputable': imputable,
        if (notes != null) 'notes': notes,
        'ordre': ordre,
      };

  VetusteDecompteLigneModel copyWith({
    String? categorie,
    double? valeurAchat,
    DateTime? dateAcquisition,
    double? ageAnnees,
    double? abattementPct,
    double? valeurResiduelle,
    bool? imputable,
    String? notes,
  }) =>
      VetusteDecompteLigneModel(
        id: id,
        decompteId: decompteId,
        equipement: equipement,
        categorie: categorie ?? this.categorie,
        valeurAchat: valeurAchat ?? this.valeurAchat,
        dateAcquisition: dateAcquisition ?? this.dateAcquisition,
        ageAnnees: ageAnnees ?? this.ageAnnees,
        etatEntree: etatEntree,
        etatSortie: etatSortie,
        abattementPct: abattementPct ?? this.abattementPct,
        valeurResiduelle: valeurResiduelle ?? this.valeurResiduelle,
        imputable: imputable ?? this.imputable,
        notes: notes ?? this.notes,
        ordre: ordre,
      );
}
