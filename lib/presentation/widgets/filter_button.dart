import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';

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
      color: isOpen ? AppColors.primaryFixed : AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderFull,
        // Bordure teintée « primary » : le bouton était trop pâle et
        // passait inaperçu ; on lui donne de la présence avec la couleur du
        // thème, sans fond criard.
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.55)),
      ),
      elevation: AppTheme.raisedButtonElevation,
      shadowColor: AppTheme.raisedButtonShadowColor,
      child: InkWell(
        borderRadius: AppRadius.borderFull,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
              if (activeCount > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text('$activeCount',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onPrimary,
                        fontSize: 12,
                      )),
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 22, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
