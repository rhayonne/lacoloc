import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:habitafrance/data/datasources/etat_de_lieux.dart';
import 'package:habitafrance/data/datasources/signatures.dart';
import 'package:habitafrance/data/models/etat_de_lieux.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/utils/signature_pad.dart';
import 'bail_pdf_builder.dart';
import 'bail_pdf_data.dart';

/// Page de prévisualisation et d'impression du contrat de bail.
///
/// Layout standard : AppBar (titre + retour) · barre de boutons juste en
/// dessous · PdfPreview plein écran sans barre native.
///
/// Si [readOnly] est faux et que le [role] courant n'a pas encore signé, une
/// action « Confirmer ma signature » est proposée dans la barre. Une fois le
/// bail signé par les deux parties, il est verrouillé (consultation seule).
class BailPdfPreviewPage extends StatefulWidget {
  final EtatDesLieuxModel edl;

  /// Rôle de l'utilisateur courant (`proprietaire` = bailleur, `locataire`).
  final String role;

  /// Mode consultation seule (aucune signature proposée). Utilisé quand le bail
  /// est déjà entièrement signé (« Visualiser le bail »).
  final bool readOnly;

  const BailPdfPreviewPage({
    super.key,
    required this.edl,
    this.role = 'proprietaire',
    this.readOnly = false,
  });

  @override
  State<BailPdfPreviewPage> createState() => _BailPdfPreviewPageState();
}

class _BailPdfPreviewPageState extends State<BailPdfPreviewPage> {
  late Future<BailPdfData> _dataFuture;
  bool _signing = false;
  // Portée d'impression (bail individuel) : tout / chambre / parties communes.
  BailPdfScope _scope = BailPdfScope.complet;

  @override
  void initState() {
    super.initState();
    _dataFuture = BailPdfData.fromEdl(widget.edl);
  }

  /// Appose la signature de l'utilisateur courant sur le bail puis recharge les
  /// données (la signature + sa date apparaissent alors dans le PDF).
  Future<void> _confirmSignature(BailPdfData data) async {
    if (_signing) return;
    setState(() => _signing = true);
    try {
      String? sigUrl = await SignaturesDatasource.getSavedUrl();
      if (!mounted) return;
      if (sigUrl == null) {
        final res = await showSignatureDialog(context);
        if (res == null || !mounted) return;
        sigUrl = res.url;
      }
      await EtatDesLieuxDatasource.setBailSignature(
        id: data.edl.id,
        role: widget.role,
        signatureUrl: sigUrl,
      );
      final fresh = await EtatDesLieuxDatasource.findById(data.edl.id);
      if (!mounted) return;
      setState(() {
        _dataFuture = BailPdfData.fromEdl(fresh ?? data.edl);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Signature enregistrée sur le bail.'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossible d\'enregistrer la signature : $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  Future<void> _print(BailPdfData data) async {
    final pdf = await BailPdfBuilder(data).build(scope: _scope);
    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'bail_${data.edl.id}.pdf',
    );
  }

  Future<void> _download(BailPdfData data) async {
    final pdf = await BailPdfBuilder(data).build(scope: _scope);
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
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
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
          // Impression bloquée tant qu'un garant requis n'est pas enregistré.
          final blocked = data.garantManquant;
          // Signature proposée si non verrouillé et que le rôle n'a pas signé.
          final canSign = !widget.readOnly &&
              !data.edl.bailSignedBy(widget.role) &&
              !blocked;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Barre de boutons ─────────────────────────────────────────
              _ActionBar(
                enabled: !blocked,
                onPrint: () => _print(data),
                onDownload: () => _download(data),
                onSign: canSign ? () => _confirmSignature(data) : null,
                signing: _signing,
              ),
              if (blocked) const _GarantBlockedBanner(),
              // ── Portée d'impression (bail individuel avec parties communes) ──
              if (data.hasPartiesCommunes)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<BailPdfScope>(
                      segments: const [
                        ButtonSegment(
                            value: BailPdfScope.complet, label: Text('Complet')),
                        ButtonSegment(
                            value: BailPdfScope.chambre, label: Text('Chambre')),
                        ButtonSegment(
                            value: BailPdfScope.communes,
                            label: Text('Parties communes')),
                      ],
                      selected: {_scope},
                      onSelectionChanged: (s) =>
                          setState(() => _scope = s.first),
                    ),
                  ),
                ),
              // ── Prévisualisation PDF ─────────────────────────────────────
              Expanded(
                child: PdfPreview(
                  key: ValueKey('${data.edl.id}_$_scope'),
                  build: (format) async {
                    final pdf = await BailPdfBuilder(data).build(scope: _scope);
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
  final bool enabled;

  /// Si non nul, affiche un bouton « Confirmer ma signature ».
  final VoidCallback? onSign;
  final bool signing;

  const _ActionBar({
    required this.onPrint,
    required this.onDownload,
    this.enabled = true,
    this.onSign,
    this.signing = false,
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
          if (onSign != null)
            AppButton.save(
              label: 'Confirmer ma signature',
              icon: Icons.draw_outlined,
              isBusy: signing,
              onPressed: signing ? null : onSign,
            ),
          AppButton.document(
            icon: Icons.print_outlined,
            label: 'Imprimer',
            onPressed: enabled ? onPrint : null,
          ),
          AppButton.document(
            icon: Icons.download_outlined,
            label: 'Télécharger',
            onPressed: enabled ? onDownload : null,
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'avertissement : impression bloquée car le bail nécessite un garant
/// qui n'a pas encore été enregistré par le locataire.
class _GarantBlockedBanner extends StatelessWidget {
  const _GarantBlockedBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.gpp_maybe_outlined, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "Ce bail nécessite un garant. L'impression sera possible une fois "
              "qu'au moins un garant aura été enregistré par le locataire.",
              style: AppTypography.bodyMd.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
