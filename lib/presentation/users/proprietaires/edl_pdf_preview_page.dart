import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'edl_pdf_data.dart';
import 'edl_pdf_builder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Point d'entrée public — ouvre la page de prévisualisation PDF.

/// Ouvre la prévisualisation pour un EDL **individuel** (collectif + privatif).
Future<void> openEdlIndividuelPdfPreview({
  required BuildContext context,
  required int collectifId,
  required int privatifId,
}) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => EdlPdfPreviewPage.individuel(
        collectifId: collectifId,
        privatifId: privatifId,
      ),
      fullscreenDialog: true,
    ),
  );
}

/// Ouvre la prévisualisation pour un EDL **collectif** (parties communes).
Future<void> openEdlCollectifPdfPreview({
  required BuildContext context,
  required int edlId,
}) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => EdlPdfPreviewPage.collectif(edlId: edlId),
      fullscreenDialog: true,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class EdlPdfPreviewPage extends StatefulWidget {
  final int? collectifId;
  final int? privatifId;

  const EdlPdfPreviewPage.individuel({
    super.key,
    required int this.collectifId,
    required int this.privatifId,
  });

  const EdlPdfPreviewPage.collectif({
    super.key,
    required int edlId,
  })  : collectifId = edlId,
        privatifId = null;

  @override
  State<EdlPdfPreviewPage> createState() => _EdlPdfPreviewPageState();
}

class _EdlPdfPreviewPageState extends State<EdlPdfPreviewPage> {
  late final Future<EdlPdfData> _futurePdfData;
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  // Mode d'impression d'un sortie : seul ou en contrepoint avec l'entrée.
  EdlPdfMode _mode = EdlPdfMode.sortieSeul;
  // Portée (bail individuel) : complet / parties communes / chambre.
  EdlPdfScope _scope = EdlPdfScope.complet;

  @override
  void initState() {
    super.initState();
    _futurePdfData = _loadData();
  }

