import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Menu déroulant (accordéon) standard de l'application : une carte cliquable
/// avec icône, titre en gras et sous-titre, qui révèle son contenu au clic.
///
/// Reprend le style des accordéons existants (ex. Maintenance → Services) pour
/// qu'on voie clairement qu'il s'agit d'un élément actionnable. À réutiliser
/// partout où un bloc doit être repliable.
class AppAccordion extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry childrenPadding;
  final CrossAxisAlignment childrenCrossAxisAlignment;

  const AppAccordion({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.initiallyExpanded = false,
    this.childrenPadding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    this.childrenCrossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: icon != null ? Icon(icon) : null,
        title: Text(
          title,
          style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              )
            : null,
        childrenPadding: childrenPadding,
        expandedCrossAxisAlignment: childrenCrossAxisAlignment,
        children: children,
      ),
    );
  }
}
