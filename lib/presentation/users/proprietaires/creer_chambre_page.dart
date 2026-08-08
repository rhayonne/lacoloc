import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/datasources/chambres.dart';
import 'package:habitafrance/data/datasources/etat_de_lieux.dart';
import 'package:habitafrance/data/datasources/immeubles.dart';
import 'package:habitafrance/data/models/chambre.dart';
import 'package:habitafrance/data/models/etat_de_lieux.dart';
import 'package:habitafrance/data/models/immeubles.dart';
import 'package:habitafrance/presentation/widgets/number_stepper_field.dart';
import 'package:habitafrance/presentation/widgets/form_page_header.dart';
import 'package:habitafrance/presentation/widgets/photo_picker_field.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/utils/currency.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

class CreerChambrePage extends StatefulWidget {
  final ChambreModel? chambre;
  final VoidCallback? onSaved;
  final VoidCallback? onBack;

  /// Pré-sélectionne (et verrouille) l'immeuble — ex. depuis le détail d'un
  /// immeuble via « Ajouter chambre ».
  final int? prefilledImmeubleId;

  const CreerChambrePage({
    super.key,
    this.chambre,
    this.onSaved,
    this.onBack,
    this.prefilledImmeubleId,
  });

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

  // Pour le montant démonstratif du dépôt de garantie (loyer × nb mois).
  double? _loyer;
  double? _cautionMois;

  // EDL d'entrée privatif lié à cette chambre (pour le statut « louée »).
  EtatDesLieuxModel? _linkedEdl;

  bool get _isEditing => widget.chambre != null;

