import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// **Unique** point d'entrée de connexion de l'application : un pop-up centré
/// avec fond flouté. Affiché aussi bien depuis l'accueil (clic « Se connecter »)
/// que lorsqu'une session expire / après déconnexion.
///
/// Le formulaire lui-même est le widget réutilisable [LoginCard].
Future<void> showConnexionDialog(BuildContext context) {
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
          child: _ConnexionDialogContent(),
        ),
      );
    },
  );
}

class _ConnexionDialogContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LoginCard(
              onSuccess: () {
                rootNav.pop(); // fermer le pop-up
                rootNav.pushReplacementNamed('/profile');
              },
              onNavigate: (route) {
                rootNav.pop();
                rootNav.pushNamed(route);
              },
              onGoHome: () {
                rootNav.pop();
                rootNav.pushNamedAndRemoveUntil('/', (r) => false);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Formulaire de connexion / sélecteur d'inscription **réutilisable**.
/// C'est le seul widget de login de l'app ; on l'affiche via
/// [showConnexionDialog]. Tous les callbacks sont optionnels.
class LoginCard extends StatefulWidget {
  /// Appelé après une connexion réussie. Par défaut, navigue vers `/profile`.
  final VoidCallback? onSuccess;

  /// Appelé pour ouvrir une route d'inscription (`/inscription-locataire` ou
  /// `/inscription-proprietaire`). Par défaut, `Navigator.pushNamed`.
  final void Function(String route)? onNavigate;

  /// Appelé par le bouton « Aller à l'accueil » sous « Se connecter ».
  /// Par défaut, navigue vers `/`.
  final VoidCallback? onGoHome;

  const LoginCard({
    super.key,
    this.onSuccess,
    this.onNavigate,
    this.onGoHome,
  });

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final _formKey = GlobalKey<FormBuilderState>();

  bool _isLoading = false;
  bool _isSignUp = false;
  String? _error; // message d'erreur affiché en ligne dans la carte

  // Converte identificador curto (ex: "super") em email completo
  String _resolveEmail(String input) {
    final trimmed = input.trim();
    if (!trimmed.contains('@')) return '$trimmed@admin.local';
    return trimmed;
  }

  void _navigate(String route) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  void _goHome() {
    if (widget.onGoHome != null) {
      widget.onGoHome!();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  /// Touche « Entrée » dans le champ mot de passe. On diffère la soumission
  /// hors du handler du canal de saisie (`performAction`) : sur Flutter web,
  /// lancer l'appel réseau directement dans `onSubmitted` gèle l'UI. Via un
  /// post-frame callback, « Entrée » se comporte exactement comme le clic sur
  /// « Se connecter ».
  void _onEnterPressed() {
    if (_isLoading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoading) _submit();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    final email = _resolveEmail(values['email'] as String);
    debugPrint('[login] « Se connecter » cliqué — email: $email');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Filet de sécurité supplémentaire : AuthService.signIn ne lève jamais
    // (il capture l'erreur gotrue via .catchError), mais ce try/catch garantit
    // que le spinner se réinitialise toujours et qu'aucune exception ne gèle
    // l'UI — quel que soit le déclencheur (bouton ou Entrée).
    try {
      final result = await AuthService.signIn(
        email: email,
        password: values['password'] as String,
      );

      if (!mounted) return;
      if (result.isSuccess) {
        setState(() => _isLoading = false);
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          Navigator.of(context).pushReplacementNamed('/profile');
        }
      } else {
        // Échec : message dans le bandeau de la carte ET en SnackBar.
        final message = result.errorMessage ?? 'Échec de la connexion.';
        setState(() {
          _error = message;
          _isLoading = false;
        });
        _showErrorSnackBar(message);
      }
    } catch (e) {
      debugPrint('[login] exception inattendue dans _submit: $e');
      if (!mounted) return;
      const message = 'Une erreur est survenue. Veuillez réessayer.';
      setState(() {
        _error = message;
        _isLoading = false;
      });
      _showErrorSnackBar(message);
    }
  }

  void _showErrorSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowTint.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: _isSignUp ? _buildSignUpPicker() : _buildLoginForm(),
    );
  }

  Widget _buildSignUpPicker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Super Coloc',
          textAlign: TextAlign.center,
          style: AppTypography.displayMd.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Quel type de compte souhaitez-vous créer ?',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _RoleSelector(
          onTap: (type) {
            _navigate(type == UserType.proprietaire
                ? '/inscription-proprietaire'
                : '/inscription-locataire');
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => setState(() {
            _isSignUp = false;
            _error = null;
          }),
          child: const Text('Déjà un compte ? Se connecter'),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return FormBuilder(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Super Coloc',
            textAlign: TextAlign.center,
            style: AppTypography.displayMd.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ravi de vous revoir !',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _label('IDENTIFIANT OU E-MAIL'),
          FormBuilderTextField(
            name: 'email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'nom@exemple.fr'),
            validator: FormBuilderValidators.required(),
          ),
          const SizedBox(height: AppSpacing.md),
          _label('MOT DE PASSE'),
          FormBuilderTextField(
            name: 'password',
            obscureText: true,
            textInputAction: TextInputAction.done,
            // No-op : empêche le unfocus automatique de « Entrée »
            // (_finalizeEditing → unfocus) qui, sur Flutter web, déclenche un
            // rebuild pendant lequel l'erreur de la requête est détournée et
            // gèle l'UI. La soumission passe par onSubmitted (post-frame).
            onEditingComplete: () {},
            onSubmitted: (_) => _onEnterPressed(),
            decoration: const InputDecoration(hintText: '••••••••'),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.minLength(
                6,
                errorText: '6 caractères minimum',
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text('Se connecter'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Bouton « Aller à l'accueil » sous « Se connecter » : permet de
          // fermer la connexion et revenir parcourir l'accueil.
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _goHome,
              icon: const Icon(Icons.home_outlined, size: 20),
              label: const Text("Aller à l'accueil"),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _isSignUp = true;
                      _error = null;
                    }),
            child: const Text("Pas encore de compte ? S'inscrire"),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          text,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
      );
}

/// Bandeau d'erreur affiché en ligne dans la carte de connexion.
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMd.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final ValueChanged<UserType> onTap;

  const _RoleSelector({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleChip(
            icon: Icons.person,
            label: 'LOCATAIRE',
            onTap: () => onTap(UserType.locataire),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _RoleChip(
            icon: Icons.home_work,
            label: 'PROPRIÉTAIRE',
            onTap: () => onTap(UserType.proprietaire),
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoleChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.onSurfaceVariant, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
