import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/presentation/login_page.dart';
import 'package:lacoloc_front/presentation/users/admin/super_admin_profil.dart';
import 'package:lacoloc_front/presentation/users/locataires/locataire_profil.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/proprietaire_profil.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Decide para onde mandar o usuário após o login.
/// Contas inativas (active = false) veem a tela de espera e são desconectadas.
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

        if (profile != null && !profile.active) {
          return _PendingActivationPage(
            email: profile.email,
            onLogout: () async {
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
          );
        }

        final type = profile?.resolvedType;
        return switch (type) {
          UserType.proprietaire => const ProprietaireProfilPage(),
          UserType.superAdmin => const SuperAdminProfilPage(),
          _ => const LocataireProfilPage(),
        };
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PendingActivationPage extends StatelessWidget {
  final String email;
  final VoidCallback onLogout;

  const _PendingActivationPage({
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Compte en attente d\'activation',
                  style: AppTypography.headlineMd,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Votre demande a bien été reçue pour le compte\n$email\n\n'
                  'Un administrateur examinera votre dossier et activera votre compte dans les meilleurs délais.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