  /// Le formulaire (hors sélecteur d'immeuble) reste bloqué tant qu'aucun
  /// immeuble n'est choisi (uniquement à la création).
  bool get _locked => !_isEditing && _selectedImmeuble == null;

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
    } else if (widget.prefilledImmeubleId != null) {
      // Création depuis le détail d'un immeuble : pré-sélectionne l'immeuble.
      _bundleFuture.then((bundle) {
        if (!mounted) return;
        final match = bundle.immeubles
            .where((i) => i.id == widget.prefilledImmeubleId)
            .firstOrNull;
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
    return _FormBundle(immeubles: immeubles);
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
          FilledButton(style: AppTheme.saveButtonStyle, onPressed: () => Navigator.pop(context, 'save'), child: const Text('Sauvegarder et quitter')),
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

  // Supprime la chambre du système (avec son inventaire). Bloqué si elle est
  // liée à un état des lieux (contrat) — message d'erreur renvoyé par la BD.
  Future<void> _deleteChambre() async {
    final ch = widget.chambre;
    if (ch == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la chambre'),
        content: Text(
          'La chambre « ${ch.roomName} » sera supprimée définitivement du '
          'système (avec son inventaire). Cette action est irréversible.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.deleteButtonStyle,
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isSubmitting = true);
    try {
      await ChambresDatasource.delete(ch.id);
      if (mounted) widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suppression impossible : $e')),
        );
      }
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
      final descVal = (values['description'] as String?)?.trim();
      final model = ChambreModel(
        id: ch?.id ?? 0,
        immeubleId: immeuble?.id ?? ch!.immeubleId,
        roomName: values['room_name'] as String,
        m2: double.tryParse(((values['m2'] as String?) ?? '').replaceAll(',', '.')),
        prixLoyer: double.tryParse(((values['prix_loyer'] as String?) ?? '').replaceAll(',', '.')),
        description: descVal?.isEmpty == true ? null : descVal,
        roomPhotos: _roomPhotos,
        // Les équipements vivent désormais dans l'inventaire (lié à la chambre).
        // On préserve l'ancienne liste pour ne pas perdre la donnée historique.
        selectedOptionIds: ch?.selectedOptionIds ?? const [],
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

      if (_isEditing) {
        await ChambresDatasource.update(model);
      } else {
        await ChambresDatasource.create(model);
      }

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
            Icon(Icons.link, color: AppColors.primary),
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
          Icon(Icons.info_outline,
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

  /// Bandeau d'invite quand aucun immeuble n'est encore sélectionné.
  Widget _selectImmeubleBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sélectionnez d\'abord un immeuble pour activer le formulaire. '
              'Les informations contractuelles sont héritées de l\'immeuble.',
              style: AppTypography.bodyMd
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
            extraActions: _isEditing
                ? [
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _deleteChambre,
                      style: AppTheme.deleteButtonStyle,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Supprimer'),
                    ),
                  ]
                : const [],
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

                                // ══ 1 — Immeuble (toujours actif) ════════════
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
                                    },
                                  ),

                                if (_selectedImmeuble?.bailLabel != null) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  _BailBadge(label: _selectedImmeuble!.bailLabel!),
                                ],

                                if (_locked) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  _selectImmeubleBanner(),
                                ],
                                const SizedBox(height: AppSpacing.md),

                                // ══ Reste du formulaire — bloqué tant qu'aucun
                                //    immeuble n'est sélectionné. ══════════════
                                AbsorbPointer(
                                  absorbing: _locked,
                                  child: Opacity(
                                    opacity: _locked ? 0.45 : 1,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        wide
                                            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Expanded(flex: 2, child: FormBuilderTextField(
                                                  name: 'room_name',
                                                  initialValue: widget.chambre?.roomName,
                                                  enabled: !_locked,
                                                  decoration: const InputDecoration(labelText: 'Nom de la chambre'),
                                                  validator: FormBuilderValidators.required(),
                                                )),
                                                const SizedBox(width: AppSpacing.md),
                                                Expanded(child: FormBuilderTextField(
                                                  name: 'm2',
                                                  initialValue: widget.chambre?.m2?.toStringAsFixed(2),
                                                  enabled: !_locked,
                                                  decoration: const InputDecoration(labelText: 'Surface (m²)'),
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                )),
                                              ])
                                            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                                FormBuilderTextField(
                                                  name: 'room_name',
                                                  initialValue: widget.chambre?.roomName,
                                                  enabled: !_locked,
                                                  decoration: const InputDecoration(labelText: 'Nom de la chambre'),
                                                  validator: FormBuilderValidators.required(),
                                                ),
                                                const SizedBox(height: AppSpacing.md),
                                                FormBuilderTextField(
                                                  name: 'm2',
                                                  initialValue: widget.chambre?.m2?.toStringAsFixed(2),
                                                  enabled: !_locked,
                                                  decoration: const InputDecoration(labelText: 'Surface (m²)'),
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                ),
                                              ]),
                                        const SizedBox(height: AppSpacing.md),

                                        FormBuilderTextField(
                                          name: 'prix_loyer',
                                          initialValue: widget.chambre?.prixLoyer?.toStringAsFixed(2),
                                          enabled: !_locked,
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
                                          enabled: !_locked,
                                          decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                                          maxLines: 4,
                                        ),
                                        const SizedBox(height: AppSpacing.lg),
                                        const Divider(),
                                        const SizedBox(height: AppSpacing.md),

                                        // ══ 2 — Photos ═══════════════════════
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

                                        // ══ 3 — Informations contractuelles ══
                                        //    Héritées de l'immeuble (modifiables).
                                        _sectionLabel("Informations contractuelles"),
                                        _buildContractuelles(wide),
                                        const SizedBox(height: AppSpacing.lg),
                                        const Divider(),
                                        const SizedBox(height: AppSpacing.md),

                                        // ══ 4 — Statut ═══════════════════════
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
                                    ),
                                  ),
                                ),
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

  /// Section « Informations contractuelles » — même présentation que le
  /// cadastre de l'immeuble. Les valeurs (dépôt, durée) sont **pré-remplies
  /// depuis l'immeuble sélectionné** et restent modifiables par chambre.
  Widget _buildContractuelles(bool wide) {
    final imm = _selectedImmeuble;
    final meuble = imm?.locationMeuble == true;
    // Valeur initiale : celle de la chambre (édition) sinon héritée de l'immeuble.
    final depotInit = widget.chambre?.depotGarantieMois?.toString() ??
        imm?.depotGarantieMois?.toString();
    final dureeInit = widget.chambre?.dureeBailMois?.toString() ??
        imm?.dureeBailMois?.toString() ??
        (meuble ? '12' : '36');
    // Clé liée à l'immeuble → le champ se ré-initialise avec la valeur héritée
    // quand on change d'immeuble (création).
    final keySuffix = '${imm?.id}';

    final depot = NumberStepperField(
      key: ValueKey('depot_$keySuffix'),
      name: 'depot_garantie_mois',
      initialValue: depotInit,
      labelText: 'Dépôt de garantie (mois)',
      helperText: meuble
          ? 'Max légal : 2 mois (meublé) · hérité de l\'immeuble'
          : 'Max légal : 1 mois (non meublé) · hérité de l\'immeuble',
      prefixIcon: Icons.lock_outline,
      min: 0,
      max: 3,
      onValue: (v) => setState(() => _cautionMois = v),
    );
    final duree = NumberStepperField(
      key: ValueKey('duree_$keySuffix'),
      name: 'duree_bail_mois',
      initialValue: dureeInit,
      labelText: 'Durée du bail (mois)',
      helperText: 'Min. légal : 12 (meublé) · 36 (non meublé) · hérité de l\'immeuble',
      prefixIcon: Icons.calendar_month_outlined,
      min: 1,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: depot),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: duree),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  depot,
                  const SizedBox(height: AppSpacing.md),
                  duree,
                ],
              ),
        _cautionPreview(),
      ],
    );
  }
}

class _FormBundle {
  final List<ImmeublesModel> immeubles;
  _FormBundle({required this.immeubles});
}

class _BailBadge extends StatelessWidget {
  final String label;
  const _BailBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.description_outlined, size: 14, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
      ],
    );
  }
}
