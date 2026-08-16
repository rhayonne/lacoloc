import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:habitafrance/data/cache/realtime_service.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/datasources/immeubles.dart';
import 'package:habitafrance/data/datasources/session_scope.dart';
import 'package:habitafrance/data/permissions/permissions_service.dart';
import 'package:habitafrance/presentation/auth_gate.dart';
import 'package:habitafrance/presentation/chambres/chambre_detail_page.dart';
import 'package:habitafrance/presentation/home_page.dart';
import 'package:habitafrance/presentation/users/locataires/completer_inscription_page.dart';
import 'package:habitafrance/presentation/users/locataires/confirmation_locataire_page.dart';
import 'package:habitafrance/presentation/users/locataires/creer_compte_locataire_page.dart';
import 'package:habitafrance/presentation/users/proprietaires/creer_compte_proprietaire_page.dart';
import 'package:habitafrance/presentation/users/proprietaires/proprietaire_profil.dart';
import 'package:habitafrance/presentation/tour/guided_tours.dart';
import 'package:habitafrance/theme/app_palette.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/theme_controller.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authSub;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Au retour au premier plan, on recharge les permissions effectives :
    // si le super admin les a modifiées entre-temps, l'UI se met à jour
    // (gating) sans nécessiter une reconnexion.
    if (state == AppLifecycleState.resumed &&
        Supabase.instance.client.auth.currentSession != null) {
      PermissionsService.instance.load();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      // `initialSession` é emitido quando a sessão é recuperada da URL/Storage
      // durante o boot (caso do link de convite na web). Tratamos junto com
      // `signedIn`/`userUpdated` para não perder o redirecionamento.
      switch (state.event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
          // Realtime + cache : démarre dès qu'une session est active.
          if (state.session != null) {
            RealtimeService.instance.start();
            PermissionsService.instance.load();
            // Applique le thème choisi par la personne (best-effort).
            AuthService.loadThemePreference();
            // Log de connexion : best-effort, ne bloque pas le flux principal.
            _logConnection();
          }
          _maybeRedirectToCompletion(state.session);
        case AuthChangeEvent.userUpdated:
          if (state.session != null) {
            RealtimeService.instance.start();
            PermissionsService.instance.load();
          }
          _maybeRedirectToCompletion(state.session);
        case AuthChangeEvent.signedOut:
          // Coupe les abonnements et vide le cache au logout.
          RealtimeService.instance.stop();
          PermissionsService.instance.clear();
          ImmeublesDatasource.clearEntrepriseCache();
          SessionScope.clear();
          // Le thème est une préférence personnelle : un visiteur déconnecté
          // retrouve le thème par défaut.
          ThemeController.instance.reset();
        default:
          break;
      }
    }, onError: (Object error) {
      // Au démarrage, Supabase tente de rafraîchir la session stockée. Si le
      // refresh token n'est plus valide (expiré / révoqué / supprimé côté
      // serveur), gotrue émet une AuthException ici. On nettoie la session
      // locale pour retomber proprement sur l'état déconnecté au lieu de laisser
      // l'exception remonter (« Invalid Refresh Token: Refresh Token Not Found »).
      if (error is AuthException) {
        Supabase.instance.client.auth.signOut();
        RealtimeService.instance.stop();
        PermissionsService.instance.clear();
        ImmeublesDatasource.clearEntrepriseCache();
        SessionScope.clear();
      }
    });
    _handleActivationLink();
    _handleTourLink();
    ThemeController.instance.addListener(_onThemeChanged);
    // Thème « principal » (Themes_Reference.is_default) : c'est ce que voit un
    // visiteur non connecté. Si une session est déjà active, le listener
    // ci-dessus appliquera par-dessus le choix personnel de la personne.
    ThemeController.instance.loadDefault();
  }

  /// Le thème a changé → **tout** l'arbre doit se reconstruire.
  ///
  /// Pourquoi ce n'est pas automatique : les écrans lisent `AppColors.<token>`,
  /// un getter statique global. Ils ne dépendent donc d'aucun `InheritedWidget`
  /// et Flutter ne sait pas qu'ils sont périmés — seul le `MaterialApp` se
  /// reconstruit, pas les pages déjà montées dans le `Navigator` (d'où
  /// l'ancien symptôme : « il faut revenir à l'accueil pour voir le thème »).
  ///
  /// On marque donc chaque élément à reconstruire. Contrairement à un
  /// changement de `key` (qui recréerait l'arbre), l'état est **préservé** :
  /// saisie en cours, position de scroll, onglet actif.
  void _onThemeChanged() {
    // Après la frame : `markNeedsBuild` est interdit pendant un build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void visitor(Element el) {
        el.markNeedsBuild();
        el.visitChildren(visitor);
      }

      (context as Element).visitChildren(visitor);
    });
  }

  /// Lien `?tour=...` (depuis le manuel « Tour guidé ») : amène l'utilisateur
  /// connecté à son espace (AuthGate route par type) pour que le tour démarre.
  /// La navigation efface les query params de l'URL, donc on **mémorise** le
  /// tour dans [PendingTour] ; la page cible (ex. ProprietaireProfil) le
  /// consomme à son montage pour lancer le bon tour.
  void _handleTourLink() {
    final tour = Uri.base.queryParameters['tour'];
    if (tour == null || tour.isEmpty) return;
    PendingTour.value = tour;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.pushReplacementNamed('/profile');
    });
  }

  /// Lien d'activation `?email=...&temp=...` : connecte automatiquement le
  /// locataire avec son mot de passe temporaire. Le listener ci-dessus prend
  /// le relais (needs_completion) et l'amène au formulaire de mot de passe.
  /// Le compte n'est activé qu'après le changement de mot de passe.
  Future<void> _handleActivationLink() async {
    final params = Uri.base.queryParameters;
    final email = params['email'];
    final temp = params['temp'];
    if (email == null || temp == null || email.isEmpty || temp.isEmpty) return;
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: temp);
      // → signedIn → _maybeRedirectToCompletion → /completer-inscription
    } catch (_) {
      // Mot de passe temporaire invalide (déjà changé) → accueil
      // (l'utilisateur peut s'y reconnecter via le pop-up « Se connecter »).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.pushReplacementNamed('/');
      });
    }
  }

  /// Se o usuário ainda precisa definir a senha (`needs_completion`), leva-o
  /// ao formulário. Adiado para pós-frame pois o evento pode chegar antes do
  /// Navigator existir.
  void _maybeRedirectToCompletion(Session? session) {
    final needs = session?.user.userMetadata?['needs_completion'] == true;
    if (!needs) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState
          ?.pushReplacementNamed('/completer-inscription');
    });
  }

  /// Enregistre la connexion dans `connection_logs` via la edge function.
  /// Best-effort : les erreurs sont ignorées pour ne pas bloquer le flux.
  Future<void> _logConnection() async {
    try {
      await Supabase.instance.client.functions.invoke(
        'log-connection',
        body: {'timezone': DateTime.now().timeZoneName},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ThemeController.instance.removeListener(_onThemeChanged);
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Le thème vit dans `ThemeController` (thème principal pour les visiteurs,
    // choix personnel une fois connecté). On s'y abonne ici pour que le
    // `MaterialApp` reprenne le nouveau `theme:` ; `_onThemeChanged` se charge
    // des pages déjà montées.
    return ValueListenableBuilder<AppPalette>(
      valueListenable: ThemeController.instance,
      builder: (context, _, _) => _buildApp(),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'HabitaFrance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
      ],
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 1024, name: TABLET),
          Breakpoint(start: 1025, end: 1920, name: DESKTOP),
          Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/profile': (context) => const AuthGate(),
        '/proprietaire': (context) => const ProprietaireProfilPage(),
        '/inscription-locataire': (context) => const CrierCompteLocatairePage(),
        '/inscription-proprietaire': (context) =>
            const CrierCompteProprietairePage(),
        '/completer-inscription': (context) =>
            const CompleterInscriptionPage(),
        '/confirmation-locataire': (context) =>
            const ConfirmationLocatairePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/chambre') {
          final id = settings.arguments as int;
          return MaterialPageRoute(
            builder: (_) => ChambreDetailPage(chambreId: id),
          );
        }
        return null;
      },
    );
  }
}
