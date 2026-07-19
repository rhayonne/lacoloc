import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_palette.dart';
import 'package:lacoloc_front/theme/theme_controller.dart';

/// Tokens de couleur de l'app — **le seul point d'accès aux couleurs** depuis
/// les écrans.
///
/// ## Important : ces tokens ne sont plus des constantes
///
/// Chaque token lit la **palette courante** ([ThemeController.palette]), pour
/// que l'utilisateur puisse changer de thème depuis son profil. Conséquence
/// pratique : on ne peut plus écrire `const Icon(color: AppColors.primary)`.
/// Retirez simplement le `const` (le compilateur vous le dira).
///
/// ## Que choisir
///
/// - [primary] — l'action principale, la décision, ce qui est actif. Dans le
///   thème par défaut c'est l'ocre : la couleur de l'annotation, du trait que
///   l'on pose sur un relevé.
/// - [secondary] — un **état**, une information. Pas une action.
/// - [success] / [tertiary] — validé, signé, payé.
/// - [error] — danger, suppression, litige.
/// - `surface*` — les fonds, du plus bas ([surfaceContainerLowest], les cartes)
///   au plus haut. Le fond de page est [surface].
/// - [onSurface] pour le texte principal, [onSurfaceVariant] pour le secondaire.
///
/// Les valeurs, leurs contrastes et le raisonnement derrière chaque teinte sont
/// documentés dans `app_palette.dart`. Pour changer l'apparence de l'app,
/// modifiez une palette là-bas — jamais une couleur en dur dans un écran.
class AppColors {
  AppColors._();

  static AppPalette get _p => ThemeController.palette;

  // ── Surfaces / neutres ─────────────────────────────────────────────────────
  static Color get surface => _p.surface;
  static Color get surfaceDim => _p.surfaceDim;
  static Color get surfaceBright => _p.surfaceBright;
  static Color get surfaceContainerLowest => _p.surfaceContainerLowest;
  static Color get surfaceContainerLow => _p.surfaceContainerLow;
  static Color get surfaceContainer => _p.surfaceContainer;
  static Color get surfaceContainerHigh => _p.surfaceContainerHigh;
  static Color get surfaceContainerHighest => _p.surfaceContainerHighest;
  static Color get onSurface => _p.onSurface;
  static Color get onSurfaceVariant => _p.onSurfaceVariant;
  static Color get inverseSurface => _p.inverseSurface;
  static Color get inverseOnSurface => _p.inverseOnSurface;
  static Color get outline => _p.outline;
  static Color get outlineVariant => _p.outlineVariant;
  static Color get surfaceTint => _p.surfaceTint;
  static Color get surfaceVariant => _p.surfaceVariant;

  // ── Primary — action / décision / annotation ───────────────────────────────
  static Color get primary => _p.primary;
  static Color get onPrimary => _p.onPrimary;
  static Color get primaryContainer => _p.primaryContainer;
  static Color get onPrimaryContainer => _p.onPrimaryContainer;
  static Color get inversePrimary => _p.inversePrimary;
  static Color get primaryFixed => _p.primaryFixed;
  static Color get primaryFixedDim => _p.primaryFixedDim;
  static Color get onPrimaryFixed => _p.onPrimaryFixed;
  static Color get onPrimaryFixedVariant => _p.onPrimaryFixedVariant;

  // ── Secondary — état / information ─────────────────────────────────────────
  static Color get secondary => _p.secondary;
  static Color get onSecondary => _p.onSecondary;
  static Color get secondaryContainer => _p.secondaryContainer;
  static Color get onSecondaryContainer => _p.onSecondaryContainer;
  static Color get secondaryFixed => _p.secondaryFixed;
  static Color get secondaryFixedDim => _p.secondaryFixedDim;
  static Color get onSecondaryFixed => _p.onSecondaryFixed;
  static Color get onSecondaryFixedVariant => _p.onSecondaryFixedVariant;

  // ── Tertiary — validé / signé / payé ───────────────────────────────────────
  static Color get tertiary => _p.tertiary;
  static Color get onTertiary => _p.onTertiary;
  static Color get tertiaryContainer => _p.tertiaryContainer;
  static Color get onTertiaryContainer => _p.onTertiaryContainer;
  static Color get tertiaryFixed => _p.tertiaryFixed;
  static Color get tertiaryFixedDim => _p.tertiaryFixedDim;
  static Color get onTertiaryFixed => _p.onTertiaryFixed;
  static Color get onTertiaryFixedVariant => _p.onTertiaryFixedVariant;

