import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_extra_fields/form_builder_extra_fields.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/fournisseurs.dart';
import 'package:lacoloc_front/data/models/fournisseur.dart';
import 'package:lacoloc_front/presentation/widgets/email_field.dart';
import 'package:lacoloc_front/presentation/widgets/phone_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────

class FournisseursPage extends StatefulWidget {
  const FournisseursPage({super.key});

  @override
  State<FournisseursPage> createState() => _FournisseursPageState();
}

class _FournisseursPageState extends State<FournisseursPage> {
  late Future<List<FournisseurModel>> _future;
  FournisseurModel? _editing;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final ownerId = AuthService.currentUser?.id;
    setState(() {
      _future = ownerId != null
          ? FournisseursDatasource.listByOwner(ownerId)
          : Future.value([]);
    });
  }

  void _openCreation() => setState(() {
        _editing = null;
        _showForm = true;
      });

  void _openEdition(FournisseurModel f) => setState(() {
        _editing = f;
        _showForm = true;
      });

  void _closeForm() => setState(() {
        _showForm = false;
        _editing = null;
      });

  void _onSaved() {
    _closeForm();
    _reload();
  }

  Future<void> _confirmDelete(FournisseurModel f) async {
    final linked = await FournisseursDatasource.hasFactures(f.nom);
    if (!mounted) return;

    if (linked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '« ${f.nom} » est lié à une ou plusieurs factures '
            'et ne peut pas être supprimé.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le fournisseur ?'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${f.nom} » ?\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FournisseursDatasource.delete(f.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showForm) {
      return _FournisseurFormWithBack(
        fournisseur: _editing,
        onBack: _closeForm,
        onSaved: _onSaved,
      );
    }

    return FutureBuilder<List<FournisseurModel>>(
      future: _future,
      builder: (context, snap) {
        final list = snap.data ?? [];
        final isLoading = snap.connectionState == ConnectionState.waiting;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Fournisseurs', style: AppTypography.titleLg),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _openCreation,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (list.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.store_outlined,
                            size: 48, color: AppColors.onSurfaceVariant),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Aucun fournisseur enregistré',
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: _openCreation,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter un fournisseur'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: _FournisseursTable(
                      fournisseurs: list,
                      onEdit: _openEdition,
                      onDelete: _confirmDelete,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FournisseursTable extends StatelessWidget {
  final List<FournisseurModel> fournisseurs;
  final ValueChanged<FournisseurModel> onEdit;
  final ValueChanged<FournisseurModel> onDelete;

  const _FournisseursTable({
    required this.fournisseurs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columnSpacing: 24,
      columns: const [
        DataColumn(label: Text('Nom')),
        DataColumn(label: Text('Catégorie')),
        DataColumn(label: Text('Téléphone')),
        DataColumn(label: Text('E-mail')),
        DataColumn(label: Text('Statut')),
        DataColumn(label: Text('Actions')),
      ],
      rows: fournisseurs.map((f) {
        return DataRow(cells: [
          DataCell(Text(f.nom, style: AppTypography.bodyMd)),
          DataCell(Text(f.categorie ?? '—',
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant))),
          DataCell(Text(f.telephone ?? '—',
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant))),
          DataCell(Text(f.email ?? '—',
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant))),
          DataCell(_StatutBadge(isActive: f.isActive)),
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Modifier',
                onPressed: () => onEdit(f),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppColors.error),
                tooltip: 'Supprimer',
                onPressed: () => onDelete(f),
              ),
            ],
          )),
        ]);
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatutBadge extends StatelessWidget {
  final bool isActive;
  const _StatutBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.tertiary : AppColors.onSurfaceVariant;
    final label = isActive ? 'Actif' : 'Inactif';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FournisseurFormWithBack extends StatelessWidget {
  final FournisseurModel? fournisseur;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  const _FournisseurFormWithBack({
    required this.onBack,
    required this.onSaved,
    this.fournisseur,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
                tooltip: 'Retour à la liste',
              ),
              const SizedBox(width: 16),
              Text(
                fournisseur == null
                    ? 'Nouveau fournisseur'
                    : 'Modifier le fournisseur',
                style: AppTypography.titleLg,
              ),
            ],
          ),
        ),
        Expanded(
          child: FournisseurFormPage(
            fournisseur: fournisseur,
            onSaved: onSaved,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class FournisseurFormPage extends StatefulWidget {
  final FournisseurModel? fournisseur;
  final VoidCallback? onSaved;

  const FournisseurFormPage({super.key, this.fournisseur, this.onSaved});

  @override
  State<FournisseurFormPage> createState() => _FournisseurFormPageState();
}

class _FournisseurFormPageState extends State<FournisseurFormPage> {
  final _formKey = GlobalKey<FormBuilderState>();

  bool _isSubmitting = false;

  static const _codeWero = 'wero';
  static const _codePaypal = 'paypal';

  bool get _isEditing => widget.fournisseur != null;

  void _syncPaymentType(String code, bool hasValue) {
    final current = List<String>.from(
      (_formKey.currentState?.fields['types_paiement']?.value as List?)
              ?.whereType<String>()
              .toList() ??
          [],
    );
    if (hasValue && !current.contains(code)) {
      current.add(code);
      _formKey.currentState?.fields['types_paiement']?.didChange(current);
    } else if (!hasValue && current.contains(code)) {
      current.remove(code);
      _formKey.currentState?.fields['types_paiement']?.didChange(current);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;

    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return;

    setState(() => _isSubmitting = true);
    try {
      String? trimOrNull(String? v) =>
          v?.trim().isEmpty == true ? null : v?.trim();

      final typesPaiement = (values['types_paiement'] as List?)
              ?.whereType<String>()
              .toList() ??
          [];

      final weroPhone = trimOrNull(values['wero_phone'] as String?);
      final paypalEmail = trimOrNull(values['paypal_email'] as String?);

      final model = FournisseurModel(
        id: widget.fournisseur?.id ?? 0,
        ownerId: ownerId,
        nom: values['nom'] as String,
        categorie: trimOrNull(values['categorie'] as String?),
        telephone: trimOrNull(values['telephone'] as String?),
        email: trimOrNull(values['email'] as String?),
        siteWeb: trimOrNull(values['site'] as String?),
        notes: trimOrNull(values['notes'] as String?),
        isActive: (values['is_active'] as bool?) ?? true,
        iban: trimOrNull(
            (values['iban'] as String?)?.replaceAll(' ', '')),
        bic: trimOrNull(values['bic'] as String?),
        titulaireCompte: trimOrNull(values['titulaire'] as String?),
        telephoneWero: weroPhone,
        weroActif: typesPaiement.contains(_codeWero),
        emailPaypal: paypalEmail,
        paypalActif: typesPaiement.contains(_codePaypal),
        typesPaiement: typesPaiement,
      );

      _isEditing
          ? await FournisseursDatasource.update(model)
          : await FournisseursDatasource.create(model);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Fournisseur modifié avec succès'
            : 'Fournisseur créé avec succès'),
      ));
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fournisseur;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: FormBuilder(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Informations générales ─────────────────────────────────
            _SectionHeader(label: 'Informations générales'),
            const SizedBox(height: AppSpacing.md),

            FormBuilderTextField(
              name: 'nom',
              initialValue: f?.nom,
              decoration: const InputDecoration(
                labelText: 'Nom du fournisseur *',
              ),
              validator: FormBuilderValidators.required(),
            ),
            const SizedBox(height: AppSpacing.md),

            FormBuilderTypeAhead<String>(
              name: 'categorie',
              initialValue: f?.categorie,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              suggestionsCallback: (query) async {
                if (query.trim().isEmpty) {
                  return kCategoriesFournisseur.toList();
                }
                return kCategoriesFournisseur
                    .where((c) =>
                        c.toLowerCase().contains(query.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, item) => ListTile(
                dense: true,
                title: Text(item, style: AppTypography.bodyMd),
              ),
              selectionToTextTransformer: (item) => item,
            ),
            const SizedBox(height: AppSpacing.md),

            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 600;
                final phoneField = PhoneField(
                  name: 'telephone',
                  initialValue: f?.telephone,
                );
                final emailField = EmailField(
                  name: 'email',
                  initialValue: f?.email,
                );
                if (narrow) {
                  return Column(children: [
                    phoneField,
                    const SizedBox(height: AppSpacing.md),
                    emailField,
                  ]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: phoneField),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: emailField),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            FormBuilderTextField(
              name: 'site',
              initialValue: f?.siteWeb,
              decoration: const InputDecoration(labelText: 'Site web'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.md),

            FormBuilderTextField(
              name: 'notes',
              initialValue: f?.notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),

            FormBuilderSwitch(
              name: 'is_active',
              initialValue: f?.isActive ?? true,
              title: const Text('Fournisseur actif'),
              subtitle: Text(
                (f?.isActive ?? true)
                    ? 'Visible dans la sélection des factures'
                    : 'Masqué dans la sélection des factures',
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Informations bancaires ─────────────────────────────────
            _SectionHeader(label: 'Informations bancaires'),
            const SizedBox(height: AppSpacing.md),

            FormBuilderTextField(
              name: 'titulaire',
              initialValue: f?.titulaireCompte,
              decoration:
                  const InputDecoration(labelText: 'Titulaire du compte'),
            ),
            const SizedBox(height: AppSpacing.md),

            FormBuilderTextField(
              name: 'iban',
              initialValue: f?.iban,
              decoration: const InputDecoration(
                labelText: 'IBAN',
                hintText: 'FR76 XXXX XXXX XXXX XXXX XXXX XXX',
              ),
              inputFormatters: [_IbanInputFormatter()],
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final clean = v.replaceAll(' ', '');
                if (clean.length < 14 || clean.length > 34) {
                  return 'IBAN invalide (longueur incorrecte)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            FormBuilderTextField(
              name: 'bic',
              initialValue: f?.bic,
              decoration: const InputDecoration(
                labelText: 'BIC / SWIFT',
                hintText: 'BNPAFRPP',
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(11),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final l = v.trim().length;
                if (l != 8 && l != 11) {
                  return 'BIC invalide (8 ou 11 caractères)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            PhoneField(
              key: ValueKey('wero-${f?.id}'),
              name: 'wero_phone',
              initialValue: f?.telephoneWero,
              labelText: 'Téléphone Wero',
              onChanged: (v) =>
                  _syncPaymentType(_codeWero, v != null && v.isNotEmpty),
            ),
            const SizedBox(height: AppSpacing.md),

            EmailField(
              name: 'paypal_email',
              initialValue: f?.emailPaypal,
              labelText: 'E-mail PayPal',
              onChanged: (v) =>
                  _syncPaymentType(_codePaypal, v?.trim().isNotEmpty ?? false),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Moyens de paiement ─────────────────────────────────────
            _SectionHeader(label: 'Moyens de paiement acceptés'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sélectionnez un ou plusieurs moyens de paiement utilisés '
              'par ce fournisseur.',
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),

            FutureBuilder<List<PaymentTypeRef>>(
              future: FournisseursDatasource.listPaymentTypes(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final types = snap.data ?? [];
                return FormBuilderFilterChips<String>(
                  name: 'types_paiement',
                  initialValue: f?.typesPaiement ?? [],
                  options: types
                      .map((pt) => FormBuilderChipOption(
                            value: pt.code,
                            child: Text(pt.label),
                          ))
                      .toList(),
                  spacing: AppSpacing.sm,
                  decoration: const InputDecoration(border: InputBorder.none),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _isEditing
                    ? 'Enregistrer les modifications'
                    : 'Enregistrer',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.titleLg.copyWith(color: AppColors.primary),
        ),
        const Divider(height: 8),
      ],
    );
  }
}

class _IbanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clean = newValue.text.replaceAll(' ', '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
