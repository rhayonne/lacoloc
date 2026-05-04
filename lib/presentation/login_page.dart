import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormBuilderState>();

  bool _isLoading = false;
  bool _isSignUp = false;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithPassword(
        email: values['email'] as String,
        password: values['password'] as String,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/profile');
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
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
            ),
          ),
        ),
      ),
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
            if (type == UserType.proprietaire) {
              Navigator.of(context).pushNamed('/inscription-proprietaire');
            } else {
              Navigator.of(context).pushNamed('/inscription-locataire');
            }
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => setState(() => _isSignUp = false),
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
          _label('E-MAIL'),
          FormBuilderTextField(
            name: 'email',
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'nom@exemple.fr'),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.email(),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
          _label('MOT DE PASSE'),
          FormBuilderTextField(
            name: 'password',
            obscureText: true,
            decoration: const InputDecoration(hintText: '••••••••'),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.minLength(
                6,
                errorText: '6 caractères minimum',
              ),
            ]),
          ),
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
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() => _isSignUp = true),
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
