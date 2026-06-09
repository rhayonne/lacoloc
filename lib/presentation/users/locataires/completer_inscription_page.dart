import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/utils/phone_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacoloc_front/utils/auth_error.dart';

/// Page de complétion de profil pour un locataire invité par un propriétaire.
/// Pré-remplit les champs avec les données saisies par le propriétaire.
/// Le locataire doit choisir un mot de passe pour finaliser son compte.
class CompleterInscriptionPage extends StatefulWidget {
  const CompleterInscriptionPage({super.key});

  @override
  State<CompleterInscriptionPage> createState() =>
      _CompleterInscriptionPageState();
}

class _CompleterInscriptionPageState extends State<CompleterInscriptionPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  late Future<UsersClient?> _profileFuture;
  bool _isLoading = false;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  int? _previewAge;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService.loadCurrentProfile();
  }

  static int _computeAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _submit(UsersClient profile) async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;

    setState(() => _isLoading = true);
    try {
      final password = values['password'] as String;
      final fullName = (values['full_name'] as String).trim();
      final rawPhone = (values['phone'] as String?)?.trim();
      final phone = (rawPhone?.isEmpty ?? true) ? null : rawPhone;
      final dob = values['date_of_birth'] as DateTime?;

      // Définit le mot de passe et retire le flag needs_completion
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: password,
          data: {'needs_completion': false},
        ),
      );

      // Met à jour le profil Users_Client
      await AuthService.updateProfile(
        fullName: fullName,
        phone: phone,
        age: dob != null ? _computeAge(dob) : null,
        dateOfBirth: dob,
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/profile');
      }
    } catch (e) {
      _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lastDateAllowed = DateTime(now.year - 16, now.month, now.day);

    return FutureBuilder<UsersClient?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.link_off,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Lien invalide ou expiré',
                      style: AppTypography.titleLg,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Demandez à votre propriétaire de renvoyer l\'invitation.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/'),
                      child: const Text("Aller à l'accueil"),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
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
                          'Complétez votre inscription',
                          style: AppTypography.headlineMd,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Votre propriétaire a créé un profil pour vous. '
                          'Créez votre mot de passe pour finaliser votre compte.',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // ── E-mail (lecture seule) ───────────────────────
                        _label('E-MAIL'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: AppRadius.borderSm,
                            border:
                                Border.all(color: AppColors.outlineVariant),
                          ),
                          child: Text(
                            profile.email,
                            style: AppTypography.bodyMd,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Nom complet (pré-rempli) ─────────────────────
                        _label('NOM COMPLET'),
                        FormBuilderTextField(
                          name: 'full_name',
                          initialValue: profile.fullName ?? '',
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Jean Dupont',
                          ),
                          validator: FormBuilderValidators.required(
                            errorText: 'Champ obligatoire',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Téléphone (pré-rempli si fourni) ────────────
                        _label('TÉLÉPHONE'),
                        PhoneField(
                          name: 'phone',
                          initialValue: profile.phone,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Date de naissance ────────────────────────────
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
                          onChanged: (v) => setState(
                            () => _previewAge =
                                v != null ? _computeAge(v) : null,
                          ),
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

                        // ── Mot de passe ─────────────────────────────────
                        _label('MOT DE PASSE'),
                        FormBuilderTextField(
                          name: 'password',
                          obscureText: _obscurePwd,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePwd
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
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

                        // ── Confirmer le mot de passe ────────────────────
                        _label('CONFIRMER LE MOT DE PASSE'),
                        FormBuilderTextField(
                          name: 'password_confirm',
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                          validator: (val) {
                            final pwd = _formKey.currentState
                                ?.fields['password']?.value as String?;
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
                          child: FilledButton(
                            onPressed:
                                _isLoading ? null : () => _submit(profile),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                : const Text('Finaliser mon inscription'),
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
      },
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
