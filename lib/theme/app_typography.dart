import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tipografia centralizada usando Be Vietnam Pro (via google_fonts).
/// Espelha os tokens definidos em `pallete.md`.
class AppTypography {
  AppTypography._();

  static TextStyle get _base =>
      GoogleFonts.beVietnamPro(color: AppColors.onSurface);

  // Display
  static TextStyle get displayLg => _base.copyWith(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.96, // -0.02em
  );

  static TextStyle get displayMd => _base.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.72, // -0.02em
  );

  // Headline
  static TextStyle get headlineLg =>
      _base.copyWith(fontSize: 30, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get headlineMd =>
      _base.copyWith(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3);

  // Title
  static TextStyle get titleLg =>
      _base.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4);

  static TextStyle get titleLs =>
      _base.copyWith(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3);

  // Body
  static TextStyle get bodyLg =>
      _base.copyWith(fontSize: 18, fontWeight: FontWeight.w400, height: 1.6);

  static TextStyle get bodyMd =>
      _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6);

  // Label
  static TextStyle get labelMd => _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.14, // 0.01em
  );

  static TextStyle get labelSm => _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.24, // 0.02em
  );

  /// [TextTheme] do Material 3 mapeado para os tokens do design system.
  /// Componentes que não declaram estilo manual herdam daqui.
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