  // ── Success — alias sémantique du Tertiary ─────────────────────────────────
  // Un « ✓ » et un « bail signé » doivent avoir la même couleur : on garde donc
  // un seul vert dans l'app, exposé sous deux noms selon l'intention.
  static Color get success => _p.tertiary;
  static Color get onSuccess => _p.onTertiary;
  static Color get successContainer => _p.tertiaryContainer;
  static Color get onSuccessContainer => _p.onTertiaryContainer;
  static Color get successFixed => _p.tertiaryFixed;
  static Color get onSuccessFixed => _p.onTertiaryFixed;

  // ── Error — danger / suppression / litige ──────────────────────────────────
  static Color get error => _p.error;
  static Color get onError => _p.onError;
  static Color get errorContainer => _p.errorContainer;
  static Color get onErrorContainer => _p.onErrorContainer;

  // ── Fond de page ───────────────────────────────────────────────────────────
  static Color get background => _p.surface;
  static Color get onBackground => _p.onSurface;

  /// Teinte des ombres (jamais du noir pur : ça « salit » un fond coloré).
  static Color get shadowTint => _p.shadowTint;

  // ── Interactions / survol ─────────────────────────────────────────────────
  /// Survol d'une **cellule cliquable** — utilisé par la grille de l'agenda
  /// (créneaux de 30 min). Teinte primaire semi-opaque posée *par-dessus* le
  /// fond de la cellule, donc visible quel que soit ce fond (dispo/pause/hors
  /// plage). Ajuster l'alpha pour la rendre plus ou moins voyante.
  static Color get hoverCell => _p.primary.withValues(alpha: 0.25);

  /// Bordure de survol de la cellule (accentue le contour au hover).
  static Color get hoverCellBorder => _p.primary;

  // ═══════════════════════════════════════════════════════════════════════════
  // TOKENS SÉMANTIQUES — Barre de titre & menu latéral
  // Point unique de configuration : changez ces valeurs pour modifier
  // l'apparence de TOUTES les barres de titre (FormPageHeader / AppTopBar) et
  // du menu latéral (AppNavSidebar) d'un seul coup. La décoration prête à
  // l'emploi de la barre est dans `AppTheme.barDecoration`.
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Barre de titre (FormPageHeader / AppTopBar) ────────────────────────────
  /// Fond de la barre — volontairement **distinct** du fond de page ([surface])
  /// pour la détacher visuellement.
  static Color get barBackground => _p.surfaceContainerLowest;

  /// Couleur (semi-transparente) de l'**ombre portée** sous la barre.
  static Color get barShadow => _p.shadowTint.withValues(alpha: 0.12);

  // ── Menu latéral (AppNavSidebar) ───────────────────────────────────────────
  /// Fond d'un **item de menu sélectionné** (feuille).
  static Color get navItemSelected => _p.primaryFixed.withValues(alpha: 0.45);

  /// Fond du **bloc d'un groupe déplié** (en-tête + sous-menus).
  static Color get navGroupBackground =>
      _p.primaryFixed.withValues(alpha: 0.22);

  /// Fond du **sous-menu sélectionné** — un peu plus marqué que le groupe.
  static Color get navChildSelected => _p.primaryFixed.withValues(alpha: 0.60);

  /// Survol (hover) des items / sous-menus du menu latéral.
  static Color get navHover => _p.surfaceContainerLow;

  /// Trait d'arborescence des sous-menus (partie neutre).
  static Color get navConnector => _p.outlineVariant;

  /// Trait d'arborescence coloré (du haut jusqu'au sous-menu actif) + tiret actif.
  static Color get navConnectorActive => _p.primary;

  /// [ColorScheme] dérivé de la palette courante. Material 3 distribue
  /// automatiquement ces couleurs dans les composants qui utilisent le thème.
  static ColorScheme get lightScheme => ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    inversePrimary: inversePrimary,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    surfaceDim: surfaceDim,
    surfaceBright: surfaceBright,
    inverseSurface: inverseSurface,
    onInverseSurface: inverseOnSurface,
    outline: outline,
    outlineVariant: outlineVariant,
    surfaceTint: surfaceTint,
  );
}
