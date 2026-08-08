import 'dart:math' as math;
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:habitafrance/data/datasources/storage_service.dart';
import 'package:habitafrance/data/models/edl_details.dart';
import 'package:habitafrance/data/models/observation_edl.dart';
import 'edl_pdf_data.dart';
import 'signature_proof.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette & typographie

final _primary = PdfColor.fromHex('006685');
final _primaryLight = PdfColor.fromHex('E0F2F8');
final _accent = PdfColor.fromHex('F59E0B');
final _accentLight = PdfColor.fromHex('FEF3C7');
final _grey = PdfColor.fromHex('6B7280');
final _red = PdfColor.fromHex('DC2626');
final _green = PdfColor.fromHex('16A34A');
final _white = PdfColors.white;
// Bordure de tableau fine et discrète (look moderne).
final _border = PdfColor.fromHex('D1D5DB');
final _tableBorder = pw.TableBorder.all(color: _border, width: 0.4);

const _dateFmt = 'dd/MM/yyyy';

// ─────────────────────────────────────────────────────────────────────────────

Future<pw.Document> buildEdlPdf(
  EdlPdfData fullData, {
  EdlPdfMode mode = EdlPdfMode.sortieSeul,
  EdlPdfScope scope = EdlPdfScope.complet,
}) async {
  // Police Unicode (les polices PDF par défaut — Helvetica — ne savent pas
  // dessiner « — » (U+2014), « € », etc.). On charge Noto Sans (Google Fonts).
  final theme = pw.ThemeData.withFont(
    base: await PdfGoogleFonts.notoSansRegular(),
    bold: await PdfGoogleFonts.notoSansBold(),
    italic: await PdfGoogleFonts.notoSansItalic(),
  );

  // Portée (bail individuel : complet / communes / chambre).
  final data = fullData.scoped(scope);

  // Contrepoint actif uniquement si demandé ET qu'une entrée est couplée.
  final contrepoint = mode == EdlPdfMode.contrepoint && data.hasEntree;

  // Télécharger les images de signature (best-effort : null si indisponible).
  final edl = data.edl;
  final sigResults = await Future.wait([
    _fetchImageBytes(edl.proprietaireSignatureUrl),
    _fetchImageBytes(edl.locataireSignatureUrl),
  ]);
  final propSigBytes = sigResults[0];
  final locSigBytes = sigResults[1];

  final doc = pw.Document(
    title: _ascii('Etat des lieux - ${edl.lieuLabel}'),
    author: _ascii(edl.proprietaireNom ?? 'Proprietaire'),
  );

  doc.addPage(
    pw.MultiPage(
      pageTheme: _pageTheme(theme, watermark: !data.isFinalise),
      build: (ctx) => _buildContent(
        data,
        contrepoint: contrepoint,
        propSigBytes: propSigBytes,
        locSigBytes: locSigBytes,
      ),
    ),
  );

  return doc;
}

/// Télécharge les bytes d'une image, qu'elle soit privée (`doc:` → URL signée
/// / download RLS) ou une URL publique. Retourne null en cas d'erreur ou si la
/// référence est nulle.
Future<Uint8List?> _fetchImageBytes(String? ref) async {
  if (ref == null) return null;
  return StorageService.downloadBytes(ref);
}

/// Remplace les caractères hors Latin-1 par leur équivalent ASCII.
/// Nécessaire uniquement pour les métadonnées du PDF (titre, auteur), qui sont
/// encodées en Latin-1 indépendamment de la police.
String _ascii(String s) => s
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('’', "'")
    .replaceAll('‘', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('…', '...');

// ─────────────────────────────────────────────────────────────────────────────
// Mise en page globale

pw.PageTheme _pageTheme(pw.ThemeData theme, {bool watermark = false}) =>
    pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      buildBackground: (ctx) =>
          pw.FullPage(ignoreMargins: true, child: pw.Container(color: _white)),
      buildForeground: watermark ? _buildWatermark : null,
    );

