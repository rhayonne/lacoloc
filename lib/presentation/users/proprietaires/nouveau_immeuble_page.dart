import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/address_search.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/commons_seeder.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/pieces.dart';
import 'package:lacoloc_front/data/datasources/reference.dart';
import 'package:lacoloc_front/data/pieces_communes_seed.dart';
import 'package:lacoloc_front/data/models/address_suggestion.dart';
import 'package:lacoloc_front/data/models/immeuble_type.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/presentation/widgets/address_autocomplete_field.dart';
import 'package:lacoloc_front/presentation/widgets/form_page_header.dart';
import 'package:lacoloc_front/presentation/widgets/photo_picker_field.dart';
import 'package:lacoloc_front/presentation/widgets/unsaved_changes_dialog.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/responsive_form_wrapper.dart';

class NouveauImmeublePage extends StatefulWidget {
  final ImmeublesModel? immeuble;
  final VoidCallback? onSaved;
  final VoidCallback? onBack;

  const NouveauImmeublePage({super.key, this.immeuble, this.onSaved, this.onBack});

  @override
  State<NouveauImmeublePage> createState() => _NouveauImmeublePageState();
}

class _NouveauImmeublePageState extends State<NouveauImmeublePage> {
  final _formKey = GlobalKey<FormBuilderState>();

  late Future<List<ImmeubleTypeModel>> _typesFuture;
  ImmeubleTypeModel? _selectedType;
  String _address = '';
  String? _codePostal;
  List<String> _photos = [];
  String? _mainPhoto;
  bool _isSubmitting = false;
  bool _isBailCollectif = false;

  // Parties communes
  ImmeublesModel? _createdImmeuble; // immeuble créé via le bouton (page neuve)
  bool _communesCreated = false;
  bool _creatingCommunes = false;

  /// Immeuble persisté (édition d'un existant OU créé via le bouton communes).
  ImmeublesModel? get _persistedImmeuble => widget.immeuble ?? _createdImmeuble;
  bool get _isEditing => _persistedImmeuble != null;

  @override
  void initState() {
    super.initState();
    _typesFuture = ReferenceDatasource.immeubleTypes();
    final imm = widget.immeuble;
    if (imm != null) {
      _address = imm.address ?? '';
      _codePostal = imm.codePostal;
      _photos = List.from(imm.commonPhotos);
      _mainPhoto = imm.mainPhoto;
      _isBailCollectif = imm.bailCollectif;
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
      _checkCommunesExistantes(imm.id);
    }
  }

  /// Désactive le bouton si les pièces communes standard existent déjà.
  Future<void> _checkCommunesExistantes(int immeubleId) async {
    try {
      final pieces = await PiecesDatasource.listByImmeuble(immeubleId);
      final hasCommunes =
          pieces.any((p) => kPiecesCommunesNoms.contains(p.nom));
      if (mounted && hasCommunes) setState(() => _communesCreated = true);
    } catch (_) {}
  }

  void _onAddressSuggested(AddressSuggestion s) {
    setState(() {
      _address = s.label;
      if (s.postcode.isNotEmpty) _codePostal = s.postcode;
    });
    _formKey.currentState?.fields['city']?.didChange(s.city);
    _formKey.currentState?.fields['department']?.didChange(s.department);
    _formKey.currentState?.fields['region']?.didChange(s.region);
  }

  /// Garante que département/région/code postal estejam preenchidos a partir
  /// do endereço. Quando o usuário digita o endereço sem clicar numa sugestão,
  /// esses campos ficam vazios; aqui fazemos um lookup na API BAN (code postal
  /// do imóvel) e preenchemos antes de gravar. Idempotente: só busca se faltar
  /// algum dos três e houver endereço.
  Future<void> _ensureLocationData() async {
    final state = _formKey.currentState;
    if (state == null) return;
    final dept = (state.fields['department']?.value as String?)?.trim() ?? '';
    final region = (state.fields['region']?.value as String?)?.trim() ?? '';
    final cp = _codePostal?.trim() ?? '';
    final address = _address.trim();
    if (address.isEmpty) return;
    if (dept.isNotEmpty && region.isNotEmpty && cp.isNotEmpty) return;

    final results = await AddressSearchService.search(address);
    if (results.isEmpty || !mounted) return;
    final s = results.first;
    if (dept.isEmpty && s.department.isNotEmpty) {
      state.fields['department']?.didChange(s.department);
    }
    if (region.isEmpty && s.region.isNotEmpty) {
      state.fields['region']?.didChange(s.region);
    }
    if ((state.fields['city']?.value as String?)?.trim().isEmpty != false &&
        s.city.isNotEmpty) {
      state.fields['city']?.didChange(s.city);
    }
    if (cp.isEmpty && s.postcode.isNotEmpty) _codePostal = s.postcode;
  }

  Future<void> _handleBack() async {
    final isDirty = _formKey.currentState?.isDirty ?? false;
    if (!isDirty) {
      widget.onBack?.call();
      return;
    }
    final choice = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (choice) {
      case UnsavedChoice.cancel:
        return;
      case UnsavedChoice.discard:
        widget.onBack?.call();
      case UnsavedChoice.save:
        await _submit();
    }
  }

