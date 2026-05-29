import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class MeubleTypesPage extends StatefulWidget {
  const MeubleTypesPage({super.key});

  @override
  State<MeubleTypesPage> createState() => _MeubleTypesPageState();
}

class _MeubleTypesPageState extends State<MeubleTypesPage> {
  late Future<List<MeubleReferenceModel>> _future;
  MeubleReferenceModel? _editing;
  bool _showForm = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _future = InventaireDatasource.listMeubleReferences();
      });

  void _openCreation() => setState(() {
        _editing = null;
        _showForm = true;
      });

  void _openEdition(MeubleReferenceModel mt) => setState(() {
        _editing = mt;
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

  Future<void> _confirmDelete(MeubleReferenceModel mt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce type de meuble ?'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${mt.nom} » ?\n'
          'Les articles de l\'inventaire référençant ce type ne seront pas supprimés.',
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
      await InventaireDatasource.deleteRef(mt.id);
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
      return _MeubleTypeFormWithBack(
        meubleType: _editing,
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
                  Text('Types de meuble', style: AppTypography.headlineMd),
                  const SizedBox(height: 2),
                  Text(
                    'Gérez les types d\'articles disponibles dans l\'inventaire.',
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
          const SizedBox(height: AppSpacing.md),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher par nom ou catégorie…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: FutureBuilder<List<MeubleReferenceModel>>(
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
                    : all
                        .where((m) =>
                            m.nom.toLowerCase().contains(_search) ||
                            (m.categorie?.toLowerCase().contains(_search) ??
                                false))
                        .toList();
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chair_outlined,
                            size: 48, color: AppColors.onSurfaceVariant),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Aucun type de meuble enregistré',
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
                  child: _MeubleTypesTable(
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

class _MeubleTypesTable extends StatelessWidget {
  final List<MeubleReferenceModel> types;
  final ValueChanged<MeubleReferenceModel> onEdit;
  final ValueChanged<MeubleReferenceModel> onDelete;

  const _MeubleTypesTable({
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
        DataColumn(label: Text('Nom')),
        DataColumn(label: Text('Catégorie')),
        DataColumn(label: Text('Actions')),
      ],
      rows: types.map((mt) {
        return DataRow(cells: [
          DataCell(Text(
            mt.id.toString(),
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          )),
          DataCell(Text(mt.nom, style: AppTypography.bodyMd)),
          DataCell(
            mt.categorie != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mt.categorie!,
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.primary),
                    ),
                  )
                : Text(
                    '—',
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
          ),
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Modifier',
                onPressed: () => onEdit(mt),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppColors.error),
                tooltip: 'Supprimer',
                onPressed: () => onDelete(mt),
              ),
            ],
          )),
        ]);
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MeubleTypeFormWithBack extends StatelessWidget {
  final MeubleReferenceModel? meubleType;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  const _MeubleTypeFormWithBack({
    required this.onBack,
    required this.onSaved,
    this.meubleType,
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
                meubleType == null
                    ? 'Nouveau type de meuble'
                    : 'Modifier le type de meuble',
                style: AppTypography.titleLg,
              ),
            ],
          ),
        ),
        Expanded(
          child: _MeubleTypeForm(
            meubleType: meubleType,
            onSaved: onSaved,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MeubleTypeForm extends StatefulWidget {
  final MeubleReferenceModel? meubleType;
  final VoidCallback onSaved;

  const _MeubleTypeForm({this.meubleType, required this.onSaved});

  @override
  State<_MeubleTypeForm> createState() => _MeubleTypeFormState();
}

class _MeubleTypeFormState extends State<_MeubleTypeForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isSubmitting = false;

  bool get _isEditing => widget.meubleType != null;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    setState(() => _isSubmitting = true);
    try {
      final nom = (values['nom'] as String).trim();
      final categorie = (values['categorie'] as String?)?.trim();
      final cat = (categorie?.isEmpty ?? true) ? null : categorie;
      if (_isEditing) {
        await InventaireDatasource.updateRef(
          widget.meubleType!.id,
          nom: nom,
          categorie: cat,
        );
      } else {
        await InventaireDatasource.createRef(nom: nom, categorie: cat);
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
    final mt = widget.meubleType;
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
                name: 'nom',
                initialValue: mt?.nom,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  hintText: 'ex: Chaise, Bureau, Armoire',
                ),
                validator: FormBuilderValidators.required(),
              ),
              const SizedBox(height: AppSpacing.md),
              FormBuilderTextField(
                name: 'categorie',
                initialValue: mt?.categorie,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  hintText: 'ex: Mobilier, Électroménager, Literie',
                  helperText:
                      'Optionnel — permet de regrouper les types similaires.',
                ),
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
                    : 'Créer le type de meuble'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
