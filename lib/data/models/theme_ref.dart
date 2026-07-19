import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_palette.dart';
import 'package:lacoloc_front/theme/palette_builder.dart';
import 'package:lacoloc_front/utils/color_codec.dart';

/// Un thème tel qu'il est stocké en base (`Themes_Reference`).
///
/// Deux natures :
/// - **intégré** ([isBuiltin]) — sa palette est réglée à la main dans
///   `app_palette.dart` (Ocre, Ardoise, Encre). Pas de couleurs sources, pas
///   supprimable ; on peut seulement l'activer/désactiver ou en faire le thème
///   par défaut.
/// - **personnalisé** — créé par le super admin à partir de **3 couleurs**
///   (fond, texte, action) collées depuis huemint.com. Le reste de la palette
///   est dérivé par [PaletteBuilder].
@immutable
class ThemeRef {
  final int id;
  final String code;
  final String label;
  final String? description;

  /// Les 3 couleurs sources. `null` sur un thème intégré.
  final Color? colorSurface; // Fond de page
  final Color? colorOnSurface; // Texte
  final Color? colorPrimary; // Action (boutons)

  final bool isBuiltin;

  /// Proposé aux utilisateurs dans « Mon profil ».
  final bool isActive;

  /// Thème des visiteurs et des nouveaux comptes.
  final bool isDefault;

  final int ordre;

  const ThemeRef({
    required this.id,
    required this.code,
    required this.label,
    this.description,
    this.colorSurface,
    this.colorOnSurface,
    this.colorPrimary,
    this.isBuiltin = false,
    this.isActive = true,
    this.isDefault = false,
    this.ordre = 0,
  });

  /// La palette complète de ce thème.
  ///
  /// Intégré → la palette réglée à la main. Personnalisé → dérivée des 3
  /// couleurs. Si un thème personnalisé est incomplet (ne devrait pas arriver,
  /// la base l'interdit), on retombe sur la palette par défaut plutôt que de
  /// planter l'app sur une question d'apparence.
  AppPalette get palette => derivation?.palette ?? _builtinOrFallback;

  /// La dérivation (palette + corrections de contraste appliquées), ou `null`
  /// pour un thème intégré — il n'y a rien à dériver.
  PaletteDerivation? get derivation {
    final s = colorSurface, o = colorOnSurface, p = colorPrimary;
    if (isBuiltin || s == null || o == null || p == null) return null;
    return PaletteBuilder.derive(surface: s, ink: o, action: p);
  }

  AppPalette get _builtinOrFallback =>
      AppPalettes.byCode(code) ?? AppPalettes.ardoise;

  factory ThemeRef.fromMap(Map<String, dynamic> map) => ThemeRef(
    id: (map['id'] as num).toInt(),
    code: map['code'] as String,
    label: map['label'] as String,
    description: map['description'] as String?,
    colorSurface: ColorCodec.parseHex((map['color_surface'] as String?) ?? ''),
    colorOnSurface: ColorCodec.parseHex(
      (map['color_on_surface'] as String?) ?? '',
    ),
    colorPrimary: ColorCodec.parseHex((map['color_primary'] as String?) ?? ''),
    isBuiltin: (map['is_builtin'] as bool?) ?? false,
    isActive: (map['is_active'] as bool?) ?? true,
    isDefault: (map['is_default'] as bool?) ?? false,
    ordre: (map['ordre'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toInsert() => {
    'code': code,
    'label': label,
    if (description != null && description!.isNotEmpty)
      'description': description,
    if (colorSurface != null) 'color_surface': ColorCodec.toHex(colorSurface!),
    if (colorOnSurface != null)
      'color_on_surface': ColorCodec.toHex(colorOnSurface!),
    if (colorPrimary != null) 'color_primary': ColorCodec.toHex(colorPrimary!),
    'is_builtin': isBuiltin,
    'is_active': isActive,
    'ordre': ordre,
  };
}
