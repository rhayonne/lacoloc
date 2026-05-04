import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/presentation/widgets/email_field.dart';
import 'package:lacoloc_front/presentation/widgets/phone_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CrierCompteProprietairePage extends StatefulWidget {
  const CrierCompteProprietairePage({super.key});

  @override
  State<CrierCompteProprietairePage> createState() =>
      _CrierCompteProprietairePageState();
}

class _CrierCompteProprietairePageState
    extends State<CrierCompteProprietairePage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isLoading = false;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;

    setState(() => _isLoading = true);
    try {
      final fullName = (values['full_name'] as String).trim();
      final email = (values['email'] as String).trim();
      final phone = values['phone'] as String?;
      final note = (values['note'] as String?)?.trim();
      final password = values['password'] as String;

      await AuthService.signUp(
        email: email,
        password: password,
        type: UserType.proprietaire,
        fullName: fullName,
      );

      // Notificação ao admin — best-effort, não bloqueia
      AuthService.notifyProprietaireRegistration(
        fullName: fullName,
        email: email,
        phone: phone,
        note: note,
      );

      if (!mounted) return;
      _showSuccessDialog();
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Demande enregistrée'),
        content: const Text(
          'Votre dossier a bien été transmis.\n\n'
          'Consultez vos e-mails pour confirmer votre adresse, '
          'puis attendez l\'activation de votre compte par un administrateur.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inscription Propriétaire'),
          leading: const BackButton(),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppRadius.borderXl,
                border: Border.all(color: AppColors.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowTint.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FormBuilder(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Créez votre compte',
                      style: AppTypography.headlineMd,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Remplissez le formulaire ci-dessous. '
                      'Un administrateur examinera votre demande et activera votre compte.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _label('NOM COMPLET'),
                    FormBuilderTextField(
                      name: 'full_name',
                      decoration:
                          const InputDecoration(hintText: 'Jean Dupont'),
                      textCapitalization: TextCapitalization.words,
                      validator: FormBuilderValidators.required(
                        errorText: 'Champ obligatoire',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _label('E-MAIL'),
                    EmailField(name: 'email', required: true),
                    const SizedBox(height: AppSpacing.md),

                    _label('TÉLÉPHONE'),
                    PhoneField(name: 'phone'),
                    const SizedBox(height: AppSpacing.md),

                    _label('MOT DE PASSE'),
                    FormBuilderTextField(
                      name: 'password',
                      obscureText: _obscurePwd,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePwd
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscurePwd = !_obscurePwd),
                        ),
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.minLength(
                          6,
                          errorText: '6 caractères minimum',
                        ),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _label('CONFIRMER LE MOT DE PASSE'),
                    FormBuilderTextField(
                      name: 'password_confirm',
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (val) {
                        final pwd = _formKey
                            .currentState?.fields['password']?.value as String?;
                        if (val == null || val.isEmpty) {
                          return 'Champ obligatoire';
                        }
                        if (val != pwd) return 'Les mots de passe ne correspondent pas';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _label('MESSAGE (facultatif)'),
                    FormBuilderTextField(
                      name: 'note',
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'Présentez-vous ou ajoutez une note pour l\'administrateur…',
                      ),
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
                            : const Text("Envoyer ma demande"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
