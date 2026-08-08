import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_palette.dart';

/// Construit une [AppPalette] complète à partir de **3 couleurs** — celles
/// qu'on colle depuis huemint.com :
///
/// 1. **Fond de page** (le papier)
/// 2. **Texte** (l'encre)
/// 3. **Action** (les boutons)
///
/// ## Pourquoi seulement 3
///
/// Ce sont les trois qui décident vraiment de l'allure d'une interface. Le
/// reste (les 5 tons de surface, les bordures, le texte secondaire, les
/// couleurs « on- ») n'est pas un choix esthétique mais une **conséquence** :
/// il doit rester cohérent avec le fond et lisible. On le calcule.
///
/// ## Ce qu'on ne dérive pas, et pourquoi
///
/// **Succès (vert)** et **erreur (rouge)** restent sémantiques. Une palette
/// générée n'a aucune raison de « savoir » que supprimer est dangereux : si le
/// bouton Supprimer prenait la teinte d'accent du thème, l'interface
/// mentirait. On les garde donc verts/rouges, simplement **accordés** à la
/// chaleur du fond pour qu'ils n'aient pas l'air rapportés.
///
/// **Information (secondaire)** est dérivée par rotation de teinte depuis
/// l'action : c'est un contrepoids, il doit se distinguer de l'action sans
/// sortir de la famille.
///
/// ## Contraste
///
/// Chaque couple texte/fond est vérifié et **corrigé** si besoin (WCAG AA,
/// 4.5:1) : une couleur qui échoue est éclaircie ou assombrie du minimum
/// nécessaire. [PaletteDerivation.warnings] liste ce qui a été ajusté, pour
/// qu'on puisse le dire à la personne au lieu de le faire en douce.
class PaletteBuilder {
  PaletteBuilder._();

  /// Contraste minimum exigé pour du texte (WCAG AA).
  static const double _minTextContrast = 4.5;

  /// Contraste minimum pour un élément non textuel (bordure, gros pictogramme).
  static const double _minUiContrast = 3.0;

