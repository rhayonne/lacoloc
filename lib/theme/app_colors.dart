import 'package:flutter/material.dart';

/// Paleta de cores do app, espelhando `pallete.md`.
/// Centralizada aqui para que qualquer alteração se propague via [ColorScheme].
class AppColors {
  AppColors._();

  // Surface
  static const Color surface = Color(0xFFF6FAFD);
  static const Color surfaceDim = Color(0xFFD6DADE);
  static const Color surfaceBright = Color(0xFFF6FAFD);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F4F8);
  static const Color surfaceContainer = Color(0xFFEAEEF2);
  static const Color surfaceContainerHigh = Color(0xFFE5E9EC);
  static const Color surfaceContainerHighest = Color(0xFFDFE3E6);
  static const Color onSurface = Color(0xFF181C1F);
  static const Color onSurfaceVariant = Color(0xFF3E484E);
  static const Color inverseSurface = Color(0xFF2C3134);
  static const Color inverseOnSurface = Color(0xFFEDF1F5);
  static const Color outline = Color(0xFF6E797F);
  static const Color outlineVariant = Color(0xFFBEC8CF);
  static const Color surfaceTint = Color(0xFF006685);
  static const Color surfaceVariant = Color(0xFFDFE3E6);

  // Primary (Blue) - ações principais e branding
  static const Color primary = Color(0xFF006685);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF31A2CC);
  static const Color onPrimaryContainer = Color(0xFF003445);
  static const Color inversePrimary = Color(0xFF6DD2FE);
  static const Color primaryFixed = Color(0xFFBFE9FF);
  static const Color primaryFixedDim = Color(0xFF6DD2FE);
  static const Color onPrimaryFixed = Color(0xFF001F2A);
  static const Color onPrimaryFixedVariant = Color(0xFF004D65);

  // Secondary (Yellow) - alertas e destaques
  static const Color secondary = Color(0xFF795900);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFEC330);
  static const Color onSecondaryContainer = Color(0xFF6F5100);
  static const Color secondaryFixed = Color(0xFFFFDFA0);
  static const Color secondaryFixedDim = Color(0xFFF8BD2A);
  static const Color onSecondaryFixed = Color(0xFF261A00);
  static const Color onSecondaryFixedVariant = Color(0xFF5C4300);

  // Tertiary (Green) - sucesso e ações positivas
  static const Color tertiary = Color(0xFF3C6A00);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF70A636);
  static const Color onTertiaryContainer = Color(0xFF1C3600);
  static const Color tertiaryFixed = Color(0xFFB8F47A);
  static const Color tertiaryFixedDim = Color(0xFF9DD761);
  static const Color onTertiaryFixed = Color(0xFF0E2000);
  static const Color onTertiaryFixedVariant = Color(0xFF2C5000);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Background
  static const Color background = Color(0xFFF6FAFD);
  static const Color onBackground = Color(0xFF181C1F);

  // Tonalidade para sombras (mantém aspecto profissional, não preto puro)
  static const Color shadowTint = Color(0xFF1E293B);

  /// [ColorScheme] derivado da paleta. Material 3 distribui automaticamente
  /// essas cores nos componentes que usam o tema.
  static const ColorScheme lightScheme = ColorScheme(
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
