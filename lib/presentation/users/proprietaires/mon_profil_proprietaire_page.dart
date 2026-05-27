import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/utils/phone_field.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class MonProfilProprietairePage extends StatefulWidget {
  const MonProfilProprietairePage({super.key});

  @override
  State<MonProfilProprietairePage> createState() =>
      _MonProfilProprietairePageState();
}

class _MonProfilProprietairePageState extends State<MonProfilProprietairePage> {
  late Future<UsersClient?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService.loadCurrentProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UsersClient?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur : ${snapshot.error}',
              style: AppTypography.bodyMd.copyWith(color: AppColors.error),
            ),
          );
        }
        return _ProfilForm(profile: snapshot.data);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProfilForm extends StatefulWidget {
  final UsersClient? profile;
  const _ProfilForm({required this.profile});

  @override
  State<_ProfilForm> createState() => _ProfilFormState();
}

class _ProfilFormState extends State<_ProfilForm> {
  bool _isEditing = false;
  bool _isSaving = false;

  late final TextEditingController _nameCtrl;

  late String _displayName;
  late String _displayPhone;

  GlobalKey<FormBuilderState> _phoneFormKey = GlobalKey<FormBuilderState>();

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _displayName = widget.profile?.fullName ?? '';
    _displayPhone = widget.profile?.phone ?? '';
    _nameCtrl = TextEditingController(text: _displayName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) {
      _nameCtrl.text = _displayName;
      // Recreating the key destroys and rebuilds the FormBuilder, resetting
      // the PhoneField to _displayPhone.
      setState(() {
        _isEditing = false;
        _phoneFormKey = GlobalKey<FormBuilderState>();
      });
    } else {
      setState(() => _isEditing = true);
    }
  }

  Future<void> _save() async {
    final newName = _nameCtrl.text.trim();
    final newPhone =
        PhoneField.fullNumberFromState(_phoneFormKey.currentState, 'phone') ??
        '';
    setState(() => _isSaving = true);
    try {
      await AuthService.updateProfile(
        fullName: newName,
        phone: newPhone.isEmpty ? null : newPhone,
      );
      if (!mounted) return;
      setState(() {
        _displayName = newName;
        _displayPhone = newPhone;
        _isEditing = false;
        _isSaving = false;
        // Recreate key so the field reinitialises with the newly saved value.
        _phoneFormKey = GlobalKey<FormBuilderState>();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final email = profile?.email ?? AuthService.currentUser?.email ?? '';
    final createdAt = profile?.createdAt;
    final initial = (_displayName.isNotEmpty ? _displayName : email)
        .substring(0, 1)
        .toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Barre de titre ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(color: AppColors.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Mon Profil', style: AppTypography.titleLg),
              ),
              IconButton(
                icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
                tooltip: _isEditing ? 'Annuler' : 'Modifier',
                color: _isEditing ? AppColors.error : null,
                onPressed: _toggleEdit,
              ),
              IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.save_outlined,
                        color: _isEditing
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant
                                .withValues(alpha: 0.35),
                      ),
                tooltip: 'Sauvegarder',
                onPressed: _isEditing && !_isSaving ? _save : null,
              ),
            ],
          ),
        ),

        // ── Corps ────────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.primaryFixed,
                            child: Text(
                              initial,
                              style: AppTypography.headlineMd.copyWith(
                                color: AppColors.onPrimaryFixedVariant,
                              ),
                            ),
                          ),
                          if (_isEditing)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surfaceContainerLowest,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Nom complet
                    _fieldLabel('NOM COMPLET'),
                    TextField(
                      controller: _nameCtrl,
                      enabled: _isEditing,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(hintText: 'Jean Dupont'),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // E-mail
                    _fieldLabel('E-MAIL'),
                    _staticField(email),
                    const SizedBox(height: AppSpacing.lg),

                    // Téléphone
                    _fieldLabel('TÉLÉPHONE'),
                    if (_isEditing)
                      FormBuilder(
                        key: _phoneFormKey,
                        child: PhoneField(
                          name: 'phone',
                          initialValue: _displayPhone,
                        ),
                      )
                    else
                      _staticField(
                        _displayPhone.isEmpty ? '—' : _displayPhone,
                      ),
                    const SizedBox(height: AppSpacing.lg),

                    // Type de compte
                    _fieldLabel('TYPE DE COMPTE'),
                    _staticField('Propriétaire'),

                    // Membre depuis
                    if (createdAt != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _fieldLabel('MEMBRE DEPUIS'),
                      _staticField(_dateFmt.format(createdAt)),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),

                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              "Pour modifier votre adresse e-mail ou votre "
                              "mot de passe, contactez l'administrateur de "
                              "la plateforme.",
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          text,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _staticField(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(value, style: AppTypography.bodyMd),
      );
}
