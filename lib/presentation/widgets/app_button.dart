import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_theme.dart';

/// Variantes **sémantiques** de bouton (la COULEUR/le rôle, pas la taille).
///
/// Chaque variante correspond à un style de couleur déjà défini dans
/// [AppTheme] : on garde ainsi une seule source pour les couleurs (le thème)
/// et une seule pour les dimensions ([AppButtonSizes]).
enum AppButtonVariant {
  /// Action principale (bleu plein, élevé). Ex. « Connexion », « Voir détails ».
  primary,

  /// Enregistrer / Valider (vert clair) — [AppTheme.saveButtonStyle].
  save,

  /// Annuler / Fermer (bordé neutre) — [AppTheme.cancelButtonStyle].
  cancel,

  /// Supprimer / Réinitialiser (rouge) — [AppTheme.deleteButtonStyle].
  delete,

  /// Modifier (bordé bleu primaire) — [AppTheme.editButtonStyle].
  edit,

  /// Document / PDF (bordé bleu) — [AppTheme.documentButtonStyle].
  document,
}

/// ⭐ Bouton **standard réutilisable** de l'app.
///
/// Combine deux sources uniques :
///   • la **couleur/le rôle** via [AppButtonVariant] → styles de [AppTheme] ;
///   • la **taille** via [AppButtonSize] → dimensions de [AppButtonSizes].
///
/// À utiliser à la place des `ElevatedButton`/`FilledButton`/`OutlinedButton`
/// crus dès qu'on veut un bouton cohérent et re-dimensionnable globalement.
/// Pour changer l'allure de TOUS les boutons : couleurs → `AppTheme`, tailles →
/// `AppButtonSizes`. Aucun réglage « en dur » ici.
///
/// ```dart
/// AppButton.save(label: 'Enregistrer', onPressed: _save)          // standard
/// AppButton.primary(label: 'Connexion', icon: Icons.login,
///                   size: AppButtonSize.compact, onPressed: _go)  // barre dense
/// AppButton.cancel(label: 'Annuler', fullWidth: true, onPressed: _x) // dans Expanded
/// ```
class AppButton extends StatelessWidget {
  /// Rôle/couleur du bouton.
  final AppButtonVariant variant;

  /// Taille (dimensions) — défaut [AppButtonSize.standard].
  final AppButtonSize size;

  /// Libellé texte (tronqué en une ligne avec « … » si trop long).
  final String label;

  /// Icône optionnelle à gauche du libellé.
  final IconData? icon;

  /// Callback ; `null` = bouton désactivé.
  final VoidCallback? onPressed;

  /// Affiche un spinner à la place de l'icône et désactive le bouton.
  final bool isBusy;

  /// Occupe toute la largeur disponible (utile dans un `Expanded`/une colonne).
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.variant,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AppButtonSize.standard,
    this.isBusy = false,
    this.fullWidth = false,
  });

  // ── Fabriques sémantiques (raccourcis lisibles) ─────────────────────────────
  const AppButton.primary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    AppButtonSize size = AppButtonSize.standard,
    bool isBusy = false,
    bool fullWidth = false,
  }) : this(
          key: key,
          variant: AppButtonVariant.primary,
          label: label,
          onPressed: onPressed,
          icon: icon,
          size: size,
          isBusy: isBusy,
          fullWidth: fullWidth,
        );

  const AppButton.save({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon = Icons.check,
    AppButtonSize size = AppButtonSize.standard,
    bool isBusy = false,
    bool fullWidth = false,
  }) : this(
          key: key,
          variant: AppButtonVariant.save,
          label: label,
          onPressed: onPressed,
          icon: icon,
          size: size,
          isBusy: isBusy,
          fullWidth: fullWidth,
        );

  const AppButton.cancel({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    AppButtonSize size = AppButtonSize.standard,
    bool fullWidth = false,
  }) : this(
          key: key,
          variant: AppButtonVariant.cancel,
          label: label,
          onPressed: onPressed,
          icon: icon,
          size: size,
          fullWidth: fullWidth,
        );

  const AppButton.delete({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon = Icons.delete_outline,
    AppButtonSize size = AppButtonSize.standard,
    bool isBusy = false,
    bool fullWidth = false,
  }) : this(
          key: key,
          variant: AppButtonVariant.delete,
          label: label,
          onPressed: onPressed,
          icon: icon,
          size: size,
          isBusy: isBusy,
          fullWidth: fullWidth,
        );

  const AppButton.edit({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon = Icons.edit_outlined,
    AppButtonSize size = AppButtonSize.standard,
    bool fullWidth = false,
  }) : this(
          key: key,
          variant: AppButtonVariant.edit,
          label: label,
          onPressed: onPressed,
          icon: icon,
          size: size,
          fullWidth: fullWidth,
        );

  const AppButton.document({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon = Icons.description_outlined,
    AppButtonSize size = AppButtonSize.standard,
    bool fullWidth = false,
  }) : this(
          key: key,
          variant: AppButtonVariant.document,
          label: label,
          onPressed: onPressed,
          icon: icon,
          size: size,
          fullWidth: fullWidth,
        );

  /// Style de COULEUR du thème correspondant à la variante (source unique).
  ButtonStyle get _colorStyle => switch (variant) {
    AppButtonVariant.primary => AppTheme.elevatedPrimaryStyle,
    AppButtonVariant.save => AppTheme.saveButtonStyle,
    AppButtonVariant.cancel => AppTheme.cancelButtonStyle,
    AppButtonVariant.delete => AppTheme.deleteButtonStyle,
    AppButtonVariant.edit => AppTheme.editButtonStyle,
    AppButtonVariant.document => AppTheme.documentButtonStyle,
  };

  @override
  Widget build(BuildContext context) {
    // Densité (taille) d'abord → son padding/hauteur l'emporte ; la couleur
    // vient du style de variante fusionné par-dessous.
    final style = AppButtonSizes.density(size).merge(_colorStyle);
    final spec = AppButtonSizes.of(size);
    final onTap = isBusy ? null : onPressed;

    final Widget? leading = isBusy
        ? SizedBox(
            width: spec.iconSize,
            height: spec.iconSize,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        : (icon != null ? Icon(icon, size: spec.iconSize) : null);

    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    // Les variantes bordées passent par OutlinedButton, les pleines/élevée par
    // (Filled/Elevated)Button — cohérent avec les styles du thème.
    final bool outlined = variant == AppButtonVariant.cancel ||
        variant == AppButtonVariant.edit ||
        variant == AppButtonVariant.document;
    final bool elevated = variant == AppButtonVariant.primary;

    Widget button;
    if (leading != null) {
      if (outlined) {
        button =
            OutlinedButton.icon(onPressed: onTap, style: style, icon: leading, label: text);
      } else if (elevated) {
        button =
            ElevatedButton.icon(onPressed: onTap, style: style, icon: leading, label: text);
      } else {
        button =
            FilledButton.icon(onPressed: onTap, style: style, icon: leading, label: text);
      }
    } else {
      if (outlined) {
        button = OutlinedButton(onPressed: onTap, style: style, child: text);
      } else if (elevated) {
        button = ElevatedButton(onPressed: onTap, style: style, child: text);
      } else {
        button = FilledButton(onPressed: onTap, style: style, child: text);
      }
    }

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
