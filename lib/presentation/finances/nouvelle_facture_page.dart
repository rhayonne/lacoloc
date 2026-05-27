import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_extra_fields/form_builder_extra_fields.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/factures.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/facture.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/responsive_form_wrapper.dart';

class NouvelleFacturePage extends StatefulWidget {
  final FactureModel? facture;
  final bool readOnly;
  final VoidCallback? onSaved;
  final int? prefilledImmeubleId;
  final String? prefilledImmeubleName;

  const NouvelleFacturePage({
    super.key,
    this.facture,
    this.readOnly = false,
    this.onSaved,
    this.prefilledImmeubleId,
    this.prefilledImmeubleName,
  });

  @override
  State<NouvelleFacturePage> createState() => _NouvelleFacturePageState();
}

class _NouvelleFacturePageState extends State<NouvelleFacturePage> {
  final _formKey = GlobalKey<FormBuilderState>();

  bool _dataLoaded = false;
  bool _isSubmitting = false;
  bool _loadingChambres = false;

  List<ImmeublesModel> _immeubles = [];
  List<ChambreModel> _chambresForImmeuble = [];
  ImmeublesModel? _selectedImmeuble;
  ChambreModel? _selectedChambre;

  bool get _isEditing => widget.facture != null;
  bool get _readOnly => widget.readOnly;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final ownerId = AuthService.currentUser?.id;
    final immeubles = ownerId != null
        ? await ImmeublesDatasource.listByOwner(ownerId)
        : <ImmeublesModel>[];

    if (!mounted) return;

    final initImmeubleId =
        widget.facture?.immeubleId ?? widget.prefilledImmeubleId;
    ImmeublesModel? initImmeuble;
    List<ChambreModel> initChambres = [];
    ChambreModel? initChambre;

    if (initImmeubleId != null) {
      try {
        initImmeuble =
            immeubles.firstWhere((i) => i.id == initImmeubleId);
      } catch (_) {}
      initChambres =
          await ChambresDatasource.listByImmeuble(initImmeubleId);
      if (!mounted) return;

      final initChambreId = widget.facture?.chambreId;
      if (initChambreId != null) {
        try {
          initChambre =
              initChambres.firstWhere((c) => c.id == initChambreId);
        } catch (_) {}
      }
    }

