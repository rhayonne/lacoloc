import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/immeuble_lots.dart';
import 'package:lacoloc_front/data/models/immeuble_lot.dart';
import 'package:lacoloc_front/presentation/widgets/app_list_search_field.dart';
import 'package:lacoloc_front/presentation/widgets/app_top_bar.dart';
import 'package:lacoloc_front/presentation/widgets/lot_dialog.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/card_delete_button.dart';

/// Catalogue des lots de copropriété du propriétaire (indépendant des
/// immeubles — un lot peut exister avant d'être rattaché). Même layout
/// standard que l'Inventaire : `AppTopBar` en haut, listing à droite.
class LotsPage extends StatefulWidget {
  const LotsPage({super.key});

  @override
  State<LotsPage> createState() => _LotsPageState();
}

class _LotsPageState extends State<LotsPage> {
  late Future<List<ImmeubleLotModel>> _future;
  String _query = '';

  /// null = tous ; true = attribués ; false = non attribués.
  bool? _filterAttribue;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final ownerId = AuthService.currentUser?.id;
    setState(() {
      _future = ownerId == null
          ? Future.value(<ImmeubleLotModel>[])
          : ImmeubleLotsDatasource.listByOwner(ownerId, refresh: true);
    });
  }

  Future<void> _nouveauLot() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return;
    final created = await showLotDialog(context, ownerId: ownerId);
    if (created != null) _reload();
  }

  Future<void> _modifierLot(ImmeubleLotModel lot) async {
    final updated = await showLotDialog(
      context,
      ownerId: lot.ownerId,
      existing: lot,
    );
    if (updated != null) _reload();
  }

  Future<void> _supprimerLot(ImmeubleLotModel lot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce lot ?'),
        content: Text(
          'Le lot « ${lot.numeroLot} » sera supprimé définitivement'
          '${lot.immeubleNom != null ? " (il sera aussi détaché de « ${lot.immeubleNom} »)" : ""}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.deleteButtonStyle,
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ImmeubleLotsDatasource.delete(lot.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ImmeubleLotModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erreur : ${snap.error}'));
        }
        final all = snap.data ?? const <ImmeubleLotModel>[];
        final filtered = all.where((l) {
          if (_filterAttribue == true && l.immeubleId == null) return false;
          if (_filterAttribue == false && l.immeubleId != null) return false;
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return l.numeroLot.toLowerCase().contains(q) ||
              (l.nomCopropriete?.toLowerCase().contains(q) ?? false) ||
              (l.immeubleNom?.toLowerCase().contains(q) ?? false);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTopBar(
              title: 'Lots de copropriété',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: _nouveauLot,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouveau lot'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.outlined(
                    icon: const Icon(Icons.refresh),
                    onPressed: _reload,
                    tooltip: 'Actualiser',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final searchField = AppListSearchField(
                    hint: 'Rechercher (numéro, copropriété, immeuble)…',
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onChanged: (v) => setState(() => _query = v),
                  );
                  final chipsRow = Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _LotFilterChip(
                        label: 'Tous',
                        count: all.length,
                        selected: _filterAttribue == null,
                        onTap: () => setState(() => _filterAttribue = null),
                      ),
                      _LotFilterChip(
                        label: 'Attribués',
                        count: all.where((l) => l.immeubleId != null).length,
                        selected: _filterAttribue == true,
                        onTap: () => setState(() => _filterAttribue = true),
                      ),
                      _LotFilterChip(
                        label: 'Non attribués',
                        count: all.where((l) => l.immeubleId == null).length,
                        selected: _filterAttribue == false,
                        onTap: () => setState(() => _filterAttribue = false),
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: AppSpacing.sm),
                        chipsRow,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: AppSpacing.md),
                      Flexible(child: chipsRow),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        all.isEmpty
                            ? 'Aucun lot de copropriété pour le moment.'
                            : 'Aucun lot ne correspond à la recherche.',
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (_, i) => _LotRow(
                        lot: filtered[i],
                        onEdit: () => _modifierLot(filtered[i]),
                        onDelete: () => _supprimerLot(filtered[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _LotRow extends StatelessWidget {
  final ImmeubleLotModel lot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LotRow({required this.lot, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryFixed,
          child: Icon(Icons.apartment_outlined, color: AppColors.primary, size: 20),
        ),
        title: Text(lot.displayLabel,
            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            lot.typeLot.label,
            if (lot.tantiemes != null) '${lot.tantiemes!.toStringAsFixed(0)}‰',
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: lot.immeubleId != null
                    ? AppColors.tertiaryContainer
                    : AppColors.surfaceContainerHighest,
                borderRadius: AppRadius.borderSm,
              ),
              child: Text(
                lot.immeubleNom ?? 'Non attribué',
                style: AppTypography.labelSm,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Modifier',
              onPressed: onEdit,
            ),
            CardDeleteButton(onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

/// Chip compact (même style que `EdlFilterBar`) pour les filtres de la page.
class _LotFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _LotFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : AppColors.surfaceContainerLowest;
    final fg = selected ? AppColors.onPrimary : AppColors.onSurface;
    final badgeBg = selected
        ? AppColors.onPrimary.withValues(alpha: 0.18)
        : AppColors.surfaceContainerHigh;
    final borderColor = selected ? AppColors.primary : AppColors.outlineVariant;

    return InkWell(
      borderRadius: AppRadius.borderFull,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 13, color: fg),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: AppRadius.borderFull,
              ),
              child: Text(
                '$count',
                style: AppTypography.labelSm.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
