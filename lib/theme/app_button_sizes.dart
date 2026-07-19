import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';

/// ⭐ FONTE ÚNICA DE VERDADE das **dimensões** de botão da aplicação.
///
/// Assim como as cores vivem em `app_palette.dart`/`AppColors` e o espaçamento
/// em `AppSpacing`, **todo tamanho de botão** (altura, padding, tamanho de
/// ícone) mora aqui. Para deixar todos os botões do app mais altos/baixos,
/// mais/menos espaçados, mude os valores **neste arquivo** — nada de números
/// «em dur» espalhados pelas telas.
///
/// ── Cibles tactiles (referência da indústria) ───────────────────────────────
///   • Apple HIG (iOS)       → 44×44 pt minimum.
///   • Material Design (And.) → 48×48 dp minimum.
///   • WCAG 2.5.5 (Web)       → 44×44 px CSS minimum.
/// Insight-chave: o *visual* pode ser menor que o alvo — o que conta é a área
/// **tocável** (padding + hit area). Por isso [AppButtonSize.small] tem altura
/// visual de 36 mas mantém a área tocável ≥ 44 via [MaterialTapTargetSize].
///
/// COMO USAR:
///   • Nas telas, prefira o widget reutilizável `AppButton`
///     ([lib/presentation/widgets/app_button.dart]) — ele já lê estes tokens.
///   • Se precisar aplicar só a densidade (padding+altura) a um botão Material
///     cru, use [AppButtonSizes.density] fundido ao estilo de cor do tema:
///     `style: AppButtonSizes.density(AppButtonSize.compact).merge(AppTheme.saveButtonStyle)`.
enum AppButtonSize {
  /// Taille par DÉFAUT de l'app : formulaires, dialogues, actions de page.
  /// Hauteur 44 = « taille d'excellence » (cible tactile iOS HIG / WCAG 2.5.5),
  /// confortable sur mobile comme sur desktop. Padding horizontal aéré.
  standard,

  /// Même hauteur (44) mais padding horizontal plus serré : barres denses,
  /// popovers, boutons côte à côte sur mobile (où l'aéré déborderait).
  compact,

  /// Micro-actions en ligne : chips d'action, lignes de tableau. Hauteur
  /// visuelle 36, mais l'aire tactile reste ≥ 44 (tapTargetSize « padded »).
  small,
}

/// Spécification dimensionnelle d'une taille de bouton (immuable).
class AppButtonSpec {
  /// Hauteur cible du bouton (= dimension tactile principale).
  final double height;

  /// Padding interne (autour du contenu).
  final EdgeInsets padding;

  /// Taille des icônes accompagnant le libellé.
  final double iconSize;

  /// Faut-il « remplir » l'aire tactile à 48 même si [height] est plus petite ?
  /// (utile pour [AppButtonSize.small] : visuellement compact, tapable à 48).
  final bool padTapTarget;

  const AppButtonSpec({
    required this.height,
    required this.padding,
    required this.iconSize,
    this.padTapTarget = false,
  });

  /// Taille minimale à passer à un [ButtonStyle] (largeur libre, hauteur = cible).
  Size get minimumSize => Size(0, height);

  /// Stratégie de cible tactile Material correspondante.
  MaterialTapTargetSize get tapTargetSize => padTapTarget
      ? MaterialTapTargetSize.padded
      : MaterialTapTargetSize.shrinkWrap;
}

/// Catalogue des tailles + helpers pour les convertir en [ButtonStyle].
class AppButtonSizes {
  AppButtonSizes._();

  /// Cible tactile minimale absolue (iOS HIG / WCAG 2.5.5).
  static const double minTouchTarget = 44.0;

  /// Taille STANDARD (44 = cible tactile iOS/WCAG) — la valeur par défaut de
  /// l'app. Tous les `*ButtonTheme` et `*ButtonStyle` du thème s'y branchent :
  /// changer cette hauteur re-dimensionne TOUS les boutons de l'app d'un coup.
  static const AppButtonSpec standard = AppButtonSpec(
    height: 44,
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.lg, // 24
      vertical: AppSpacing.sm, // 8 (la hauteur mini pilote, pas le padding)
    ),
    iconSize: 18,
  );

  /// Taille COMPACTE (44pt iOS) — barres/popovers/cartes sur mobile.
  static const AppButtonSpec compact = AppButtonSpec(
    height: 44,
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.md, // 16
      vertical: AppSpacing.sm, // 8
    ),
    iconSize: 18,
  );

  /// Taille PETITE (36 visuel, 48 tactile) — micro-actions en ligne.
  static const AppButtonSpec small = AppButtonSpec(
    height: 36,
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.sm, // 8
      vertical: AppSpacing.xs, // 4
    ),
    iconSize: 16,
    padTapTarget: true,
  );

  /// Retourne le [AppButtonSpec] d'une [AppButtonSize].
  static AppButtonSpec of(AppButtonSize size) => switch (size) {
    AppButtonSize.standard => standard,
    AppButtonSize.compact => compact,
    AppButtonSize.small => small,
  };

  /// Surcouche de **densité** (padding + hauteur + cible tactile), **sans
  /// couleur**, à fusionner avec un style de couleur du thème :
  /// `AppButtonSizes.density(size).merge(AppTheme.saveButtonStyle)`.
  ///
  /// `merge` place cette densité en premier → son padding/minimumSize
  /// l'emporte, tandis que la couleur vient du style fusionné.
  static ButtonStyle density(AppButtonSize size) {
    final spec = of(size);
    return ButtonStyle(
      padding: WidgetStatePropertyAll(spec.padding),
      minimumSize: WidgetStatePropertyAll(spec.minimumSize),
      tapTargetSize: spec.tapTargetSize,
    );
  }
}
