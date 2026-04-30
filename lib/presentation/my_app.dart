import 'package:flutter/material.dart';
import 'package:lacoloc_front/presentation/auth_gate.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_detail_page.dart';
import 'package:lacoloc_front/presentation/home_page.dart';
import 'package:lacoloc_front/presentation/login_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/proprietaire_profil.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:responsive_framework/responsive_framework.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Coloc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