    setState(() {
      _immeubles = immeubles;
      _selectedImmeuble = initImmeuble;
      _chambresForImmeuble = initChambres;
      _selectedChambre = initChambre;
      _dataLoaded = true;
    });
  }

  Future<void> _loadChambresPourImmeuble(int immeubleId) async {
    setState(() {
      _loadingChambres = true;
      _chambresForImmeuble = [];
      _selectedChambre = null;
    });
    _formKey.currentState?.fields['chambre']?.didChange(null);
    final chambres = await ChambresDatasource.listByImmeuble(immeubleId);
    if (!mounted) return;
    setState(() {
      _chambresForImmeuble = chambres;
      _loadingChambres = false;
    });
  }

  void _recalcTtc(String? htStr, String? tvaStr) {
    final ht = double.tryParse((htStr ?? '').replaceAll(',', '.'));
    final tva = double.tryParse((tvaStr ?? '').replaceAll(',', '.'));
    if (ht != null && tva != null) {
      _formKey.currentState?.fields['montant_ttc']
          ?.didChange((ht * (1 + tva / 100)).toStringAsFixed(2));
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;

    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return;

    setState(() => _isSubmitting = true);
    try {
      String? trimOrNull(String? v) =>
          v?.trim().isEmpty == true ? null : v?.trim();

      // Extract immeuble id: from searchable dropdown (model) or prefilled id
      final immeubleModel = values['immeuble'] as ImmeublesModel?;
      final immeubleId =
          immeubleModel?.id ?? widget.prefilledImmeubleId;

      final chambreModel = values['chambre'] as ChambreModel?;

      final model = FactureModel(
        id: widget.facture?.id ?? 0,
        ownerId: ownerId,
        immeubleId: immeubleId,
        chambreId: chambreModel?.id,
        codeFacture: trimOrNull(values['code_facture'] as String?),
        fournisseur: values['fournisseur'] as String,
        typeFacture: values['type_facture'] as String,
        periodeDebut: values['periode_debut'] as DateTime?,
        periodeFin: values['periode_fin'] as DateTime?,
        dateEmission: values['date_emission'] as DateTime?,
        dateEcheance: values['date_echeance'] as DateTime?,
        montantHt: double.tryParse(
            ((values['montant_ht'] as String?) ?? '').replaceAll(',', '.')),
        tauxTva: double.tryParse(
                ((values['taux_tva'] as String?) ?? '').replaceAll(',', '.')) ??
            20,
        montantTtc: double.tryParse(
            ((values['montant_ttc'] as String?) ?? '').replaceAll(',', '.')),
        statut: values['statut'] as String,
        notes: trimOrNull(values['notes'] as String?),
      );

      _isEditing
          ? await FacturesDatasource.update(model)
          : await FacturesDatasource.create(model);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Facture modifiée avec succès'
            : 'Facture créée avec succès'),
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

  static const _searchBoxDecoration = InputDecoration(
    hintText: 'Rechercher…',
    isDense: true,
    contentPadding: EdgeInsets.symmetric(
      vertical: AppSpacing.sm,
      horizontal: AppSpacing.sm,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final f = widget.facture;
    final title = _readOnly
        ? 'Détail de la facture'
        : _isEditing
            ? 'Modifier la facture'
            : 'Nouvelle facture';

    if (!_dataLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ResponsiveFormWrapper(
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: FormBuilder(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.titleLg),
            const SizedBox(height: AppSpacing.lg),

            // ── Immeuble ──────────────────────────────────────────────
            if (widget.prefilledImmeubleId != null)
              FormBuilderTextField(
                name: 'immeuble_id_display',
                initialValue: widget.prefilledImmeubleName ?? '',
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Immeuble',
                  suffixIcon: Icon(Icons.lock_outline, size: 16),
                ),
              )
            else
              FormBuilderSearchableDropdown<ImmeublesModel>(
                name: 'immeuble',
                initialValue: _selectedImmeuble,
                items: _immeubles,
                itemAsString: (i) => i.name,
                filterFn: (i, q) =>
                    i.name.toLowerCase().contains(q.toLowerCase()) ||
                    (i.city?.toLowerCase().contains(q.toLowerCase()) ?? false),
                compareFn: (a, b) => a.id == b.id,
                enabled: !_readOnly,
                decoration: const InputDecoration(labelText: 'Immeuble'),
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: const TextFieldProps(
                    decoration: _searchBoxDecoration,
                  ),
                ),
                onChanged: (imm) {
                  if (imm != null) {
                    _loadChambresPourImmeuble(imm.id);
                  } else {
                    setState(() {
                      _chambresForImmeuble = [];
                      _selectedChambre = null;
                    });
                    _formKey.currentState?.fields['chambre']?.didChange(null);
                  }
                },
              ),
            const SizedBox(height: AppSpacing.md),

            // ── Chambre (optionnel) ───────────────────────────────────
            FormBuilderSearchableDropdown<ChambreModel>(
              key: ValueKey(_chambresForImmeuble.length),
              name: 'chambre',
              initialValue: _selectedChambre,
              items: _chambresForImmeuble,
              itemAsString: (c) => c.roomName,
              filterFn: (c, q) =>
                  c.roomName.toLowerCase().contains(q.toLowerCase()),
              compareFn: (a, b) => a.id == b.id,
              enabled: !_readOnly &&
                  !_loadingChambres &&
                  _chambresForImmeuble.isNotEmpty,
              decoration: InputDecoration(
                labelText: 'Chambre (optionnel)',
                suffixIcon: _loadingChambres
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                hintText: _loadingChambres
                    ? 'Chargement…'
                    : (widget.prefilledImmeubleId == null &&
                            _selectedImmeuble == null &&
                            _chambresForImmeuble.isEmpty)
                        ? 'Sélectionnez d\'abord un immeuble'
                        : null,
              ),
              popupProps: PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: const TextFieldProps(
                  decoration: _searchBoxDecoration,
                ),
                emptyBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('Aucune chambre disponible'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Type + Code ───────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: FormBuilderDropdown<String>(
                    name: 'type_facture',
                    initialValue: f?.typeFacture,
                    decoration:
                        const InputDecoration(labelText: 'Type de facture'),
                    enabled: !_readOnly,
                    items: kTypesFacture
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    validator: FormBuilderValidators.required(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'code_facture',
                    initialValue: f?.codeFacture,
                    enabled: !_readOnly,
                    decoration:
                        const InputDecoration(labelText: 'N° facture'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Fournisseur ───────────────────────────────────────────
            FormBuilderTextField(
              name: 'fournisseur',
              initialValue: f?.fournisseur,
              enabled: !_readOnly,
              decoration:
                  const InputDecoration(labelText: 'Fournisseur / Prestataire'),
              validator: FormBuilderValidators.required(),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Période ───────────────────────────────────────────────
            Text('Période', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FormBuilderDateTimePicker(
                    name: 'periode_debut',
                    initialValue: f?.periodeDebut,
                    inputType: InputType.date,
                    format: _dateFmt,
                    locale: const Locale('fr', 'FR'),
                    enabled: !_readOnly,
                    decoration: const InputDecoration(
                      labelText: 'Du',
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FormBuilderDateTimePicker(
                    name: 'periode_fin',
                    initialValue: f?.periodeFin,
                    inputType: InputType.date,
                    format: _dateFmt,
                    locale: const Locale('fr', 'FR'),
                    enabled: !_readOnly,
                    decoration: const InputDecoration(
                      labelText: 'Au',
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Dates émission / échéance ─────────────────────────────
            Row(
              children: [
                Expanded(
                  child: FormBuilderDateTimePicker(
                    name: 'date_emission',
                    initialValue: f?.dateEmission,
                    inputType: InputType.date,
                    format: _dateFmt,
                    locale: const Locale('fr', 'FR'),
                    enabled: !_readOnly,
                    decoration: const InputDecoration(
                      labelText: "Date d'émission",
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FormBuilderDateTimePicker(
                    name: 'date_echeance',
                    initialValue: f?.dateEcheance,
                    inputType: InputType.date,
                    format: _dateFmt,
                    locale: const Locale('fr', 'FR'),
                    enabled: !_readOnly,
                    decoration: const InputDecoration(
                      labelText: "Date d'échéance",
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Montants ──────────────────────────────────────────────
            Text('Montants', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'montant_ht',
                    initialValue: f?.montantHt?.toStringAsFixed(2),
                    enabled: !_readOnly,
                    decoration: const InputDecoration(
                      labelText: 'Montant HT (€)',
                      hintText: '0.00',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _readOnly
                        ? null
                        : (v) => _recalcTtc(
                              v,
                              _formKey.currentState?.fields['taux_tva']?.value
                                  as String?,
                            ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'taux_tva',
                    initialValue: f != null
                        ? f.tauxTva.toStringAsFixed(2)
                        : '20',
                    enabled: !_readOnly,
                    decoration: const InputDecoration(
                        labelText: 'TVA (%)', hintText: '20'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _readOnly
                        ? null
                        : (v) => _recalcTtc(
                              _formKey.currentState?.fields['montant_ht']?.value
                                  as String?,
                              v,
                            ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'montant_ttc',
                    initialValue: f?.montantTtc?.toStringAsFixed(2),
                    enabled: !_readOnly,
                    decoration: const InputDecoration(
                      labelText: 'Montant TTC (€)',
                      hintText: '0.00',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Statut ────────────────────────────────────────────────
            FormBuilderDropdown<String>(
              name: 'statut',
              initialValue: f?.statut ?? 'Non payée',
              enabled: !_readOnly,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: kStatutsFacture
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Notes ─────────────────────────────────────────────────
            FormBuilderTextField(
              name: 'notes',
              initialValue: f?.notes,
              enabled: !_readOnly,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),

            if (!_readOnly) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: AppTheme.saveButtonStyle,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isEditing
                    ? 'Enregistrer les modifications'
                    : 'Enregistrer'),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
