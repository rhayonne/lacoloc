import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/reference.dart';
import 'package:lacoloc_front/data/models/address_suggestion.dart';
import 'package:lacoloc_front/data/models/immeuble_type.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/presentation/widgets/address_autocomplete_field.dart';
import 'package:lacoloc_front/presentation/widgets/photo_picker_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class NouveauImmeublePage extends StatefulWidget {
  final ImmeublesModel? immeuble;
  final VoidCallback? onSaved;

  const NouveauImmeublePage({super.key, this.immeuble, this.onSaved});

  @override
  State<NouveauImmeublePage> createState() => _NouveauImmeublePageState();
}

class _NouveauImmeublePageState extends State<NouveauImmeublePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _address = '';
  final _cityCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _totalM2Ctrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  late Future<List<ImmeubleTypeModel>> _typesFuture;
  ImmeubleTypeModel? _selectedType;
  List<String> _photos = [];
  String? _mainPhoto;
  bool _isActive = true;
  bool _isSubmitting = false;

  bool get _isEditing => widget.immeuble != null;

  @override
  void initState() {
    super.initState();
    _typesFuture = ReferenceDatasource.immeubleTypes();
    final imm = widget.immeuble;
    if (imm != null) {
      _nameCtrl.text = imm.name;
      _address = imm.address ?? '';
      _cityCtrl.text = imm.city ?? '';
      _regionCtrl.text = imm.region ?? '';
      _departmentCtrl.text = imm.department ?? '';
      _totalM2Ctrl.text = imm.totalM2?.toStringAsFixed(2) ?? '';
      _descriptionCtrl.text = imm.description ?? '';
      _photos = List.from(imm.commonPhotos);
      _mainPhoto = imm.mainPhoto;
      _isActive = imm.isActive;
      _typesFuture.then((types) {
        if (!mounted) return;
        final match = types.where((t) => t.id == imm.typeId).firstOrNull;
        if (match != null) setState(() => _selectedType = match);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _regionCtrl.dispose();
    _departmentCtrl.dispose();
    _totalM2Ctrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _onAddressSuggested(AddressSuggestion s) {
    setState(() {
      _address = s.label;
      _cityCtrl.text = s.city;
      _regionCtrl.text = s.region;
      _departmentCtrl.text = s.department;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sélectionnez un type d'immeuble")),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final model = ImmeublesModel(
        id: widget.immeuble?.id ?? 0,
        name: _nameCtrl.text.trim(),
        ownerId: AuthService.currentUser?.id,
        typeId: _selectedType!.id,
        address: _address.trim().isEmpty ? null : _address.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        region:
            _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim(),
        department: _departmentCtrl.text.trim().isEmpty
            ? null
            : _departmentCtrl.text.trim(),
        totalM2: double.tryParse(_totalM2Ctrl.text.replaceAll(',', '.')),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        commonPhotos: _photos,
        isActive: _isActive,
        mainPhoto: _mainPhoto,
      );
      _isEditing
          ? await ImmeublesDatasource.update(model)
          : await ImmeublesDatasource.create(model);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Immeuble modifié avec succès'
            : 'Immeuble créé avec succès'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? "Modifier l'immeuble" : "Nouvel immeuble",
              style: AppTypography.titleLg,
            ),
            const SizedBox(height: AppSpacing.lg),
            FutureBuilder<List<ImmeubleTypeModel>>(
              future: _typesFuture,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const [];
                return DropdownButtonFormField<ImmeubleTypeModel>(
                  initialValue: _selectedType,
                  decoration:
                      const InputDecoration(labelText: "Type d'immeuble"),
                  items: items
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.typeName),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedType = v),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AddressAutocompleteField(
              initialValue: _address,
              onChanged: (v) => _address = v,
              onSuggestionSelected: _onAddressSuggested,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(labelText: 'Ville'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _departmentCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Département'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _regionCtrl,
              decoration: const InputDecoration(labelText: 'Région'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _totalM2Ctrl,
              decoration:
                  const InputDecoration(labelText: 'Surface totale (m²)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Photos des espaces communs', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            PhotoPickerField(
              folder: 'immeubles',
              initialPhotos: _photos,
              initialMainPhoto: _mainPhoto,
              onChanged: (urls) => setState(() => _photos = urls),
              onMainPhotoChanged: (url) => setState(() => _mainPhoto = url),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            CheckboxListTile(
              value: !_isActive,
              onChanged: (v) => setState(() => _isActive = !(v ?? false)),
              title: const Text('Désactiver immeuble'),
              subtitle: const Text(
                'Toutes les chambres seront masquées du site public.',
              ),
              activeColor: AppColors.error,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
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
                  _isEditing ? 'Enregistrer les modifications' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