  /// Dérive la palette complète.
  ///
  /// [surface] = fond de page · [ink] = texte · [action] = boutons.
  static PaletteDerivation derive({
    required Color surface,
    required Color ink,
    required Color action,
  }) {
    final warnings = <String>[];

    // ── 1. Le papier ────────────────────────────────────────────────────────
    // On garde la teinte du fond et on décline les « étages » de l'interface
    // (page → carte → survol → sélection).
    final surfHsl = HSLColor.fromColor(surface);
    final light = surfHsl.lightness >= 0.5; // thème clair ?

    Color step(double delta) => _shift(surface, delta);

    // Les cartes se posent *au-dessus* du fond : plus claires en thème clair,
    // plus sombres en thème foncé. Mais si le fond est déjà au bout de
    // l'échelle (blanc pur, noir pur), il n'y a plus de place dans ce sens :
    // on part alors dans l'autre, sinon la carte serait invisible.
    final headroom = light
        ? 1.0 - surfHsl.lightness // combien de clair reste-t-il ?
        : surfHsl.lightness; // combien de sombre reste-t-il ?
    final canLift = headroom >= 0.05;
    final lift = light ? 1.0 : -1.0; // sens du « au-dessus »
    final containerLowest = canLift ? step(lift * 0.045) : step(lift * -0.035);

    final containerLow = light ? step(-0.025) : step(0.025);
    final container = light ? step(-0.05) : step(0.05);
    final containerHigh = light ? step(-0.075) : step(0.075);
    final containerHighest = light ? step(-0.10) : step(0.10);
    final surfaceDim = light ? step(-0.14) : step(0.14);
    final surfaceBright = light ? step(0.03) : step(-0.03);

    // ── 2. L'encre ──────────────────────────────────────────────────────────
    // Le texte ne vit pas que sur le fond de page : il est aussi sur les
    // cartes, dont la couleur diffère légèrement. On le corrige donc contre le
    // **plus défavorable des deux** — sinon un texte « valide » sur la page
    // devient limite sur une carte.
    Color worstBgFor(Color text) =>
        _contrast(text, surface) <= _contrast(text, containerLowest)
        ? surface
        : containerLowest;

    var onSurface = ink;
    if (_contrast(onSurface, worstBgFor(onSurface)) < _minTextContrast) {
      onSurface = _fixContrast(
        onSurface,
        worstBgFor(onSurface),
        _minTextContrast,
      );
      warnings.add(
        'La couleur de texte manquait de contraste sur le fond : elle a été '
        '${light ? 'assombrie' : 'éclaircie'} pour rester lisible.',
      );
    }
    // Texte secondaire : la même encre, adoucie — mais toujours ≥ 4.5:1, car
    // c'est encore du texte (libellés, légendes), pas de la décoration.
    var onSurfaceVariant = _mix(onSurface, surface, 0.32);
    if (_contrast(onSurfaceVariant, worstBgFor(onSurfaceVariant)) <
        _minTextContrast) {
      onSurfaceVariant = _fixContrast(
        onSurfaceVariant,
        worstBgFor(onSurfaceVariant),
        _minTextContrast,
      );
    }

    // Bordures : visibles mais discrètes. La bordure « forte » doit atteindre
    // 3:1 (c'est un élément d'interface, pas du texte).
    var outline = _mix(onSurface, surface, 0.55);
    if (_contrast(outline, surface) < _minUiContrast) {
      outline = _fixContrast(outline, surface, _minUiContrast);
    }
    final outlineVariant = _mix(onSurface, surface, 0.82);

    // ── 3. L'action ─────────────────────────────────────────────────────────
    // Un bouton plein porte du texte : sa couleur doit permettre du blanc ou
    // du noir à 4.5:1. Sinon on la corrige.
    var primary = action;
    var onPrimary = _bestOn(primary);
    if (_contrast(onPrimary, primary) < _minTextContrast) {
      primary = _fixContrast(primary, onPrimary, _minTextContrast, moveFirst: true);
      onPrimary = _bestOn(primary);
      warnings.add(
        'La couleur d\'action ne laissait pas assez de contraste pour le texte '
        'des boutons : elle a été ajustée.',
      );
    }

    final actionHsl = HSLColor.fromColor(primary);
    final primaryPill = _pill(primary, surface, light);
    final primaryFixedDim = _tint(primary, surface, light ? 0.62 : 0.48);

    // ── 4. L'information ────────────────────────────────────────────────────
    // Contrepoids de l'action : on tourne la teinte pour qu'on les distingue
    // au premier coup d'œil, sans quitter la famille du thème.
    var secondary = HSLColor.fromAHSL(
      1,
      (actionHsl.hue + 165) % 360,
      (actionHsl.saturation * 0.75).clamp(0.20, 0.70),
      light ? 0.30 : 0.68,
    ).toColor();
    if (_contrast(_bestOn(secondary), secondary) < _minTextContrast) {
      secondary = _fixContrast(
        secondary,
        _bestOn(secondary),
        _minTextContrast,
        moveFirst: true,
      );
    }

    // ── 5. Succès & erreur : sémantiques ───────────────────────────────────
    // Le vert emprunte un peu de la chaleur/froideur du papier pour ne pas
    // avoir l'air rapporté, tout en restant reconnaissable comme un vert.
    final warmth = surfHsl.hue;
    final tertiary = _semantic(
      baseHue: 152, // vert
      surfaceHue: warmth,
      light: light,
    );

    // Le rouge, lui, ne suit pas le fond : sa seule contrainte est de ne
    // jamais ressembler à l'action, sinon « Supprimer » et le bouton principal
    // deviennent interchangeables. On prend donc, parmi plusieurs rouges
    // acceptables, celui qui est le plus loin de l'action.
    final errorHue = _kErrorHues.reduce(
      (a, b) => _hueDistance(a, actionHsl.hue) >= _hueDistance(b, actionHsl.hue)
          ? a
          : b,
    );
    final error = HSLColor.fromAHSL(
      1,
      errorHue,
      0.62,
      light ? 0.36 : 0.62,
    ).toColor();

    // Les pastilles (fond pâle + son texte), garanties lisibles ensemble.
    final secondaryPill = _pill(secondary, surface, light);
    final tertiaryPill = _pill(tertiary, surface, light);
    final errorPill = _pill(error, surface, light);

    return PaletteDerivation(
      warnings: warnings,
      palette: AppPalette(
        surface: surface,
        surfaceDim: surfaceDim,
        surfaceBright: surfaceBright,
        surfaceContainerLowest: containerLowest,
        surfaceContainerLow: containerLow,
        surfaceContainer: container,
        surfaceContainerHigh: containerHigh,
        surfaceContainerHighest: containerHighest,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        inverseSurface: _shift(onSurface, light ? 0.10 : -0.10),
        inverseOnSurface: _shift(surface, light ? -0.02 : 0.02),
        outline: outline,
        outlineVariant: outlineVariant,
        surfaceTint: primary,
        surfaceVariant: containerHighest,

        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: _lighten(primary, 0.12),
        onPrimaryContainer: primaryPill.onFixed,
        inversePrimary: _tint(primary, Colors.white, 0.55),
        primaryFixed: primaryPill.fixed,
        primaryFixedDim: primaryFixedDim,
        onPrimaryFixed: primaryPill.onFixed,
        onPrimaryFixedVariant: primaryPill.onFixedVariant,

        secondary: secondary,
        onSecondary: _bestOn(secondary),
        secondaryContainer: _lighten(secondary, 0.18),
        onSecondaryContainer: secondaryPill.onFixed,
        secondaryFixed: secondaryPill.fixed,
        secondaryFixedDim: _tint(secondary, surface, 0.60),
        onSecondaryFixed: secondaryPill.onFixed,
        onSecondaryFixedVariant: secondaryPill.onFixedVariant,

        tertiary: tertiary,
        onTertiary: _bestOn(tertiary),
        tertiaryContainer: _lighten(tertiary, 0.18),
        onTertiaryContainer: tertiaryPill.onFixed,
        tertiaryFixed: tertiaryPill.fixed,
        tertiaryFixedDim: _tint(tertiary, surface, 0.58),
        onTertiaryFixed: tertiaryPill.onFixed,
        onTertiaryFixedVariant: tertiaryPill.onFixedVariant,

        error: error,
        onError: _bestOn(error),
        errorContainer: errorPill.fixed,
        onErrorContainer: errorPill.onFixed,

        shadowTint: _deepen(surface, 0.72),
      ),
    );
  }

