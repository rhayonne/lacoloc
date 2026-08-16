import 'package:flutter/foundation.dart';
import 'package:habitafrance/data/datasources/themes.dart';
import 'package:habitafrance/data/models/theme_ref.dart';
import 'package:habitafrance/theme/app_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
/// Un **choix explicite** (sélecteur de « Mon profil » ou bouton clair/sombre)
/// gagne toujours, et il est enregistré à deux endroits :
///
/// - **sur l'appareil** ([SharedPreferences]) — pour qu'il tienne au
///   rechargement de la page, y compris **sans compte** ;
/// - **sur le compte** (`Users_Client.theme_preference`) — pour qu'il suive la
///   personne d'un appareil à l'autre.
///
/// D'où l'ordre de priorité :
///
/// 1. **Visiteur non connecté** : son choix sur cet appareil ; à défaut, le
///    thème marqué « principal » en base (`Themes_Reference.is_default`).
/// 2. **À la connexion** : si un choix a été fait *juste avant* de se
///    connecter, ce choix devient la préférence du compte (c'est ce qui fait
///    qu'on ne « perd » pas le thème sombre en se connectant) ; sinon on
///    applique la préférence enregistrée du compte, si son thème est toujours
///    actif ; sinon le thème principal.
/// 3. **À la déconnexion** : on retombe sur le choix de l'appareil, à défaut
///    le thème principal. (Le compte suivant qui se connecte imposera le sien.)
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

  /// Clé du choix local. Ne pas renommer : ça remettrait tout le monde au
  /// thème principal au prochain déploiement.
  static const String _prefsKey = 'theme_choice';

  /// La palette courante. Lue par `AppColors`.
  static AppPalette get palette => instance.value;

  /// Code du thème courant (`Themes_Reference.code`).
  String get code => _code;
  String _code = _fallbackCode;

  /// Le thème courant est-il sombre ? (Déduit de la palette, pas déclaré.)
  bool get isDark => value.isDark;

  /// Les thèmes proposables, chargés une fois au démarrage. Vide tant que le
  /// chargement n'a pas eu lieu.
  List<ThemeRef> get available => List.unmodifiable(_available);
  List<ThemeRef> _available = const [];

  /// Choix explicite fait **avant** la connexion, en attente d'être écrit sur
  /// le compte. Consommé une seule fois par `AuthService.loadThemePreference`.
  String? _pendingAccountWrite;

  void _apply(ThemeRef theme) {
    _code = theme.code;
    value = theme.palette; // notifie → MyApp reconstruit tout
  }

  // ── Choix local (appareil) ─────────────────────────────────────────────────

  /// Lit le choix enregistré sur cet appareil. Best-effort : le stockage local
  /// peut être refusé (navigation privée) — l'apparence ne doit pas en pâtir.
  Future<String?> _readLocalChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefsKey);
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLocalChoice(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {}
  }

  /// Le thème actif portant ce code, ou `null`. Un thème désactivé par le super
  /// admin depuis le choix est traité comme absent.
  ThemeRef? _find(String? code) =>
      code == null ? null : _available.where((t) => t.code == code).firstOrNull;

  // ── Chargement ─────────────────────────────────────────────────────────────

  /// Charge les thèmes et applique le thème **principal**, sauf si cet appareil
  /// porte déjà un choix explicite — auquel cas c'est lui qui gagne.
  /// Appelé au démarrage (avant toute session) et après une modification des
  /// thèmes par le super admin.
  Future<void> loadDefault({bool refresh = false}) async {
    try {
      _available = await ThemesDatasource.listActive(refresh: refresh);
      final local = _find(await _readLocalChoice());
      if (local != null) {
        _apply(local);
        return;
      }
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
      final match = _find(preferredCode);
      if (match != null) {
        _apply(match);
        // Le compte fait autorité : on aligne l'appareil dessus, sinon la
        // prochaine visite déconnectée ressortirait un autre thème.
        await _writeLocalChoice(match.code);
        return;
      }
    } catch (_) {
      // On tente quand même le thème principal ci-dessous.
    }
    await loadDefault();
  }

  // ── Choix explicite ────────────────────────────────────────────────────────

  /// Applique un thème déjà chargé (sélection dans « Mon profil », aperçu
  /// côté admin). Ne persiste rien : c'est à l'appelant de le faire.
  void set(ThemeRef theme) => _apply(theme);

  /// Enregistre un **choix explicite** : appliqué tout de suite, retenu sur
  /// l'appareil, et mis en attente d'écriture sur le compte si personne n'est
  /// connecté (voir [takePendingAccountWrite]).
  ///
  /// [signedIn] : l'appelant sait, lui, si une session est ouverte — le
  /// contrôleur de thème n'a pas à connaître la couche d'authentification.
  Future<void> choose(ThemeRef theme, {required bool signedIn}) async {
    _apply(theme);
    await _writeLocalChoice(theme.code);
    if (!signedIn) _pendingAccountWrite = theme.code;
  }

  /// Le choix fait avant la connexion, à écrire sur le compte. Consommé (remis
  /// à `null`) par l'appel — il ne doit être appliqué qu'une fois.
  String? takePendingAccountWrite() {
    final v = _pendingAccountWrite;
    _pendingAccountWrite = null;
    return v;
  }

  // ── Bouton clair / sombre ──────────────────────────────────────────────────

  /// Le thème sombre proposé, ou `null` si le super admin l'a désactivé (le
  /// bouton clair/sombre se cache alors, plutôt que de ne rien faire au clic).
  ///
  /// On cherche d'abord le thème intégré « sombre » ; à défaut, n'importe quel
  /// thème actif dont la palette est sombre — un super admin peut avoir créé
  /// le sien à partir de 3 couleurs foncées.
  ThemeRef? get darkTheme =>
      _find(AppPalettes.sombreCode) ??
      _available.where((t) => t.palette.isDark).firstOrNull;

  /// Le thème clair vers lequel revenir : le dernier thème clair utilisé, sinon
  /// le principal, sinon le premier thème clair actif.
  ThemeRef? get _lightTheme {
    final memo = _find(_lastLightCode);
    if (memo != null && !memo.palette.isDark) return memo;
    final def = _available.where((t) => t.isDefault && !t.palette.isDark);
    return def.firstOrNull ??
        _available.where((t) => !t.palette.isDark).firstOrNull;
  }

  /// Dernier thème **clair** porté, pour que revenir au clair rende son thème
  /// à la personne (Ocre reste Ocre) au lieu de l'aplatir sur le principal.
  String? _lastLightCode;

  /// Le thème vers lequel basculer (clair ⇄ sombre), ou `null` si la bascule
  /// est impossible (aucun thème du bon type actif).
  ///
  /// Ne l'applique pas : l'appliquer, c'est **choisir**, et un choix passe par
  /// `AuthService.saveThemePreference` qui l'enregistre au bon endroit selon
  /// qu'une session est ouverte ou non. Une seule voie de persistance.
  Future<ThemeRef?> pickToggleTarget() async {
    if (_available.isEmpty) await loadDefault();
    // On mémorise le thème clair quitté pour pouvoir y revenir tel quel :
    // quelqu'un qui travaille en Ocre doit retrouver Ocre, pas le principal.
    if (!isDark) _lastLightCode = _code;
    return isDark ? _lightTheme : darkTheme;
  }

  /// Retour au thème de l'appareil (déconnexion). Le choix local survit à la
  /// déconnexion : passer du sombre au clair d'un coup, en pleine nuit, serait
  /// une agression gratuite. Le compte suivant qui se connecte imposera le sien.
  Future<void> reset() => loadDefault();
}
