import 'package:flutter/material.dart';
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
/// [showEquipments] – exibe chips de équipements (apenas para chambres).
/// [filter] / [onChanged] – estado externo; o pai gerencia o ChambreFilter.
class FilterPanel extends StatefulWidget {
  final ChambreFilter filter;
  final ValueChanged<ChambreFilter> onChanged;
  final bool showEquipments;

  const FilterPanel({
    super.key,
    required this.filter,
    required this.onChanged,
    this.showEquipments = false,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  bool _expanded = false;
  final _cityCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
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
    // Sincroniza campos de texto quando o pai reseta o filtro
    if (old.filter != widget.filter) _syncCtrls(widget.filter);
  }

  void _syncCtrls(ChambreFilter f) {
    if (_cityCtrl.text != f.city) _cityCtrl.text = f.city;
    if (_regionCtrl.text != f.region) _regionCtrl.text = f.region;
    if (_deptCtrl.text != f.department) _deptCtrl.text = f.department;
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _regionCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  void _emitLocation() {
    widget.onChanged(
      widget.filter.copyWith(
        city: _cityCtrl.text.trim(),
        region: _regionCtrl.text.trim(),
        department: _deptCtrl.text.trim(),
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
                // Localização
                Text('Localisation', style: AppTypography.labelMd),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _LocationField(
                        controller: _cityCtrl,
                        label: 'Ville',
                        icon: Icons.location_city_outlined,
                        onSubmitted: (_) => _emitLocation(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _LocationField(
                        controller: _deptCtrl,
                        label: 'Département',
                        icon: Icons.map_outlined,
                        onSubmitted: (_) => _emitLocation(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _LocationField(
                        controller: _regionCtrl,
                        label: 'Région',
                        icon: Icons.public_outlined,
                        onSubmitted: (_) => _emitLocation(),
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

                // Appliquer (confirma campos de texto não submetidos)
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () {
                      _emitLocation();
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
