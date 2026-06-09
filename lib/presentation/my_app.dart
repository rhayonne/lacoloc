import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/presentation/auth_gate.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_detail_page.dart';
import 'package:lacoloc_front/presentation/home_page.dart';
import 'package:lacoloc_front/presentation/users/locataires/completer_inscription_page.dart';
import 'package:lacoloc_front/presentation/users/locataires/confirmation_locataire_page.dart';
import 'package:lacoloc_front/presentation/users/locataires/creer_compte_locataire_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/creer_compte_proprietaire_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/proprietaire_profil.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      // `initialSession` é emitido quando a sessão é recuperada da URL/Storage
      // durante o boot (caso do link de convite na web). Tratamos junto com
      // `signedIn`/`userUpdated` para não perder o redirecionamento.
      switch (state.event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.userUpdated:
          // Realtime + cache : démarre dès qu'une session est active.
          if (state.session != null) RealtimeService.instance.start();
          _maybeRedirectToCompletion(state.session);
        case AuthChangeEvent.signedOut:
          // Coupe les abonnements et vide le cache au logout.
          RealtimeService.instance.stop();
        default:
          break;
      }
    });
    _handleActivationLink();
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

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Super Coloc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
