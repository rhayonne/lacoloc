import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Pop-up de sélection d'un immeuble pour démarrer un nouvel état des lieux.
/// Affiche pour chaque immeuble des chips bail (collectif/individuel) et
/// location (meublée/non meublée). Retourne l'immeuble choisi ou null.
Future<ImmeublesModel?> showSelectImmeubleDialog(
  BuildContext context,
  List<ImmeublesModel> immeubles,
) {
  return showDialog<ImmeublesModel>(
    context: context,
    builder: (_) => _SelectImmeubleDialog(immeubles: immeubles),
  );
}

class _SelectImmeubleDialog extends StatelessWidget {
  final List<ImmeublesModel> immeubles;

  const _SelectImmeubleDialog({required this.immeubles});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Sélectionner l'immeuble",
                style: AppTypography.titleLg,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "Choisissez l'immeuble pour démarrer l'état des lieux.",
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (immeubles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    "Aucun immeuble enregistré.",
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: immeubles.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final imm = immeubles[i];
                      return _ImmeubleTile(
                        immeuble: imm,
                        onTap: () => Navigator.of(context).pop(imm),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImmeubleTile extends StatelessWidget {
  final ImmeublesModel immeuble;
  final VoidCallback onTap;

  const _ImmeubleTile({required this.immeuble, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bailLabel = immeuble.bailIndividuel
        ? 'Bail individuel'
        : 'Bail collectif';
    final meubleLabel = switch (immeuble.locationMeuble) {
      true => 'Meublée',
      false => 'Non meublée',
      _ => 'Location ?',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              immeuble.name,
              style: AppTypography.titleLg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (immeuble.address != null && immeuble.address!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                immeuble.address!,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _Chip(label: bailLabel),
                _Chip(label: meubleLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
