import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lacoloc_front/data/datasources/reference.dart';
import 'package:lacoloc_front/data/models/filter_state.dart';
import 'package:lacoloc_front/data/models/reference.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

export 'package:lacoloc_front/data/models/filter_state.dart'
    show ChambreFilter, BailTypeFilter;

/// Painel de filtros expansível, reutilizável em Chambres e Immeubles.
///
/// [showEquipments] – chips de équipements (apenas para chambres).
/// [showM2]         – campos de surface min/max.
/// [showPrix]       – campos de loyer min/max.
class FilterPanel extends StatefulWidget {
  final ChambreFilter filter;
  final ValueChanged<ChambreFilter> onChanged;
  final bool showEquipments;
  final bool showM2;
  final bool showPrix;

  const FilterPanel({
    super.key,
    required this.filter,
    required this.onChanged,
    this.showEquipments = false,
    this.showM2 = false,
    this.showPrix = false,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  bool _expanded = false;
  final _cityCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _m2MinCtrl = TextEditingController();
  final _m2MaxCtrl = TextEditingController();
  final _prixMinCtrl = TextEditingController();
  final _prixMaxCtrl = TextEditingController();
  Future<List<ReferenceItem>>? _optionsFuture;

  @override
  void initState() {
    super.initState();
    _syncCtrls(widget.filter);
    if (widget.showEquipments) {
      _optionsFuture = ReferenceDatasource.roomOptions();
    }
  }

  @override
  void didUpdateWidget(FilterPanel old) {
    super.didUpdateWidget(old);
    if (old.filter != widget.filter) _syncCtrls(widget.filter);
  }

  void _syncCtrls(ChambreFilter f) {
    if (_cityCtrl.text != f.city) _cityCtrl.text = f.city;
    if (_regionCtrl.text != f.region) _regionCtrl.text = f.region;
    if (_deptCtrl.text != f.department) _deptCtrl.text = f.department;
    final m2Min = f.m2Min?.toStringAsFixed(0) ?? '';
    final m2Max = f.m2Max?.toStringAsFixed(0) ?? '';
    final prixMin = f.prixMin?.toStringAsFixed(0) ?? '';
    final prixMax = f.prixMax?.toStringAsFixed(0) ?? '';
    if (_m2MinCtrl.text != m2Min) _m2MinCtrl.text = m2Min;
    if (_m2MaxCtrl.text != m2Max) _m2MaxCtrl.text = m2Max;
    if (_prixMinCtrl.text != prixMin) _prixMinCtrl.text = prixMin;
    if (_prixMaxCtrl.text != prixMax) _prixMaxCtrl.text = prixMax;
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _regionCtrl.dispose();
    _deptCtrl.dispose();
    _m2MinCtrl.dispose();
    _m2MaxCtrl.dispose();
    _prixMinCtrl.dispose();
    _prixMaxCtrl.dispose();
    super.dispose();
  }

  void _emitAll() {
    widget.onChanged(
      widget.filter.copyWith(
        city: _cityCtrl.text.trim(),
        region: _regionCtrl.text.trim(),
        department: _deptCtrl.text.trim(),
        m2Min: double.tryParse(_m2MinCtrl.text.trim()),
        m2Max: double.tryParse(_m2MaxCtrl.text.trim()),
        prixMin: double.tryParse(_prixMinCtrl.text.trim()),
        prixMax: double.tryParse(_prixMaxCtrl.text.trim()),
      ),
    );
  }

  void _toggleOption(int id, bool selected) {
    final next = Set<int>.from(widget.filter.optionIds);
    selected ? next.add(id) : next.remove(id);
    widget.onChanged(widget.filter.copyWith(optionIds: next));
  }

  void _reset() {
    _cityCtrl.clear();
    _regionCtrl.clear();
    _deptCtrl.clear();
    _m2MinCtrl.clear();
    _m2MaxCtrl.clear();
    _prixMinCtrl.clear();
    _prixMaxCtrl.clear();
    widget.onChanged(ChambreFilter.empty);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.filter.activeCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Barre de déclenchement ──────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            color: AppColors.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tune,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Filtres', style: AppTypography.titleLs),
                if (active > 0) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadius.borderFull,
                    ),
                    child: Text(
                      '$active',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (active > 0)
                  TextButton(
                    onPressed: _reset,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Réinitialiser'),
                  ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        // ── Contenu dépliable ───────────────────────────────────────────────
        if (_expanded)
          Container(
            color: AppColors.surfaceContainerLowest,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Localisation
                Text('Localisation', style: AppTypography.labelMd),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _LocationField(
                        controller: _cityCtrl,
                        label: 'Ville',
                        icon: Icons.location_city_outlined,
                        onSubmitted: (_) => _emitAll(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _LocationField(
                        controller: _deptCtrl,
                        label: 'Département',
                        icon: Icons.map_outlined,
                        onSubmitted: (_) => _emitAll(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _LocationField(
                        controller: _regionCtrl,
                        label: 'Région',
                        icon: Icons.public_outlined,
                        onSubmitted: (_) => _emitAll(),
                      ),
                    ),
                  ],
                ),

                // Type de bail
                const SizedBox(height: AppSpacing.md),
                Text('Type de bail', style: AppTypography.labelMd),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilterChip(
                      label: Text('Bail collectif',
                          style: AppTypography.labelSm),
                      selected: widget.filter.bailType ==
                          BailTypeFilter.collectif,
                      onSelected: (v) => widget.onChanged(
                        widget.filter.copyWith(
                          bailType: v ? BailTypeFilter.collectif : null,
                        ),
                      ),
                      selectedColor: AppColors.primaryFixed,
                      checkmarkColor: AppColors.primary,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    FilterChip(
                      label: Text('Bail individuel',
                          style: AppTypography.labelSm),
                      selected: widget.filter.bailType ==
                          BailTypeFilter.individuel,
                      onSelected: (v) => widget.onChanged(
                        widget.filter.copyWith(
                          bailType: v ? BailTypeFilter.individuel : null,
                        ),
                      ),
                      selectedColor: AppColors.primaryFixed,
                      checkmarkColor: AppColors.primary,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),

                // Surface m²
                if (widget.showM2) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Surface (m²)', style: AppTypography.labelMd),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          controller: _m2MinCtrl,
                          label: 'Min m²',
                          onSubmitted: (_) => _emitAll(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _NumberField(
                          controller: _m2MaxCtrl,
                          label: 'Max m²',
                          onSubmitted: (_) => _emitAll(),
                        ),
                      ),
                    ],
                  ),
                ],

                // Loyer €
                if (widget.showPrix) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Loyer mensuel (€)', style: AppTypography.labelMd),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          controller: _prixMinCtrl,
                          label: 'Min €',
                          onSubmitted: (_) => _emitAll(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _NumberField(
                          controller: _prixMaxCtrl,
                          label: 'Max €',
                          onSubmitted: (_) => _emitAll(),
                        ),
                      ),
                    ],
                  ),
                ],

                // Équipements
                if (widget.showEquipments && _optionsFuture != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Équipements', style: AppTypography.labelMd),
                  const SizedBox(height: AppSpacing.sm),
                  FutureBuilder<List<ReferenceItem>>(
                    future: _optionsFuture,
                    builder: (_, snap) {
                      final opts = snap.data ?? [];
                      if (opts.isEmpty) return const SizedBox.shrink();
                      return Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: opts.map((o) {
                          final sel = widget.filter.optionIds.contains(o.id);
                          return FilterChip(
                            label: Text(o.name, style: AppTypography.labelSm),
                            selected: sel,
                            onSelected: (v) => _toggleOption(o.id, v),
                            selectedColor: AppColors.primaryFixed,
                            checkmarkColor: AppColors.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],

                // Appliquer
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () {
                      _emitAll();
                      setState(() => _expanded = false);
                    },
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String>? onSubmitted;

  const _LocationField({
    required this.controller,
    required this.label,
    required this.icon,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;

  const _NumberField({
    required this.controller,
    required this.label,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.done,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
      ),
    );
  }
}
