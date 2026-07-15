import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/factures.dart';
import 'package:lacoloc_front/data/datasources/recettes.dart';
import 'package:lacoloc_front/data/models/facture.dart';
import 'package:lacoloc_front/data/models/recette.dart';
import 'package:lacoloc_front/data/permissions/permissions_service.dart';
import 'package:lacoloc_front/presentation/finances/nouvelle_facture_page.dart';
import 'package:lacoloc_front/presentation/widgets/app_top_bar.dart';
import 'package:lacoloc_front/presentation/widgets/permission_gate.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/app_tab_bar.dart';

class FacturesListPage extends StatefulWidget {
  final VoidCallback onAjouter;
  final void Function(FactureModel, {required bool readOnly}) onOuvrir;
  final VoidCallback onAjouterRecette;

  final int initialTab;
  final bool showTabBar;

  const FacturesListPage({
    super.key,
    required this.onAjouter,
    required this.onOuvrir,
    required this.onAjouterRecette,
    this.initialTab = 0,
    this.showTabBar = true,
  });

  @override
  State<FacturesListPage> createState() => _FacturesListPageState();
}

class _FacturesListPageState extends State<FacturesListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Future<List<FactureModel>> _future;
  late Future<List<RecetteModel>> _futureRecettes;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
    _future = _load();
    _futureRecettes = _loadRecettes();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<FactureModel>> _load() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return [];
    return FacturesDatasource.listByOwner(ownerId);
  }

  Future<List<RecetteModel>> _loadRecettes() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return [];
    return RecettesDatasource.listByOwner(ownerId);
  }

  Future<void> _refreshRecettes() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return;
    final f = RecettesDatasource.listByOwner(ownerId, refresh: true);
    setState(() => _futureRecettes = f);
  }

  List<FactureModel> _filter(List<FactureModel> all) {
    if (_query.isEmpty) return all;
    return all.where((f) {
      return (f.immeubleName ?? '').toLowerCase().contains(_query) ||
          (f.codeFacture ?? '').toLowerCase().contains(_query) ||
          f.fournisseur.toLowerCase().contains(_query) ||
          f.typeFacture.toLowerCase().contains(_query) ||
          f.statut.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Barra de abas (masquée si pilotée par les sous-menus) ─────────
        if (widget.showTabBar) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: AppTabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(text: 'Vue générale'),
                Tab(text: 'Recettes'),
                Tab(text: 'Dépenses / Factures'),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        // ── Conteúdo das abas ───────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildVisionGeneraleTab(),
              _buildRecettesTab(),
              _buildFacturesTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Aba 1 : Vision générale ─────────────────────────────────────────────────

  Widget _buildVisionGeneraleTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTopBar(title: 'Vue générale'),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bar_chart_outlined,
                    size: 64,
                    color: AppColors.outline,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Statistiques et résumés financiers disponibles prochainement.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Aba 2 : Factures ────────────────────────────────────────────────────────

  Widget _buildFacturesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Dépenses / Factures',
          trailing: PermissionGate(
            permission: Perm.facturesCreate,
            child: FilledButton.icon(
              onPressed: widget.onAjouter,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter une facture'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText:
                      'Rechercher par immeuble, fournisseur, N° facture…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Effacer',
                          onPressed: _searchCtrl.clear,
                        )
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<FactureModel>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Erreur : ${snap.error}'));
                  }
                  final all = snap.data ?? [];
                  if (all.isEmpty) {
                    return _EmptyState(onAjouter: widget.onAjouter);
                  }
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun résultat pour "$_query".',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return _FacturesTable(
                    factures: filtered,
                    onVoir: (f) => widget.onOuvrir(f, readOnly: true),
                    onModifier: (f) => widget.onOuvrir(f, readOnly: false),
                  );
                },
              ),
            ),
          ],
        );
  }

  // ── Aba 2 : Recettes ────────────────────────────────────────────────────────

  Widget _buildRecettesTab() {
    return FutureBuilder<List<RecetteModel>>(
      future: _futureRecettes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erreur : ${snap.error}'));
        }
        final all = snap.data ?? [];
        return _RecettesTab(
          recettes: all,
          onAjouter: widget.onAjouterRecette,
          onRefresh: _refreshRecettes,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aba Recettes
// ─────────────────────────────────────────────────────────────────────────────

class _RecettesTab extends StatefulWidget {
  final List<RecetteModel> recettes;
  final VoidCallback onAjouter;
  final Future<void> Function() onRefresh;

  const _RecettesTab({
    required this.recettes,
    required this.onAjouter,
    required this.onRefresh,
  });

  @override
  State<_RecettesTab> createState() => _RecettesTabState();
}

class _RecettesTabState extends State<_RecettesTab> {
  // Filtre actif : null = tous
  String? _filtreStatut;
  bool _saving = false;

  static final _currFmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

  List<RecetteModel> get _filtered {
    if (_filtreStatut == null) return widget.recettes;
    return widget.recettes
        .where((r) => r.statut == _filtreStatut)
        .toList();
  }

  double _total(String statut) => widget.recettes
      .where((r) => r.statut == statut)
      .fold(0.0, (s, r) => s + r.montant);

  Future<void> _markPaid(RecetteModel r) async {
    setState(() => _saving = true);
    await RecettesDatasource.markPaid(r.id, DateTime.now());
    await widget.onRefresh();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _markUnpaid(RecetteModel r) async {
    setState(() => _saving = true);
    await RecettesDatasource.markUnpaid(r.id);
    await widget.onRefresh();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _markLate(RecetteModel r) async {
    setState(() => _saving = true);
    await RecettesDatasource.markLate(r.id);
    await widget.onRefresh();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final aRecevoir = _total('a_recevoir');
    final recu = _total('recu');
    final enRetard = _total('en_retard');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Recettes',
          trailing: PermissionGate(
            permission: Perm.facturesCreate,
            child: FilledButton.icon(
              onPressed: widget.onAjouter,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Résumé financier ──────────────────────────────────────
                Row(
                  children: [
                    _SummaryChip(
                      label: 'À recevoir',
                      amount: aRecevoir,
                      color: AppColors.primary,
                      selected: _filtreStatut == 'a_recevoir',
                      onTap: () => setState(() => _filtreStatut =
                          _filtreStatut == 'a_recevoir' ? null : 'a_recevoir'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _SummaryChip(
                      label: 'Reçu',
                      amount: recu,
                      color: AppColors.tertiary,
                      selected: _filtreStatut == 'recu',
                      onTap: () => setState(() => _filtreStatut =
                          _filtreStatut == 'recu' ? null : 'recu'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _SummaryChip(
                      label: 'En retard',
                      amount: enRetard,
                      color: AppColors.error,
                      selected: _filtreStatut == 'en_retard',
                      onTap: () => setState(() => _filtreStatut =
                          _filtreStatut == 'en_retard' ? null : 'en_retard'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Tableau ───────────────────────────────────────────────
                Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 56, color: AppColors.outline),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          widget.recettes.isEmpty
                              ? 'Aucune recette enregistrée.'
                              : 'Aucune recette pour ce filtre.',
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                        if (widget.recettes.isEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Les loyers sont générés automatiquement lors de la finalisation d\'un bail.',
                            style: AppTypography.labelSm
                                .copyWith(color: AppColors.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (ctx, constraints) {
                      final narrow = constraints.maxWidth < 750;
                      return SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minWidth: constraints.maxWidth),
                            child: DataTable(
                              columnSpacing: AppSpacing.lg,
                              headingRowColor: WidgetStateProperty.all(
                                  AppColors.surfaceContainerLow),
                              columns: [
                                const DataColumn(label: Text('Mois')),
                                if (!narrow)
                                  const DataColumn(label: Text('Bien')),
                                if (!narrow)
                                  const DataColumn(label: Text('Locataire')),
                                DataColumn(
                                    label: const Text('Loyer (€)'),
                                    numeric: true),
                                const DataColumn(label: Text('Statut')),
                                const DataColumn(label: Text('Payé le')),
                                const DataColumn(label: Text('Actions')),
                              ],
                              rows: filtered.map((r) {
                                return DataRow(cells: [
                                  DataCell(Text(r.moisLabel,
                                      style: AppTypography.bodyMd)),
                                  if (!narrow)
                                    DataCell(Text(r.lieuLabel,
                                        style: AppTypography.bodyMd,
                                        overflow: TextOverflow.ellipsis)),
                                  if (!narrow)
                                    DataCell(Text(
                                        r.locataireNom ?? '—',
                                        style: AppTypography.bodyMd,
                                        overflow: TextOverflow.ellipsis)),
                                  DataCell(Text(
                                      _currFmt.format(r.montant),
                                      style: AppTypography.bodyMd)),
                                  DataCell(_RecetteStatutBadge(
                                      statut: r.statut)),
                                  DataCell(Text(r.paiementLabel ?? '—',
                                      style: AppTypography.bodyMd)),
                                  DataCell(_saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : _ActionMenu(
                                          recette: r,
                                          onMarkPaid: () => _markPaid(r),
                                          onMarkUnpaid: () => _markUnpaid(r),
                                          onMarkLate: () => _markLate(r),
                                        )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  static final _fmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surfaceContainerLowest,
          border: Border.all(
            color: selected ? color : AppColors.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: AppRadius.borderMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style:
                    AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
            Text(_fmt.format(amount),
                style: AppTypography.titleLs
                    .copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RecetteStatutBadge extends StatelessWidget {
  final String statut;
  const _RecetteStatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (statut) {
      'recu' => ('Reçu', AppColors.tertiaryFixed, AppColors.onTertiaryFixedVariant),
      'en_retard' => ('En retard', AppColors.errorContainer, AppColors.onErrorContainer),
      _ => ('À recevoir', AppColors.secondaryFixed, AppColors.onSecondaryFixedVariant),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(label, style: AppTypography.labelSm.copyWith(color: fg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  final RecetteModel recette;
  final VoidCallback onMarkPaid;
  final VoidCallback onMarkUnpaid;
  final VoidCallback onMarkLate;

  const _ActionMenu({
    required this.recette,
    required this.onMarkPaid,
    required this.onMarkUnpaid,
    required this.onMarkLate,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: 'Actions',
      onSelected: (v) {
        if (v == 'paid') onMarkPaid();
        if (v == 'unpaid') onMarkUnpaid();
        if (v == 'late') onMarkLate();
      },
      itemBuilder: (_) => [
        if (recette.statut != 'recu')
          const PopupMenuItem(
            value: 'paid',
            child: Row(children: [
              Icon(Icons.check_circle_outline, size: 18),
              SizedBox(width: 8),
              Text('Marquer reçu'),
            ]),
          ),
        if (recette.statut == 'recu')
          const PopupMenuItem(
            value: 'unpaid',
            child: Row(children: [
              Icon(Icons.undo, size: 18),
              SizedBox(width: 8),
              Text('Annuler paiement'),
            ]),
          ),
        if (recette.statut != 'en_retard' && recette.statut != 'recu')
          const PopupMenuItem(
            value: 'late',
            child: Row(children: [
              Icon(Icons.warning_amber_outlined, size: 18),
              SizedBox(width: 8),
              Text('Marquer en retard'),
            ]),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum _SortField {
  immeuble,
  codeFacture,
  fournisseur,
  type,
  ht,
  ttc,
  statut,
}

class _FacturesTable extends StatefulWidget {
  final List<FactureModel> factures;
  final ValueChanged<FactureModel> onVoir;
  final ValueChanged<FactureModel> onModifier;

  const _FacturesTable({
    required this.factures,
    required this.onVoir,
    required this.onModifier,
  });

  @override
  State<_FacturesTable> createState() => _FacturesTableState();
}

class _FacturesTableState extends State<_FacturesTable> {
  _SortField? _sortField;
  bool _sortAscending = true;

  List<FactureModel> get _sorted {
    if (_sortField == null) return widget.factures;
    final list = [...widget.factures];
    list.sort((a, b) {
      final cmp = switch (_sortField!) {
        _SortField.immeuble =>
          (a.immeubleName ?? '').compareTo(b.immeubleName ?? ''),
        _SortField.codeFacture =>
          (a.codeFacture ?? '').compareTo(b.codeFacture ?? ''),
        _SortField.fournisseur => a.fournisseur.compareTo(b.fournisseur),
        _SortField.type => a.typeFacture.compareTo(b.typeFacture),
        _SortField.ht => (a.montantHt ?? 0).compareTo(b.montantHt ?? 0),
        _SortField.ttc => (a.montantTtc ?? 0).compareTo(b.montantTtc ?? 0),
        _SortField.statut => a.statut.compareTo(b.statut),
      };
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  void _onSort(_SortField field, bool ascending) {
    setState(() {
      _sortField = field;
      _sortAscending = ascending;
    });
  }

  int? _sortColIndex(bool narrow) {
    if (_sortField == null) return null;
    final fields = [
      _SortField.immeuble,
      _SortField.codeFacture,
      _SortField.fournisseur,
      if (!narrow) _SortField.type,
      _SortField.ht,
      _SortField.ttc,
      if (!narrow) _SortField.statut,
    ];
    final i = fields.indexOf(_sortField!);
    return i == -1 ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 700;
        final sorted = _sorted;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                sortColumnIndex: _sortColIndex(narrow),
                sortAscending: _sortAscending,
                columnSpacing: AppSpacing.lg,
                headingRowColor: WidgetStateProperty.all(
                  AppColors.surfaceContainerLow,
                ),
                columns: [
                  DataColumn(
                    label: const Text('Immeuble'),
                    onSort: (_, asc) => _onSort(_SortField.immeuble, asc),
                  ),
                  DataColumn(
                    label: const Text('N° Facture'),
                    onSort: (_, asc) => _onSort(_SortField.codeFacture, asc),
                  ),
                  DataColumn(
                    label: const Text('Fournisseur'),
                    onSort: (_, asc) => _onSort(_SortField.fournisseur, asc),
                  ),
                  if (!narrow)
                    DataColumn(
                      label: const Text('Type'),
                      onSort: (_, asc) => _onSort(_SortField.type, asc),
                    ),
                  DataColumn(
                    label: const Text('HT (€)'),
                    numeric: true,
                    onSort: (_, asc) => _onSort(_SortField.ht, asc),
                  ),
                  DataColumn(
                    label: const Text('TTC (€)'),
                    numeric: true,
                    onSort: (_, asc) => _onSort(_SortField.ttc, asc),
                  ),
                  if (!narrow)
                    DataColumn(
                      label: const Text('Statut'),
                      onSort: (_, asc) => _onSort(_SortField.statut, asc),
                    ),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: sorted.map((f) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          f.immeubleName ?? '—',
                          style: AppTypography.bodyMd,
                        ),
                      ),
                      DataCell(
                        Text(
                          f.codeFacture ?? '—',
                          style: AppTypography.bodyMd,
                        ),
                      ),
                      DataCell(
                        Text(f.fournisseur, style: AppTypography.bodyMd),
                      ),
                      if (!narrow)
                        DataCell(
                          Text(f.typeFacture, style: AppTypography.bodyMd),
                        ),
                      DataCell(
                        Text(
                          f.montantHt != null
                              ? f.montantHt!.toStringAsFixed(2)
                              : '—',
                          style: AppTypography.bodyMd,
                        ),
                      ),
                      DataCell(
                        Text(
                          f.montantTtc != null
                              ? f.montantTtc!.toStringAsFixed(2)
                              : '—',
                          style: AppTypography.bodyMd,
                        ),
                      ),
                      if (!narrow) DataCell(_StatutBadge(statut: f.statut)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Voir',
                              child: IconButton(
                                icon: const Icon(Icons.search, size: 20),
                                color: AppColors.primary,
                                onPressed: () => widget.onVoir(f),
                              ),
                            ),
                            PermissionGate(
                              permission: Perm.facturesEdit,
                              child: Tooltip(
                                message: 'Modifier',
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  color: AppColors.onSurfaceVariant,
                                  onPressed: () => widget.onModifier(f),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatutBadge extends StatelessWidget {
  final String statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (statut) {
      'Payée' => (AppColors.tertiaryFixed, AppColors.onTertiaryFixedVariant),
      'En litige' => (AppColors.errorContainer, AppColors.onErrorContainer),
      _ => (AppColors.secondaryFixed, AppColors.onSecondaryFixedVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(statut, style: AppTypography.labelSm.copyWith(color: fg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAjouter;
  const _EmptyState({required this.onAjouter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Aucune facture enregistrée', style: AppTypography.titleLg),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ajoutez votre première facture pour commencer.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onAjouter,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une facture'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Overlay em tela cheia para ver ou editar uma factura a partir da lista.
/// Chamado pelo ProprietaireProfilPage quando o usuário clica nos ícones.
class FactureDetailOverlay extends StatelessWidget {
  final FactureModel facture;
  final bool readOnly;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  const FactureDetailOverlay({
    super.key,
    required this.facture,
    required this.readOnly,
    required this.onClose,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    // Le header (titre + Enregistrer/Fermer) est rendu par NouvelleFacturePage.
    return NouvelleFacturePage(
      facture: facture,
      readOnly: readOnly,
      onSaved: onSaved,
      onClose: onClose,
    );
  }
}
