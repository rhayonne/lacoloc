import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/factures.dart';
import 'package:lacoloc_front/data/models/facture.dart';
import 'package:lacoloc_front/presentation/finances/nouvelle_facture_page.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class FacturesListPage extends StatefulWidget {
  final VoidCallback onAjouter;
  final void Function(FactureModel, {required bool readOnly}) onOuvrir;

  const FacturesListPage({
    super.key,
    required this.onAjouter,
    required this.onOuvrir,
  });

  @override
  State<FacturesListPage> createState() => _FacturesListPageState();
}

class _FacturesListPageState extends State<FacturesListPage> {
  late Future<List<FactureModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FactureModel>> _load() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return [];
    return FacturesDatasource.listByOwner(ownerId);
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
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Text('Factures', style: AppTypography.headlineMd),
              const Spacer(),
              FilledButton.icon(
                onPressed: widget.onAjouter,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter une facture'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<FactureModel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erreur : ${snap.error}'));
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return _EmptyState(onAjouter: widget.onAjouter);
              }
              return _FacturesTable(
                factures: list,
                onVoir: (f) => widget.onOuvrir(f, readOnly: true),
                onModifier: (f) => widget.onOuvrir(f, readOnly: false),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FacturesTable extends StatelessWidget {
  final List<FactureModel> factures;
  final ValueChanged<FactureModel> onVoir;
  final ValueChanged<FactureModel> onModifier;

  const _FacturesTable({
    required this.factures,
    required this.onVoir,
    required this.onModifier,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 700;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: AppSpacing.lg,
                headingRowColor: WidgetStateProperty.all(
                  AppColors.surfaceContainerLow,
                ),
                columns: [
                  const DataColumn(label: Text('Immeuble')),
                  const DataColumn(label: Text('N° Facture')),
                  const DataColumn(label: Text('Fournisseur')),
                  if (!narrow) const DataColumn(label: Text('Type')),
                  const DataColumn(label: Text('HT (€)'), numeric: true),
                  const DataColumn(label: Text('TTC (€)'), numeric: true),
                  if (!narrow) const DataColumn(label: Text('Statut')),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: factures.map((f) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          f.immeubleName ?? '—',
                          style: AppTypography.bodyMd,
                        ),
                      ),
                      DataCell(
                        Text(f.codeFacture ?? '—', style: AppTypography.bodyMd),
                      ),
                      DataCell(
                        Text(f.fournisseur, style: AppTypography.bodyMd),
                      ),
                      if (!narrow)
                        DataCell(
                          Text(f.typeFacture, style: AppTypography.bodyMd),
                        ),
                      DataCell(
                        Text(
                          f.montantHt != null
                              ? f.montantHt!.toStringAsFixed(2)
                              : '—',
                          style: AppTypography.bodyMd,
                        ),
                      ),
                      DataCell(
                        Text(
                          f.montantTtc != null
                              ? f.montantTtc!.toStringAsFixed(2)
                              : '—',
                          style: AppTypography.bodyMd,
                        ),
                      ),
                      if (!narrow) DataCell(_StatutBadge(statut: f.statut)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Voir',
                              child: IconButton(
                                icon: const Icon(Icons.search, size: 20),
                                color: AppColors.primary,
                                onPressed: () => onVoir(f),
                              ),
                            ),
                            Tooltip(
                              message: 'Modifier',
                              child: IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                color: AppColors.onSurfaceVariant,
                                onPressed: () => onModifier(f),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatutBadge extends StatelessWidget {
  final String statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (statut) {
      'Payée' => (AppColors.tertiaryFixed, AppColors.onTertiaryFixedVariant),
      'En litige' => (AppColors.errorContainer, AppColors.onErrorContainer),
      _ => (AppColors.secondaryFixed, AppColors.onSecondaryFixedVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(statut, style: AppTypography.labelSm.copyWith(color: fg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAjouter;
  const _EmptyState({required this.onAjouter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Aucune facture enregistrée', style: AppTypography.titleLg),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ajoutez votre première facture pour commencer.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onAjouter,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une facture'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Overlay em tela cheia para ver ou editar uma factura a partir da lista.
/// Chamado pelo ProprietaireProfilPage quando o usuário clica nos ícones.
class FactureDetailOverlay extends StatelessWidget {
  final FactureModel facture;
  final bool readOnly;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  const FactureDetailOverlay({
    super.key,
    required this.facture,
    required this.readOnly,
    required this.onClose,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de navegação de volta
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.arrow_back),
                onPressed: onClose,
                tooltip: 'Retour à la liste',
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                readOnly ? 'Détail de la facture' : 'Modifier la facture',
                style: AppTypography.titleLg,
              ),
            ],
          ),
        ),
        Expanded(
          child: NouvelleFacturePage(
            facture: facture,
            readOnly: readOnly,
            onSaved: onSaved,
          ),
        ),
      ],
    );
  }
}
