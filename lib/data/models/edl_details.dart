// Modelos das tabelas filhas do état des lieux completo:
//  • etat_de_lieux_preneurs   → EdlPreneur
//  • etat_de_lieux_releves    → EdlReleve (compteurs, chauffage, eau chaude)
//  • etat_de_lieux_cles       → EdlCle    (remise des clés)
//  • etat_de_lieux_sections   → EdlSection (pièce do documento)
//  • etat_de_lieux_lignes     → EdlLigne   (linha de equipamento)
//
// Convenção `etat_d'usure`: N (neuf), B (bon état), U (état d'usage), M (mauvais).

/// Estados de usura possíveis (coluna `etat_usure`).
const kEtatsUsure = <String>['N', 'B', 'U', 'M'];

String etatUsureLabel(String? code) => switch (code) {
  'N' => 'Neuf',
  'B' => 'Bon état',
  'U' => "État d'usage",
  'M' => 'Mauvais état',
  _ => '—',
};

// ─────────────────────────────────────────────────────────────────────────────

class EdlPreneur {
  final int? id;
  final int etatDesLieuxId;
  final String? locataireId;
  final String? nom;
  final String? adresse;
  final int ordre;
  // Campo local preenchido via join — não persiste no DB
  final String? email;

  const EdlPreneur({
    this.id,
    required this.etatDesLieuxId,
    this.locataireId,
    this.nom,
    this.adresse,
    this.ordre = 0,
    this.email,
  });

  factory EdlPreneur.fromMap(Map<String, dynamic> m) {
    final loc = m['locataire'] as Map<String, dynamic>?;
    return EdlPreneur(
      id: m['id'] as int?,
      etatDesLieuxId: m['etat_de_lieux_id'] as int,
      locataireId: m['locataire_id'] as String?,
      nom: m['nom'] as String?,
      adresse: m['adresse'] as String?,
      ordre: (m['ordre'] as num?)?.toInt() ?? 0,
      email: loc?['email'] as String?,
    );
  }

