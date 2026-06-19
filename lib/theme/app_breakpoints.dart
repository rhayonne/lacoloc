/// Breakpoints **centralisés** du projet (ordinateur + tablette ; prêt Android).
///
/// Pourquoi : les écrans utilisaient des seuils en dur disparates (`< 600`,
/// `< 720`, `< 800`, `< 900`…), ce qui rendait le comportement imprévisible —
/// surtout en **tablette portrait** (~768–834 px). On regroupe tout ici.
///
/// Règle du projet : décider la mise en page d'après la **largeur du composant**
/// (`LayoutBuilder`), pas la largeur de la fenêtre (`MediaQuery`) — la sidebar
/// consomme une partie de l'écran. Utiliser [classOf]/[isCompact] avec la
/// `maxWidth` des contraintes du `LayoutBuilder`.
class AppBreakpoints {
  AppBreakpoints._();

  /// En dessous : une seule colonne, listes en **cartes** (mobile + tablette
  /// portrait étroite). Couvre le portrait des tablettes courantes.
  static const double compact = 600;

  /// En dessous : densité réduite (2 colonnes, tableaux condensés). Au-dessus :
  /// pleine densité « bureau ».
  static const double medium = 900;

  /// Au-delà : très grand écran (3+ colonnes possibles).
  static const double expanded = 1200;

  /// Seuil **tableau → cartes** : en dessous, une `DataTable`/ligne dense doit
  /// devenir une liste de cartes verticales (lisible et tactile en tablette).
  static const double tableToCards = medium;

  /// Hauteur/largeur minimale d'une cible tactile confortable (Material/Android
  /// recommandent 48 dp ; on accepte 44 dp minimum sur les actions secondaires).
  static const double minTouchTarget = 48;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < medium;
  static bool isExpanded(double width) => width >= medium;

  /// Nombre de colonnes suggéré pour une grille de cartes selon la largeur.
  static int gridColumns(double width) {
    if (width < compact) return 1;
    if (width < medium) return 2;
    if (width < expanded) return 3;
    return 4;
  }
}
