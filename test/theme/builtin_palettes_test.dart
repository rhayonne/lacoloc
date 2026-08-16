import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/theme/app_palette.dart';

/// Le contrat des palettes **intégrées** (réglées à la main dans
/// `app_palette.dart`, donc jamais passées par le correcteur de contraste de
/// `PaletteBuilder`). Personne ne les valide à notre place : c'est ici.
///
/// Ces tests existent surtout pour le thème **Sombre**, où l'erreur classique
/// est invisible à la relecture (« du gris clair sur du gris clair ») et ne se
/// voit qu'à l'usage, de nuit, par la personne qui subit l'écran.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void expectAtLeast(double ratio, double min, String what, String theme) {
  expect(
    ratio,
    greaterThanOrEqualTo(min),
    reason:
        '[$theme] $what : ${ratio.toStringAsFixed(2)}:1 — minimum $min:1.',
  );
}

void main() {
  const palettes = <String, AppPalette>{
    'Ardoise': AppPalettes.ardoise,
    'Ocre': AppPalettes.ocre,
    'Encre': AppPalettes.encre,
    'Sombre': AppPalettes.sombre,
  };

  group('Palettes intégrées — texte lisible (WCAG AA, 4.5:1)', () {
    palettes.forEach((nom, p) {
      test(nom, () {
        // Chaque couple ci-dessous porte du VRAI texte quelque part dans
        // l'app ; le commentaire dit où, pour qu'on sache ce qu'on casse en
        // touchant une valeur.
        final pairs = <String, (Color, Color)>{
          // Corps de texte, sur la page et sur une carte.
          'texte / page': (p.onSurface, p.surface),
          'texte / carte': (p.onSurface, p.surfaceContainerLowest),
          'texte secondaire / page': (p.onSurfaceVariant, p.surface),
          'texte secondaire / carte': (
            p.onSurfaceVariant,
            p.surfaceContainerLowest,
          ),
          // Les surfaces hautes servent de fond aux survols, chips et
          // en-têtes de tableau : le texte y atterrit aussi.
          'texte secondaire / surface haute': (
            p.onSurfaceVariant,
            p.surfaceContainerHighest,
          ),
          // Boutons pleins : le libellé posé sur la couleur.
          'libellé bouton principal': (p.onPrimary, p.primary),
          'libellé bouton information': (p.onSecondary, p.secondary),
          'libellé bouton succès': (p.onTertiary, p.tertiary),
          'libellé bouton erreur (Supprimer)': (p.onError, p.error),
          // Pastilles / badges : fond teinté + ses deux niveaux de texte.
          'texte sur pastille principale': (p.onPrimaryFixed, p.primaryFixed),
          'texte faible sur pastille principale': (
            p.onPrimaryFixedVariant,
            p.primaryFixed,
          ),
          'texte sur pastille information': (
            p.onSecondaryFixed,
            p.secondaryFixed,
          ),
          // Fond du bouton « Enregistrer » (AppTheme.saveButtonStyle).
          'libellé Enregistrer': (p.onTertiaryFixed, p.tertiaryFixed),
          'texte sur conteneur erreur': (p.onErrorContainer, p.errorContainer),
          // Snackbar : boîte inversée.
          'texte de snackbar': (p.inverseOnSurface, p.inverseSurface),
        };
        pairs.forEach((quoi, c) => expectAtLeast(
              contrast(c.$1, c.$2),
              4.5,
              quoi,
              nom,
            ));
      });
    });
  });

  group('Palettes intégrées — couleurs employées comme TEXTE', () {
    // `primary` n'est pas qu'un fond de bouton : c'est la couleur des liens
    // (`textButtonTheme`), du bouton bordé, de l'onglet actif et des icônes de
    // menu sélectionnées. Elle est donc lue directement sur le fond.
    palettes.forEach((nom, p) {
      test(nom, () {
        expectAtLeast(
          contrast(p.primary, p.surface),
          4.5,
          'lien / action en texte sur la page',
          nom,
        );
        expectAtLeast(
          contrast(p.primary, p.surfaceContainerLowest),
          4.5,
          'lien / action en texte sur une carte',
          nom,
        );
        expectAtLeast(
          contrast(p.error, p.surfaceContainerLowest),
          4.5,
          'message d\'erreur en texte sur une carte',
          nom,
        );
        expectAtLeast(
          contrast(p.tertiary, p.surfaceContainerLowest),
          4.5,
          'mention « validé » en texte sur une carte',
          nom,
        );
      });
    });
  });

  group('Palettes intégrées — éléments d\'interface (3:1)', () {
    palettes.forEach((nom, p) {
      test(nom, () {
        expectAtLeast(
          contrast(p.outline, p.surface),
          3.0,
          'bordure forte / page',
          nom,
        );
        // `*Container` est la variante VIVE, documentée comme réservée aux
        // grands éléments (pastilles, icônes, texte ≥ 18px) — jamais au corps
        // de texte. Le seuil qui s'y applique est donc celui du grand texte
        // (WCAG 1.4.3), pas celui du corps.
        expectAtLeast(
          contrast(p.onPrimaryContainer, p.primaryContainer),
          3.0,
          'grand texte / conteneur principal',
          nom,
        );
        // Une carte doit se distinguer du fond de page, sinon la mise en page
        // se réduit à une bouillie uniforme.
        expect(
          p.surfaceContainerLowest,
          isNot(equals(p.surface)),
          reason: '[$nom] la carte doit se détacher de la page.',
        );
      });
    });
  });

  group('Thème sombre — les règles propres à la nuit', () {
    const p = AppPalettes.sombre;

    test('est bien détecté comme sombre', () {
      expect(p.isDark, isTrue);
      for (final clair in [
        AppPalettes.ardoise,
        AppPalettes.ocre,
        AppPalettes.encre,
      ]) {
        expect(clair.isDark, isFalse);
      }
    });

    test('l\'élévation monte vers le CLAIR', () {
      // Règle nº1 du thème sombre : une carte plus foncée que la page se lit
      // comme un trou. Chaque palier doit donc être plus clair que le
      // précédent, en partant de la page.
      final echelle = <String, Color>{
        'page': p.surface,
        'carte (lowest)': p.surfaceContainerLowest,
        'low': p.surfaceContainerLow,
        'container': p.surfaceContainer,
        'high': p.surfaceContainerHigh,
        'highest': p.surfaceContainerHighest,
      };
      final noms = echelle.keys.toList();
      for (var i = 1; i < noms.length; i++) {
        final avant = echelle[noms[i - 1]]!.computeLuminance();
        final apres = echelle[noms[i]]!.computeLuminance();
        expect(
          apres,
          greaterThan(avant),
          reason:
              '« ${noms[i]} » doit être plus clair que « ${noms[i - 1]} » : '
              'en thème sombre, s\'élever c\'est s\'éclaircir.',
        );
      }
    });

    test('ni noir pur, ni blanc pur', () {
      // Le fond noir pur ne laisse pas de place aux paliers en dessous ; le
      // texte blanc pur « vibre » sur fond foncé (halation) en lecture longue.
      expect(p.surface.computeLuminance(), greaterThan(0.0));
      expect(
        contrast(p.onSurface, p.surface),
        lessThan(17.0),
        reason: 'texte trop éclatant pour une lecture longue de nuit',
      );
    });

    test('le texte posé sur une couleur d\'accent est FONCÉ', () {
      // Corollaire de l'éclaircissement des accents : écrire `Colors.white`
      // en dur sur un bouton de couleur devient une faute de lisibilité.
      for (final on in [p.onPrimary, p.onError, p.onTertiary, p.onSecondary]) {
        expect(
          on.computeLuminance(),
          lessThan(0.5),
          reason: 'sur fond d\'accent clair, le libellé doit être foncé',
        );
      }
    });

    test('les pastilles sont des fonds FONCÉS à texte clair', () {
      for (final couple in [
        (p.primaryFixed, p.onPrimaryFixed),
        (p.tertiaryFixed, p.onTertiaryFixed),
        (p.secondaryFixed, p.onSecondaryFixed),
      ]) {
        expect(couple.$1.computeLuminance(), lessThan(0.35));
        expect(couple.$2.computeLuminance(), greaterThan(0.35));
      }
    });
  });
}
