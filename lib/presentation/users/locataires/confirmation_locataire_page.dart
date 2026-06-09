import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _ConfirmState { waiting, confirmed, error }

class ConfirmationLocatairePage extends StatefulWidget {
  const ConfirmationLocatairePage({super.key});

  @override
  State<ConfirmationLocatairePage> createState() =>
      _ConfirmationLocatairePageState();
}

class _ConfirmationLocatairePageState
    extends State<ConfirmationLocatairePage> {
  _ConfirmState _state = _ConfirmState.waiting;
  StreamSubscription<AuthState>? _sub;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    if (AuthService.isLoggedIn) {
      _state = _ConfirmState.confirmed;
      return;
    }
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (!mounted) return;
      if (s.event == AuthChangeEvent.signedIn) {
        _timeout?.cancel();
        setState(() => _state = _ConfirmState.confirmed);
      }
    });
    _timeout = Timer(const Duration(seconds: 10), () {
      if (mounted && _state == _ConfirmState.waiting) {
        setState(() => _state = _ConfirmState.error);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _goToLogin() async {
    if (AuthService.isLoggedIn) await AuthService.signOut();
    if (mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: switch (_state) {
              _ConfirmState.waiting => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: AppSpacing.lg),
                    Text('Vérification en cours…'),
                  ],
                ),
              _ConfirmState.confirmed => _SuccessCard(onLogin: _goToLogin),
              _ConfirmState.error => _ErrorCard(onLogin: _goToLogin),
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SuccessCard extends StatelessWidget {
  final VoidCallback onLogin;
  const _SuccessCard({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 80,
          color: AppColors.tertiary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Compte confirmé !',
          style: AppTypography.headlineMd,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Votre adresse e-mail a été confirmée avec succès.\n'
          'Vous pouvez maintenant vous connecter à votre compte.',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login),
            label: const Text('Se connecter'),
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback onLogin;
  const _ErrorCard({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.link_off_rounded,
          size: 80,
          color: AppColors.error,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Lien invalide ou expiré',
          style: AppTypography.headlineMd,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ce lien de confirmation n\'est plus valide.\n'
          'Essayez de vous inscrire à nouveau ou contactez le support.',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login),
            label: const Text('Se connecter'),
          ),
        ),
      ],
    );
  }
}
