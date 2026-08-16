import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:habitafrance/data/datasources/payment_types.dart';
import 'package:habitafrance/data/models/fournisseur.dart';
import 'package:habitafrance/presentation/widgets/app_list_search_field.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────

class PaymentTypesPage extends StatefulWidget {
  const PaymentTypesPage({super.key});

  @override
  State<PaymentTypesPage> createState() => _PaymentTypesPageState();
}

class _PaymentTypesPageState extends State<PaymentTypesPage> {
  late Future<List<PaymentTypeRef>> _future;
  PaymentTypeRef? _editing;
  bool _showForm = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _future = PaymentTypesDatasource.listAll();
      });

  void _openCreation() => setState(() {
        _editing = null;
        _showForm = true;
      });

  void _openEdition(PaymentTypeRef pt) => setState(() {
        _editing = pt;
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

  Future<void> _confirmDelete(PaymentTypeRef pt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce type de paiement ?'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${pt.label} » ?\n'
          'Les fournisseurs utilisant ce type ne seront pas affectés '
          '(la valeur est stockée comme texte).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: AppTheme.deleteButtonStyle,
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PaymentTypesDatasource.delete(pt.id);
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
      return _PaymentTypeFormWithBack(
        paymentType: _editing,
        onBack: _closeForm,
        onSaved: _onSaved,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── En-tête ──────────────────────────────────────────────────────────
        AppTopBar(
          title: 'Types de paiement',
          trailing: FilledButton.icon(
            onPressed: _openCreation,
            icon: const Icon(Icons.add),
            label: const Text('Nouveau type'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
          child: Text(
            'Gérez les moyens de paiement disponibles sur la plateforme.',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Recherche ─────────────────────────────────────────────────────────
        AppListSearchField(
          hint: 'Rechercher par libellé, code ou description…',
          onChanged: (q) => setState(() => _search = q),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Liste ─────────────────────────────────────────────────────────────
        Expanded(
          child: FutureBuilder<List<PaymentTypeRef>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erreur : ${snap.error}'));
              }
              final all = snap.data ?? [];
              final list = _search.isEmpty
                  ? all
                  : all.where((p) =>
                      p.label.toLowerCase().contains(_search) ||
                      p.code.toLowerCase().contains(_search) ||
                      (p.description?.toLowerCase().contains(_search) ?? false))
                  .toList();
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payment_outlined,
                          size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Aucun type de paiement enregistré',
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: _openCreation,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un type'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _PaymentRow(
                  paymentType: list[i],
                  onEdit: () => _openEdition(list[i]),
                  onDelete: () => _confirmDelete(list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentRow extends StatelessWidget {
  final PaymentTypeRef paymentType;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PaymentRow({
    required this.paymentType,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 0, vertical: AppSpacing.xs),
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryFixed,
        child: Icon(
          Icons.payment_outlined,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Text(paymentType.label, style: AppTypography.bodyMd),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              paymentType.code,
              style: AppTypography.labelSm.copyWith(
                  color: AppColors.primary, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
      subtitle: paymentType.description != null
          ? Text(
              paymentType.description!,
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              color: AppColors.primary,
              onPressed: onEdit),
          IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Supprimer',
              color: AppColors.error,
              onPressed: onDelete),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentTypeFormWithBack extends StatelessWidget {
  final PaymentTypeRef? paymentType;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  const _PaymentTypeFormWithBack({
    required this.onBack,
    required this.onSaved,
    this.paymentType,
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
                paymentType == null
                    ? 'Nouveau type de paiement'
                    : 'Modifier le type de paiement',
                style: AppTypography.titleLg,
              ),
            ],
          ),
        ),
        Expanded(
          child: _PaymentTypeForm(
            paymentType: paymentType,
            onSaved: onSaved,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentTypeForm extends StatefulWidget {
  final PaymentTypeRef? paymentType;
  final VoidCallback onSaved;

  const _PaymentTypeForm({this.paymentType, required this.onSaved});

  @override
  State<_PaymentTypeForm> createState() => _PaymentTypeFormState();
}

class _PaymentTypeFormState extends State<_PaymentTypeForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isSubmitting = false;

  bool get _isEditing => widget.paymentType != null;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    setState(() => _isSubmitting = true);
    try {
      final description = (values['description'] as String?)?.trim();
      if (_isEditing) {
        await PaymentTypesDatasource.update(
          id: widget.paymentType!.id,
          code: values['code'] as String,
          label: values['label'] as String,
          description: description?.isEmpty == true ? null : description,
        );
      } else {
        await PaymentTypesDatasource.create(
          code: values['code'] as String,
          label: values['label'] as String,
          description: description?.isEmpty == true ? null : description,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            _isEditing ? 'Type modifié avec succès' : 'Type créé avec succès'),
      ));
      widget.onSaved();
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
    final pt = widget.paymentType;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: FormBuilder(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormBuilderTextField(
                  name: 'code',
                  initialValue: pt?.code,
                  decoration: const InputDecoration(
                    labelText: 'Code (identifiant unique) *',
                    hintText: 'ex: virement, cheque, wero',
                    helperText:
                        'Minuscules, sans accents, underscores autorisés.',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                    LengthLimitingTextInputFormatter(40),
                  ],
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    (v) {
                      if (v != null &&
                          v.isNotEmpty &&
                          !RegExp(r'^[a-z0-9_]+$').hasMatch(v.trim())) {
                        return 'Minuscules, chiffres et _ uniquement';
                      }
                      return null;
                    },
                  ]),
                ),
                const SizedBox(height: AppSpacing.md),
                FormBuilderTextField(
                  name: 'label',
                  initialValue: pt?.label,
                  decoration: const InputDecoration(
                    labelText: 'Libellé *',
                    hintText: 'ex: Virement bancaire',
                  ),
                  validator: FormBuilderValidators.required(),
                ),
                const SizedBox(height: AppSpacing.md),
                FormBuilderTextField(
                  name: 'description',
                  initialValue: pt?.description,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Courte description du moyen de paiement',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      style: AppTheme.saveButtonStyle,
                      icon: _isSubmitting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.onTertiaryFixed),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isEditing ? 'Enregistrer' : 'Créer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
