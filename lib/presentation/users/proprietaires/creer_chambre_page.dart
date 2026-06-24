import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambre_charges.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/charges_reference.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/datasources/immeuble_charges.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/reference.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/chambre_charge.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/charge_reference.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/reference.dart';
import 'package:lacoloc_front/presentation/widgets/charges_selector.dart';
import 'package:lacoloc_front/presentation/widgets/number_stepper_field.dart';
import 'package:lacoloc_front/presentation/widgets/form_page_header.dart';
import 'package:lacoloc_front/presentation/widgets/photo_picker_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/utils/currency.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class CreerChambrePage extends StatefulWidget {
  final ChambreModel? chambre;
  final VoidCallback? onSaved;
  final VoidCallback? onBack;

  const CreerChambrePage({super.key, this.chambre, this.onSaved, this.onBack});

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
  List<ChargeSelection> _charges = [];

  // Pour le montant démonstratif du dépôt de garantie (loyer × nb mois).
  double? _loyer;
  double? _cautionMois;

  // EDL d'entrée privatif lié à cette chambre (pour le statut « louée »).
  EtatDesLieuxModel? _linkedEdl;

  bool get _isEditing => widget.chambre != null;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
    final ch = widget.chambre;
    _loyer = ch?.prixLoyer;
    _cautionMois = ch?.depotGarantieMois;
    if (ch != null) {
      // EDL d'entrée privatif lié → permet d'afficher le code du bail/EDL.
      EtatDesLieuxDatasource.findPrivatif(chambreId: ch.id, typeEdl: 'entree')
          .then((edl) {
        if (mounted) setState(() => _linkedEdl = edl);
      }).catchError((_) {});
      _roomPhotos = List.from(ch.roomPhotos);
      _mainPhoto = ch.mainPhoto;
      _bundleFuture.then((bundle) {
        if (!mounted) return;
        final match = bundle.immeubles.where((i) => i.id == ch.immeubleId).firstOrNull;
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
    final chargesRef = await ChargesReferenceDatasource.listAll(activeOnly: true);

    // Charger les charges existantes de la chambre (édition)
    List<ChargeSelection> initCharges = [];
    final ch = widget.chambre;
    if (ch != null) {
      final existing = await ChambreChargesDatasource.listByChambre(ch.id);
      initCharges = existing.map((cc) {
        final ref = chargesRef.where((r) => r.id == cc.chargeRefId).firstOrNull;
        if (ref == null) return null;
        return ChargeSelection(ref: ref, type: cc.type, montant: cc.montant);
      }).whereType<ChargeSelection>().toList();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _charges = initCharges);
    });

    return _FormBundle(immeubles: immeubles, options: options, chargesRef: chargesRef);
  }

  /// Quand un immeuble est sélectionné, pré-remplir les charges depuis l'immeuble.
  Future<void> _loadImmeubleCharges(ImmeublesModel immeuble, List<ChargeReferenceModel> chargesRef) async {
    if (_isEditing) return; // en édition on garde les charges de la chambre
    try {
      final ic = await ImmeubleChargesDatasource.listByImmeuble(immeuble.id);
      if (!mounted) return;
      final sel = ic.map((c) {
        final ref = chargesRef.where((r) => r.id == c.chargeRefId).firstOrNull;
        if (ref == null) return null;
        return ChargeSelection(ref: ref, type: c.type, montant: c.montant);
      }).whereType<ChargeSelection>().toList();
      setState(() => _charges = sel);
    } catch (_) {}
  }

  int? _parseCents(String? text) {
    final normalized = (text ?? '').trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return (value * 100).round();
  }

  Future<void> _handleBack() async {
    final isDirty = _formKey.currentState?.isDirty ?? false;
    if (!isDirty) {
      widget.onBack?.call();
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifications non sauvegardées'),
        content: const Text('Vous avez des modifications non sauvegardées. Que souhaitez-vous faire ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Continuer')),
          OutlinedButton(onPressed: () => Navigator.pop(context, 'discard'), child: const Text('Quitter sans sauvegarder')),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Sauvegarder et quitter')),
        ],
      ),
    );
    if (!mounted) return;
    if (result == 'discard') {
      widget.onBack?.call();
    } else if (result == 'save') {
      await _submit(fromBack: true);
    }
  }

  Future<void> _saveCharges(int chambreId) async {
    await ChambreChargesDatasource.deleteByChambre(chambreId);
    for (final sel in _charges) {
      await ChambreChargesDatasource.upsert(ChambreChargeModel(
        id: 0,
        chambreId: chambreId,
        chargeRefId: sel.ref.id,
        type: sel.type,
        montant: sel.montant,
      ));
    }
  }

  Future<void> _submit({bool fromBack = false}) async {
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
              .toList() ?? [];
      final descVal = (values['description'] as String?)?.trim();
      final model = ChambreModel(
        id: ch?.id ?? 0,
        immeubleId: immeuble?.id ?? ch!.immeubleId,
        roomName: values['room_name'] as String,
        m2: double.tryParse(((values['m2'] as String?) ?? '').replaceAll(',', '.')),
        prixLoyer: double.tryParse(((values['prix_loyer'] as String?) ?? '').replaceAll(',', '.')),
        description: descVal?.isEmpty == true ? null : descVal,
        roomPhotos: _roomPhotos,
        selectedOptionIds: selectedOptions,
        isActive: !((values['desactiver'] as bool?) ?? false),
        // Si la chambre est liée à un bail finalisé, elle reste occupée
        // (la case n'est pas affichée dans ce cas).
        estLoue: _linkedEdl?.situation == SituationEdl.finalise
            ? true
            : ((values['est_loue'] as bool?) ?? false),
        mainPhoto: _mainPhoto,
        depotGarantieMois: double.tryParse(((values['depot_garantie_mois'] as String?) ?? '').replaceAll(',', '.')),
        dureeBailMois: int.tryParse((values['duree_bail_mois'] as String?) ?? ''),
      );

      int savedId;
      if (_isEditing) {
        await ChambresDatasource.update(model);
        savedId = ch!.id;
      } else {
        final created = await ChambresDatasource.create(model);
        savedId = created.id;
      }
      await _saveCharges(savedId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing ? 'Chambre modifiée avec succès' : 'Chambre créée avec succès'),
      ));

      if (_isEditing || fromBack) {
        widget.onSaved?.call();
      } else {
        _formKey.currentState?.reset();
        setState(() {
          _selectedImmeuble = null;
          _roomPhotos = [];
          _mainPhoto = null;
          _pricePreview = null;
          _charges = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: AppTypography.labelMd),
      );

  /// Statut « Chambre louée » :
  /// - liée à un bail/EDL **finalisé** → case cochée, **verrouillée**, avec le
  ///   **code de l'EDL/bail** pour le localiser.
  /// - sinon → case modifiable ; si cochée sans bail, la chambre est marquée
  ///   occupée **par le propriétaire** (note explicite).
  Widget _buildStatutLouee() {
    final edl = _linkedEdl;
    final linkedFinalise = edl != null && edl.situation == SituationEdl.finalise;

    if (linkedFinalise) {
      final code = edl.code ?? 'EDL #${edl.id}';
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryFixed.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.link, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chambre louée — liée à un bail',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  SelectableText(
                    'Code : $code',
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return FormBuilderCheckbox(
      name: 'est_loue',
      initialValue: widget.chambre?.estLoue ?? false,
      title: const Text('Chambre louée'),
      subtitle: const Text(
          'Aucun bail lié. Si vous la cochez, la chambre sera marquée occupée '
          'par le propriétaire (sans bail).'),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  /// Montant démonstratif du dépôt de garantie = loyer HC × nb de mois.
  /// Affiché sous le champ ; sera facturé au locataire à la génération du bail.
  Widget _cautionPreview() {
    final loyer = _loyer;
    final mois = _cautionMois;
    if (loyer == null || mois == null || loyer <= 0 || mois <= 0) {
      return const SizedBox.shrink();
    }
    final montant = loyer * mois;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Dépôt demandé au locataire : ${montant.toStringAsFixed(2)} € '
              '(${mois.toStringAsFixed(mois % 1 == 0 ? 0 : 1)} × ${loyer.toStringAsFixed(2)} €). '
              'Une échéance sera créée à la génération du bail.',
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormPageHeader(
          title: _isEditing ? 'Modifier la chambre' : 'Nouvelle chambre',
          trailing: FormHeaderActions(
            onSave: _submit,
            onClose: _handleBack,
            isSaving: _isSubmitting,
            saveLabel: _isEditing ? 'Enregistrer les modifications' : 'Créer la chambre',
          ),
        ),
        Expanded(
          child: FutureBuilder<_FormBundle>(
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
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: FormBuilder(
                        key: _formKey,
                        child: LayoutBuilder(
                          builder: (ctx, constraints) {
                            final wide = constraints.maxWidth >= 560;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [

                                // ══ 1 — Immeuble + Identification ════════════
                                _sectionLabel("Identification"),
                                if (_isEditing)
                                  FormBuilderTextField(
                                    name: 'immeuble_display',
                                    initialValue: widget.chambre?.immeubleName ?? _selectedImmeuble?.name ?? '',
                                    enabled: false,
                                    decoration: const InputDecoration(labelText: 'Immeuble'),
                                  )
                                else
                                  FormBuilderDropdown<ImmeublesModel>(
                                    key: ValueKey(_selectedImmeuble?.id),
                                    name: 'immeuble',
                                    initialValue: _selectedImmeuble,
                                    decoration: const InputDecoration(labelText: 'Immeuble'),
                                    items: bundle.immeubles.map((i) => DropdownMenuItem(value: i, child: Text(i.name))).toList(),
                                    validator: FormBuilderValidators.required(),
                                    onChanged: (v) {
                                      setState(() => _selectedImmeuble = v);
                                      if (v != null) _loadImmeubleCharges(v, bundle.chargesRef);
                                    },
                                  ),

                                if (_selectedImmeuble?.bailLabel != null) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  _BailBadge(label: _selectedImmeuble!.bailLabel!),
                                ],
                                const SizedBox(height: AppSpacing.md),

                                wide
                                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Expanded(flex: 2, child: FormBuilderTextField(
                                          name: 'room_name',
                                          initialValue: widget.chambre?.roomName,
                                          decoration: const InputDecoration(labelText: 'Nom de la chambre'),
                                          validator: FormBuilderValidators.required(),
                                        )),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(child: FormBuilderTextField(
                                          name: 'm2',
                                          initialValue: widget.chambre?.m2?.toStringAsFixed(2),
                                          decoration: const InputDecoration(labelText: 'Surface (m²)'),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        )),
                                      ])
                                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                        FormBuilderTextField(
                                          name: 'room_name',
                                          initialValue: widget.chambre?.roomName,
                                          decoration: const InputDecoration(labelText: 'Nom de la chambre'),
                                          validator: FormBuilderValidators.required(),
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        FormBuilderTextField(
                                          name: 'm2',
                                          initialValue: widget.chambre?.m2?.toStringAsFixed(2),
                                          decoration: const InputDecoration(labelText: 'Surface (m²)'),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        ),
                                      ]),
                                const SizedBox(height: AppSpacing.md),

                                FormBuilderTextField(
                                  name: 'prix_loyer',
                                  initialValue: widget.chambre?.prixLoyer?.toStringAsFixed(2),
                                  decoration: InputDecoration(
                                    labelText: 'Prix du loyer (€/mois)',
                                    prefixIcon: const Icon(Icons.euro),
                                    helperText: _pricePreview,
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}'))],
                                  onChanged: (v) {
                                    final cents = _parseCents(v);
                                    setState(() {
                                      _pricePreview = cents != null && cents > 0 ? formatFrenchCurrency(cents) : null;
                                      _loyer = double.tryParse((v ?? '').replaceAll(',', '.'));
                                    });
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),

                                FormBuilderTextField(
                                  name: 'description',
                                  initialValue: widget.chambre?.description,
                                  decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                                  maxLines: 4,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 2 — Photos ═══════════════════════════════
                                _sectionLabel("Photos de la chambre"),
                                PhotoPickerField(
                                  folder: 'chambres',
                                  initialPhotos: _roomPhotos,
                                  initialMainPhoto: _mainPhoto,
                                  onChanged: (urls) => setState(() => _roomPhotos = urls),
                                  onMainPhotoChanged: (url) => setState(() => _mainPhoto = url),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 3 — Équipements ══════════════════════════
                                _sectionLabel("Équipements"),
                                FormBuilderFilterChips<ReferenceItem>(
                                  name: 'options',
                                  initialValue: bundle.options
                                      .where((o) => widget.chambre?.selectedOptionIds.contains(o.id) ?? false)
                                      .toList(),
                                  options: bundle.options.map((o) => FormBuilderChipOption(value: o, child: Text(o.name))).toList(),
                                  selectedColor: AppColors.primaryFixed,
                                  checkmarkColor: AppColors.primary,
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  decoration: const InputDecoration(border: InputBorder.none),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 4 — Informations contractuelles ══════════
                                _sectionLabel("Informations contractuelles"),
                                Builder(builder: (_) {
                                  final meuble =
                                      _selectedImmeuble?.locationMeuble == true;
                                  final depot = NumberStepperField(
                                    name: 'depot_garantie_mois',
                                    initialValue:
                                        widget.chambre?.depotGarantieMois?.toString(),
                                    labelText: 'Dépôt de garantie (mois)',
                                    helperText: meuble
                                        ? 'Max légal : 2 mois (meublé)'
                                        : 'Max légal : 1 mois (non meublé)',
                                    prefixIcon: Icons.lock_outline,
                                    min: 0,
                                    max: 3,
                                    onValue: (v) =>
                                        setState(() => _cautionMois = v),
                                  );
                                  final duree = NumberStepperField(
                                    name: 'duree_bail_mois',
                                    initialValue:
                                        widget.chambre?.dureeBailMois?.toString() ??
                                            (meuble ? '12' : '36'),
                                    labelText: 'Durée du bail (mois)',
                                    helperText:
                                        'Min. légal : 12 (meublé) · 36 (non meublé)',
                                    prefixIcon: Icons.calendar_month_outlined,
                                    min: 1,
                                  );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      wide
                                          ? Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(child: depot),
                                                const SizedBox(
                                                    width: AppSpacing.md),
                                                Expanded(child: duree),
                                              ],
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                depot,
                                                const SizedBox(
                                                    height: AppSpacing.md),
                                                duree,
                                              ],
                                            ),
                                      _cautionPreview(),
                                    ],
                                  );
                                }),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 5 — Charges ══════════════════════════════
                                _sectionLabel("Charges locatives"),
                                if (bundle.chargesRef.isEmpty)
                                  Text(
                                    'Aucune charge disponible. Contactez le super admin.',
                                    style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                                  )
                                else ...[
                                  Text(
                                    _selectedImmeuble != null
                                        ? 'Charges pré-remplies depuis l\'immeuble. Vous pouvez les ajuster.'
                                        : 'Sélectionnez les charges incluses dans le loyer de cette chambre.',
                                    style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  ChargesSelector(
                                    available: bundle.chargesRef,
                                    initial: _charges,
                                    onChanged: (sel) => setState(() => _charges = sel),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 6 — Statut ═══════════════════════════════
                                _sectionLabel("Statut"),
                                _buildStatutLouee(),
                                FormBuilderCheckbox(
                                  name: 'desactiver',
                                  initialValue: !(widget.chambre?.isActive ?? true),
                                  title: const Text('Désactiver chambre'),
                                  subtitle: const Text('Cette chambre ne sera plus visible sur le site.'),
                                  activeColor: AppColors.error,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                                const SizedBox(height: AppSpacing.xl),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FormBundle {
  final List<ImmeublesModel> immeubles;
  final List<ReferenceItem> options;
  final List<ChargeReferenceModel> chargesRef;
  _FormBundle({required this.immeubles, required this.options, required this.chargesRef});
}

class _BailBadge extends StatelessWidget {
  final String label;
  const _BailBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.description_outlined, size: 14, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
      ],
    );
  }
}
