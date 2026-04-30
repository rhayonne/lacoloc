import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/factures.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/models/facture.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

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
  final _formKey = GlobalKey<FormState>();

  final _codeCtrl = TextEditingController();
  final _fournisseurCtrl = TextEditingController();
  final _montantHtCtrl = TextEditingController();
  final _montantTtcCtrl = TextEditingController();
  final _tauxTvaCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _typeFacture;
  String _statut = 'Non payée';
  int? _immeubleId;

  DateTime? _periodeDebut;
  DateTime? _periodeFin;
  DateTime? _dateEmission;
  DateTime? _dateEcheance;

  late Future<List<ImmeublesModel>> _immeublesFuture;
  bool _isSubmitting = false;

  bool get _isEditing => widget.facture != null;
  bool get _readOnly => widget.readOnly;

  @override
  void initState() {
    super.initState();
    final ownerId = AuthService.currentUser?.id;
    _immeublesFuture = ownerId != null
        ? ImmeublesDatasource.listByOwner(ownerId)
        : Future.value([]);

    final f = widget.facture;
    if (f != null) {
      _codeCtrl.text = f.codeFacture ?? '';
      _fournisseurCtrl.text = f.fournisseur;
      _montantHtCtrl.text = f.montantHt?.toStringAsFixed(2) ?? '';
      _montantTtcCtrl.text = f.montantTtc?.toStringAsFixed(2) ?? '';
      _tauxTvaCtrl.text = f.tauxTva.toStringAsFixed(2);
      _notesCtrl.text = f.notes ?? '';
      _typeFacture = f.typeFacture;
      _statut = f.statut;
      _immeubleId = f.immeubleId;
      _periodeDebut = f.periodeDebut;
      _periodeFin = f.periodeFin;
      _dateEmission = f.dateEmission;
      _dateEcheance = f.dateEcheance;
    } else {
      _tauxTvaCtrl.text = '20';
      _immeubleId = widget.prefilledImmeubleId;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _fournisseurCtrl.dispose();
    _montantHtCtrl.dispose();
    _montantTtcCtrl.dispose();
    _tauxTvaCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Calcule automatiquement TTC à partir de HT + TVA
  void _recalcTtc() {
    final ht = double.tryParse(_montantHtCtrl.text.replaceAll(',', '.'));
    final tva = double.tryParse(_tauxTvaCtrl.text.replaceAll(',', '.'));
    if (ht != null && tva != null) {
      final ttc = ht * (1 + tva / 100);
      _montantTtcCtrl.text = ttc.toStringAsFixed(2);
    }
  }

  Future<void> _pickDate({
    required String label,
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: label,
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_typeFacture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un type de facture')),
      );
      return;
    }
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final model = FactureModel(
        id: widget.facture?.id ?? 0,
        ownerId: ownerId,
        immeubleId: _immeubleId,
        codeFacture:
            _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        fournisseur: _fournisseurCtrl.text.trim(),
        typeFacture: _typeFacture!,
        periodeDebut: _periodeDebut,
        periodeFin: _periodeFin,
        dateEmission: _dateEmission,
        dateEcheance: _dateEcheance,
        montantHt:
            double.tryParse(_montantHtCtrl.text.replaceAll(',', '.')),
        tauxTva:
            double.tryParse(_tauxTvaCtrl.text.replaceAll(',', '.')) ?? 20,
        montantTtc:
            double.tryParse(_montantTtcCtrl.text.replaceAll(',', '.')),
        statut: _statut,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    String title;
    if (_readOnly) {
      title = 'Détail de la facture';
    } else if (_isEditing) {
      title = 'Modifier la facture';
    } else {
      title = 'Nouvelle facture';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.titleLg),
            const SizedBox(height: AppSpacing.lg),

            // ── Immeuble ──────────────────────────────────────────────────
            FutureBuilder<List<ImmeublesModel>>(
              future: _immeublesFuture,
              builder: (context, snap) {
                final items = snap.data ?? [];

                // Immeuble fixé depuis le contexte détail : lecture seule
                if (widget.prefilledImmeubleId != null) {
                  return TextFormField(
                    initialValue: widget.prefilledImmeubleName ?? '',
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Immeuble',
                      suffixIcon: Icon(Icons.lock_outline, size: 16),
                    ),
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  );
                }

                return DropdownButtonFormField<int?>(
                  initialValue: _immeubleId,
                  decoration: const InputDecoration(labelText: 'Immeuble'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('— Aucun —')),
                    ...items.map((i) =>
                        DropdownMenuItem(value: i.id, child: Text(i.name))),
                  ],
                  onChanged: _readOnly
                      ? null
                      : (v) => setState(() => _immeubleId = v),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Type + Code ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _typeFacture,
                    decoration:
                        const InputDecoration(labelText: 'Type de facture'),
                    items: kTypesFacture
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: _readOnly
                        ? null
                        : (v) => setState(() => _typeFacture = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _codeCtrl,
                    readOnly: _readOnly,
                    decoration:
                        const InputDecoration(labelText: 'N° facture'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Fournisseur ───────────────────────────────────────────────
            TextFormField(
              controller: _fournisseurCtrl,
              readOnly: _readOnly,
              decoration:
                  const InputDecoration(labelText: 'Fournisseur / Prestataire'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Période ───────────────────────────────────────────────────
            Text('Période', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Du',
                    value: _periodeDebut,
                    readOnly: _readOnly,
                    onTap: _readOnly
                        ? null
                        : () => _pickDate(
                              label: 'Début de période',
                              current: _periodeDebut,
                              onPicked: (d) =>
                                  setState(() => _periodeDebut = d),
                            ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _DateField(
                    label: 'Au',
                    value: _periodeFin,
                    readOnly: _readOnly,
                    onTap: _readOnly
                        ? null
                        : () => _pickDate(
                              label: 'Fin de période',
                              current: _periodeFin,
                              onPicked: (d) =>
                                  setState(() => _periodeFin = d),
                            ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Dates émission / échéance ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: "Date d'émission",
                    value: _dateEmission,
                    readOnly: _readOnly,
                    onTap: _readOnly
                        ? null
                        : () => _pickDate(
                              label: "Date d'émission",
                              current: _dateEmission,
                              onPicked: (d) =>
                                  setState(() => _dateEmission = d),
                            ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _DateField(
                    label: "Date d'échéance",
                    value: _dateEcheance,
                    readOnly: _readOnly,
                    onTap: _readOnly
                        ? null
                        : () => _pickDate(
                              label: "Date d'échéance",
                              current: _dateEcheance,
                              onPicked: (d) =>
                                  setState(() => _dateEcheance = d),
                            ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Montants ──────────────────────────────────────────────────
            Text('Montants', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _montantHtCtrl,
                    readOnly: _readOnly,
                    decoration: const InputDecoration(
                      labelText: 'Montant HT (€)',
                      hintText: '0.00',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _readOnly ? null : (_) => _recalcTtc(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _tauxTvaCtrl,
                    readOnly: _readOnly,
                    decoration:
                        const InputDecoration(labelText: 'TVA (%)', hintText: '20'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _readOnly ? null : (_) => _recalcTtc(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _montantTtcCtrl,
                    readOnly: _readOnly,
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

            // ── Statut ────────────────────────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: _statut,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: kStatutsFacture
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged:
                  _readOnly ? null : (v) => setState(() => _statut = v!),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Notes ─────────────────────────────────────────────────────
            TextFormField(
              controller: _notesCtrl,
              readOnly: _readOnly,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),

            if (!_readOnly) ...[
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool readOnly;
  final VoidCallback? onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.readOnly,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? '${value!.day.toString().padLeft(2, '0')}/'
            '${value!.month.toString().padLeft(2, '0')}/'
            '${value!.year}'
        : '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: readOnly
              ? null
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          text.isEmpty ? '—' : text,
          style: TextStyle(
            color: text.isEmpty
                ? AppColors.onSurfaceVariant
                : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}