  /// Rouges acceptables pour « danger ». On choisit celui qui est le plus loin
  /// de la couleur d'action : si l'action est déjà rouge, « Supprimer » doit
  /// rester distinguable du bouton principal. C'est la seule contrainte du
  /// rouge — contrairement au vert, il ne suit pas la teinte du papier, car la
  /// lisibilité de l'avertissement prime sur l'harmonie.
  static const List<double> _kErrorHues = [352, 2, 12, 342, 20];

  /// Une **pastille** : un fond pâle tiré de [base], et les deux niveaux de
  /// texte qui s'y posent — tous vérifiés à 4.5:1 *contre ce fond-là*.
  ///
  /// C'est indispensable pour les thèmes sombres : là, la pastille est sombre,
  /// donc son texte doit être **clair**. Une formule qui suppose « pastille
  /// claire → texte foncé » produit du texte noir sur fond noir.
  static ({Color fixed, Color onFixed, Color onFixedVariant}) _pill(
    Color base,
    Color surface,
    bool light,
  ) {
    final fixed = _tint(base, surface, light ? 0.84 : 0.72);
    final fixedIsLight = _luminance(fixed) > 0.4;
    // Le texte part de la couleur de base, poussé à l'opposé de la pastille.
    var onFixed = _deepen(base, fixedIsLight ? 0.16 : 0.92);
    onFixed = _fixContrast(onFixed, fixed, _minTextContrast);
    var onFixedVariant = _deepen(base, fixedIsLight ? 0.30 : 0.80);
    onFixedVariant = _fixContrast(onFixedVariant, fixed, _minTextContrast);
    return (fixed: fixed, onFixed: onFixed, onFixedVariant: onFixedVariant);
  }

