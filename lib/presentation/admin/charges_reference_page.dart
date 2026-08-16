import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:habitafrance/data/datasources/charges_reference.dart';
import 'package:habitafrance/data/models/charge_reference.dart';
import 'package:habitafrance/presentation/widgets/app_list_search_field.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/presentation/widgets/unsaved_changes_dialog.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';

class ChargesReferencePage extends StatefulWidget {
  /// Appelé quand l'état du formulaire (ouvert/fermé) change.
  final ValueChanged<bool>? onFormOpenChanged;

  const ChargesReferencePage({super.key, this.onFormOpenChanged});

  @override
  State<ChargesReferencePage> createState() => _ChargesReferencePageState();
}

class _ChargesReferencePageState extends State<ChargesReferencePage> {
  late Future<List<ChargeReferenceModel>> _future;
  ChargeReferenceModel? _editing;
  bool _showForm = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _future = ChargesReferenceDatasource.listAll();
      });

  void _openCreation() {
    widget.onFormOpenChanged?.call(true);
    setState(() { _editing = null; _showForm = true; });
  }

  void _openEdition(ChargeReferenceModel c) {
    widget.onFormOpenChanged?.call(true);
    setState(() { _editing = c; _showForm = true; });
  }

  void _closeForm() {
    widget.onFormOpenChanged?.call(false);
    setState(() { _showForm = false; _editing = null; });
  }

  void _onSaved() {
    _closeForm();
    _reload();
  }

  Future<void> _toggleActive(ChargeReferenceModel c) async {
    try {
      await ChargesReferenceDatasource.toggleActive(c.id, !c.isActive);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _confirmDelete(ChargeReferenceModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette charge ?'),
        content: Text(
          'Voulez-vous supprimer « ${c.nom} » ?\n'
          'Les charges déjà associées aux immeubles/chambres ne seront pas supprimées.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: AppTheme.deleteButtonStyle,
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ChargesReferenceDatasource.delete(c.id);
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
      return _ChargeFormWithBack(
        charge: _editing,
        onBack: _closeForm,
        onSaved: _onSaved,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Charges locatives',
          trailing: FilledButton.icon(
            onPressed: _openCreation,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle charge'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
          child: Text(
            'Gérez les types de charges disponibles pour tous les propriétaires.',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppListSearchField(
          hint: 'Rechercher…',
          onChanged: (q) => setState(() => _search = q),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: FutureBuilder<List<ChargeReferenceModel>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erreur : ${snap.error}'));
              }
              final items = (snap.data ?? [])
                  .where((c) =>
                      _search.isEmpty ||
                      c.nom.toLowerCase().contains(_search) ||
                      (c.description ?? '').toLowerCase().contains(_search))
                  .toList();
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucune charge trouvée.',
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: _openCreation,
                        icon: const Icon(Icons.add),
                        label: const Text('Nouvelle charge'),
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
                itemBuilder: (_, i) => _ChargeRow(
                  charge: items[i],
                  onEdit: () => _openEdition(items[i]),
                  onToggle: () => _toggleActive(items[i]),
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

class _ChargeRow extends StatelessWidget {
  final ChargeReferenceModel charge;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ChargeRow({
    required this.charge,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 0, vertical: AppSpacing.xs),
      leading: CircleAvatar(
        backgroundColor: charge.isActive
            ? AppColors.primaryFixed
            : AppColors.surfaceContainerHigh,
        child: Icon(
          charge.iconData,
          color: charge.isActive ? AppColors.primary : AppColors.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Text(charge.nom, style: AppTypography.bodyMd),
          if (!charge.isActive) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Inactif',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ],
        ],
      ),
      subtitle: charge.description != null
          ? Text(charge.description!,
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: charge.isActive ? 'Désactiver' : 'Activer',
            child: Switch(
              value: charge.isActive,
              onChanged: (_) => onToggle(),
              activeThumbColor: AppColors.primary,
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

class _ChargeFormWithBack extends StatefulWidget {
  final ChargeReferenceModel? charge;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  const _ChargeFormWithBack({
    required this.charge,
    required this.onBack,
    required this.onSaved,
  });

  @override
  State<_ChargeFormWithBack> createState() => _ChargeFormWithBackState();
}

class _ChargeFormWithBackState extends State<_ChargeFormWithBack> {
  final _contentKey = GlobalKey<_ChargeFormContentState>();

  Future<void> _handleBack() async {
    final choice = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    if (choice == UnsavedChoice.cancel) return;
    if (choice == UnsavedChoice.save) {
      // trySubmit valide + sauvegarde + appelle onSaved si succès
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
                widget.charge == null
                    ? 'Nouvelle charge'
                    : 'Modifier la charge',
                style: AppTypography.titleLg,
              ),
            ],
          ),
        ),
        Expanded(
          child: _ChargeFormContent(
            key: _contentKey,
            charge: widget.charge,
            onSaved: widget.onSaved,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChargeFormContent extends StatefulWidget {
  final ChargeReferenceModel? charge;
  final VoidCallback onSaved;

  const _ChargeFormContent({super.key, required this.charge, required this.onSaved});

  @override
  State<_ChargeFormContent> createState() => _ChargeFormContentState();
}

class _ChargeFormContentState extends State<_ChargeFormContent> {
  final _key = GlobalKey<FormBuilderState>();
  bool _saving = false;
  String _selectedIcon = 'receipt_long';

  bool get _isEditing => widget.charge != null;

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.charge?.icone ?? 'receipt_long';
  }

  /// Appelé depuis le bouton "Enregistrer" dans le formulaire.
  Future<void> _submit() => trySubmit();

  /// Valide + sauvegarde. Retourne silencieusement en cas d'erreur de validation.
  /// Appelé aussi depuis le dialog "sauvegarder et quitter".
  Future<void> trySubmit() async {
    if (!(_key.currentState?.saveAndValidate() ?? false)) return;
    final v = _key.currentState!.value;
    setState(() => _saving = true);
    try {
      final ordre = int.tryParse((v['ordre'] as String?) ?? '') ?? 0;
      final model = widget.charge != null
          ? widget.charge!.copyWith(
              nom: v['nom'] as String,
              icone: _selectedIcon,
              description: (v['description'] as String?)?.trim(),
              ordre: ordre,
            )
          : ChargeReferenceModel(
              id: 0,
              nom: v['nom'] as String,
              icone: _selectedIcon,
              description: (v['description'] as String?)?.trim(),
              ordre: ordre,
            );
      _isEditing
          ? await ChargesReferenceDatasource.update(model)
          : await ChargesReferenceDatasource.create(model);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Charge modifiée avec succès'
            : 'Charge créée avec succès'),
      ));
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.charge;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: FormBuilder(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormBuilderTextField(
                  name: 'nom',
                  initialValue: c?.nom,
                  decoration: const InputDecoration(labelText: 'Nom *'),
                  validator: FormBuilderValidators.required(),
                ),
                const SizedBox(height: AppSpacing.md),
                FormBuilderTextField(
                  name: 'description',
                  initialValue: c?.description,
                  decoration:
                      const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),
                FormBuilderTextField(
                  name: 'ordre',
                  initialValue: (c?.ordre ?? 0).toString(),
                  decoration: const InputDecoration(
                    labelText: "Ordre d'affichage",
                    helperText: 'Entier — plus petit = affiché en premier',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Icône', style: AppTypography.labelMd),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: ChargeReferenceModel.kAvailableIcons
                      .map((t) => _IconTile(
                            iconKey: t.$1,
                            icon: t.$2,
                            label: t.$3,
                            selected: _selectedIcon == t.$1,
                            onTap: () =>
                                setState(() => _selectedIcon = t.$1),
                          ))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      style: AppTheme.saveButtonStyle,
                      icon: _saving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.onTertiaryFixed))
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

class _IconTile extends StatelessWidget {
  final String iconKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IconTile({
    required this.iconKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 72,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryFixed
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: selected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
