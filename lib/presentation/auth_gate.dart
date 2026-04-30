import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/presentation/login_page.dart';
import 'package:lacoloc_front/presentation/users/locataires/locataire_profil.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/proprietaire_profil.dart';

/// Decide para onde mandar o usuário após o login.
/// - Sem sessão → LoginPage.
/// - Proprietaire → dashboard do proprietário.
/// - Locataire / Super Admin → tela do locatário (placeholder por enquanto).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return const LoginPage();
    }

    return FutureBuilder<UsersClient?>(
      future: AuthService.loadCurrentProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data;
        if (profile?.typeClient == UserType.proprietaire) {
          return const ProprietaireProfilPage();
        }
        return const LocataireProfilPage();
      },
    );
  }
}
