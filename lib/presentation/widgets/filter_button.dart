import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Bouton « Filtres » standard du système (déclencheur d'un popover de filtres).
///
/// Source unique du style : à utiliser **partout** où il y a un bouton de
/// filtres (page d'accueil, immeubles, inventaire…). Modifier l'apparence ici
/// la met à jour dans tout le système.
///
/// Affiche une icône, un libellé, un badge avec le nombre de filtres actifs et
/// un chevron qui s'inverse selon [isOpen].
class FilterButton extends StatelessWidget {
  /// Le popover associé est-il ouvert (chevron vers le haut + fond accentué).
  final bool isOpen;

  /// Nombre de filtres actifs (badge masqué si 0).
  final int activeCount;

  final VoidCallback onTap;

  /// Libellé affiché (par défaut « Filtres »).
  final String label;

  const FilterButton({
    super.key,
    required this.isOpen,
    required this.onTap,
    this.activeCount = 0,
    this.label = 'Filtres',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isOpen ? AppColors.primaryFixed : AppColors.surfaceContainerLow,
      borderRadius: AppRadius.borderFull,
      elevation: AppTheme.raisedButtonElevation,
      shadowColor: AppTheme.raisedButtonShadowColor,
      child: InkWell(
        borderRadius: AppRadius.borderFull,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w600),
              ),
              if (activeCount > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text('$activeCount',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onPrimary,
                        fontSize: 10,
                      )),
                ),
              ],
              const SizedBox(width: 3),
              Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 17, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
