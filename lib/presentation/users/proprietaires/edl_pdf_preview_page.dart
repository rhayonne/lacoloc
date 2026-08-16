import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'edl_pdf_data.dart';
import 'edl_pdf_builder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Point d'entrée public — ouvre la page de prévisualisation PDF.

/// Ouvre la prévisualisation pour un EDL **individuel** (collectif + privatif).
/// Si [enableSign] est vrai, un bouton « Signer » est affiché et la page renvoie
/// `true` quand l'utilisateur le presse (pour enchaîner l'acceptation).
Future<bool?> openEdlIndividuelPdfPreview({
  required BuildContext context,
  required int collectifId,
  required int privatifId,
  bool enableSign = false,
}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => EdlPdfPreviewPage.individuel(
        collectifId: collectifId,
        privatifId: privatifId,
        enableSign: enableSign,
      ),
      fullscreenDialog: true,
    ),
  );
}

/// Ouvre la prévisualisation pour un EDL **collectif** (parties communes).
Future<bool?> openEdlCollectifPdfPreview({
  required BuildContext context,
  required int edlId,
  bool enableSign = false,
}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => EdlPdfPreviewPage.collectif(edlId: edlId, enableSign: enableSign),
      fullscreenDialog: true,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class EdlPdfPreviewPage extends StatefulWidget {
  final int? collectifId;
  final int? privatifId;

  /// Affiche un bouton « Signer » en bas ; la page se ferme en renvoyant `true`.
  final bool enableSign;

  const EdlPdfPreviewPage.individuel({
    super.key,
    required int this.collectifId,
    required int this.privatifId,
    this.enableSign = false,
  });

  const EdlPdfPreviewPage.collectif({
    super.key,
    required int edlId,
    this.enableSign = false,
  })  : collectifId = edlId,
        privatifId = null;

  @override
  State<EdlPdfPreviewPage> createState() => _EdlPdfPreviewPageState();
}

class _EdlPdfPreviewPageState extends State<EdlPdfPreviewPage> {
  late final Future<EdlPdfData> _futurePdfData;
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  EdlPdfMode _mode = EdlPdfMode.sortieSeul;
  EdlPdfScope _scope = EdlPdfScope.complet;

  @override
  void initState() {
    super.initState();
    _futurePdfData = _loadData();
  }

  Future<EdlPdfData> _loadData() {
    if (widget.privatifId != null) {
      return EdlPdfData.loadIndividuel(
        collectifId: widget.collectifId!,
        privatifId: widget.privatifId!,
      );
    }
    return EdlPdfData.loadCollectif(widget.collectifId!);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<EdlPdfData>(
          future: _futurePdfData,
          builder: (_, snap) => Text(
            snap.hasData
                ? 'Document — ${snap.data!.edl.sensLabel} · ${snap.data!.edl.lieuLabel}'
                : 'Document — État des lieux',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: FutureBuilder<EdlPdfData>(
        future: _futurePdfData,
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Erreur : ${snap.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Barre de boutons + options ─────────────────────────────────
              _EdlActionBar(
                onPrint: () => _printPdf(data),
                onDownload: () => _downloadPdf(data),
                hasEntree: data.hasEntree,
                isIndividuel: data.isIndividuel,
                mode: _mode,
                scope: _scope,
                onModeChanged: (m) => setState(() => _mode = m),
                onScopeChanged: (s) => setState(() => _scope = s),
              ),
              // ── Bandeau « non finalisé » ───────────────────────────────────
              if (!data.isFinalise) _WarningBanner(),
              // ── Prévisualisation PDF ───────────────────────────────────────
              Expanded(
                child: PdfPreview(
                  key: ValueKey('${_mode}_$_scope'),
                  build: (_) async {
                    final doc = await buildEdlPdf(data, mode: _mode, scope: _scope);
                    return doc.save();
                  },
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  pdfFileName: '${_pdfName(data)}.pdf',
                  loadingWidget: const Center(child: CircularProgressIndicator()),
                  initialPageFormat: PdfPageFormat.a4,
                  previewPageMargin: const EdgeInsets.all(AppSpacing.md),
                ),
              ),
            ],
          );
        },
      ),
      // Bouton de signature en pied de page (locataire → accepter et signer).
      bottomNavigationBar: widget.enableSign
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FutureBuilder<EdlPdfData>(
                  future: _futurePdfData,
                  builder: (_, snap) => AppButton.save(
                    icon: Icons.draw_outlined,
                    label: 'Signer et accepter',
                    onPressed: snap.hasData
                        ? () => Navigator.of(context).pop(true)
                        : null,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Barre d'actions : Imprimer · Télécharger + toggles mode/portée.
class _EdlActionBar extends StatelessWidget {
  final VoidCallback onPrint;
  final VoidCallback onDownload;
  final bool hasEntree;
  final bool isIndividuel;
  final EdlPdfMode mode;
  final EdlPdfScope scope;
  final ValueChanged<EdlPdfMode> onModeChanged;
  final ValueChanged<EdlPdfScope> onScopeChanged;

  const _EdlActionBar({
    required this.onPrint,
    required this.onDownload,
    required this.hasEntree,
    required this.isIndividuel,
    required this.mode,
    required this.scope,
    required this.onModeChanged,
    required this.onScopeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasToggles = hasEntree || isIndividuel;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppButton.document(
            icon: Icons.print_outlined,
            label: 'Imprimer',
            onPressed: onPrint,
          ),
          AppButton.document(
            icon: Icons.download_outlined,
            label: 'Télécharger',
            onPressed: onDownload,
          ),
          if (hasToggles) ...[
            Container(width: 1, height: 28, color: AppColors.outlineVariant),
            if (hasEntree)
              SegmentedButton<EdlPdfMode>(
                segments: const [
                  ButtonSegment(
                      value: EdlPdfMode.sortieSeul, label: Text('Sortie seul')),
                  ButtonSegment(
                      value: EdlPdfMode.contrepoint,
                      label: Text('Sortie + entrée')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => onModeChanged(s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (isIndividuel)
              SegmentedButton<EdlPdfScope>(
                segments: const [
                  ButtonSegment(
                      value: EdlPdfScope.complet, label: Text('Complet')),
                  ButtonSegment(
                      value: EdlPdfScope.communes,
                      label: Text('Parties communes')),
                  ButtonSegment(
                      value: EdlPdfScope.chambre, label: Text('Chambre')),
                ],
                selected: {scope},
                onSelectionChanged: (s) => onScopeChanged(s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "Cet EDL n'est pas encore finalisé. Le PDF contiendra le filigrane « APERÇU · NON FINALISÉ ».",
              style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget de résumé des données (utilisé ponctuellement en débogage / affichage)

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
            _row('Bail', edl.typeLabel),
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
              _row('Avenants', data.additions.length.toString()),
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
