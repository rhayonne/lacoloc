import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typographie de l'app — **trois rôles**, chacun avec un travail précis.
///
/// ## Pourquoi trois familles
///
/// 1. **Archivo** — le *display*. Une grotesque de signalétique : formes
///    serrées, allure administrative assumée. C'est la voix des titres, et
///    elle est utilisée **avec retenue** (titres de page, chiffres de tête).
///    Employée partout, elle deviendrait bruyante ; c'est justement pour ça
///    qu'elle n'habille que le haut de la hiérarchie.
///
/// 2. **Public Sans** — le *corps* et l'UI. Dessinée pour les interfaces
///    administratives lues en petit : ouvertures larges, accents français
///    nets, excellente à 12–16px dans un tableau dense. C'est exactement ce
///    qu'est cette app (baux, tantièmes, relevés) — le choix vient du métier,
///    pas d'une préférence esthétique.
///
/// 3. **IBM Plex Mono** — les *données*. Montants, index de compteurs,
///    tantièmes, codes de facture. Les chiffres tabulaires s'alignent
///    verticalement en colonne, ce qu'une police proportionnelle ne fait pas :
///    dans une table de loyers, une virgule qui ne tombe pas au même endroit
///    d'une ligne à l'autre se lit moins vite.
///
/// ## Quel token utiliser
///
/// - [displayLg]/[displayMd] — un chiffre de tête, un titre de page d'accueil.
/// - [headlineLg]/[headlineMd] — titre d'écran.
/// - [titleLg]/[titleLs] — titre de carte, de section.
/// - [bodyLg]/[bodyMd] — texte courant.
/// - [labelMd]/[labelSm] — libellés, légendes, en-têtes de colonne.
/// - [dataMd]/[dataSm] — **tout nombre qu'on compare d'une ligne à l'autre**
///   (montants, index, tantièmes, codes). Pas pour du texte.
class AppTypography {
  AppTypography._();

  /// Display — Archivo. Réservée aux titres : voir la doc de classe.
  static TextStyle get _display =>
      GoogleFonts.archivo(color: AppColors.onSurface);

  /// Corps / UI — Public Sans.
  static TextStyle get _base =>
      GoogleFonts.publicSans(color: AppColors.onSurface);

  /// Données — IBM Plex Mono (chiffres alignés).
  static TextStyle get _mono =>
      GoogleFonts.ibmPlexMono(color: AppColors.onSurface);

  // ── Display (Archivo) ──────────────────────────────────────────────────────
  // Interlettrage négatif : à ces corps, Archivo respire trop par défaut et
  // les titres perdent leur densité.
  static TextStyle get displayLg => _display.copyWith(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -1.44, // -0.03em
  );

  static TextStyle get displayMd => _display.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.9, // -0.025em
  );

  // ── Headline (Archivo) ─────────────────────────────────────────────────────
  static TextStyle get headlineLg => _display.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.56, // -0.02em
  );

  static TextStyle get headlineMd => _display.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.33, // -0.015em
  );

  // ── Title (Public Sans) ────────────────────────────────────────────────────
  // On repasse au corps ici : un titre de carte vit au milieu du texte, il doit
  // s'y accorder plutôt que trancher.
  static TextStyle get titleLg =>
      _base.copyWith(fontSize: 19, fontWeight: FontWeight.w600, height: 1.35);

  static TextStyle get titleLs =>
      _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3);

  // ── Body (Public Sans) ─────────────────────────────────────────────────────
  static TextStyle get bodyLg =>
      _base.copyWith(fontSize: 17, fontWeight: FontWeight.w400, height: 1.55);

  static TextStyle get bodyMd =>
      _base.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5);

  // ── Label (Public Sans) ────────────────────────────────────────────────────
  static TextStyle get labelMd => _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.07,
  );

  static TextStyle get labelSm => _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.18,
  );

  // ── Données (IBM Plex Mono) ────────────────────────────────────────────────
  /// Un montant, un index, un tantième — dans une fiche ou une cellule.
  static TextStyle get dataMd => _mono.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Même rôle, en plus discret (légende, sous-ligne).
  static TextStyle get dataSm => _mono.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// [TextTheme] Material 3 mappé sur les tokens ci-dessus. Les composants qui
  /// ne déclarent pas de style explicite héritent d'ici.
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLg,
    displayMedium: displayMd,
    displaySmall: headlineLg,
    headlineLarge: headlineLg,
    headlineMedium: headlineMd,
    headlineSmall: titleLg,
    titleLarge: titleLg,
    titleMedium: bodyLg,
    titleSmall: labelMd,
    bodyLarge: bodyLg,
    bodyMedium: bodyMd,
    bodySmall: labelSm,
    labelLarge: labelMd,
    labelMedium: labelMd,
    labelSmall: labelSm,
  );
}