  Future<EdlPdfData> _loadData() {
    final isIndividuel = widget.privatifId != null;
    if (isIndividuel) {
      return EdlPdfData.loadIndividuel(
        collectifId: widget.collectifId!,
        privatifId: widget.privatifId!,
      );
    }
    return EdlPdfData.loadCollectif(
      widget.collectifId!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // Force la couleur des icônes (fermer/imprimer/télécharger) au blanc du
        // titre — sinon un IconButtonTheme global les rendrait noires.
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: FutureBuilder<EdlPdfData>(
          future: _futurePdfData,
          builder: (ctx, snap) => Text(
            snap.hasData
                ? 'Document — ${snap.data!.edl.sensLabel} · ${snap.data!.edl.lieuLabel}'
                : 'Document — État des lieux',
            style: const TextStyle(fontSize: 15, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          FutureBuilder<EdlPdfData>(
            future: _futurePdfData,
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print),
                      color: Colors.white,
                      tooltip: 'Imprimer',
                      onPressed: () => _printPdf(snap.data!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download),
                      color: Colors.white,
                      tooltip: 'Télécharger PDF',
                      onPressed: () => _downloadPdf(snap.data!),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<EdlPdfData>(
        future: _futurePdfData,
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Erreur : ${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          return Column(
            children: [
              if (!data.isFinalise) _warningBanner(),
              if (data.hasEntree) _modeToggle(),
              if (data.isIndividuel) _scopeToggle(),
              Expanded(
                child: _PdfPreviewWidget(
                  // Clé sur (mode, portée) → régénère l'aperçu au changement.
                  key: ValueKey('${_mode}_$_scope'),
                  data: data,
                  mode: _mode,
                  scope: _scope,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _warningBanner() => Container(
    width: double.infinity,
    color: const Color(0xFFFEF3C7),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Cet EDL n\'est pas encore finalisé. Le PDF contiendra le filigrane « PRÉVIA · NON FINALISÉ ».',
            style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
          ),
        ),
      ],
    ),
  );

  /// Sélecteur « Sortie seul / Sortie + entrée » (uniquement pour un sortie
  /// avec entrée couplée).
  Widget _modeToggle() => Container(
        width: double.infinity,
        color: AppColors.surfaceContainerHigh,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.compare_arrows, size: 18),
            const SizedBox(width: 8),
            const Text('Impression :', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 12),
            SegmentedButton<EdlPdfMode>(
              segments: const [
                ButtonSegment(
                  value: EdlPdfMode.sortieSeul,
                  label: Text('Sortie seul'),
                ),
                ButtonSegment(
                  value: EdlPdfMode.contrepoint,
                  label: Text('Sortie + entrée'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ],
        ),
      );

  /// Sélecteur de portée (bail individuel) : tout / parties communes / chambre.
  Widget _scopeToggle() => Container(
        width: double.infinity,
        color: AppColors.surfaceContainerHigh,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.layers_outlined, size: 18),
            const SizedBox(width: 8),
            const Text('Portée :', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 12),
            SegmentedButton<EdlPdfScope>(
              segments: const [
                ButtonSegment(
                  value: EdlPdfScope.complet,
                  label: Text('Complet'),
                ),
                ButtonSegment(
                  value: EdlPdfScope.communes,
                  label: Text('Parties communes'),
                ),
                ButtonSegment(
                  value: EdlPdfScope.chambre,
                  label: Text('Chambre'),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (s) => setState(() => _scope = s.first),
            ),
          ],
        ),
      );

  Future<void> _printPdf(EdlPdfData data) async {
    final doc = await buildEdlPdf(data, mode: _mode, scope: _scope);
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: _pdfName(data),
    );
  }

  Future<void> _downloadPdf(EdlPdfData data) async {
    final doc = await buildEdlPdf(data, mode: _mode, scope: _scope);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${_pdfName(data)}.pdf',
    );
  }

  String _pdfName(EdlPdfData data) {
    final edl = data.edl;
    final date = _dateFmt.format(edl.dateEtatLieux).replaceAll('/', '-');
    final sens = edl.typeEdl == 'sortie' ? 'sortie' : 'entree';
    return 'EDL_${sens}_$date';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget de prévisualisation native (PdfPreview du package printing)

class _PdfPreviewWidget extends StatelessWidget {
  final EdlPdfData data;
  final EdlPdfMode mode;
  final EdlPdfScope scope;

  const _PdfPreviewWidget({
    super.key,
    required this.data,
    required this.mode,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    return PdfPreview(
      build: (_) async {
        final doc = await buildEdlPdf(data, mode: mode, scope: scope);
        return doc.save();
      },
      canChangePageFormat: false,
      canDebug: false,
      pdfFileName: 'etat_des_lieux.pdf',
      loadingWidget: const Center(child: CircularProgressIndicator()),
      initialPageFormat: PdfPageFormat.a4,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget de résumé des données (affiché avant/sous la prévisualisation)

class EdlDataSummaryCard extends StatelessWidget {
  final EdlPdfData data;

  const EdlDataSummaryCard({super.key, required this.data});

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final edl = data.edl;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Type', '${edl.sensLabel} · ${edl.typeLabel} · ${edl.meubleLabel}'),
            _row('Bail', edl.typeBail == 'collectif' ? 'Collectif' : 'Individuel'),
            _row('Immeuble', edl.immeubleNom ?? '—'),
            if (edl.chambreNom != null) _row('Chambre', edl.chambreNom!),
            _row('Date EDL', _dateFmt.format(edl.dateEtatLieux)),
            if (edl.dateFinalisation != null)
              _row('Finalisé le', _dateFmt.format(edl.dateFinalisation!)),
            _row('Situation', edl.situation.label),
            if (data.preneurs.isNotEmpty)
              _row('Preneurs', data.preneurs.map((p) => p.nom ?? '—').join(', ')),
            _row('Sections', data.sections.length.toString()),
            _row('Relevés', data.releves.length.toString()),
            if (data.cles.isNotEmpty) _row('Clés', data.cles.length.toString()),
            if (data.additions.isNotEmpty)
              _row('Additions', data.additions.length.toString()),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}
