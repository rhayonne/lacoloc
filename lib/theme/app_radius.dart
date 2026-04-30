import 'package:flutter/material.dart';

/// Raios de borda padronizados para o sistema de design.
/// Default = 8px (linguagem unificada de "container").
class AppRadius {
  AppRadius._();

  static const double sm = 4;
  static const double md = 8; // padrão (componentes em geral)
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;
  static const double full = 9999;

  static BorderRadius get borderSm => BorderRadius.circular(sm);
  static BorderRadius get borderMd => BorderRadius.circular(md);
  static BorderRadius get borderLg => BorderRadius.circular(lg);
  static BorderRadius get borderXl => BorderRadius.circular(xl);
  static BorderRadius get borderXxl => BorderRadius.circular(xxl);
  static BorderRadius get borderFull => BorderRadius.circular(full);
}
