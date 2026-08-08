import 'package:flutter/foundation.dart';
import 'package:habitafrance/data/datasources/themes.dart';
import 'package:habitafrance/data/models/theme_ref.dart';
import 'package:habitafrance/theme/app_palette.dart';

/// Thème **courant** de l'application.
///
/// ## Comment ça marche
///
/// `AppColors.<token>` ne renvoie pas une constante mais lit
/// [ThemeController.palette]. Changer le thème change donc *toutes* les
/// couleurs de l'app d'un coup — aucun écran n'a besoin de le savoir.
///
/// ## ⚠️ Pourquoi un rebuild complet est nécessaire
///
/// `AppColors.<token>` est un **getter statique global** : un widget qui le lit
/// ne dépend d'aucun `InheritedWidget`, donc Flutter n'a **aucun moyen de
/// savoir** que sa couleur est périmée quand le thème change. Reconstruire le
/// `MaterialApp` ne suffit pas : les pages tenues par le `Navigator` gardent
/// leurs anciennes couleurs (d'où l'ancien symptôme « il faut revenir à
/// l'accueil pour voir le thème »).
///
/// `MyApp` écoute donc ce contrôleur et marque **tout l'arbre** à reconstruire
/// (`_onThemeChanged`), ce qui préserve l'état (saisie, scroll, onglet actif)
/// contrairement à un changement de `key`.
///
/// ## Qui gagne, entre le thème par défaut et le choix de la personne
///
/// 1. Un **visiteur non connecté** voit le thème marqué « principal » en base
///    (`Themes_Reference.is_default`), chargé au démarrage.
/// 2. À la **connexion**, si la personne a choisi un thème (`Users_Client.
///    theme_preference`) **et** que ce thème est toujours actif, son choix
///    l'emporte. Sinon, le thème principal.
/// 3. À la **déconnexion**, on revient au thème principal.
///
/// Autrement dit : changer le thème principal n'écrase jamais un choix déjà
/// fait — il ne concerne que les visiteurs et les comptes qui n'ont rien choisi.
class ThemeController extends ValueNotifier<AppPalette> {
  ThemeController._() : super(_fallbackPalette);

  static final ThemeController instance = ThemeController._();

  /// Palette de secours : utilisée avant le premier chargement et si la base
  /// est injoignable. L'apparence ne doit jamais empêcher l'app de démarrer.
  static const AppPalette _fallbackPalette = AppPalettes.ardoise;
  static const String _fallbackCode = 'ardoise';

  /// La palette courante. Lue par `AppColors`.
  static AppPalette get palette => instance.value;

  /// Code du thème courant (`Themes_Reference.code`).
  String get code => _code;
  String _code = _fallbackCode;

  /// Les thèmes proposables, chargés une fois au démarrage. Vide tant que le
  /// chargement n'a pas eu lieu.
  List<ThemeRef> get available => List.unmodifiable(_available);
  List<ThemeRef> _available = const [];

  void _apply(ThemeRef theme) {
    _code = theme.code;
    value = theme.palette; // notifie → MyApp reconstruit tout
  }

  /// Charge les thèmes et applique le thème **principal**.
  /// Appelé au démarrage (avant toute session) et après une modification des
  /// thèmes par le super admin.
  Future<void> loadDefault({bool refresh = false}) async {
    try {
      _available = await ThemesDatasource.listActive(refresh: refresh);
      final def = await ThemesDatasource.defaultTheme(refresh: refresh);
      if (def != null) _apply(def);
    } catch (_) {
      // Base injoignable : on garde la palette de secours.
    }
  }

  /// Applique le choix d'une personne à la connexion.
  /// [preferredCode] = `Users_Client.theme_preference` (peut être `null`).
  /// Un thème désactivé ou supprimé entre-temps est ignoré → thème principal.
  Future<void> applyUserPreference(String? preferredCode) async {
    try {
      _available = await ThemesDatasource.listActive();
      final match = _available.where((t) => t.code == preferredCode).firstOrNull;
      if (match != null) {
        _apply(match);
        return;
      }
    } catch (_) {
      // On tente quand même le thème principal ci-dessous.
    }
    await loadDefault();
  }

  /// Applique un thème déjà chargé (sélection dans « Mon profil », aperçu
  /// côté admin). Ne persiste rien : c'est à l'appelant de le faire.
  void set(ThemeRef theme) => _apply(theme);

  /// Retour au thème principal (déconnexion).
  Future<void> reset() => loadDefault();
}