  Map<String, dynamic> toInsert() => {
    'etat_de_lieux_id': etatDesLieuxId,
    if (locataireId != null) 'locataire_id': locataireId,
    if (nom != null && nom!.isNotEmpty) 'nom': nom,
    if (adresse != null && adresse!.isNotEmpty) 'adresse': adresse,
    'ordre': ordre,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

enum ReleveCategorie {
  eauGaz,
  electrique,
  chauffage,
  eauChaude;

  String get raw => switch (this) {
    ReleveCategorie.eauGaz => 'eau_gaz',
    ReleveCategorie.electrique => 'electrique',
    ReleveCategorie.chauffage => 'chauffage',
    ReleveCategorie.eauChaude => 'eau_chaude',
  };

  String get label => switch (this) {
    ReleveCategorie.eauGaz => 'Relevés des compteurs eau, gaz…',
    ReleveCategorie.electrique => 'Relevé compteur électrique',
    ReleveCategorie.chauffage => 'Type de chauffage',
    ReleveCategorie.eauChaude => "Production d'eau chaude",
  };

  static ReleveCategorie fromRaw(String? raw) => switch (raw) {
    'electrique' => ReleveCategorie.electrique,
    'chauffage' => ReleveCategorie.chauffage,
    'eau_chaude' => ReleveCategorie.eauChaude,
    _ => ReleveCategorie.eauGaz,
  };
}

class EdlReleve {
  final int? id;
  final int etatDesLieuxId;
  final ReleveCategorie categorie;
  final String? type;
  final String? numeroSerie;
  final double? valeurIndex;
  final String? unite; // 'M3' | 'KW'
  final String? etatUsure;
  final String? fonctionnement;
  final String? observations;
  final int ordre;

  const EdlReleve({
    this.id,
    required this.etatDesLieuxId,
    required this.categorie,
    this.type,
    this.numeroSerie,
    this.valeurIndex,
    this.unite,
    this.etatUsure,
    this.fonctionnement,
    this.observations,
    this.ordre = 0,
  });

  factory EdlReleve.fromMap(Map<String, dynamic> m) => EdlReleve(
    id: m['id'] as int?,
    etatDesLieuxId: m['etat_de_lieux_id'] as int,
    categorie: ReleveCategorie.fromRaw(m['categorie'] as String?),
    type: m['type'] as String?,
    numeroSerie: m['numero_serie'] as String?,
    valeurIndex: (m['valeur_index'] as num?)?.toDouble(),
    unite: m['unite'] as String?,
    etatUsure: m['etat_usure'] as String?,
    fonctionnement: m['fonctionnement'] as String?,
    observations: m['observations'] as String?,
    ordre: (m['ordre'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toInsert() => {
    'etat_de_lieux_id': etatDesLieuxId,
    'categorie': categorie.raw,
    if (type != null && type!.isNotEmpty) 'type': type,
    if (numeroSerie != null && numeroSerie!.isNotEmpty) 'numero_serie': numeroSerie,
    if (valeurIndex != null) 'valeur_index': valeurIndex,
    if (unite != null && unite!.isNotEmpty) 'unite': unite,
    if (etatUsure != null && etatUsure!.isNotEmpty) 'etat_usure': etatUsure,
    if (fonctionnement != null && fonctionnement!.isNotEmpty)
      'fonctionnement': fonctionnement,
    if (observations != null && observations!.isNotEmpty)
      'observations': observations,
    'ordre': ordre,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

class EdlCle {
  final int? id;
  final int etatDesLieuxId;
  final String typeCle;
  final int? nombre;
  final bool remiseCeJour;
  final DateTime? dateRemise;
  final String? commentaire;
  final int ordre;

  const EdlCle({
    this.id,
    required this.etatDesLieuxId,
    required this.typeCle,
    this.nombre,
    this.remiseCeJour = false,
    this.dateRemise,
    this.commentaire,
    this.ordre = 0,
  });

  factory EdlCle.fromMap(Map<String, dynamic> m) => EdlCle(
    id: m['id'] as int?,
    etatDesLieuxId: m['etat_de_lieux_id'] as int,
    typeCle: m['type_cle'] as String,
    nombre: (m['nombre'] as num?)?.toInt(),
    remiseCeJour: (m['remise_ce_jour'] as bool?) ?? false,
    dateRemise: m['date_remise'] != null
        ? DateTime.parse(m['date_remise'] as String)
        : null,
    commentaire: m['commentaire'] as String?,
    ordre: (m['ordre'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toInsert() => {
    'etat_de_lieux_id': etatDesLieuxId,
    'type_cle': typeCle,
    if (nombre != null) 'nombre': nombre,
    'remise_ce_jour': remiseCeJour,
    if (dateRemise != null)
      'date_remise': dateRemise!.toIso8601String().substring(0, 10),
    if (commentaire != null && commentaire!.isNotEmpty) 'commentaire': commentaire,
    'ordre': ordre,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

class EdlLigne {
  final int? id;
  final int sectionId;
  final String equipement;
  final String? natureNombre;
  final String? etatUsure;
  final String? fonctionnement;
  final String? commentaires;
  final int ordre;

  const EdlLigne({
    this.id,
    required this.sectionId,
    required this.equipement,
    this.natureNombre,
    this.etatUsure,
    this.fonctionnement,
    this.commentaires,
    this.ordre = 0,
  });

  factory EdlLigne.fromMap(Map<String, dynamic> m) => EdlLigne(
    id: m['id'] as int?,
    sectionId: m['section_id'] as int,
    equipement: m['equipement'] as String,
    natureNombre: m['nature_nombre'] as String?,
    etatUsure: m['etat_usure'] as String?,
    fonctionnement: m['fonctionnement'] as String?,
    commentaires: m['commentaires'] as String?,
    ordre: (m['ordre'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toInsert() => {
    'section_id': sectionId,
    'equipement': equipement,
    if (natureNombre != null && natureNombre!.isNotEmpty)
      'nature_nombre': natureNombre,
    if (etatUsure != null && etatUsure!.isNotEmpty) 'etat_usure': etatUsure,
    if (fonctionnement != null && fonctionnement!.isNotEmpty)
      'fonctionnement': fonctionnement,
    if (commentaires != null && commentaires!.isNotEmpty)
      'commentaires': commentaires,
    'ordre': ordre,
  };

  EdlLigne copyWith({
    String? equipement,
    String? natureNombre,
    String? etatUsure,
    String? fonctionnement,
    String? commentaires,
    int? ordre,
  }) => EdlLigne(
    id: id,
    sectionId: sectionId,
    equipement: equipement ?? this.equipement,
    natureNombre: natureNombre ?? this.natureNombre,
    etatUsure: etatUsure ?? this.etatUsure,
    fonctionnement: fonctionnement ?? this.fonctionnement,
    commentaires: commentaires ?? this.commentaires,
    ordre: ordre ?? this.ordre,
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class EdlSection {
  final int? id;
  final int etatDesLieuxId;
  final String nom;
  final int ordre;
  final String? commentaireGlobal;
  final List<EdlLigne> lignes;

  const EdlSection({
    this.id,
    required this.etatDesLieuxId,
    required this.nom,
    this.ordre = 0,
    this.commentaireGlobal,
    this.lignes = const [],
  });

  factory EdlSection.fromMap(Map<String, dynamic> m) {
    final rawLignes = m['etat_de_lieux_lignes'] ?? m['lignes'];
    final lignes = rawLignes is List
        ? rawLignes
              .cast<Map<String, dynamic>>()
              .map(EdlLigne.fromMap)
              .toList()
        : <EdlLigne>[];
    lignes.sort((a, b) => a.ordre.compareTo(b.ordre));
    return EdlSection(
      id: m['id'] as int?,
      etatDesLieuxId: m['etat_de_lieux_id'] as int,
      nom: m['nom'] as String,
      ordre: (m['ordre'] as num?)?.toInt() ?? 0,
      commentaireGlobal: m['commentaire_global'] as String?,
      lignes: lignes,
    );
  }

  Map<String, dynamic> toInsert() => {
    'etat_de_lieux_id': etatDesLieuxId,
    'nom': nom,
    'ordre': ordre,
    if (commentaireGlobal != null && commentaireGlobal!.isNotEmpty)
      'commentaire_global': commentaireGlobal,
  };
}
