import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/app_radius.dart';

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
    _tabCtrl = TabController(length: 2, vsync: this);
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
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [_VisionGeneralePage(), _BauxPage()],
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
