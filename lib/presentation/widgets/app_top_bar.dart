import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Barre de titre **standard** de tout l'app (titre + actions).
///
/// Rendu unifié via [AppTheme.barDecoration] : fond distinct du fond de page +
/// ombre portée en bas (voir les tokens dans `AppColors` / `AppTheme`).
///
/// ## Règle du projet (non négociable)
///
/// **Toute** barre de titre passe par CE widget — liste, section, messagerie,
/// fiche… Il n'existe pas de « petite barre » écrite à la main pour un écran
/// particulier. Ce qui change d'un écran à l'autre, ce sont **les actions**
/// ([trailing]) : le gabarit, lui, est le même partout.
///
/// C'est pour cela que la barre impose une **hauteur minimale** égale à celle
/// d'un bouton standard ([AppButtonSizes.standard]) : sans elle, un écran sans
/// action (« Messages ») rendait une barre visiblement plus basse qu'un écran
/// avec boutons (« Mes Propriétés »), et le passage de l'un à l'autre faisait
/// sauter la mise en page. La barre garde donc le même gabarit qu'elle porte
/// des boutons ou non.
///
/// [FormPageHeader] délègue à ce widget (mêmes styles) et ajoute les actions
/// standard des écrans d'édition ([FormHeaderActions]).
///
/// **Bouton menu automatique** : si une [TopBarMenuScope] est présente au-dessus
/// (fournie par une coquille, ex. le super admin sur mobile) et qu'aucun
/// [leading] explicite n'est passé, la barre insère automatiquement le bouton
/// « menu » (hamburger) de la coquille. Une seule page-mère peut ainsi injecter
/// l'ouverture du tiroir dans la barre de titre de N'IMPORTE quelle page, sans
/// modifier chaque page. Ailleurs (scope absent) le comportement est inchangé.
class TopBarMenuScope extends InheritedWidget {
  /// Bouton « menu » à injecter (null = pas d'injection, ex. desktop).
  final Widget? menuButton;

  /// Balayage horizontal vers la GAUCHE sur la barre de titre (→ sous-menu
  /// suivant). null = geste désactivé.
  final VoidCallback? onSwipeLeft;

  /// Balayage horizontal vers la DROITE sur la barre de titre (→ précédent).
  final VoidCallback? onSwipeRight;

  const TopBarMenuScope({
    super.key,
    required this.menuButton,
    this.onSwipeLeft,
    this.onSwipeRight,
    required super.child,
  });

  static TopBarMenuScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TopBarMenuScope>();

  @override
  bool updateShouldNotify(TopBarMenuScope old) =>
      old.menuButton != menuButton ||
      old.onSwipeLeft != onSwipeLeft ||
      old.onSwipeRight != onSwipeRight;
}

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
    // `leading` explicite prioritaire ; sinon, bouton menu de la coquille (si
    // une [TopBarMenuScope] en fournit un — cas mobile du super admin).
    final scope = TopBarMenuScope.of(context);
    final effectiveLeading = leading ?? scope?.menuButton;

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

    final bar = Container(
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
                    if (effectiveLeading != null) ...[
                      effectiveLeading,
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
          // Hauteur minimale = celle d'un bouton standard, même sans action :
          // sinon une barre sans boutons (« Messages ») est plus basse qu'une
          // barre avec boutons (« Mes Propriétés ») et la mise en page saute
          // d'un écran à l'autre.
          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: AppButtonSizes.standard.height,
            ),
            child: Row(
              children: [
                if (effectiveLeading != null) ...[
                  effectiveLeading,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(child: titleBlock),
                ?trailing,
              ],
            ),
          );
        },
      ),
    );

    // Balayage horizontal RESTREINT à la barre de titre : si la coquille
    // fournit des callbacks (mobile), un drag horizontal sur CETTE barre change
    // de sous-menu. Le contenu, lui, ne navigue jamais au balayage.
    if (scope?.onSwipeLeft == null && scope?.onSwipeRight == null) return bar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -100) {
          scope?.onSwipeLeft?.call();
        } else if (v > 100) {
          scope?.onSwipeRight?.call();
        }
      },
      child: bar,
    );
  }
}
