import 'package:flutter/material.dart';

/// Formats dans lesquels on peut saisir une couleur.
///
/// huemint.com (et les autres générateurs) exportent selon le contexte : du
/// hex pour le web, du RGB 0–255, ou des flottants 0–1 pour iOS/macOS. Plutôt
/// que d'obliger à convertir à la main, on accepte les trois.
enum ColorFormat {
  hex('HEX', '#RRGGBB', 'Le format du web. Ex. : #006685'),
  rgb('RGB', 'R, G, B', 'Trois valeurs de 0 à 255. Ex. : 0, 102, 133'),
  apple(
    'iOS / macOS',
    'R G B (0–1)',
    'Trois flottants de 0 à 1, comme dans UIColor / SwiftUI. Ex. : 0 0.4 0.522',
  );

  const ColorFormat(this.label, this.hint, this.help);

  /// Nom affiché dans le sélecteur.
  final String label;

  /// Placeholder du champ.
  final String hint;

  /// Une phrase expliquant le format, montrée sous le champ.
  final String help;
}

/// Lecture/écriture d'une couleur dans les formats de [ColorFormat].
///
/// Toutes les fonctions de lecture sont **tolérantes** : espaces, virgules,
/// point-virgules, parenthèses et préfixes (`#`, `rgb(`) sont ignorés. Une
/// saisie invalide renvoie `null` — au caller de le dire à la personne.
class ColorCodec {
  ColorCodec._();

  /// Lit [input] dans le format [format]. `null` si la saisie est invalide.
  static Color? parse(String input, ColorFormat format) => switch (format) {
    ColorFormat.hex => parseHex(input),
    ColorFormat.rgb => parseRgb(input),
    ColorFormat.apple => parseApple(input),
  };

  /// Écrit [color] dans le format [format].
  static String format(Color color, ColorFormat format) => switch (format) {
    ColorFormat.hex => toHex(color),
    ColorFormat.rgb => toRgb(color),
    ColorFormat.apple => toApple(color),
  };

  /// `#006685`, `006685`, `#068` (forme courte) → [Color].
  static Color? parseHex(String input) {
    var s = input.trim().replaceAll('#', '').replaceAll(' ', '');
    if (s.length == 3) {
      // #068 → #006688
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length != 6) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  /// `0, 102, 133` · `rgb(0 102 133)` → [Color].
  static Color? parseRgb(String input) {
    final parts = _numbers(input);
    if (parts.length != 3) return null;
    if (parts.any((n) => n < 0 || n > 255)) return null;
    return Color.fromARGB(
      255,
      parts[0].round(),
      parts[1].round(),
      parts[2].round(),
    );
  }

  /// `0 0.4 0.522` · `UIColor(red: 0, green: 0.4, blue: 0.522, alpha: 1)`
  /// → [Color]. Un éventuel 4e nombre (alpha) est ignoré : l'app n'utilise pas
  /// de couleurs de thème translucides.
  static Color? parseApple(String input) {
    final parts = _numbers(input);
    if (parts.length < 3) return null;
    final rgb = parts.take(3).toList();
    if (rgb.any((n) => n < 0 || n > 1)) return null;
    return Color.fromARGB(
      255,
      (rgb[0] * 255).round(),
      (rgb[1] * 255).round(),
      (rgb[2] * 255).round(),
    );
  }

  static String toHex(Color c) {
    String two(double v) =>
        (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
  }

  static String toRgb(Color c) {
    int ch(double v) => (v * 255).round().clamp(0, 255);
    return '${ch(c.r)}, ${ch(c.g)}, ${ch(c.b)}';
  }

  static String toApple(Color c) {
    String f(double v) => v.toStringAsFixed(3);
    return '${f(c.r)} ${f(c.g)} ${f(c.b)}';
  }

  /// Extrait tous les nombres d'une chaîne, quels que soient les séparateurs
  /// (virgule, espace, parenthèses, libellés `red:`…).
  static List<double> _numbers(String input) => RegExp(r'-?\d*\.?\d+')
      .allMatches(input)
      .map((m) => double.tryParse(m.group(0)!))
      .whereType<double>()
      .toList();
}
