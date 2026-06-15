import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/signatures.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/signature_pad.dart';

class DocumentationPage extends StatefulWidget {
  const DocumentationPage({super.key});

  @override
  State<DocumentationPage> createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Text('Documentation', style: AppTypography.headlineMd),
        ),
        const Divider(height: 1),
        TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Vision générale'),
            Tab(text: 'Baux'),
            Tab(text: 'Ma signature'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              _VisionGeneralePage(),
              _BauxPage(),
              _SignaturePage(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _VisionGeneralePage extends StatelessWidget {
  const _VisionGeneralePage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Section Important
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.errorContainer.withValues(alpha: 0.35),
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Important',
                    style: AppTypography.titleLg.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Cette section contiendra les informations importantes concernant la gestion des baux et des propriétés.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Section Lista Baux
        Text('Baux actifs', style: AppTypography.titleLg),
        const SizedBox(height: AppSpacing.md),
        _ListaBauxTable(),
      ],
    );
  }
}

class _ListaBauxTable extends StatelessWidget {
  const _ListaBauxTable();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: AppRadius.borderMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow),
            children: [
              _TableHeader('Locataire'),
              _TableHeader('Chambre'),
              _TableHeader('Début'),
              _TableHeader('Fin'),
              _TableHeader('Statut'),
            ],
          ),
          // Linha placeholder enquanto não há dados
          TableRow(
            children: [
              _TableCell(
                colspan: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'Aucun bail enregistré',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              _TableCell(child: const SizedBox.shrink()),
              _TableCell(child: const SizedBox.shrink()),
              _TableCell(child: const SizedBox.shrink()),
              _TableCell(child: const SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;
  const _TableHeader(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: Text(label, style: AppTypography.labelMd),
  );
}

class _TableCell extends StatelessWidget {
  final Widget child;
  final int colspan;
  const _TableCell({required this.child, this.colspan = 1});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: child,
  );
}

// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Tab : Ma Signature

class _SignaturePage extends StatefulWidget {
  const _SignaturePage();

  @override
  State<_SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<_SignaturePage> {
  late Future<String?> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = SignaturesDatasource.getSavedUrl();
  }

  Future<void> _update() async {
    final sig = await showSignatureDialog(context);
    if (sig == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await SignaturesDatasource.saveUrl(sig.url);
      if (mounted) setState(() { _future = SignaturesDatasource.getSavedUrl(); _saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _delete(String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la signature ?'),
        content: const Text('La signature sauvegardée sera supprimée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.deleteButtonStyle,
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await SignaturesDatasource.deleteSignature();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
    if (mounted) setState(() { _future = SignaturesDatasource.getSavedUrl(); _saving = false; });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snap) {
        final url = snap.data;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Ma signature par défaut', style: AppTypography.titleLg),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cette signature sera proposée automatiquement lors de la finalisation ou de l\'acceptation d\'un état des lieux.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (snap.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (url != null && url.isNotEmpty) ...[
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.outlineVariant),
                  borderRadius: AppRadius.borderMd,
                ),
                child: Image.network(url, fit: BoxFit.contain),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : _update,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _delete(url),
                    style: AppTheme.deleteButtonStyle,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                  ),
                ],
              ),
            ] else ...[
              Container(
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  border: Border.all(color: AppColors.outlineVariant),
                  borderRadius: AppRadius.borderMd,
                ),
                child: Text(
                  'Aucune signature sauvegardée',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _saving ? null : _update,
                icon: const Icon(Icons.draw_outlined, size: 18),
                label: const Text('Ajouter ma signature'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BauxPage extends StatelessWidget {
  const _BauxPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(child: Text('Baux', style: AppTypography.titleLg)),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité Nouveau Bail à venir.'),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau Bail'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 64,
                  color: AppColors.outline,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Gestion des baux', style: AppTypography.titleLg),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Cette fonctionnalité sera disponible prochainement.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
