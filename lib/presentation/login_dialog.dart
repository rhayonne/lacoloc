import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lacoloc_front/presentation/login_page.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';

/// Ouvre la connexion sous forme de pop-up centré, avec l'arrière-plan flouté.
/// Remplace la navigation vers `/login` quand l'utilisateur clique « Se connecter ».
Future<void> showLoginDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Connexion',
    barrierColor: Colors.black.withValues(alpha: 0.20),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, _) {
      final blur = 10.0 * anim.value;
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: FadeTransition(
          opacity: anim,
          child: _LoginDialogContent(),
        ),
      );
    },
  );
}

class _LoginDialogContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LoginCard(
              onSuccess: () {
                final nav = Navigator.of(context, rootNavigator: true);
                nav.pop(); // fermer le pop-up
                nav.pushReplacementNamed('/profile');
              },
              onNavigate: (route) {
                final nav = Navigator.of(context, rootNavigator: true);
                nav.pop();
                nav.pushNamed(route);
              },
            ),
          ),
        ),
      ),
    );
  }
}
