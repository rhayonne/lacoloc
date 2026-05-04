import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
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
  final _formKey = GlobalKey<FormBuilderState>();

  late Future<List<ImmeubleTypeModel>> _typesFuture;
  ImmeubleTypeModel? _selectedType;
  String _address = '';
  List<String> _photos = [];
  String? _mainPhoto;
  bool _isSubmitting = false;

  bool get _isEditing => widget.immeuble != null;

  @override
  void initState() {
    super.initState();
    _typesFuture = ReferenceDatasource.immeubleTypes();
    final imm = widget.immeuble;
    if (imm != null) {
      _address = imm.address ?? '';
      _photos = List.from(imm.commonPhotos);
      _mainPhoto = imm.mainPhoto;
      _typesFuture.then((types) {
        if (!mounted) return;
        final match = types.where((t) => t.id == imm.typeId).firstOrNull;
        if (match != null) {
          setState(() => _selectedType = match);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _formKey.currentState?.fields['type']?.didChange(match);
          });
        }
      });
    }
  }

  void _onAddressSuggested(AddressSuggestion s) {
    setState(() => _address = s.label);
    _formKey.currentState?.fields['city']?.didChange(s.city);
    _formKey.currentState?.fields['department']?.didChange(s.department);
    _formKey.currentState?.fields['region']?.didChange(s.region);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;

    final type = values['type'] as ImmeubleTypeModel?;
    if (type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sélectionnez un type d'immeuble")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? trimOrNull(String? v) => v?.trim().isEmpty == true ? null : v?.trim();

      final model = ImmeublesModel(
        id: widget.immeuble?.id ?? 0,
        name: values['name'] as String,
        ownerId: AuthService.currentUser?.id,
        typeId: type.id,
        address: _address.trim().isEmpty ? null : _address.trim(),
        city: trimOrNull(values['city'] as String?),
        region: trimOrNull(values['region'] as String?),
        department: trimOrNull(values['department'] as String?),
        totalM2: double.tryParse(
            ((values['total_m2'] as String?) ?? '').replaceAll(',', '.')),
        description: trimOrNull(values['description'] as String?),
        commonPhotos: _photos,
        isActive: !((values['desactiver'] as bool?) ?? false),
        mainPhoto: _mainPhoto,
        bailCollectif: (values['bail_collectif'] as bool?) ?? false,
        bailIndividuel: (values['bail_individuel'] as bool?) ?? false,
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
      child: FormBuilder(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? "Modifier l'immeuble" : "Nouvel immeuble",
              style: AppTypography.titleLg,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Type d'immeuble (async) ────────────────────────────────
            FutureBuilder<List<ImmeubleTypeModel>>(
              future: _typesFuture,
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                return FormBuilderDropdown<ImmeubleTypeModel>(
                  key: ValueKey(_selectedType?.id),
                  name: 'type',
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

            FormBuilderTextField(
              name: 'name',
              initialValue: widget.immeuble?.name,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: FormBuilderValidators.required(),
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
                  child: FormBuilderTextField(
                    name: 'city',
                    initialValue: widget.immeuble?.city,
                    decoration: const InputDecoration(labelText: 'Ville'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'department',
                    initialValue: widget.immeuble?.department,
                    decoration: const InputDecoration(labelText: 'Département'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            FormBuilderTextField(
              name: 'region',
              initialValue: widget.immeuble?.region,
              decoration: const InputDecoration(labelText: 'Région'),
            ),
            const SizedBox(height: AppSpacing.md),

            FormBuilderTextField(
              name: 'total_m2',
              initialValue: widget.immeuble?.totalM2?.toStringAsFixed(2),
              decoration:
                  const InputDecoration(labelText: 'Surface totale (m²)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.md),

            FormBuilderTextField(
              name: 'description',
              initialValue: widget.immeuble?.description,
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
            const SizedBox(height: AppSpacing.sm),

            Text('Type de bail', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.xs),
            FormBuilderCheckbox(
              name: 'bail_collectif',
              initialValue: widget.immeuble?.bailCollectif ?? false,
              title: const Text('Bail collectif'),
              subtitle: const Text(
                  'Un seul contrat pour toutes les chambres de l\'immeuble.'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) {
                if (v == true) {
                  _formKey.currentState?.fields['bail_individuel']
                      ?.didChange(false);
                }
              },
            ),
            FormBuilderCheckbox(
              name: 'bail_individuel',
              initialValue: widget.immeuble?.bailIndividuel ?? false,
              title: const Text('Bail individuel'),
              subtitle: const Text(
                  'Contrat séparé pour chaque chambre.'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) {
                if (v == true) {
                  _formKey.currentState?.fields['bail_collectif']
                      ?.didChange(false);
                }
              },
            ),
            const Divider(),

            FormBuilderCheckbox(
              name: 'desactiver',
              initialValue: !(widget.immeuble?.isActive ?? true),
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