pw.Widget _buildWatermark(pw.Context ctx) => pw.FullPage(
  ignoreMargins: true,
  child: pw.Center(
    child: pw.Transform.rotate(
      angle: -math.pi / 6,
      child: pw.Opacity(
        opacity: 0.12,
        child: pw.Text(
          'APERÇU\nNON FINALISÉ',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 64,
            fontWeight: pw.FontWeight.bold,
            color: _red,
          ),
        ),
      ),
    ),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Sections de contenu
//
// IMPORTANT (pagination) : les sections longues (composition, observations,
// additions, relevés) sont émises comme widgets de **premier niveau** dans la
// liste de `MultiPage` — les `pw.Table` se répartissent automatiquement sur
// plusieurs pages. Un `Container` avec bordure est atomique : on ne l'utilise
// que pour les sections courtes (Bien, Signatures).

List<pw.Widget> _buildContent(
  EdlPdfData data, {
  bool contrepoint = false,
  Uint8List? propSigBytes,
  Uint8List? locSigBytes,
}) => [
  _header(data),
  pw.SizedBox(height: 12),
  _sectionBien(data),
  if (data.preneurs.isNotEmpty) ...[
    pw.SizedBox(height: 12),
    ..._sectionPreneurs(data.preneurs),
  ],
  if (data.releves.isNotEmpty) ...[
    pw.SizedBox(height: 12),
    ..._sectionReleves(data.releves),
  ],
  if (data.cles.isNotEmpty) ...[
    pw.SizedBox(height: 12),
    ..._sectionCles(data.cles),
  ],
  // « État des pièces et chambres » : visible s'il y a des sections OU (hors
  // contrepoint) des observations rattachées à une pièce/chambre sans section
  // (cas non meublée : pas d'inventaire → pas de sections, mais des obs).
  if (data.sections.isNotEmpty ||
      (!contrepoint && _extraRoomObservations(data).isNotEmpty)) ...[
    pw.SizedBox(height: 12),
    // En contrepoint, les observations passent dans la table comparative
    // dédiée → pas de doublon sous chaque pièce.
    ..._sectionComposition(data, withObservations: !contrepoint),
  ],
  // Observations : en contrepoint, on compare entrée vs sortie ; sinon, les
  // observations rattachées à une pièce/chambre sont déjà sous leur section ;
  // on n'affiche ici que les « orphelines » (sans pièce/chambre identifiée).
  if (contrepoint && data.entree != null) ...[
    pw.SizedBox(height: 12),
    ..._sectionObservationsContrepoint(
      data.entree!.observations,
      data.observations,
    ),
  ] else ...[
    for (final orphans in [_orphanObservations(data)])
      if (orphans.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        ..._sectionObservations(orphans),
      ],
  ],
  if (_diversObservations(data).isNotEmpty) ...[
    pw.SizedBox(height: 12),
    ..._sectionDivers(_diversObservations(data)),
  ],
  if (data.additions.isNotEmpty) ...[
    pw.SizedBox(height: 12),
    ..._sectionAdditions(data.additions),
  ],
  pw.SizedBox(height: 16),
  _sectionSignatures(data, propSigBytes: propSigBytes, locSigBytes: locSigBytes),
  _sectionProof(data),
];

// Cachet de preuve de signature électronique (faisceau d'indices).
pw.Widget _sectionProof(EdlPdfData data) {
  final edl = data.edl;
  final base = pw.TextStyle(fontSize: 9);
  final bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
  return buildSignatureProofBlock(
    base: base,
    bold: bold,
    signers: [
      ProofSigner(
        role: 'Le bailleur',
        name: edl.bailleurNom ?? edl.proprietaireNom,
        signedAt: edl.proprietaireSignedAtFormatted,
      ),
      ProofSigner(
        role: 'Le(s) locataire(s)',
        name: data.preneurs.isNotEmpty
            ? data.preneurs.map((p) => p.nom ?? '—').join(', ')
            : edl.locataireNom,
        signedAt: edl.locataireSignedAtFormatted,
      ),
    ],
    fingerprint: integrityFingerprint([
      'EDL',
      edl.id,
      edl.typeEdl,
      edl.partie,
      edl.bailleurNom ?? edl.proprietaireNom,
      for (final p in data.preneurs) p.nom,
      edl.locataireNom,
      edl.proprietaireSignatureUrl,
      edl.locataireSignatureUrl,
      edl.proprietaireSignedAtFormatted,
      edl.locataireSignedAtFormatted,
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// En-tête

pw.Widget _header(EdlPdfData data) {
  final edl = data.edl;
  final sens = edl.typeEdl == 'sortie' ? 'SORTIE' : 'ENTRÉE';
  final bail =
      edl.typeBail == 'location' ? 'Location' : 'Bail individuel (Colocation)';
  final partie = edl.partie.label;
  final meuble = edl.immeubleMeuble ? 'Meublée' : 'Non meublée';

  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _primary,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ÉTAT DES LIEUX — $sens',
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                edl.lieuLabel,
                style: pw.TextStyle(color: _primaryLight, fontSize: 11),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '$bail · $partie · $meuble',
                style: pw.TextStyle(color: _primaryLight, fontSize: 10),
              ),
              if (edl.code != null && edl.code!.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Réf. : ${edl.code}',
                  style: pw.TextStyle(
                    color: _white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _pill(edl.situation.label, data.isFinalise ? _green : _accent),
            pw.SizedBox(height: 6),
            pw.Text(
              'Date : ${DateFormat(_dateFmt).format(edl.dateEtatLieux)}',
              style: pw.TextStyle(color: _white, fontSize: 10),
            ),
            if (edl.dateFinalisation != null)
              pw.Text(
                'Finalisé : ${DateFormat(_dateFmt).format(edl.dateFinalisation!)}',
                style: pw.TextStyle(color: _primaryLight, fontSize: 10),
              ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _pill(String label, PdfColor color) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: pw.BoxDecoration(
    color: color,
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
  ),
  child: pw.Text(
    label,
    style: pw.TextStyle(
      color: _white,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    ),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Section BIEN (courte → card atomique)

pw.Widget _sectionBien(EdlPdfData data) {
  final edl = data.edl;
  final rows = <(String, String?)>[
    ('Désignation', edl.designation),
    ('Surface', edl.surfaceM2 != null ? '${edl.surfaceM2} m²' : null),
    ('Étage', edl.etage),
    ('Nb pièces principales', edl.nombrePiecesPrincipales?.toString()),
    ('Adresse', edl.immeubleAdresse),
    ('Bailleur', edl.bailleurNom),
    ('Adresse bailleur', edl.bailleurAdresse),
    if (edl.typeEdl == 'sortie') ('Nouvelle adresse', edl.nouvelleAdresse),
    ('Lieu de rédaction', edl.lieuRedaction),
    ('Nb exemplaires', edl.nombreExemplaires),
  ];
  final filled = rows.where((r) => r.$2 != null && r.$2!.isNotEmpty).toList();
  if (filled.isEmpty) return pw.SizedBox.shrink();

  return _card(
    title: 'LE BIEN',
    child: pw.Wrap(
      spacing: 12,
      runSpacing: 4,
      children: filled.map((r) => _labelValue(r.$1, r.$2!)).toList(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section PRENEURS (table → flottante)

List<pw.Widget> _sectionPreneurs(List<EdlPreneur> preneurs) => [
  _titleBar('LOCATAIRES / PRENEURS'),
  pw.SizedBox(height: 4),
  pw.Table(
    border: _tableBorder,
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(3),
    },
    children: [
      _tableHeaderRow(['Nom', 'Adresse']),
      ...preneurs.map((p) => _tableDataRow([p.nom ?? '—', p.adresse ?? '—'])),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Section RELEVÉS (tables → flottantes)

List<pw.Widget> _sectionReleves(List<EdlReleve> releves) {
  final byCategorie = <ReleveCategorie, List<EdlReleve>>{};
  for (final r in releves) {
    byCategorie.putIfAbsent(r.categorie, () => []).add(r);
  }

  return [
    _titleBar('RELEVÉS'),
    pw.SizedBox(height: 4),
    for (final entry in byCategorie.entries) ...[
      pw.Text(
        entry.key.label,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _primary,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Table(
        border: _tableBorder,
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1.5),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(2),
        },
        children: [
          _tableHeaderRow([
            'Type',
            'N° série',
            'Index',
            'Unité',
            'Observations',
          ]),
          ...entry.value.map(
            (r) => _tableDataRow([
              r.type ?? '—',
              r.numeroSerie ?? '—',
              r.valeurIndex?.toString() ?? '—',
              r.unite ?? '—',
              r.observations ?? '—',
            ]),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
    ],
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Section CLÉS (table → flottante)

List<pw.Widget> _sectionCles(List<EdlCle> cles) => [
  _titleBar('REMISE DES CLÉS'),
  pw.SizedBox(height: 4),
  pw.Table(
    border: _tableBorder,
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(1),
      2: const pw.FlexColumnWidth(1.5),
      3: const pw.FlexColumnWidth(3),
    },
    children: [
      _tableHeaderRow(['Type', 'Nombre', 'Remis ce jour', 'Commentaire']),
      ...cles.map(
        (c) => _tableDataRow([
          c.typeCle,
          c.nombre?.toString() ?? '—',
          c.remiseCeJour ? 'Oui' : 'Non',
          c.commentaire ?? '—',
        ]),
      ),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Section COMPOSITION (sections + lignes) — flottante

List<pw.Widget> _sectionComposition(
  EdlPdfData data, {
  bool withObservations = true,
}) => [
  _titleBar('ÉTAT DES PIÈCES ET CHAMBRES'),
  pw.SizedBox(height: 4),
  for (final section in data.sections) ...[
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _primaryLight,
      child: pw.Text(
        section.nom,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: _primary,
        ),
      ),
    ),
    if (section.commentaireGlobal != null &&
        section.commentaireGlobal!.isNotEmpty)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, left: 8),
        child: pw.Text(
          section.commentaireGlobal!,
          style: pw.TextStyle(fontSize: 8, color: _grey),
        ),
      ),
    if (section.lignes.isNotEmpty) ...[
      pw.SizedBox(height: 4),
      pw.Table(
        border: _tableBorder,
        columnWidths: {
          0: const pw.FlexColumnWidth(2.5),
          1: const pw.FlexColumnWidth(1.5),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1.5),
          4: const pw.FlexColumnWidth(3),
        },
        children: [
          _tableHeaderRow([
            'Équipement',
            'Nombre/Nature',
            'État',
            'Fonctionnement',
            'Observations',
          ]),
          ...section.lignes.map(
            (l) => _tableDataRow([
              l.equipement,
              l.natureNombre ?? '—',
              etatUsureLabel(l.etatUsure),
              l.fonctionnement ?? '—',
              l.commentaires ?? '—',
            ]),
          ),
        ],
      ),
    ],
    // Observations rattachées à cette pièce/chambre (par nom).
    if (withObservations) ..._observationsForSection(section, data),
    pw.SizedBox(height: 8),
  ],
  // Pièces/chambres ayant des observations mais aucune section (non meublée :
  // pas d'inventaire → pas de sections). On les affiche quand même ici, groupées.
  if (withObservations)
    for (final entry in _extraRoomObservations(data)) ...[
      _roomObservationBlock(entry.key, entry.value),
      pw.SizedBox(height: 8),
    ],
];

/// Pièces/chambres qui ont des observations mais AUCUNE section de composition.
/// Groupées par nom de pièce/chambre, dans l'ordre de rencontre.
List<MapEntry<String, List<ObservationEdl>>> _extraRoomObservations(
  EdlPdfData data,
) {
  final sectionNames =
      data.sections.map((s) => s.nom.trim().toLowerCase()).toSet();
  final byRoom = <String, List<ObservationEdl>>{};
  for (final o in data.observations) {
    if (!o.hasContent) continue;
    final name = _obsRoomName(o, data)?.trim();
    if (name == null || name.isEmpty) continue; // vraie orpheline
    if (sectionNames.contains(name.toLowerCase())) continue; // déjà sous section
    byRoom.putIfAbsent(name, () => []).add(o);
  }
  return byRoom.entries.toList();
}

/// Bloc « pièce/chambre » (titre + observations par mur), même style que l'en-tête
/// d'une section de composition. Utilisé pour les pièces sans section.
pw.Widget _roomObservationBlock(String roomName, List<ObservationEdl> obs) {
  final byWall = <String, List<ObservationEdl>>{};
  for (final o in obs) {
    byWall.putIfAbsent(o.wallLabel, () => []).add(o);
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: _primaryLight,
        child: pw.Text(
          roomName,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
            color: _primary,
          ),
        ),
      ),
      pw.SizedBox(height: 4),
      for (final entry in byWall.entries)
        ...entry.value.map((o) => _observationRow(o, prefix: entry.key)),
    ],
  );
}

/// Nom de la pièce/chambre d'une observation (via piece_id/chambre_id).
String? _obsRoomName(ObservationEdl o, EdlPdfData data) => o.pieceId != null
    ? data.pieceNames[o.pieceId]
    : o.chambreId != null
    ? data.chambreNames[o.chambreId]
    : null;

/// Observations « orphelines » : uniquement celles SANS pièce/chambre
/// identifiable. Celles rattachées à une pièce/chambre sont rendues sous leur
/// bloc dans « État des pièces et chambres » (section existante ou bloc dédié).
List<ObservationEdl> _orphanObservations(EdlPdfData data) {
  return data.observations.where((o) {
    if (!o.hasContent) return false;
    if (o.isDivers) return false; // rendues dans la section « DIVERS »
    final n = _obsRoomName(o, data)?.trim();
    return n == null || n.isEmpty;
  }).toList();
}

/// Observations libres « Divers » (wall_key = 'divers'), avec contenu.
List<ObservationEdl> _diversObservations(EdlPdfData data) =>
    data.observations.where((o) => o.isDivers && o.hasContent).toList();

/// Observations dont la pièce/chambre (via piece_id/chambre_id → nom) correspond
/// au nom de la section. Rendues juste sous la table de la section.
List<pw.Widget> _observationsForSection(EdlSection section, EdlPdfData data) {
  final wantName = section.nom.trim().toLowerCase();
  String? roomName(ObservationEdl o) => o.pieceId != null
      ? data.pieceNames[o.pieceId]
      : o.chambreId != null
      ? data.chambreNames[o.chambreId]
      : null;
  final obs = data.observations
      .where(
        (o) =>
            o.hasContent &&
            (roomName(o)?.trim().toLowerCase() ?? '') == wantName,
      )
      .toList();
  if (obs.isEmpty) return const [];

  // Groupe par mur.
  final byWall = <String, List<ObservationEdl>>{};
  for (final o in obs) {
    byWall.putIfAbsent(o.wallLabel, () => []).add(o);
  }
  return [
    pw.SizedBox(height: 4),
    // Barra lateral primária + recuo: mostra visualmente que estas observações
    // pertencem à secção/chambre imediatamente acima.
    pw.Container(
      margin: const pw.EdgeInsets.only(left: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: _primary, width: 2),
        ),
      ),
      padding: const pw.EdgeInsets.only(left: 8, top: 4, bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Observations',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          pw.SizedBox(height: 2),
          for (final entry in byWall.entries)
            ...entry.value.map((o) => _observationRow(o, prefix: entry.key)),
        ],
      ),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Section DIVERS (observations libres) — flottante

List<pw.Widget> _sectionDivers(List<ObservationEdl> observations) {
  final list = observations.where((o) => o.hasContent).toList();
  if (list.isEmpty) return const [];
  return [
    _titleBar('DIVERS'),
    pw.SizedBox(height: 4),
    ...list.map((o) => _observationRow(o)),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Section OBSERVATIONS (plan 2D — murales) — flottante

List<pw.Widget> _sectionObservations(List<ObservationEdl> observations) {
  final byWall = <String, List<ObservationEdl>>{};
  for (final o in observations.where((o) => o.hasContent)) {
    byWall.putIfAbsent(o.wallLabel, () => []).add(o);
  }
  if (byWall.isEmpty) return const [];

  return [
    _titleBar('OBSERVATIONS'),
    pw.SizedBox(height: 4),
    for (final entry in byWall.entries) ...[
      pw.Text(
        entry.key,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _primary,
        ),
      ),
      pw.SizedBox(height: 3),
      ...entry.value.map(_observationRow),
      pw.SizedBox(height: 6),
    ],
  ];
}

/// Ligne d'observation. [prefix] (ex. le mur) est affiché en gras devant le
/// texte quand fourni.
pw.Widget _observationRow(ObservationEdl o, {String? prefix}) => pw.Padding(
  padding: const pw.EdgeInsets.only(left: 4, bottom: 3),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 3,
        height: 12,
        color: o.isLocataire ? _accent : _primary,
        margin: const pw.EdgeInsets.only(right: 6, top: 1),
      ),
      pw.Expanded(
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              if (prefix != null && prefix.isNotEmpty)
                pw.TextSpan(
                  text: '$prefix : ',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _grey,
                  ),
                ),
              pw.TextSpan(
                text: o.description ?? '',
                style: const pw.TextStyle(fontSize: 8),
              ),
              if (o.isLocataire)
                pw.TextSpan(
                  text: '  [Locataire]',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Section OBSERVATIONS — CONTREPOINT (entrée vs sortie), flottante

List<pw.Widget> _sectionObservationsContrepoint(
  List<ObservationEdl> entree,
  List<ObservationEdl> sortie,
) {
  // Clé composite (pièce/chambre + mur) pour aligner entrée et sortie.
  String keyOf(ObservationEdl o) =>
      '${o.pieceId ?? ''}|${o.chambreId ?? ''}|${o.wallLabel}';
  final labels = <String, String>{};
  final entreeBy = <String, List<ObservationEdl>>{};
  final sortieBy = <String, List<ObservationEdl>>{};
  for (final o in entree.where((o) => o.hasContent)) {
    final k = keyOf(o);
    labels[k] = o.wallLabel;
    entreeBy.putIfAbsent(k, () => []).add(o);
  }
  for (final o in sortie.where((o) => o.hasContent)) {
    final k = keyOf(o);
    labels[k] = o.wallLabel;
    sortieBy.putIfAbsent(k, () => []).add(o);
  }
  final keys = labels.keys.toList()..sort();
  if (keys.isEmpty) return const [];

  return [
    _titleBar('OBSERVATIONS — ENTRÉE / SORTIE'),
    pw.SizedBox(height: 4),
    pw.Table(
      border: pw.TableBorder.all(color: _primaryLight, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4),
        1: const pw.FlexColumnWidth(2.3),
        2: const pw.FlexColumnWidth(2.3),
      },
      children: [
        _tableHeaderRow(['Emplacement', "État d'entrée", 'État de sortie']),
        for (final k in keys)
          pw.TableRow(
            children: [
              _ctpCell([_text(labels[k] ?? '', bold: true)]),
              _ctpCell(_obsTexts(entreeBy[k] ?? const [])),
              _ctpCell(_obsTexts(sortieBy[k] ?? const [])),
            ],
          ),
      ],
    ),
  ];
}

pw.Widget _text(String s, {bool bold = false}) => pw.Text(
  s,
  style: pw.TextStyle(
    fontSize: 8,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  ),
);

List<pw.Widget> _obsTexts(List<ObservationEdl> obs) {
  if (obs.isEmpty) return [_text('—')];
  return [
    for (final o in obs)
      _text(
        o.isLocataire
            ? '• ${o.description ?? ''}  [Locataire]'
            : '• ${o.description ?? ''}',
      ),
  ];
}

pw.Widget _ctpCell(List<pw.Widget> children) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: children,
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Section ADDITIONS — flottante

List<pw.Widget> _sectionAdditions(List<ObservationEdl> additions) {
  final byComodo = <String, List<ObservationEdl>>{};
  for (final a in additions) {
    final key = a.chambreId != null
        ? 'chambre:${a.chambreId}'
        : a.pieceId != null
        ? 'piece:${a.pieceId}'
        : 'general';
    byComodo.putIfAbsent(key, () => []).add(a);
  }

  return [
    _titleBar('AVENANTS (après finalisation)', color: _red),
    pw.SizedBox(height: 4),
    for (final entry in byComodo.entries) ...[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        color: _accentLight,
        child: pw.Text(
          _comodoLabel(entry.key),
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
            color: _accent,
          ),
        ),
      ),
      pw.SizedBox(height: 4),
      ...entry.value.map(_additionRow),
      pw.SizedBox(height: 6),
    ],
  ];
}

pw.Widget _additionRow(ObservationEdl a) => pw.Padding(
  padding: const pw.EdgeInsets.only(left: 8, bottom: 6),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        children: [
          _pill(
            a.isLocataire ? 'Locataire' : 'Propriétaire',
            a.isLocataire ? _accent : _primary,
          ),
          pw.SizedBox(width: 6),
          if (a.createdAtLabel != null)
            pw.Text(
              a.createdAtLabel!,
              style: pw.TextStyle(fontSize: 8, color: _grey),
            ),
        ],
      ),
      if (a.wallKey != null) ...[
        pw.SizedBox(height: 2),
        pw.Text(
          a.wallLabel,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _grey,
          ),
        ),
      ],
      if (a.description != null && a.description!.isNotEmpty)
        pw.Text(a.description!, style: const pw.TextStyle(fontSize: 9)),
    ],
  ),
);

String _comodoLabel(String key) {
  if (key == 'general') return 'Général';
  final parts = key.split(':');
  if (parts[0] == 'chambre') return 'Chambre #${parts[1]}';
  return 'Pièce #${parts[1]}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Section SIGNATURES (courte → card atomique)

pw.Widget _sectionSignatures(
  EdlPdfData data, {
  Uint8List? propSigBytes,
  Uint8List? locSigBytes,
}) {
  final edl = data.edl;
  final preneurNames = data.preneurs.isNotEmpty
      ? data.preneurs.map((p) => p.nom ?? '—').join(', ')
      : (edl.locataireNom ?? '—');

  return _card(
    title: 'SIGNATURES',
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _signatureBlock(
            'Le bailleur',
            edl.bailleurNom ?? edl.proprietaireNom ?? '—',
            signedAt: edl.proprietaireSignedAt,
            sigBytes: propSigBytes,
          ),
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(
          child: _signatureBlock(
            'Le(s) locataire(s)',
            preneurNames,
            signedAt: edl.locataireSignedAt,
            sigBytes: locSigBytes,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _signatureBlock(
  String role,
  String name, {
  DateTime? signedAt,
  Uint8List? sigBytes,
}) {
  final fmt = DateFormat(_dateFmt);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        role,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _primary,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
      if (signedAt != null) ...[
        pw.SizedBox(height: 2),
        pw.Text(
          'Signé le ${fmt.format(signedAt)}',
          style: pw.TextStyle(fontSize: 8, color: _grey),
        ),
      ],
      pw.SizedBox(height: 6),
      // Image de signature ou zone vide
      if (sigBytes != null)
        pw.Container(
          height: 48,
          alignment: pw.Alignment.centerLeft,
          child: pw.Image(
            pw.MemoryImage(sigBytes),
            fit: pw.BoxFit.contain,
            height: 48,
          ),
        )
      else
        pw.SizedBox(height: 36),
      pw.Container(height: 1, color: _grey),
      pw.SizedBox(height: 4),
      pw.Text('Signature', style: pw.TextStyle(fontSize: 8, color: _grey)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers communs

/// Barre de titre de section (pleine largeur, colorée). Atomique mais petite,
/// donc sûre pour la pagination.
pw.Widget _titleBar(String title, {PdfColor? color}) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: pw.BoxDecoration(
    color: color ?? _primary,
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
  ),
  child: pw.Text(
    title,
    style: pw.TextStyle(
      color: _white,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 0.3,
    ),
  ),
);

/// Carte bordée (titre + corps). À réserver aux sections **courtes** : le corps
/// est un `Container` atomique qui ne se répartit pas sur plusieurs pages.
pw.Widget _card({
  required String title,
  required pw.Widget child,
  PdfColor? titleColor,
}) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: titleColor ?? _primary,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(4),
          topRight: pw.Radius.circular(4),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: _white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    ),
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      // Bordure non-uniforme (sans le haut, déjà couvert par le titre) →
      // pas de borderRadius (interdit par le package pdf sur une bordure
      // non uniforme).
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: titleColor ?? _primary),
          right: pw.BorderSide(color: titleColor ?? _primary),
          bottom: pw.BorderSide(color: titleColor ?? _primary),
        ),
      ),
      child: child,
    ),
  ],
);

pw.Widget _labelValue(String label, String value) => pw.SizedBox(
  width: 180,
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _grey)),
      pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    ],
  ),
);

pw.TableRow _tableHeaderRow(List<String> headers) => pw.TableRow(
  decoration: pw.BoxDecoration(color: _primaryLight),
  children: headers
      .map(
        (h) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(
            h,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
        ),
      )
      .toList(),
);

pw.TableRow _tableDataRow(List<String> cells) => pw.TableRow(
  children: cells
      .map(
        (c) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
          child: pw.Text(c, style: const pw.TextStyle(fontSize: 7.5)),
        ),
      )
      .toList(),
);
