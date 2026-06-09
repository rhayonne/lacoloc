import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/utils/email_field.dart';
import 'package:lacoloc_front/utils/phone_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/auth_error.dart';

class CrierCompteLocatairePage extends StatefulWidget {
  const CrierCompteLocatairePage({super.key});

  @override
  State<CrierCompteLocatairePage> createState() =>
      _CrierCompteLocatairePageState();
}

class _CrierCompteLocatairePageState extends State<CrierCompteLocatairePage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isLoading = false;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  int? _previewAge;

  static int? _computeAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;

    setState(() => _isLoading = true);
    try {
      final fullName = (values['full_name'] as String).trim();
      final email = (values['email'] as String).trim();
      final password = values['password'] as String;
      final phone = (values['phone'] as String?)?.trim();
      final dob = values['date_of_birth'] as DateTime?;
      final age = dob != null ? _computeAge(dob) : null;

      final response = await AuthService.signUp(
        email: email,
        password: password,
        type: UserType.locataire,
        fullName: fullName,
        phone: phone,
        age: age,
        dateOfBirth: dob,
      );

      if (!mounted) return;

      if (response.session == null) {
        _showSuccessDialog();
      } else {
        Navigator.of(context).pushReplacementNamed('/profile');
      }
    } catch (e) {
      _showError(authErrorMessage(e));
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
        title: const Text('Vérifiez vos e-mails'),
        content: const Text(
          'Un e-mail de confirmation a été envoyé à votre adresse.\n\n'
          'Cliquez sur le lien pour activer votre compte, '
          'puis revenez vous connecter.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/');
            },
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lastDateAllowed = DateTime(now.year - 16, now.month, now.day);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inscription Locataire'),
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
                      'Remplissez le formulaire ci-dessous pour créer votre compte locataire.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Nom complet ──────────────────────────────────────
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

                    // ── E-mail ───────────────────────────────────────────
                    _label('E-MAIL'),
                    EmailField(name: 'email', required: true),
                    const SizedBox(height: AppSpacing.md),

                    // ── Téléphone ────────────────────────────────────────
                    _label('TÉLÉPHONE'),
                    PhoneField(name: 'phone'),
                    const SizedBox(height: AppSpacing.md),

                    // ── Date de naissance ────────────────────────────────
                    _label('DATE DE NAISSANCE'),
                    FormBuilderDateTimePicker(
                      name: 'date_of_birth',
                      inputType: InputType.date,
                      locale: const Locale('fr'),
                      format: DateFormat('dd/MM/yyyy'),
                      firstDate: DateTime(1920),
                      lastDate: lastDateAllowed,
                      decoration: const InputDecoration(
                        hintText: 'JJ/MM/AAAA',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _previewAge =
                              value != null ? _computeAge(value) : null;
                        });
                      },
                      validator: (value) {
                        if (value == null) return null;
                        final age = _computeAge(value)!;
                        if (age < 16) {
                          return 'Vous devez avoir au moins 16 ans';
                        }
                        return null;
                      },
                    ),
                    if (_previewAge != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Âge : $_previewAge ans',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),

                    // ── Mot de passe ─────────────────────────────────────
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

                    // ── Confirmer le mot de passe ────────────────────────
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
                        if (val != pwd) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
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
                            : const Text("Créer mon compte"),
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
