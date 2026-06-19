import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'bail_pdf_builder.dart';
import 'bail_pdf_data.dart';

/// Page de prévisualisation et d'impression du contrat de bail.
///
/// Layout standard : AppBar (titre + retour) · barre de boutons juste en
/// dessous · PdfPreview plein écran sans barre native.
class BailPdfPreviewPage extends StatefulWidget {
  final EtatDesLieuxModel edl;

  const BailPdfPreviewPage({super.key, required this.edl});

  @override
  State<BailPdfPreviewPage> createState() => _BailPdfPreviewPageState();
}

class _BailPdfPreviewPageState extends State<BailPdfPreviewPage> {
  late Future<BailPdfData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = BailPdfData.fromEdl(widget.edl);
  }

  Future<void> _print(BailPdfData data) async {
    final pdf = await BailPdfBuilder(data).build();
    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'bail_${data.edl.id}.pdf',
    );
  }

  Future<void> _download(BailPdfData data) async {
    final pdf = await BailPdfBuilder(data).build();
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'bail_${data.edl.id}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contrat de bail')),
      body: FutureBuilder<BailPdfData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: AppSpacing.md),
                    Text('Impossible de générer le bail :',
                        style: AppTypography.titleLg),
                    const SizedBox(height: AppSpacing.sm),
                    Text('${snapshot.error}', style: AppTypography.bodyMd),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Barre de boutons ─────────────────────────────────────────
              _ActionBar(
                onPrint: () => _print(data),
                onDownload: () => _download(data),
              ),
              // ── Prévisualisation PDF ─────────────────────────────────────
              Expanded(
                child: PdfPreview(
                  key: ValueKey(data.edl.id),
                  build: (format) async {
                    final pdf = await BailPdfBuilder(data).build();
                    return pdf.save();
                  },
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  pdfFileName: 'bail_${data.edl.id}.pdf',
                  previewPageMargin: const EdgeInsets.all(AppSpacing.md),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Barre d'actions standard : Imprimer + Télécharger.
/// Utilisée par BailPdfPreviewPage et EdlPdfPreviewPage.
class _ActionBar extends StatelessWidget {
  final VoidCallback onPrint;
  final VoidCallback onDownload;

  const _ActionBar({
    required this.onPrint,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: onPrint,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Imprimer'),
          ),
          OutlinedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Télécharger'),
          ),
        ],
      ),
    );
  }
}
