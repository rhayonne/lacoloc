/// Grid de espaçamento de 8px (com xs=4 para casos finos).
/// Use sempre estas constantes em vez de literais para manter consistência.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Largura máxima de container central no layout fluido.
  static const double maxContentWidth = 1280;
}