  /// Construit le modèle à partir des valeurs du formulaire (déjà validées).
  ImmeublesModel _buildModel(Map<String, dynamic> values, ImmeubleTypeModel type) {
    String? trimOrNull(String? v) => v?.trim().isEmpty == true ? null : v?.trim();
    return ImmeublesModel(
      id: _persistedImmeuble?.id ?? 0,
      name: values['name'] as String,
      ownerId: AuthService.currentUser?.id,
      typeId: type.id,
      address: _address.trim().isEmpty ? null : _address.trim(),
      city: trimOrNull(values['city'] as String?),
      region: trimOrNull(values['region'] as String?),
      department: trimOrNull(values['department'] as String?),
      codePostal: trimOrNull(_codePostal),
      totalM2: double.tryParse(
          ((values['total_m2'] as String?) ?? '').replaceAll(',', '.')),
      description: trimOrNull(values['description'] as String?),
      commonPhotos: _photos,
      isActive: !((values['desactiver'] as bool?) ?? false),
      mainPhoto: _mainPhoto,
      bailCollectif: (values['bail_collectif'] as bool?) ?? false,
      bailIndividuel: (values['bail_individuel'] as bool?) ?? false,
      prixLoyer: _isBailCollectif
          ? double.tryParse(
              ((values['prix_loyer'] as String?) ?? '').replaceAll(',', '.'))
          : null,
      locationMeuble: values['location_meuble'] as bool?,
    );
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
      await _ensureLocationData();
      final model = _buildModel(_formKey.currentState!.value, type);
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Génère automatiquement les pièces communes (+ inventaire si meublé).
  /// Persiste l'immeuble au besoin pour obtenir son id.
  Future<void> _creerCommunes() async {
    final state = _formKey.currentState;
    final meuble = state?.fields['location_meuble']?.value as bool?;
    if (meuble == null) {
      _snack('Sélectionnez le type de location (meublée ou non) avant de '
          'créer les pièces.');
      return;
    }
    if (!(state?.saveAndValidate() ?? false)) return;
    final values = state!.value;
    final type = values['type'] as ImmeubleTypeModel?;
    if (type == null) {
      _snack("Sélectionnez un type d'immeuble");
      return;
    }

    setState(() => _creatingCommunes = true);
    try {
      await _ensureLocationData();
      // 1) Garantir l'existence de l'immeuble (id requis pour rattacher).
      var immeuble = _persistedImmeuble;
      final model = _buildModel(state.value, type);
      if (immeuble == null) {
        immeuble = await ImmeublesDatasource.create(model);
        if (!mounted) return;
        setState(() => _createdImmeuble = immeuble);
      } else {
        await ImmeublesDatasource.update(model);
      }
      // 2) Semer les pièces communes (+ inventaire si meublé).
      await CommonsSeeder.seed(immeuble.id, meuble: meuble);
      if (!mounted) return;
      setState(() => _communesCreated = true);
      _snack('Les parties communes ont été créées.');
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _creatingCommunes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormPageHeader(
          title: _isEditing ? "Modifier l'immeuble" : "Nouvel immeuble",
          trailing: FormHeaderActions(
            onSave: _submit,
            onClose: _handleBack,
            isSaving: _isSubmitting,
            saveLabel:
                _isEditing ? 'Enregistrer les modifications' : 'Enregistrer',
          ),
        ),
        Expanded(child: ResponsiveFormWrapper(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FormBuilder(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

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
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FormBuilderCheckbox(
                  name: 'bail_collectif',
                  initialValue: widget.immeuble?.bailCollectif ?? false,
                  title: const Text('Bail collectif'),
                  subtitle: const Text(
                      'Un seul contrat pour toutes les chambres de l\'immeuble.'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) {
                    setState(() => _isBailCollectif = v ?? false);
                    if (v == true) {
                      _formKey.currentState?.fields['bail_individuel']
                          ?.didChange(false);
                    }
                  },
                ),
              ),
            ),
            if (_isBailCollectif) ...[
              const SizedBox(height: AppSpacing.md),
              FormBuilderTextField(
                name: 'prix_loyer',
                initialValue: widget.immeuble?.prixLoyer?.toStringAsFixed(2),
                decoration: const InputDecoration(
                  labelText: 'Valeur du loyer (€/mois)',
                  prefixText: '€ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FormBuilderCheckbox(
                  name: 'bail_individuel',
                  initialValue: widget.immeuble?.bailIndividuel ?? false,
                  title: const Text('Bail individuel'),
                  subtitle: const Text('Contrat séparé pour chaque chambre.'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) {
                    if (v == true) {
                      setState(() => _isBailCollectif = false);
                      _formKey.currentState?.fields['bail_collectif']
                          ?.didChange(false);
                    }
                  },
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),

            // ── Parties communes ───────────────────────────────────────
            Text('Parties communes', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            FormBuilderDropdown<bool>(
              name: 'location_meuble',
              initialValue: widget.immeuble?.locationMeuble,
              decoration:
                  const InputDecoration(labelText: 'Location meublée ?'),
              items: const [
                DropdownMenuItem(value: true, child: Text('Oui')),
                DropdownMenuItem(value: false, child: Text('Non')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: (_communesCreated || _creatingCommunes)
                  ? null
                  : _creerCommunes,
              icon: _creatingCommunes
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.meeting_room_outlined),
              label: const Text('Ajouter les pièces communes et inventaire'),
            ),
            if (_communesCreated) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: AppColors.tertiary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Les parties communes ont été créées.',
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.tertiary),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            const Divider(),

            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FormBuilderCheckbox(
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
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
          ),
        )),
  ],
    );
  }
}
