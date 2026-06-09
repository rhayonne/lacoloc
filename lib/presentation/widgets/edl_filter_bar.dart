import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/presentation/widgets/edl_date_range_picker.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Catálogo de módulos de filtro disponíveis na [EdlFilterBar] (barra de
/// filtros das tabelas d'états des lieux).
///
/// COMO USAR : cada tela passa em `modules` o conjunto de filtros que quer
/// exibir ; ils sont rendus dans l'ordre de l'enum. L'état partagé est
/// [EdlTableFilter] (immuable) ; le filtrage se fait via
/// [EdlTableFilter.matches].
///
/// COMO ADICIONAR UM NOVO FILTRO (règle du projet) :
/// 1. Ajouter le champ dans [EdlTableFilter] (+ `copyWith`, `matches`).
/// 2. Ajouter une valeur à cet enum.
/// 3. Construire le contrôle dans [_EdlFilterBarState] (`_buildModule`).
/// 4. L'activer dans les écrans via `modules`.
enum EdlFilterModule {
  /// Champ texte (locataire, immeuble, chambre).
  recherche,

  /// Situation : Toutes / En cours / À venir / Finalisé (avec compteurs).
  situation,

  /// Type de bail : Collectif / Individuel.
  bail,

  /// Type d'EDL : Entrée / Sortie.
  typeEdl,

  /// Plage de dates de création de l'EDL.
  dateCreation,

  /// Plage de dates de finalisation (signature locataire).
  dateFinalisation,
}

/// État immuable des filtres d'une table d'états des lieux.
///
/// - [query] : texte libre (locataire / immeuble / chambre).
/// - [situation] : null = toutes.
/// - [typeBail] : `collectif` | `individuel` | null.
/// - [typeEdl] : `entree` | `sortie` | null.
/// - [createdRange] : filtre sur `created_at`.
/// - [finalisedRange] : filtre sur `date_finalisation` (exclut les non finalisés).
class EdlTableFilter {
  final String query;
  final SituationEdl? situation;
  final String? typeBail;
  final String? typeEdl;
  final DateTimeRange? createdRange;
  final DateTimeRange? finalisedRange;

  const EdlTableFilter({
    this.query = '',
    this.situation,
    this.typeBail,
    this.typeEdl,
    this.createdRange,
    this.finalisedRange,
  });

  static const empty = EdlTableFilter();

  bool get isEmpty =>
      query.isEmpty &&
      situation == null &&
      typeBail == null &&
      typeEdl == null &&
      createdRange == null &&
      finalisedRange == null;

  /// Nombre de filtres actifs (hors recherche texte), pour un éventuel badge.
  int get activeCount =>
      (situation != null ? 1 : 0) +
      (typeBail != null ? 1 : 0) +
      (typeEdl != null ? 1 : 0) +
      (createdRange != null ? 1 : 0) +
      (finalisedRange != null ? 1 : 0);

  EdlTableFilter copyWith({
    String? query,
    Object? situation = _sentinel,
    Object? typeBail = _sentinel,
    Object? typeEdl = _sentinel,
    Object? createdRange = _sentinel,
    Object? finalisedRange = _sentinel,
  }) =>
      EdlTableFilter(
        query: query ?? this.query,
        situation:
            situation == _sentinel ? this.situation : situation as SituationEdl?,
        typeBail: typeBail == _sentinel ? this.typeBail : typeBail as String?,
        typeEdl: typeEdl == _sentinel ? this.typeEdl : typeEdl as String?,
        createdRange: createdRange == _sentinel
            ? this.createdRange
            : createdRange as DateTimeRange?,
        finalisedRange: finalisedRange == _sentinel
            ? this.finalisedRange
            : finalisedRange as DateTimeRange?,
      );

  /// Vrai si l'EDL satisfait tous les filtres actifs.
  bool matches(EtatDesLieuxModel e) {
    if (situation != null && e.situation != situation) return false;
    if (typeBail != null && e.typeBail != typeBail) return false;
    if (typeEdl != null && e.typeEdl != typeEdl) return false;
    if (createdRange != null && !_inRange(e.createdAt, createdRange!)) {
      return false;
    }
    if (finalisedRange != null) {
      final d = e.dateFinalisation;
      if (d == null || !_inRange(d, finalisedRange!)) return false;
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final hit = e.displayLocataire.toLowerCase().contains(q) ||
          (e.locataireEmail?.toLowerCase().contains(q) ?? false) ||
          (e.immeubleNom?.toLowerCase().contains(q) ?? false) ||
          (e.chambreNom?.toLowerCase().contains(q) ?? false);
      if (!hit) return false;
    }
    return true;
  }

  static bool _inRange(DateTime d, DateTimeRange r) {
    final day = DateTime(d.year, d.month, d.day);
    final start = DateTime(r.start.year, r.start.month, r.start.day);
    final end = DateTime(r.end.year, r.end.month, r.end.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

const _sentinel = Object();

/// Barre de filtres compacte et réutilisable pour les tables d'EDL.
///
/// Paramètres :
/// - [filter] / [onChanged] : état partagé ([EdlTableFilter]).
/// - [edls] : la liste complète, utilisée pour calculer les compteurs des
///   chips (Toutes / En cours…).
/// - [modules] : quels filtres afficher (voir [EdlFilterModule]).
class EdlFilterBar extends StatefulWidget {
  final EdlTableFilter filter;
  final ValueChanged<EdlTableFilter> onChanged;
  final List<EtatDesLieuxModel> edls;
  final Set<EdlFilterModule> modules;

  const EdlFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.edls,
    this.modules = const {
      EdlFilterModule.recherche,
      EdlFilterModule.situation,
    },
  });

  @override
  State<EdlFilterBar> createState() => _EdlFilterBarState();
}

class _EdlFilterBarState extends State<EdlFilterBar> {
  final _searchCtrl = TextEditingController();
  static final _dateFmt = DateFormat('dd/MM/yy');

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.filter.query;
  }

  @override
  void didUpdateWidget(EdlFilterBar old) {
    super.didUpdateWidget(old);
    if (widget.filter.query != _searchCtrl.text) {
      _searchCtrl.text = widget.filter.query;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  EdlTableFilter get _f => widget.filter;

  int _countSituation(SituationEdl s) =>
      widget.edls.where((e) => e.situation == s).length;
  int _countBail(String b) => widget.edls.where((e) => e.typeBail == b).length;
  int _countTypeEdl(String t) =>
      widget.edls.where((e) => e.typeEdl == t).length;

  Future<void> _pickRange({
    required DateTimeRange? current,
    required ValueChanged<DateTimeRange?> onPicked,
  }) async {
    // Pop-up personnalisé (calendrier + raccourcis) avec arrière-plan flouté.
    final res = await showEdlDateRangePicker(context, initial: current);
    if (res == null || !mounted) return; // annulé
    onPicked(res.range); // range null = filtre réinitialisé
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final m in EdlFilterModule.values) {
      if (!widget.modules.contains(m)) continue;
      switch (m) {
        case EdlFilterModule.recherche:
          break; // champ texte rendu à part (au-dessus)
        case EdlFilterModule.situation:
          chips.addAll(_situationChips());
        case EdlFilterModule.bail:
          chips.addAll(_bailChips());
        case EdlFilterModule.typeEdl:
          chips.addAll(_typeEdlChips());
        case EdlFilterModule.dateCreation:
          chips.add(_dateChip(
            label: 'Créé',
            range: _f.createdRange,
            onPick: () => _pickRange(
              current: _f.createdRange,
              onPicked: (r) =>
                  widget.onChanged(_f.copyWith(createdRange: r)),
            ),
            onClear: () => widget.onChanged(_f.copyWith(createdRange: null)),
          ));
        case EdlFilterModule.dateFinalisation:
          chips.add(_dateChip(
            label: 'Finalisé',
            range: _f.finalisedRange,
            onPick: () => _pickRange(
              current: _f.finalisedRange,
              onPicked: (r) =>
                  widget.onChanged(_f.copyWith(finalisedRange: r)),
            ),
            onClear: () =>
                widget.onChanged(_f.copyWith(finalisedRange: null)),
          ));
      }
    }

    final chipsRow = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: chips,
    );

    if (!widget.modules.contains(EdlFilterModule.recherche)) {
      return chipsRow;
    }

    final searchField = TextField(
      controller: _searchCtrl,
      onChanged: (v) => widget.onChanged(_f.copyWith(query: v)),
      decoration: InputDecoration(
        hintText: 'Rechercher locataire, immeuble…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _f.query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  widget.onChanged(_f.copyWith(query: ''));
                },
              )
            : null,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: AppSpacing.md,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: AppSpacing.sm),
              chipsRow,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: AppSpacing.md),
            Flexible(child: chipsRow),
          ],
        );
      },
    );
  }

  // ── MODULES (chips) ─────────────────────────────────────────────────────────

  /// MODULE `situation` — Toutes / En cours / À venir / Finalisé + compteurs.
  List<Widget> _situationChips() => [
        _Chip(
          label: 'Toutes',
          count: widget.edls.length,
          selected: _f.situation == null,
          onTap: () => widget.onChanged(_f.copyWith(situation: null)),
        ),
        ...SituationEdl.values.map(
          (s) => _Chip(
            label: s.label,
            count: _countSituation(s),
            selected: _f.situation == s,
            onTap: () => widget.onChanged(
              _f.copyWith(situation: _f.situation == s ? null : s),
            ),
          ),
        ),
      ];

  /// MODULE `bail` — Collectif / Individuel (exclusif).
  List<Widget> _bailChips() => [
        for (final b in const ['collectif', 'individuel'])
          _Chip(
            label: b == 'collectif' ? 'Collectif' : 'Individuel',
            count: _countBail(b),
            selected: _f.typeBail == b,
            onTap: () => widget.onChanged(
              _f.copyWith(typeBail: _f.typeBail == b ? null : b),
            ),
          ),
      ];

  /// MODULE `typeEdl` — Entrée / Sortie (exclusif).
  List<Widget> _typeEdlChips() => [
        for (final t in const ['entree', 'sortie'])
          _Chip(
            label: t == 'entree' ? 'Entrée' : 'Sortie',
            count: _countTypeEdl(t),
            selected: _f.typeEdl == t,
            onTap: () => widget.onChanged(
              _f.copyWith(typeEdl: _f.typeEdl == t ? null : t),
            ),
          ),
      ];

  /// MODULES `dateCreation` / `dateFinalisation` — chip ouvrant un sélecteur de
  /// plage de dates ; affiche la plage choisie et permet de l'effacer.
  Widget _dateChip({
    required String label,
    required DateTimeRange? range,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final selected = range != null;
    final text = selected
        ? '$label : ${_dateFmt.format(range.start)}–${_dateFmt.format(range.end)}'
        : label;
    return _Chip(
      label: text,
      icon: Icons.calendar_today_outlined,
      selected: selected,
      onTap: onPick,
      onClear: selected ? onClear : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip compact (plus petit que l'ancien _SituationFilterChip pour en aligner plus).

class _Chip extends StatelessWidget {
  final String label;
  final int? count;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : AppColors.surfaceContainerLowest;
    final fg = selected ? AppColors.onPrimary : AppColors.onSurface;
    final badgeBg = selected
        ? AppColors.onPrimary.withValues(alpha: 0.18)
        : AppColors.surfaceContainerHigh;
    final borderColor = selected ? AppColors.primary : AppColors.outlineVariant;

    return InkWell(
      borderRadius: AppRadius.borderFull,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && icon == null) ...[
              Icon(Icons.check, size: 13, color: fg),
              const SizedBox(width: 3),
            ] else if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(
                  '$count',
                  style: AppTypography.labelSm.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
            if (onClear != null) ...[
              const SizedBox(width: 2),
              InkWell(
                onTap: onClear,
                borderRadius: AppRadius.borderFull,
                child: Icon(Icons.close, size: 13, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
