import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:habitafrance/data/datasources/inventaire.dart';
import 'package:habitafrance/data/datasources/meuble_categories.dart';
import 'package:habitafrance/data/models/inventaire.dart';
import 'package:habitafrance/presentation/widgets/app_list_search_field.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/presentation/widgets/unsaved_changes_dialog.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';

class MeubleTypesPage extends StatefulWidget {
  /// Appelé quand l'état du formulaire (ouvert/fermé) change.
  final ValueChanged<bool>? onFormOpenChanged;

  const MeubleTypesPage({super.key, this.onFormOpenChanged});

  @override
  State<MeubleTypesPage> createState() => _MeubleTypesPageState();
}

class _MeubleTypesPageState extends State<MeubleTypesPage> {
  late Future<List<MeubleReferenceModel>> _future;
  late Future<List<MeubleCategoryModel>> _categoriesFuture;
  MeubleReferenceModel? _editing;
  bool _showForm = false;
  String _search = '';
  String? _selectedCategory; // null = toutes les catégories

  @override
  void initState() {
    super.initState();
    _reload();
    _categoriesFuture = MeubleCategoriesDatasource.listAll();
  }

  void _reload() => setState(() {
        _future = InventaireDatasource.listMeubleReferences();
      });

  void _openCreation() {
    widget.onFormOpenChanged?.call(true);
    setState(() { _editing = null; _showForm = true; });
  }

  void _openEdition(MeubleReferenceModel mt) {
    widget.onFormOpenChanged?.call(true);
    setState(() { _editing = mt; _showForm = true; });
  }

  void _closeForm() {
    widget.onFormOpenChanged?.call(false);
    setState(() { _showForm = false; _editing = null; });
  }

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
          "Les articles de l'inventaire référençant ce type ne seront pas supprimés.",
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
        categoriesFuture: _categoriesFuture,
        onBack: _closeForm,
        onSaved: _onSaved,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── En-tête ──────────────────────────────────────────────────────────
        AppTopBar(
          title: 'Types de meuble',
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
            "Gérez les types d'articles disponibles dans l'inventaire.",
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Recherche ─────────────────────────────────────────────────────────
        AppListSearchField(
          hint: 'Rechercher par nom ou catégorie…',
          onChanged: (q) => setState(() => _search = q),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Filtres par catégorie (chips) ─────────────────────────────────────
        FutureBuilder<List<MeubleCategoryModel>>(
          future: _categoriesFuture,
          builder: (ctx, snap) {
            final cats = snap.data ?? [];
            if (cats.isEmpty) return const SizedBox.shrink();
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  // Chip "Toutes"
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: FilterChip(
                      label: const Text('Toutes'),
                      selected: _selectedCategory == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = null),
                    ),
                  ),
                  ...cats.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: FilterChip(
                          label: Text(cat.nom),
                          selected: _selectedCategory == cat.nom,
                          onSelected: (_) => setState(() =>
                              _selectedCategory = _selectedCategory == cat.nom
                                  ? null
                                  : cat.nom),
                        ),
                      )),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),

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
                flex: 2,
                child: Text('Catégorie',
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
              final items = all.where((m) {
                final matchSearch = _search.isEmpty ||
                    m.nom.toLowerCase().contains(_search) ||
                    (m.categorie?.toLowerCase().contains(_search) ?? false);
                final matchCat = _selectedCategory == null ||
                    m.categorie == _selectedCategory;
                return matchSearch && matchCat;
              }).toList();

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chair_outlined,
                          size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Aucun type de meuble trouvé',
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
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _MeubleRow(
                  meuble: items[i],
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

class _MeubleRow extends StatelessWidget {
  final MeubleReferenceModel meuble;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MeubleRow({
    required this.meuble,
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
            child: Text(meuble.nom, style: AppTypography.bodyMd),
          ),
          Expanded(
            flex: 2,
            child: Text(
              meuble.categorie ?? '—',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: meuble.categorie != null
                    ? AppColors.onSurface
                    : AppColors.onSurfaceVariant,
              ),
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

class _MeubleTypeFormWithBack extends StatefulWidget {
  final MeubleReferenceModel? meubleType;
  final Future<List<MeubleCategoryModel>> categoriesFuture;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  const _MeubleTypeFormWithBack({
    required this.onBack,
    required this.onSaved,
    required this.categoriesFuture,
    this.meubleType,
  });

  @override
  State<_MeubleTypeFormWithBack> createState() =>
      _MeubleTypeFormWithBackState();
}

class _MeubleTypeFormWithBackState extends State<_MeubleTypeFormWithBack> {
  final _contentKey = GlobalKey<_MeubleTypeFormState>();

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
                widget.meubleType == null
                    ? 'Nouveau type de meuble'
                    : 'Modifier le type de meuble',
                style: AppTypography.titleLg,
              ),
            ],
          ),
        ),
        Expanded(
          child: _MeubleTypeForm(
            key: _contentKey,
            meubleType: widget.meubleType,
            categoriesFuture: widget.categoriesFuture,
            onSaved: widget.onSaved,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MeubleTypeForm extends StatefulWidget {
  final MeubleReferenceModel? meubleType;
  final Future<List<MeubleCategoryModel>> categoriesFuture;
  final VoidCallback onSaved;

  const _MeubleTypeForm({
    super.key,
    this.meubleType,
    required this.categoriesFuture,
    required this.onSaved,
  });

  @override
  State<_MeubleTypeForm> createState() => _MeubleTypeFormState();
}

class _MeubleTypeFormState extends State<_MeubleTypeForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isSubmitting = false;
  List<MeubleCategoryModel> _categories = [];

  bool get _isEditing => widget.meubleType != null;

  @override
  void initState() {
    super.initState();
    widget.categoriesFuture.then((cats) {
      if (mounted) setState(() => _categories = cats);
    });
  }

  Future<void> trySubmit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    setState(() => _isSubmitting = true);
    try {
      final nom = (values['nom'] as String).trim();
      final cat = values['categorie'] as String?;
      final categorie = (cat?.isEmpty ?? true) ? null : cat;
      if (_isEditing) {
        await InventaireDatasource.updateRef(
          widget.meubleType!.id,
          nom: nom,
          categorie: categorie,
        );
      } else {
        await InventaireDatasource.createRef(nom: nom, categorie: categorie);
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
                  initialValue: mt?.nom,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    hintText: 'ex: Chaise, Bureau, Armoire',
                  ),
                  validator: FormBuilderValidators.required(),
                ),
                const SizedBox(height: AppSpacing.md),
                // Dropdown catégorie depuis la DB
                if (_categories.isNotEmpty)
                  FormBuilderDropdown<String>(
                    name: 'categorie',
                    initialValue: mt?.categorie,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('— Aucune catégorie —'),
                      ),
                      ..._categories.map((cat) => DropdownMenuItem(
                            value: cat.nom,
                            child: Text(cat.nom),
                          )),
                    ],
                  )
                else
                  FormBuilderTextField(
                    name: 'categorie',
                    initialValue: mt?.categorie,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      hintText: 'ex: Mobilier, Électroménager',
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : trySubmit,
                      style: AppTheme.saveButtonStyle,
                      icon: _isSubmitting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.onTertiaryFixed),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isEditing ? 'Enregistrer' : 'Créer le type'),
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
