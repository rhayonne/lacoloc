import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Barre de titre **standard** de tout l'app (titre + actions).
///
/// Rendu unifié via [AppTheme.barDecoration] : fond distinct du fond de page +
/// ombre portée en bas (voir les tokens dans `AppColors` / `AppTheme`).
/// **Utiliser CE widget partout où l'on a une barre de titre** (liste, section,
/// formulaire…). Le modèle de référence est la barre « Fournisseurs ».
///
/// [FormPageHeader] délègue à ce widget (mêmes styles) et ajoute les actions
/// standard des écrans d'édition ([FormHeaderActions]).
class AppTopBar extends StatelessWidget {
  final String title;

  /// Widget à gauche du titre (ex. bouton retour).
  final Widget? leading;

  /// Widget(s) à droite du titre (ex. bouton « Ajouter »).
  final Widget? trailing;

  /// Sous-titre optionnel affiché sous le titre.
  final String? subtitle;

  const AppTopBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.titleLg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            style: AppTypography.bodyMd,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    return Container(
      decoration: AppTheme.barDecoration,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.barMargin,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En dessous de ~640 px : on empile (titre au-dessus, actions
          // dessous, défilables) pour éviter d'écraser le titre.
          final stack = constraints.maxWidth < 640 && trailing != null;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(child: titleBlock),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: trailing!,
                ),
              ],
            );
          }
          return Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(child: titleBlock),
              ?trailing,
            ],
          );
        },
      ),
    );
  }
}
