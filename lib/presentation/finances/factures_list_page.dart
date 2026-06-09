import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/factures.dart';
import 'package:lacoloc_front/data/models/facture.dart';
import 'package:lacoloc_front/presentation/finances/nouvelle_facture_page.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class FacturesListPage extends StatefulWidget {
  final VoidCallback onAjouter;
  final void Function(FactureModel, {required bool readOnly}) onOuvrir;
  final VoidCallback onAjouterRecette;

  const FacturesListPage({
    super.key,
    required this.onAjouter,
    required this.onOuvrir,
    required this.onAjouterRecette,
  });

  @override
  State<FacturesListPage> createState() => _FacturesListPageState();
}

class _FacturesListPageState extends State<FacturesListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Future<List<FactureModel>> _future;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _future = _load();
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
        // ── Barra de abas ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Vision générale'),
              Tab(text: 'Factures'),
              Tab(text: 'Recettes'),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Conteúdo das abas ───────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildVisionGeneraleTab(),
              _buildFacturesTab(),
              _buildRecettesTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Aba 1 : Vision générale ─────────────────────────────────────────────────

  Widget _buildVisionGeneraleTab() {
    return Center(
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
            Text('Vision générale', style: AppTypography.titleLg),
            const SizedBox(height: AppSpacing.sm),
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
    );
  }

  // ── Aba 2 : Factures ────────────────────────────────────────────────────────

  Widget _buildFacturesTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowTint.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Text('Factures', style: AppTypography.titleLg),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: widget.onAjouter,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter une facture'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
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
        ),
      ),
    );
  }

  // ── Aba 3 : Recettes ────────────────────────────────────────────────────────

  Widget _buildRecettesTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowTint.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Text('Recettes', style: AppTypography.titleLg),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: widget.onAjouterRecette,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter une recette'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                            Tooltip(
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
