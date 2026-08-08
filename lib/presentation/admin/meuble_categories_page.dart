import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:habitafrance/data/datasources/meuble_categories.dart';
import 'package:habitafrance/presentation/widgets/app_list_search_field.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/presentation/widgets/unsaved_changes_dialog.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';

class MeubleCategoriesPage extends StatefulWidget {
  final ValueChanged<bool>? onFormOpenChanged;

  const MeubleCategoriesPage({super.key, this.onFormOpenChanged});

  @override
  State<MeubleCategoriesPage> createState() => _MeubleCategoriesPageState();
}

class _MeubleCategoriesPageState extends State<MeubleCategoriesPage> {
  late Future<List<MeubleCategoryModel>> _future;
  MeubleCategoryModel? _editing;
  bool _showForm = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _future = MeubleCategoriesDatasource.listAll();
      });

  void _openCreation() {
    widget.onFormOpenChanged?.call(true);
    setState(() { _editing = null; _showForm = true; });
  }

  void _openEdition(MeubleCategoryModel cat) {
    widget.onFormOpenChanged?.call(true);
    setState(() { _editing = cat; _showForm = true; });
  }

  void _closeForm() {
    widget.onFormOpenChanged?.call(false);
    setState(() { _showForm = false; _editing = null; });
  }

  void _onSaved() {
    _closeForm();
    _reload();
  }

  Future<void> _confirmDelete(MeubleCategoryModel cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette catégorie ?'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${cat.nom} » ?\n'
          'Les types de meuble utilisant cette catégorie ne seront pas affectés '
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
      await MeubleCategoriesDatasource.delete(cat.id);
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
      return _CategoryFormWithBack(
        category: _editing,
        onBack: _closeForm,
        onSaved: _onSaved,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── En-tête ──────────────────────────────────────────────────────────
        AppTopBar(
          title: 'Catégories de meuble',
          trailing: FilledButton.icon(
            onPressed: _openCreation,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle catégorie'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
          child: Text(
            'Gérez les catégories utilisées pour classer les types de meuble.',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Recherche ─────────────────────────────────────────────────────────
        AppListSearchField(
          hint: 'Rechercher par nom…',
          onChanged: (q) => setState(() => _search = q),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── En-tête de colonnes ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('Nom',
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ),
              Expanded(
                flex: 1,
                child: Text('Ordre',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ),
              const SizedBox(width: 96),
            ],
          ),
        ),
        const Divider(height: 8),

        // ── Liste ─────────────────────────────────────────────────────────────
        Expanded(
          child: FutureBuilder<List<MeubleCategoryModel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erreur : ${snap.error}'));
              }
              final all = snap.data ?? [];
              final items = _search.isEmpty
                  ? all
                  : all.where((c) =>
                      c.nom.toLowerCase().contains(_search)).toList();
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_outlined,
                          size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Aucune catégorie enregistrée',
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: _openCreation,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une catégorie'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _CategoryRow(
                  category: items[i],
                  onEdit: () => _openEdition(items[i]),
                  onDelete: () => _confirmDelete(items[i]),
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

class _CategoryRow extends StatelessWidget {
  final MeubleCategoryModel category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryRow({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(category.nom, style: AppTypography.bodyMd),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${category.ordre}',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
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

class _CategoryFormWithBack extends StatefulWidget {
  final MeubleCategoryModel? category;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  const _CategoryFormWithBack({
    required this.onBack,
    required this.onSaved,
    this.category,
  });

  @override
  State<_CategoryFormWithBack> createState() => _CategoryFormWithBackState();
}

class _CategoryFormWithBackState extends State<_CategoryFormWithBack> {
  final _contentKey = GlobalKey<_CategoryFormState>();

  Future<void> _handleBack() async {
    final choice = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    if (choice == UnsavedChoice.cancel) return;
    if (choice == UnsavedChoice.save) {
      await _contentKey.currentState?.trySubmit();
      return;
    }
    widget.onBack();
  }

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
                onPressed: _handleBack,
                tooltip: 'Retour à la liste',
              ),
              const SizedBox(width: 16),
              Text(
                widget.category == null
                    ? 'Nouvelle catégorie'
                    : 'Modifier la catégorie',
                style: AppTypography.titleLg,
              ),
            ],
          ),
        ),
        Expanded(
          child: _CategoryForm(
            key: _contentKey,
            category: widget.category,
            onSaved: widget.onSaved,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CategoryForm extends StatefulWidget {
  final MeubleCategoryModel? category;
  final VoidCallback onSaved;

  const _CategoryForm({super.key, this.category, required this.onSaved});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isSubmitting = false;

  bool get _isEditing => widget.category != null;

  Future<void> trySubmit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    setState(() => _isSubmitting = true);
    try {
      final nom   = (values['nom'] as String).trim();
      final ordre = int.tryParse((values['ordre'] as String?) ?? '') ?? 0;
      if (_isEditing) {
        await MeubleCategoriesDatasource.update(
          widget.category!.copyWith(nom: nom, ordre: ordre),
        );
      } else {
        await MeubleCategoriesDatasource.create(nom: nom, ordre: ordre);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Catégorie modifiée avec succès'
            : 'Catégorie créée avec succès'),
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
    final cat = widget.category;
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
                  name: 'nom',
                  initialValue: cat?.nom,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    hintText: 'ex: Mobilier, Literie, Électroménager',
                  ),
                  validator: FormBuilderValidators.required(),
                ),
                const SizedBox(height: AppSpacing.md),
                FormBuilderTextField(
                  name: 'ordre',
                  initialValue: (cat?.ordre ?? 0).toString(),
                  decoration: const InputDecoration(
                    labelText: "Ordre d'affichage",
                    helperText: 'Entier — plus petit = affiché en premier.',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : trySubmit,
                      style: AppTheme.saveButtonStyle,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined),
                      label:
                          Text(_isEditing ? 'Enregistrer' : 'Créer la catégorie'),
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