  // ── Fabrique d'une couleur sémantique (le vert) accordée au fond ───────────
  static Color _semantic({
    required double baseHue,
    required double surfaceHue,
    required bool light,
    double minSaturation = 0.45,
  }) {
    // On tire la teinte de 8° vers celle du papier : assez pour que la couleur
    // appartienne au thème, trop peu pour qu'on cesse de la reconnaître.
    final pull = _shortestHueStep(baseHue, surfaceHue).clamp(-8.0, 8.0);
    return HSLColor.fromAHSL(
      1,
      (baseHue + pull) % 360,
      minSaturation,
      light ? 0.30 : 0.62,
    ).toColor();
  }

  // ── Utilitaires couleur ───────────────────────────────────────────────────

  /// Décale la luminosité de [delta] (±) en gardant teinte et saturation.
  static Color _shift(Color c, double delta) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  static Color _lighten(Color c, double d) => _shift(c, d);

  /// Assombrit et sature légèrement — pour les textes « on container ».
  static Color _deepen(Color c, double target) {
    final h = HSLColor.fromColor(c);
    return h
        .withLightness(target.clamp(0.0, 1.0))
        .withSaturation(math.min(1.0, h.saturation * 1.1))
        .toColor();
  }

  /// Mélange [a] vers [b] de [t] (0 = a, 1 = b).
  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  /// Teinte pâle de [c] posée sur [bg] — garde un peu de la couleur.
  static Color _tint(Color c, Color bg, double t) => _mix(c, bg, t);

  /// Noir ou blanc, selon ce qui contraste le mieux avec [bg].
  static Color _bestOn(Color bg) =>
      _contrast(Colors.white, bg) >= _contrast(Colors.black, bg)
      ? Colors.white
      : Colors.black;

  /// Luminance relative (WCAG).
  static double _luminance(Color c) => c.computeLuminance();

  /// Rapport de contraste WCAG entre deux couleurs (1 → 21).
  static double _contrast(Color a, Color b) {
    final la = _luminance(a);
    final lb = _luminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Éclaircit/assombrit [c] jusqu'à atteindre [target] de contraste avec
  /// [against]. Avance par petits pas pour ne bouger que du minimum
  /// nécessaire — on veut corriger la couleur, pas la remplacer.
  ///
  /// [moveFirst] : on déplace [c] (utile quand `against` est le blanc/noir du
  /// texte et qu'on veut ajuster le fond du bouton).
  static Color _fixContrast(
    Color c,
    Color against,
    double target, {
    bool moveFirst = false,
  }) {
    // On s'éloigne de `against` : s'il est clair, on assombrit, et vice versa.
    final againstIsLight = _luminance(against) > 0.5;
    final dir = againstIsLight ? -1.0 : 1.0;
    var out = c;
    for (var i = 0; i < 40; i++) {
      if (_contrast(out, against) >= target) return out;
      out = _shift(out, dir * 0.025);
      final l = HSLColor.fromColor(out).lightness;
      if (l <= 0.0 || l >= 1.0) break;
    }
    // Cas désespéré (couleur saturée coincée) : on tombe sur le noir/blanc.
    return _contrast(out, against) >= target ? out : _bestOn(against);
  }

  /// Distance angulaire entre deux teintes (0–180).
  static double _hueDistance(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  /// Pas signé le plus court de [from] vers [to] sur le cercle des teintes.
  static double _shortestHueStep(double from, double to) {
    var d = (to - from) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }
}

/// Résultat d'une dérivation : la palette + ce qui a dû être corrigé.
@immutable
class PaletteDerivation {
  final AppPalette palette;

  /// Ce que le système a ajusté tout seul pour garder l'interface lisible.
  /// Vide = les couleurs fournies passaient telles quelles.
  final List<String> warnings;

  const PaletteDerivation({required this.palette, required this.warnings});
}
