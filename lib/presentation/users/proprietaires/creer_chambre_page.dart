import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/reference.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/reference.dart';
import 'package:lacoloc_front/presentation/widgets/photo_picker_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/utils/currency.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class CreerChambrePage extends StatefulWidget {
  final ChambreModel? chambre;
  final VoidCallback? onSaved;

  const CreerChambrePage({super.key, this.chambre, this.onSaved});

  @override
  State<CreerChambrePage> createState() => _CreerChambrePageState();
}

class _CreerChambrePageState extends State<CreerChambrePage> {
  final _formKey = GlobalKey<FormBuilderState>();

  late Future<_FormBundle> _bundleFuture;
  ImmeublesModel? _selectedImmeuble;
  List<String> _roomPhotos = [];
  String? _mainPhoto;
  String? _pricePreview;
  bool _isSubmitting = false;

  bool get _isEditing => widget.chambre != null;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
    final ch = widget.chambre;
    if (ch != null) {
      _roomPhotos = List.from(ch.roomPhotos);
      _mainPhoto = ch.mainPhoto;
      _bundleFuture.then((bundle) {
        if (!mounted) return;
        final match =
            bundle.immeubles.where((i) => i.id == ch.immeubleId).firstOrNull;
        if (match != null) {
          setState(() => _selectedImmeuble = match);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _formKey.currentState?.fields['immeuble']?.didChange(match);
          });
        }
      });
    }
  }

  Future<_FormBundle> _loadBundle() async {
    final ownerId = AuthService.currentUser?.id;
    final immeubles = ownerId == null
        ? <ImmeublesModel>[]
        : await ImmeublesDatasource.listByOwner(ownerId);
    final options = await ReferenceDatasource.roomOptions();
    return _FormBundle(immeubles: immeubles, options: options);
  }

  int? _parseCents(String? text) {
    final normalized = (text ?? '').trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return (value * 100).round();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;

    final immeuble = values['immeuble'] as ImmeublesModel?;
    if (immeuble == null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sélectionnez un immeuble")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final ch = widget.chambre;
      final selectedOptions = (values['options'] as List?)
              ?.map((e) => (e as ReferenceItem).id)
              .toList() ??
          [];

      final descVal = (values['description'] as String?)?.trim();
      final model = ChambreModel(
        id: ch?.id ?? 0,
        immeubleId: immeuble?.id ?? ch!.immeubleId,
        roomName: values['room_name'] as String,
        m2: double.tryParse(
            ((values['m2'] as String?) ?? '').replaceAll(',', '.')),
        prixLoyer: double.tryParse(
            ((values['prix_loyer'] as String?) ?? '').replaceAll(',', '.')),
        description: descVal?.isEmpty == true ? null : descVal,
        roomPhotos: _roomPhotos,
        selectedOptionIds: selectedOptions,
        isActive: !((values['desactiver'] as bool?) ?? false),
        estLoue: (values['est_loue'] as bool?) ?? false,
        mainPhoto: _mainPhoto,
      );

      _isEditing
          ? await ChambresDatasource.update(model)
          : await ChambresDatasource.create(model);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Chambre modifiée avec succès'
            : 'Chambre créée avec succès'),
      ));

      if (_isEditing) {
        widget.onSaved?.call();
      } else {
        _formKey.currentState?.reset();
        setState(() {
          _selectedImmeuble = null;
          _roomPhotos = [];
          _mainPhoto = null;
          _pricePreview = null;
        });
      }
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
    return FutureBuilder<_FormBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final bundle = snapshot.data!;

        if (!_isEditing && bundle.immeubles.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text(
                "Créez d'abord un immeuble avant d'ajouter une chambre.",
                style: AppTypography.bodyLg,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FormBuilder(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isEditing
                              ? 'Modifier la chambre'
                              : 'Nouvelle chambre',
                          style: AppTypography.titleLg,
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ── Immeuble ────────────────────────────────────
                        if (_isEditing)
                          FormBuilderTextField(
                            name: 'immeuble_display',
                            initialValue: widget.chambre?.immeubleName ??
                                _selectedImmeuble?.name ??
                                '',
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Immeuble',
                            ),
                          )
                        else
                          FormBuilderDropdown<ImmeublesModel>(
                            key: ValueKey(_selectedImmeuble?.id),
                            name: 'immeuble',
                            initialValue: _selectedImmeuble,
                            decoration:
                                const InputDecoration(labelText: 'Immeuble'),
                            items: bundle.immeubles
                                .map((i) => DropdownMenuItem(
                                      value: i,
                                      child: Text(i.name),
                                    ))
                                .toList(),
                            validator: FormBuilderValidators.required(),
                            onChanged: (v) =>
                                setState(() => _selectedImmeuble = v),
                          ),

                        if (_selectedImmeuble?.bailLabel != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          _BailBadge(label: _selectedImmeuble!.bailLabel!),
                        ],

                        const SizedBox(height: AppSpacing.md),

                        FormBuilderTextField(
                          name: 'room_name',
                          initialValue: widget.chambre?.roomName,
                          decoration: const InputDecoration(labelText: 'Nom'),
                          validator: FormBuilderValidators.required(),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        FormBuilderTextField(
                          name: 'm2',
                          initialValue:
                              widget.chambre?.m2?.toStringAsFixed(2),
                          decoration:
                              const InputDecoration(labelText: 'Surface (m²)'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        FormBuilderTextField(
                          name: 'prix_loyer',
                          initialValue:
                              widget.chambre?.prixLoyer?.toStringAsFixed(2),
                          decoration: InputDecoration(
                            labelText: 'Prix du loyer (€/mois)',
                            prefixIcon: const Icon(Icons.euro),
                            helperText: _pricePreview,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*[,.]?\d{0,2}')),
                          ],
                          onChanged: (v) {
                            final cents = _parseCents(v);
                            setState(() => _pricePreview =
                                cents != null && cents > 0
                                    ? formatFrenchCurrency(cents)
                                    : null);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        FormBuilderTextField(
                          name: 'description',
                          initialValue: widget.chambre?.description,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                        ),

                        const SizedBox(height: AppSpacing.lg),
                        Text('Photos de la chambre',
                            style: AppTypography.labelMd),
                        const SizedBox(height: AppSpacing.sm),
                        PhotoPickerField(
                          folder: 'chambres',
                          initialPhotos: _roomPhotos,
                          initialMainPhoto: _mainPhoto,
                          onChanged: (urls) =>
                              setState(() => _roomPhotos = urls),
                          onMainPhotoChanged: (url) =>
                              setState(() => _mainPhoto = url),
                        ),

                        const SizedBox(height: AppSpacing.lg),
                        Text("Équipements", style: AppTypography.titleLg),
                        const SizedBox(height: AppSpacing.sm),
                        FormBuilderFilterChips<ReferenceItem>(
                          name: 'options',
                          initialValue: bundle.options
                              .where((o) =>
                                  widget.chambre?.selectedOptionIds
                                      .contains(o.id) ??
                                  false)
                              .toList(),
                          options: bundle.options
                              .map((o) => FormBuilderChipOption(
                                    value: o,
                                    child: Text(o.name),
                                  ))
                              .toList(),
                          selectedColor: AppColors.primaryFixed,
                          checkmarkColor: AppColors.primary,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          decoration: const InputDecoration(border: InputBorder.none),
                        ),

                        const SizedBox(height: AppSpacing.lg),
                        const Divider(),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Autres options', style: AppTypography.titleLg),
                        const SizedBox(height: AppSpacing.sm),

                        FormBuilderCheckbox(
                          name: 'est_loue',
                          initialValue: widget.chambre?.estLoue ?? false,
                          title: const Text('Chambre louée'),
                          subtitle: const Text(
                              'Marque cette chambre como atualmente ocupada.'),
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        FormBuilderCheckbox(
                          name: 'desactiver',
                          initialValue: !(widget.chambre?.isActive ?? true),
                          title: const Text('Désactiver chambre'),
                          subtitle: const Text(
                              'Cette chambre ne sera plus visible sur le site.'),
                          activeColor: AppColors.error,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),

                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006D77),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(_isEditing
                                ? 'Enregistrer les modifications'
                                : 'Créer la chambre'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FormBundle {
  final List<ImmeublesModel> immeubles;
  final List<ReferenceItem> options;
  _FormBundle({required this.immeubles, required this.options});
}

class _BailBadge extends StatelessWidget {
  final String label;
  const _BailBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.description_outlined,
            size: 14, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}
