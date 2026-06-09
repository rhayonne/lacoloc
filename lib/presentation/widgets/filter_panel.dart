import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lacoloc_front/data/datasources/reference.dart';
import 'package:lacoloc_front/data/models/filter_state.dart';
import 'package:lacoloc_front/data/models/immeuble_type.dart';
import 'package:lacoloc_front/data/models/reference.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

export 'package:lacoloc_front/data/models/filter_state.dart'
    show ChambreFilter, BailTypeFilter;

/// Catálogo de módulos de filtro disponíveis no [FilterPanel].
///
/// COMO USAR:
/// Cada valor do enum corresponde a um bloco de UI (um "módulo") construído por
/// um método `_build<Modulo>()` no [_FilterPanelState]. Ao montar uma tela, você
/// escolhe quais módulos quer exibir passando-os no parâmetro `modules`:
///
/// ```dart
/// FilterPanel(
///   filter: _filter,
///   onChanged: (f) => setState(() => _filter = f),
///   modules: const {FilterModule.localisation, FilterModule.meuble},
/// )
/// ```
///
/// COMO ADICIONAR UM NOVO FILTRO (regra do projeto):
/// 1. Adicione o campo correspondente em [ChambreFilter] (estado imutável).
/// 2. Adicione um valor a este enum.
/// 3. Crie um método `_build<Nome>()` no [_FilterPanelState] com um doc-comment
///    no padrão "MODULE `x` — … / Quand l'utiliser / Émet …".
/// 4. Adicione o `case` no `switch` de [_FilterPanelState._buildModule].
/// 5. Habilite-o nas telas onde fizer sentido, via `modules`.
///
/// Os módulos são sempre renderizados na ordem deste enum.
enum FilterModule {
  /// Ville / Département / Région.
  localisation,

  /// Bail collectif / individuel.
  bail,

  /// Location meublée / non meublée.
  meuble,

  /// Type d'immeuble (Appartement, Maison, Studio…).
  typeImmeuble,

  /// Surface min / max (m²).
  surface,

  /// Loyer mensuel min / max (€).
  prix,

  /// Équipements (options des chambres).
  equipements,
}

/// Painel de filtros reutilizável (catálogo de módulos).
///
/// Renderiza um botão "Filtres" que abre/fecha o corpo dos filtros. O corpo
/// mostra apenas os módulos passados em [modules] (ver [FilterModule]).
class FilterPanel extends StatefulWidget {
  final ChambreFilter filter;
  final ValueChanged<ChambreFilter> onChanged;

  /// Conjunto de módulos a exibir. Renderizados na ordem de [FilterModule].
  final Set<FilterModule> modules;

  /// Widget opcional exibido à direita, na mesma linha do botão « Filtres »
  /// (ex.: um botão de ação contextual em telas estreitas).
  final Widget? trailing;

