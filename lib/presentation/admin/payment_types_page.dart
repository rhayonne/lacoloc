import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/payment_types.dart';
import 'package:lacoloc_front/data/models/fournisseur.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

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

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Types de paiement', style: AppTypography.headlineMd),
                  const SizedBox(height: 2),
                  Text(
                    'Gérez les moyens de paiement disponibles sur la plateforme.',
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openCreation,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
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
                final list = snap.data ?? [];
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
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter un type'),
                        ),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: _PaymentTypesTable(
                    types: list,
                    onEdit: _openEdition,
                    onDelete: _confirmDelete,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentTypesTable extends StatelessWidget {
  final List<PaymentTypeRef> types;
  final ValueChanged<PaymentTypeRef> onEdit;
  final ValueChanged<PaymentTypeRef> onDelete;

  const _PaymentTypesTable({
    required this.types,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columnSpacing: 24,
      headingRowColor: WidgetStateProperty.all(AppColors.surfaceContainerLow),
      columns: const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Code')),
        DataColumn(label: Text('Libellé')),
        DataColumn(label: Text('Description')),
        DataColumn(label: Text('Actions')),
      ],
      rows: types.map((pt) {
        return DataRow(cells: [
          DataCell(Text(pt.id.toString(),
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant))),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(pt.code,
                  style: AppTypography.labelSm.copyWith(
                      fontFamily: 'monospace', color: AppColors.primary)),
            ),
          ),
          DataCell(Text(pt.label, style: AppTypography.bodyMd)),
          DataCell(Text(pt.description ?? '—',
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant))),
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Modifier',
                onPressed: () => onEdit(pt),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppColors.error),
                tooltip: 'Supprimer',
                onPressed: () => onDelete(pt),
              ),
            ],
          )),
        ]);
      }).toList(),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: FormBuilder(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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

              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isEditing
                    ? 'Enregistrer les modifications'
                    : 'Créer le type de paiement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
