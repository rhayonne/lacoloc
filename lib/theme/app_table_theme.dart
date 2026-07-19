import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Thème centralisé des **tableaux de liste** de l'app (Inventaire, Lots,
/// etc.) — couleurs, tailles et le style de survol (hover) des lignes.
///
/// Pourquoi un fichier séparé : toutes les tables "maison" de l'app (celles
/// construites à la main avec des `Row`/`Padding`, pas de `DataTable` Flutter)
/// doivent avoir le même look — même couleur de survol, même en-tête, même
/// densité de ligne. Modifier une valeur ici la met à jour **partout** où
/// [HoverTableRow] est utilisé, sans devoir chercher dans chaque écran.
///
/// COMMENT UTILISER :
/// - Enveloppez le contenu d'une ligne de tableau avec [HoverTableRow] pour
///   avoir le fond qui change au survol de la souris, gratuitement.
/// - Utilisez [AppTableTheme.headerTextStyle]/[headerBackgroundColor] pour la
///   ligne de titre (en-tête) des colonnes.
/// - Utilisez [AppTableTheme.rowPadding] pour le padding vertical standard
///   d'une ligne de données (garde toutes les tables à la même hauteur).
class AppTableTheme {
  AppTableTheme._();

  /// Couleur de survol (hover) d'une ligne de tableau — le bleu clair déjà
  /// utilisé pour l'élément actif du menu latéral (ex. « Inventaire »
  /// surligné), pour que le survol d'une ligne rappelle visuellement la
  /// même couleur "sélection" dans toute l'app.
  static Color get rowHoverColor => AppColors.primaryFixed.withValues(alpha: 0.35);

  /// Fond de la ligne d'en-tête (titres de colonnes).
  static Color get headerBackgroundColor => AppColors.surfaceContainerLow;

  /// Style de texte des titres de colonnes (petit, gras, espacé — majuscules
  /// dans les libellés eux-mêmes, ce style ne les transforme pas).
  static TextStyle get headerTextStyle => AppTypography.labelSm.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.onSurfaceVariant,
      );

  /// Padding horizontal/vertical standard d'une ligne de données (hors
  /// en-tête). Vertical volontairement compact : la hauteur d'une ligne doit
  /// rester proportionnée aux contrôles compacts (boutons, chips) de la page.
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: 4,
  );

  /// Couleur des séparateurs entre lignes (utiliser sur un `Divider(height: 1)`
  /// ou une bordure de conteneur de tableau).
  static Color get dividerColor => AppColors.outlineVariant;
}

/// Ligne de tableau avec **survol** (hover) de toute sa largeur — la couleur
/// vient de [AppTableTheme.rowHoverColor].
///
/// À utiliser en enveloppant le contenu d'une ligne (généralement un `Row`
/// avec les cellules) : le fond change dès que la souris entre dans la zone,
/// sans qu'aucun état ne soit géré par l'écran appelant.
///
/// Exemple :
/// ```dart
/// HoverTableRow(
///   child: Padding(
///     padding: AppTableTheme.rowPadding,
///     child: Row(children: [...cellules...]),
///   ),
/// )
/// ```
class HoverTableRow extends StatefulWidget {
  final Widget child;

  /// Callback optionnel de clic sur la ligne entière (en plus des actions
  /// internes de la ligne, ex. boutons d'édition).
  final VoidCallback? onTap;

  const HoverTableRow({super.key, required this.child, this.onTap});

  @override
  State<HoverTableRow> createState() => _HoverTableRowState();
}

class _HoverTableRowState extends State<HoverTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hovered ? AppTableTheme.rowHoverColor : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}
