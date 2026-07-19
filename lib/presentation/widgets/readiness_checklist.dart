import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Un élément de la checklist « prêt à louer » : un prérequis, son état (fait ou
/// non) et, s'il n'est pas fait, une action pour le résoudre (lien/bouton).
class ChecklistItem {
  final String label;
  final String? hint;
  final bool done;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ChecklistItem({
    required this.label,
    required this.done,
    this.hint,
    this.actionLabel,
    this.onAction,
  });
}

/// Carte « Conditions pour louer » : liste de prérequis avec une barre de
/// progression et, pour chaque élément manquant, un lien direct pour le résoudre
/// (compléter le profil, créer une signature, ajouter un garant…).
///
/// Réutilisée par le tableau de bord du **locataire** et du **propriétaire** —
/// chacun fournit ses propres [items].
class ReadinessChecklist extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<ChecklistItem> items;

  const ReadinessChecklist({
    super.key,
    required this.items,
    this.title = 'Conditions pour louer',
    this.subtitle =
        'Complétez ces éléments pour pouvoir louer en toute sérénité.',
  });

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final doneCount = items.where((i) => i.done).length;
    final allDone = doneCount == total;
    final progress = total == 0 ? 1.0 : doneCount / total;

    // Une fois toutes les conditions remplies, la carte n'a plus rien à
    // signaler — elle disparaît (au lieu de rester affichée barrée en vert).
    if (allDone) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: allDone
              ? AppColors.success.withValues(alpha: 0.40)
              : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone ? Icons.verified_outlined : Icons.checklist_rtl,
                color: allDone ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTypography.titleLg)),
              Text(
                '$doneCount/$total',
                style: AppTypography.labelMd.copyWith(
                  color:
                      allDone ? AppColors.success : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.4),
              color: allDone ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            allDone ? 'Tout est prêt ✓' : subtitle,
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((it) => _ChecklistRow(item: it)),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final ChecklistItem item;
  const _ChecklistRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final done = item.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: done ? AppColors.success : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: AppTypography.bodyMd.copyWith(
                    color: done ? AppColors.onSurfaceVariant : null,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.hint != null && !done)
                  Text(
                    item.hint!,
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (!done && item.onAction != null)
            TextButton.icon(
              onPressed: item.onAction,
              icon: const Icon(Icons.arrow_forward, size: 16),
              iconAlignment: IconAlignment.end,
              label: Text(item.actionLabel ?? 'Résoudre'),
            ),
        ],
      ),
    );
  }
}
