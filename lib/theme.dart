import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF006A66),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFF38B2AC),
        onPrimaryContainer: Color(0xFF003F3D),
        secondary: Color(0xFF944B00),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFE9743),
        onSecondaryContainer: Color(0xFF6B3500),
        tertiary: Color(0xFF00629D),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFF53A7F0),
        onTertiaryContainer: Color(0xFF003B61),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF93000A),
        surface: Color(0xFFF7FAFC),
        onSurface: Color(0xFF181C1E),
        surfaceContainerHighest: Color(0xFFE0E3E5),
        onSurfaceVariant: Color(0xFF3D4948),
        outline: Color(0xFF6D7A78),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7FAFC),
      textTheme: GoogleFonts.beVietnamProTextTheme().copyWith(
        displayLarge: GoogleFonts.beVietnamPro(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.8,
        ),
        displayMedium: GoogleFonts.beVietnamPro(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 1.3,
          letterSpacing: -0.32,
        ),
        displaySmall: GoogleFonts.beVietnamPro(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        bodyLarge: GoogleFonts.beVietnamPro(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.beVietnamPro(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        labelSmall: GoogleFonts.beVietnamPro(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: 0.6,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
