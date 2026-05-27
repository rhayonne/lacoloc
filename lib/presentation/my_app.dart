import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lacoloc_front/presentation/auth_gate.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_detail_page.dart';
import 'package:lacoloc_front/presentation/home_page.dart';
import 'package:lacoloc_front/presentation/login_page.dart';
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
      if (state.event == AuthChangeEvent.signedIn) {
        final meta = state.session?.user.userMetadata;
        if (meta?['needs_completion'] == true) {
          _navigatorKey.currentState
              ?.pushReplacementNamed('/completer-inscription');
        }
      }
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
        '/login': (context) => const LoginPage(),
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
