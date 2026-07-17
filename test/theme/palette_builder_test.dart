import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/theme/app_palette.dart';
import 'package:lacoloc_front/theme/palette_builder.dart';
import 'package:lacoloc_front/utils/color_codec.dart';

/// Le contrat de `PaletteBuilder` : **quelles que soient** les 3 couleurs
/// collées depuis huemint, la palette produite doit rester lisible. Ces tests
/// passent des palettes réelles (dont des cas volontairement mauvais) et
/// vérifient chaque couple texte/fond.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Les couples qui portent du texte : ils doivent tous atteindre AA (4.5:1).
void expectReadable(AppPalette p, String label) {
  final pairs = <String, (Color, Color)>{
    'texte / fond': (p.onSurface, p.surface),
    'texte secondaire / fond': (p.onSurfaceVariant, p.surface),
    'texte / carte': (p.onSurface, p.surfaceContainerLowest),
    'texte bouton principal': (p.onPrimary, p.primary),
    'texte bouton information': (p.onSecondary, p.secondary),
    'texte bouton succès': (p.onTertiary, p.tertiary),
    'texte bouton erreur': (p.onError, p.error),
    'texte sur pastille principale': (p.onPrimaryFixedVariant, p.primaryFixed),
    'texte sur pastille succès': (p.onTertiaryFixed, p.tertiaryFixed),
    'texte sur pastille information': (p.onSecondaryFixed, p.secondaryFixed),
    'texte sur pastille erreur': (p.onErrorContainer, p.errorContainer),
  };
  pairs.forEach((name, pair) {
    final c = contrast(pair.$1, pair.$2);
    expect(
      c,
      greaterThanOrEqualTo(4.5),
      reason:
          '[$label] « $name » : contraste ${c.toStringAsFixed(2)}:1 — '
          'en dessous du minimum AA de 4.5:1.',
    );
  });
}

void main() {
  // Des palettes telles que huemint.com les sort (fond / texte / accent),
  // plus des cas limites qu'un humain peut réellement coller.
  const cases = <String, (String, String, String)>{
    'clair classique': ('#F6FAFD', '#181C1F', '#006685'),
    'papier chaud + ocre': ('#FAF7F5', '#1F1815', '#C43E15'),
    'lagune': ('#EAF4F4', '#0B2027', '#178F8F'),
    'sable + prune': ('#F5EFE6', '#241E2B', '#6D3B7A'),
    'menthe froide': ('#EEF6F2', '#10261D', '#0F7B5A'),
    'vert acide (accent très clair)': ('#FFFFFF', '#101010', '#B4FF39'),
    'jaune vif (accent clair)': ('#FFFDF5', '#1A1A00', '#FFD400'),
    'accent quasi blanc (cas pathologique)': ('#FFFFFF', '#000000', '#FAFAFA'),
    'texte trop clair (cas pathologique)': ('#FFFFFF', '#D8D8D8', '#3355FF'),
    'fond sombre': ('#14161A', '#EDEFF2', '#5AC8FA'),
    'rouge en action (érreur doit rester distincte)': (
      '#FFF8F5',
      '#1C1210',
      '#E23B1E',
    ),
  };

  group('PaletteBuilder — lisibilité garantie', () {
    cases.forEach((label, seeds) {
      test(label, () {
        final d = PaletteBuilder.derive(
          surface: ColorCodec.parseHex(seeds.$1)!,
          ink: ColorCodec.parseHex(seeds.$2)!,
          action: ColorCodec.parseHex(seeds.$3)!,
        );
        expectReadable(d.palette, label);
      });
    });
  });

  group('PaletteBuilder — règles de conception', () {
    test('une palette saine ne déclenche aucune correction', () {
      final d = PaletteBuilder.derive(
        surface: ColorCodec.parseHex('#F6FAFD')!,
        ink: ColorCodec.parseHex('#181C1F')!,
        action: ColorCodec.parseHex('#006685')!,
      );
      expect(d.warnings, isEmpty);
    });

    test('une couleur illisible est corrigée ET signalée', () {
      // Texte gris très clair sur fond blanc : impossible à lire tel quel.
      final d = PaletteBuilder.derive(
        surface: ColorCodec.parseHex('#FFFFFF')!,
        ink: ColorCodec.parseHex('#D8D8D8')!,
        action: ColorCodec.parseHex('#3355FF')!,
      );
      expect(d.warnings, isNotEmpty, reason: 'la correction doit être dite');
      expect(contrast(d.palette.onSurface, d.palette.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('l\'erreur reste distincte de l\'action, même si l\'action est rouge',
        () {
      final d = PaletteBuilder.derive(
        surface: ColorCodec.parseHex('#FFF8F5')!,
        ink: ColorCodec.parseHex('#1C1210')!,
        action: ColorCodec.parseHex('#E23B1E')!, // orange-rouge
      );
      final hueAction = HSLColor.fromColor(d.palette.primary).hue;
      final hueError = HSLColor.fromColor(d.palette.error).hue;
      var d0 = (hueAction - hueError).abs() % 360;
      if (d0 > 180) d0 = 360 - d0;
      expect(
        d0,
        greaterThanOrEqualTo(20),
        reason:
            'Supprimer et le bouton principal doivent rester distinguables '
            '(écart de teinte ${d0.toStringAsFixed(1)}°).',
      );
    });

    test('les cartes se détachent du fond', () {
      for (final seeds in cases.values) {
        final d = PaletteBuilder.derive(
          surface: ColorCodec.parseHex(seeds.$1)!,
          ink: ColorCodec.parseHex(seeds.$2)!,
          action: ColorCodec.parseHex(seeds.$3)!,
        );
        expect(
          d.palette.surfaceContainerLowest,
          isNot(equals(d.palette.surface)),
          reason: 'une carte invisible sur le fond n\'est plus une carte',
        );
      }
    });
  });

  group('ColorCodec', () {
    test('lit les trois formats vers la même couleur', () {
      const target = Color(0xFF006685);
      expect(ColorCodec.parseHex('#006685'), target);
      expect(ColorCodec.parseHex('006685'), target);
      expect(ColorCodec.parseRgb('0, 102, 133'), target);
      expect(ColorCodec.parseRgb('rgb(0 102 133)'), target);
      // iOS/macOS : flottants 0–1 (tolérance d'arrondi d'un cran).
      final apple = ColorCodec.parseApple('0 0.400 0.522')!;
      expect((apple.g * 255).round(), closeTo(102, 1));
      expect((apple.b * 255).round(), closeTo(133, 1));
    });

    test('forme courte #068', () {
      expect(ColorCodec.parseHex('#068'), const Color(0xFF006688));
    });

    test('rejette ce qui n\'est pas une couleur', () {
      expect(ColorCodec.parseHex('pas une couleur'), isNull);
      expect(ColorCodec.parseHex('#12345'), isNull);
      expect(ColorCodec.parseRgb('300, 0, 0'), isNull); // hors 0–255
      expect(ColorCodec.parseApple('2 0 0'), isNull); // hors 0–1
      expect(ColorCodec.parseRgb('1, 2'), isNull); // pas assez de valeurs
    });

    test('écrit puis relit sans perte (hex)', () {
      const c = Color(0xFFC43E15);
      expect(ColorCodec.parseHex(ColorCodec.toHex(c)), c);
    });
  });
}