  const FilterPanel({
    super.key,
    required this.filter,
    required this.onChanged,
    this.modules = const {
      FilterModule.localisation,
      FilterModule.bail,
    },
    this.trailing,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  final _portalCtrl = OverlayPortalController();
  final _link = LayerLink();

  /// Estado do filtro no momento em que o painel foi aberto — usado pelo botão
  /// « Annuler » para reverter as mudanças (chips emitem ao vivo).
  ChambreFilter _snapshot = ChambreFilter.empty;

  final _cityCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _m2MinCtrl = TextEditingController();
  final _m2MaxCtrl = TextEditingController();
  final _prixMinCtrl = TextEditingController();
  final _prixMaxCtrl = TextEditingController();
  Future<List<ReferenceItem>>? _optionsFuture;
  Future<List<ImmeubleTypeModel>>? _typesFuture;

  @override
  void initState() {
    super.initState();
    _syncCtrls(widget.filter);
    if (widget.modules.contains(FilterModule.equipements)) {
      _optionsFuture = ReferenceDatasource.roomOptions();
    }
    if (widget.modules.contains(FilterModule.typeImmeuble)) {
      _typesFuture = ReferenceDatasource.immeubleTypes();
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

  /// Réinitialiser : efface tous les filtres (le panneau reste ouvert).
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

  void _open() {
    _snapshot = widget.filter;
    _portalCtrl.show();
    setState(() {});
  }

  /// Appliquer : valide les champs texte et ferme le panneau.
  void _apply() {
    _emitAll();
    _portalCtrl.hide();
    setState(() {});
  }

  /// Annuler : revient à l'état d'ouverture (snapshot) et ferme.
  void _cancel() {
    _syncCtrls(_snapshot);
    widget.onChanged(_snapshot);
    _portalCtrl.hide();
    setState(() {});
  }

  void _toggle() => _portalCtrl.isShowing ? _cancel() : _open();

  // ── Construção de um módulo a partir do enum ────────────────────────────────
  Widget? _buildModule(FilterModule m) {
    switch (m) {
      case FilterModule.localisation:
        return _buildLocalisation();
      case FilterModule.bail:
        return _buildBail();
      case FilterModule.meuble:
        return _buildMeuble();
      case FilterModule.typeImmeuble:
        return _buildTypeImmeuble();
      case FilterModule.surface:
        return _buildSurface();
      case FilterModule.prix:
        return _buildPrix();
      case FilterModule.equipements:
        return _buildEquipements();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.filter.activeCount;
    final isOpen = _portalCtrl.isShowing;

    // ── Bouton « Filtres » (déclencheur) ────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              CompositedTransformTarget(
                link: _link,
                child: OverlayPortal(
                controller: _portalCtrl,
                overlayChildBuilder: _buildOverlay,
                child: Material(
                  color: isOpen
                      ? AppColors.primaryFixed
                      : AppColors.surfaceContainerLow,
                  borderRadius: AppRadius.borderFull,
                  child: InkWell(
                    borderRadius: AppRadius.borderFull,
                    onTap: _toggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tune,
                              size: 18, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Filtres', style: AppTypography.titleLs),
                          if (active > 0) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: AppRadius.borderFull,
                              ),
                              child: Text('$active',
                                  style: AppTypography.labelSm
                                      .copyWith(color: AppColors.onPrimary)),
                            ),
                          ],
                          const SizedBox(width: AppSpacing.xs),
                          Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                              size: 20, color: AppColors.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.trailing != null) ...[
              const Spacer(),
              widget.trailing!,
            ],
          ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  /// Corps flottant des filtres : superposé au contenu (ne le pousse pas vers le
  /// bas). Une barrière transparente ferme le panneau (équivaut à « Annuler »).
  Widget _buildOverlay(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final panelWidth = math.min(560.0, screen.width - 2 * AppSpacing.lg);

    // Ordena os módulos pela ordem do enum e descarta os não selecionados.
    final modules = FilterModule.values
        .where(widget.modules.contains)
        .map(_buildModule)
        .whereType<Widget>()
        .toList();

    return Stack(
      children: [
        // Barrière : un tap en dehors ferme (annule).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _cancel,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, AppSpacing.xs),
          showWhenUnlinked: false,
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: SizedBox(
              width: panelWidth,
              child: Material(
                color: AppColors.surfaceContainerLowest,
                elevation: 6,
                borderRadius: AppRadius.borderLg,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: screen.height * 0.7),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < modules.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.md),
                          modules[i],
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.md),
                        // ── Actions (boutons thématiques) ──────────────────
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            FilledButton.icon(
                              onPressed: _reset,
                              style: AppTheme.deleteButtonStyle,
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('Réinitialiser'),
                            ),
                            OutlinedButton(
                              onPressed: _cancel,
                              style: AppTheme.cancelButtonStyle,
                              child: const Text('Annuler'),
                            ),
                            FilledButton.icon(
                              onPressed: _apply,
                              style: AppTheme.saveButtonStyle,
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Appliquer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MODULES ─────────────────────────────────────────────────────────────────

  /// MODULE `localisation` — Ville / Département / Région.
  /// Quand l'utiliser : toute liste géolocalisée (chambres, immeubles).
  /// Émet `city` / `department` / `region` dans le [ChambreFilter] (substring,
  /// insensible à la casse, côté filtrage).
  Widget _buildLocalisation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  /// MODULE `bail` — Bail collectif / individuel (exclusif).
  /// Quand l'utiliser : listes liées au type de contrat de l'immeuble.
  /// Émet `bailType` (null = indifférent).
  Widget _buildBail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type de bail', style: AppTypography.labelMd),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _chip(
              label: 'Bail collectif',
              selected: widget.filter.bailType == BailTypeFilter.collectif,
              onSelected: (v) => widget.onChanged(widget.filter
                  .copyWith(bailType: v ? BailTypeFilter.collectif : null)),
            ),
            _chip(
              label: 'Bail individuel',
              selected: widget.filter.bailType == BailTypeFilter.individuel,
              onSelected: (v) => widget.onChanged(widget.filter
                  .copyWith(bailType: v ? BailTypeFilter.individuel : null)),
            ),
          ],
        ),
      ],
    );
  }

  /// MODULE `meuble` — Location meublée / non meublée (exclusif).
  /// Quand l'utiliser : listes où l'on distingue le mobilier (chambres, immeubles).
  /// Émet `meuble` (null = indifférent, true = meublée, false = non meublée).
  Widget _buildMeuble() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: AppTypography.labelMd),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _chip(
              label: 'Meublée',
              selected: widget.filter.meuble == true,
              onSelected: (v) =>
                  widget.onChanged(widget.filter.copyWith(meuble: v ? true : null)),
            ),
            _chip(
              label: 'Non meublée',
              selected: widget.filter.meuble == false,
              onSelected: (v) => widget.onChanged(
                  widget.filter.copyWith(meuble: v ? false : null)),
            ),
          ],
        ),
      ],
    );
  }

  /// MODULE `typeImmeuble` — Type d'immeuble (Appartement, Maison, Studio…).
  /// Quand l'utiliser : listes liées au type du bien.
  /// Émet `immeubleTypeId` (null = indifférent). Source : `Immeuble_Types_Reference`.
  Widget _buildTypeImmeuble() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Type d'immeuble", style: AppTypography.labelMd),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<List<ImmeubleTypeModel>>(
          future: _typesFuture,
          builder: (_, snap) {
            final types = snap.data ?? [];
            if (types.isEmpty) return const SizedBox.shrink();
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: types.map((t) {
                return _chip(
                  label: t.typeName,
                  selected: widget.filter.immeubleTypeId == t.id,
                  onSelected: (v) => widget.onChanged(
                      widget.filter.copyWith(immeubleTypeId: v ? t.id : null)),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  /// MODULE `surface` — Surface min / max en m².
  /// Quand l'utiliser : listes de chambres (surface de la pièce).
  /// Émet `m2Min` / `m2Max`.
  Widget _buildSurface() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }

  /// MODULE `prix` — Loyer mensuel min / max en €.
  /// Quand l'utiliser : listes de chambres avec loyer.
  /// Émet `prixMin` / `prixMax`.
  Widget _buildPrix() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }

  /// MODULE `equipements` — Options/équipements des chambres (Wifi, Lit double…).
  /// Quand l'utiliser : chambres (option directe) ou immeubles (au moins une
  /// chambre couvrant les options choisies).
  /// Émet `optionIds` (ET : toutes les options sélectionnées doivent être présentes).
  Widget _buildEquipements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                return _chip(
                  label: o.name,
                  selected: widget.filter.optionIds.contains(o.id),
                  onSelected: (v) => _toggleOption(o.id, v),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ── Helper visuel pour les chips ─────────────────────────────────────────────
  Widget _chip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label, style: AppTypography.labelSm),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.primaryFixed,
      checkmarkColor: AppColors.primary,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
