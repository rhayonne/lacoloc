import 'package:flutter/material.dart';
import 'package:habitafrance/presentation/widgets/app_date_picker.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/datasources/chambres.dart';
import 'package:habitafrance/data/datasources/immeubles.dart';
import 'package:habitafrance/data/datasources/inventaire.dart';
import 'package:habitafrance/data/datasources/meuble_categories.dart';
import 'package:habitafrance/data/datasources/pieces.dart';
import 'package:habitafrance/data/models/chambre.dart';
import 'package:habitafrance/data/models/immeubles.dart';
import 'package:habitafrance/data/models/inventaire.dart';
import 'package:habitafrance/data/models/piece.dart';
import 'package:habitafrance/data/permissions/permissions_service.dart';
import 'package:habitafrance/presentation/widgets/app_list_search_field.dart';
import 'package:habitafrance/presentation/widgets/field_help_icon.dart';
import 'package:habitafrance/presentation/widgets/filter_button.dart';
import 'package:habitafrance/presentation/widgets/permission_gate.dart';
import 'package:habitafrance/presentation/widgets/photo_picker_field.dart';
import 'package:habitafrance/presentation/widgets/unsaved_changes_dialog.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/theme/app_breakpoints.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_table_theme.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/utils/currency.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Liste principale

class InventairePage extends StatefulWidget {
  /// Pré-filtre sur un immeuble (ex: depuis le détail d'immeuble).
  final int? prefilledImmeubleId;

  /// Pré-filtre sur une chambre.
  final int? prefilledChambreId;

  /// Ouvre directement le formulaire d'ajout.
  final bool initialShowForm;

  const InventairePage({
    super.key,
    this.prefilledImmeubleId,
    this.prefilledChambreId,
    this.initialShowForm = false,
  });

  @override
  State<InventairePage> createState() => _InventairePageState();
}

class _InventairePageState extends State<InventairePage> {
  late Future<_PageData> _future;
  bool _showForm = false;
  InventaireModel? _editing;

  @override
  void initState() {
    super.initState();
    _showForm = widget.initialShowForm;
    _future = _load();
  }

  Future<_PageData> _load() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return const _PageData(immeubles: [], items: []);

    final immeubles = await ImmeublesDatasource.listByOwner(ownerId);
    final ids = immeubles.map((i) => i.id).toList();

    List<InventaireModel> items = [];
    if (widget.prefilledImmeubleId != null) {
      items = await InventaireDatasource.listByImmeuble(
        widget.prefilledImmeubleId!,
      );
    } else if (widget.prefilledChambreId != null) {
      items = await InventaireDatasource.listByChambre(
        widget.prefilledChambreId!,
      );
    } else {
      for (final id in ids) {
        items.addAll(await InventaireDatasource.listByImmeuble(id));
      }
    }

    return _PageData(immeubles: immeubles, items: items);
  }

  void _reload() {
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showForm) {
      return _InventaireForm(
        existing: _editing,
        prefilledImmeubleId: widget.prefilledImmeubleId,
        prefilledChambreId: widget.prefilledChambreId,
        onClose: (refresh) {
          setState(() {
            _showForm = false;
            _editing = null;
          });
          if (refresh) _reload();
        },
      );
    }

    return FutureBuilder<_PageData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final data = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTopBar(
              title: 'Inventaire',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PermissionGate(
                    permission: Perm.inventaireCreate,
                    child: FilledButton.icon(
                      onPressed: () => setState(() {
                        _editing = null;
                        _showForm = true;
                      }),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.outlined(
                    icon: const Icon(Icons.refresh),
                    onPressed: _reload,
                    tooltip: 'Actualiser',
                  ),
                ],
              ),
            ),
            Expanded(
              child: data.items.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun article dans l\'inventaire.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : _InventaireTable(
                      items: data.items,
                      immeubleNoms: {
                        for (final i in data.immeubles) i.id: i.name,
                      },
                      lockedImmeubleId: widget.prefilledImmeubleId,
                      onEdit: (item) => setState(() {
                        _editing = item;
                        _showForm = true;
                      }),
                      onDelete: (item) => _confirmDelete(item),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(InventaireModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cet article ?'),
        content: Text('« ${item.displayNom} » sera supprimé définitivement.'),
        actions: [
          TextButton(
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
    if (ok != true || !mounted) return;
    await InventaireDatasource.delete(item.id);
    _reload();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tableau

class _InventaireTable extends StatefulWidget {
  final List<InventaireModel> items;
  final Map<int, String> immeubleNoms;
  final int? lockedImmeubleId; // immeuble fixé (depuis le détail d'immeuble)
  final ValueChanged<InventaireModel> onEdit;
  final ValueChanged<InventaireModel> onDelete;

  const _InventaireTable({
    required this.items,
    required this.immeubleNoms,
    this.lockedImmeubleId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_InventaireTable> createState() => _InventaireTableState();
}

class _InventaireTableState extends State<_InventaireTable> {
  static TextStyle get _hStyle => AppTableTheme.headerTextStyle;

  String _query = '';
  int? _filterImmeuble;
  String? _filterCategorie;

  /// Panneau de filtres ouvert (inline, sous le bouton « Filtres »).
  /// On reste dans le flux normal (pas d'OverlayPortal) → fiable à toute
  /// résolution et sans crash de reparentage au redimensionnement.
  bool _filterOpen = false;

  @override
  void initState() {
    super.initState();
    _filterImmeuble = widget.lockedImmeubleId;
  }

  String _immeubleNom(int id) => widget.immeubleNoms[id] ?? '—';

  int get _activeFilterCount =>
      (widget.lockedImmeubleId == null && _filterImmeuble != null ? 1 : 0) +
      (_filterCategorie != null ? 1 : 0);

  List<InventaireModel> get _filtered => widget.items.where((it) {
    if (_filterImmeuble != null && it.immeubleId != _filterImmeuble) {
      return false;
    }
    if (_filterCategorie != null && it.meubleCategorie != _filterCategorie) {
      return false;
    }
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return it.displayNom.toLowerCase().contains(q) ||
        (it.meubleCategorie?.toLowerCase().contains(q) ?? false) ||
        it.displayLieu.toLowerCase().contains(q) ||
        _immeubleNom(it.immeubleId).toLowerCase().contains(q);
  }).toList();

  /// Immeubles présents dans la liste avec leur compteur.
  Map<int, int> get _immeubleCounts {
    final map = <int, int>{};
    for (final it in widget.items) {
      map[it.immeubleId] = (map[it.immeubleId] ?? 0) + 1;
    }
    return map;
  }

  /// Catégories présentes dans la liste avec leur compteur (triées).
  Map<String, int> get _categorieCounts {
    final map = <String, int>{};
    for (final it in widget.items) {
      final cat = it.meubleCategorie;
      if (cat == null || cat.isEmpty) continue;
      map[cat] = (map[cat] ?? 0) + 1;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  /// Corps inline du panneau de filtres (immeuble + catégorie), affiché sous le
  /// bouton « Filtres » dans le flux normal — fiable à toute résolution.
  Widget _buildFilterBody() {
    final locked = widget.lockedImmeubleId != null;
    final immeubleCounts = _immeubleCounts;
    final categorieCounts = _categorieCounts;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!locked) ...[
            Text('Immeuble', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _InvFilterChip(
                  label: 'Tous',
                  count: widget.items.length,
                  selected: _filterImmeuble == null,
                  onTap: () {
                    setState(() => _filterImmeuble = null);
                  },
                ),
                ...immeubleCounts.entries.map(
                  (e) => _InvFilterChip(
                    label: _immeubleNom(e.key),
                    count: e.value,
                    selected: _filterImmeuble == e.key,
                    onTap: () => setState(
                      () => _filterImmeuble = _filterImmeuble == e.key
                          ? null
                          : e.key,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text('Catégorie', style: AppTypography.labelMd),
          const SizedBox(height: AppSpacing.sm),
          if (categorieCounts.isEmpty)
            Text(
              'Aucune catégorie.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: categorieCounts.entries
                  .map(
                    (e) => _InvFilterChip(
                      label: e.key,
                      count: e.value,
                      selected: _filterCategorie == e.key,
                      onTap: () => setState(
                        () => _filterCategorie = _filterCategorie == e.key
                            ? null
                            : e.key,
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // Boutons standardisés (taille compacte) via AppButton.
              AppButton.delete(
                size: AppButtonSize.compact,
                icon: Icons.clear_all,
                label: 'Réinitialiser',
                onPressed: () {
                  setState(() {
                    if (!locked) _filterImmeuble = null;
                    _filterCategorie = null;
                  });
                },
              ),
              AppButton.save(
                size: AppButtonSize.compact,
                label: 'Appliquer',
                onPressed: () => setState(() => _filterOpen = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    final searchField = AppListSearchField(
      hint: 'Rechercher un article, un lieu, un immeuble…',
      padding: EdgeInsets.zero,
      iconSize: 20,
      onChanged: (v) => setState(() => _query = v),
    );

    // Bouton « Filtres » (standard) — bascule le panneau inline.
    final filterButton = FilterButton(
      isOpen: _filterOpen,
      activeCount: _activeFilterCount,
      onTap: () => setState(() => _filterOpen = !_filterOpen),
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Filtres (recherche + bouton Filtres) ──────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < AppBreakpoints.compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: AppSpacing.sm),
                    Align(alignment: Alignment.centerLeft, child: filterButton),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: AppSpacing.md),
                  filterButton,
                ],
              );
            },
          ),
          // Panneau de filtres inline (ouvre/ferme avec le bouton).
          if (_filterOpen) _buildFilterBody(),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppRadius.borderLg,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              // Sous ce seuil (partagé par toutes les tables de l'app) on
              // bascule en cartes verticales (lisible sur mobile) au lieu de
              // comprimer toutes les colonnes du tableau.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow =
                      constraints.maxWidth < AppBreakpoints.tableToCards;
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun article ne correspond au filtre.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  if (narrow) {
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) => _InventaireCard(
                        item: filtered[i],
                        immeubleNom: _immeubleNom(filtered[i].immeubleId),
                        onEdit: () => widget.onEdit(filtered[i]),
                        onDelete: () => widget.onDelete(filtered[i]),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Ligne de titre — fixe
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        color: AppTableTheme.headerBackgroundColor,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Article', style: _hStyle),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Catégorie', style: _hStyle),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Immeuble', style: _hStyle),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Lieu', style: _hStyle),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('Qté', style: _hStyle),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Valeur', style: _hStyle),
                            ),
                            SizedBox(width: 80),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) => _InventaireRow(
                            item: filtered[i],
                            immeubleNom: _immeubleNom(filtered[i].immeubleId),
                            onEdit: () => widget.onEdit(filtered[i]),
                            onDelete: () => widget.onDelete(filtered[i]),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventaireRow extends StatelessWidget {
  final InventaireModel item;
  final String immeubleNom;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InventaireRow({
    required this.item,
    required this.immeubleNom,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final valeur = item.valeur != null ? formatEuros(item.valeur!) : '—';

    return HoverTableRow(
      child: Padding(
        padding: AppTableTheme.rowPadding,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.displayNom,
                          style: AppTypography.labelMd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.photos.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Tooltip(
                          message: '${item.photos.length} photo(s)',
                          child: Icon(
                            Icons.photo_outlined,
                            size: 14,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (item.dansAnnonce) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Tooltip(
                          message: "Affiché dans l'annonce",
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.meubleCategorie ?? '—',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                immeubleNom,
                style: AppTypography.bodyMd,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(item.displayLieu, style: AppTypography.bodyMd),
            ),
            Expanded(
              flex: 1,
              child: Text('${item.quantite}', style: AppTypography.bodyMd),
            ),
            Expanded(flex: 2, child: Text(valeur, style: AppTypography.bodyMd)),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PermissionGate(
                    permission: Perm.inventaireEdit,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Modifier',
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                  PermissionGate(
                    permission: Perm.inventaireDelete,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Supprimer',
                      color: AppColors.error,
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte verticale d'un article (affichée sous ~760px à la place du tableau).
class _InventaireCard extends StatelessWidget {
  final InventaireModel item;
  final String immeubleNom;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InventaireCard({
    required this.item,
    required this.immeubleNom,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final valeur = item.valeur != null ? formatEuros(item.valeur!) : '—';

    Widget infoLine(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$label : ',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMd,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : nom + actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.displayNom,
                        style: AppTypography.labelMd,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.photos.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.photo_outlined,
                        size: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                    if (item.dansAnnonce) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.storefront_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
              PermissionGate(
                permission: Perm.inventaireEdit,
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Modifier',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
              ),
              PermissionGate(
                permission: Perm.inventaireDelete,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Supprimer',
                  color: AppColors.error,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
          infoLine(
            Icons.category_outlined,
            'Catégorie',
            item.meubleCategorie ?? '—',
          ),
          infoLine(Icons.apartment_outlined, 'Immeuble', immeubleNom),
          infoLine(Icons.place_outlined, 'Lieu', item.displayLieu),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: [
                _CardStat(label: 'Qté', value: '${item.quantite}'),
                const SizedBox(width: AppSpacing.lg),
                _CardStat(label: 'Valeur', value: valeur),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Petit bloc « libellé / valeur » utilisé dans la carte d'inventaire.
class _CardStat extends StatelessWidget {
  final String label;
  final String value;
  const _CardStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(value, style: AppTypography.labelMd),
      ],
    );
  }
}

// Chip de filtre avec compteur (modèle Vision générale).
class _InvFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _InvFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 13, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: AppRadius.borderFull,
              ),
              child: Text(
                '$count',
                style: AppTypography.labelSm.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulaire

class _InventaireForm extends StatefulWidget {
  final InventaireModel? existing;
  final int? prefilledImmeubleId;
  final int? prefilledChambreId;
  final void Function(bool refresh) onClose;

  const _InventaireForm({
    this.existing,
    this.prefilledImmeubleId,
    this.prefilledChambreId,
    required this.onClose,
  });

  bool get isEditing => existing != null;

  @override
  State<_InventaireForm> createState() => _InventaireFormState();
}

class _InventaireFormState extends State<_InventaireForm> {
  late Future<_FormBundle> _bundleFuture;

  ImmeublesModel? _immeuble;
  ChambreModel? _chambre;
  PieceModel? _piece;

  /// Référence catalogue choisie (si le nom saisi correspond à une entrée de
  /// `Meubles_Reference`) ; null si l'utilisateur a saisi un nom libre.
  MeubleReferenceModel? _meubleRef;

  /// Texte du nom de l'article (saisie libre ou nom choisi dans la liste).
  String _nomText = '';

  final _valeurCtrl = TextEditingController();
  final _qtCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();

  // ── Vétusté ──
  final _valeurAchatCtrl = TextEditingController();
  DateTime? _dateAcquisition;
  String? _categorieVetuste;

  List<String> _photos = [];

  /// Afficher cet article dans l'annonce de la chambre. Décoché par défaut.
  bool _dansAnnonce = false;

  List<ChambreModel> _chambresForImmeuble = [];
  List<PieceModel> _piecesForImmeuble = [];

  bool _isSaving = false;
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) _dirty = true;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
    _initFromExisting();
  }

  @override
  void dispose() {
    _valeurCtrl.dispose();
    _qtCtrl.dispose();
    _descCtrl.dispose();
    _valeurAchatCtrl.dispose();
    super.dispose();
  }

  Future<_FormBundle> _loadBundle() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) {
      return const _FormBundle(
        immeubles: [],
        allChambres: [],
        allPieces: [],
        refs: [],
      );
    }
    final refs = await InventaireDatasource.listMeubleReferences();
    final categories = (await MeubleCategoriesDatasource.listAll())
        .map((c) => c.nom)
        .toList();
    final immeubles = await ImmeublesDatasource.listByOwner(ownerId);
    final ids = immeubles.map((i) => i.id).toList();
    final chambres = ids.isEmpty
        ? <ChambreModel>[]
        : await ChambresDatasource.listByImmeubles(ids);

    List<PieceModel> pieces = [];
    for (final id in ids) {
      pieces.addAll(await PiecesDatasource.listByImmeuble(id));
    }

    final bundle = _FormBundle(
      immeubles: immeubles,
      allChambres: chambres,
      allPieces: pieces,
      refs: refs,
      categories: categories,
    );

    // Pre-fill immeuble/chambre after loading
    if (mounted) {
      final preImmId =
          widget.existing?.immeubleId ?? widget.prefilledImmeubleId;
      if (preImmId != null) {
        final imm = immeubles.where((i) => i.id == preImmId).firstOrNull;
        if (imm != null) {
          setState(() {
            _immeuble = imm;
            _chambresForImmeuble = chambres
                .where((c) => c.immeubleId == imm.id)
                .toList();
            _piecesForImmeuble = pieces
                .where((p) => p.immeubleId == imm.id)
                .toList();
          });
        }
      }
      final preChId = widget.existing?.chambreId ?? widget.prefilledChambreId;
      if (preChId != null) {
        final ch = chambres.where((c) => c.id == preChId).firstOrNull;
        if (ch != null) setState(() => _chambre = ch);
      }
      if (widget.existing?.pieceId != null) {
        final p = pieces
            .where((p) => p.id == widget.existing!.pieceId)
            .firstOrNull;
        if (p != null) setState(() => _piece = p);
      }
      if (widget.existing?.meubleRefId != null) {
        final ref = refs
            .where((r) => r.id == widget.existing!.meubleRefId)
            .firstOrNull;
        if (ref != null) setState(() => _meubleRef = ref);
      }
    }

    return bundle;
  }

  void _initFromExisting() {
    final e = widget.existing;
    if (e == null) return;
    _nomText = e.displayNom == '—' ? '' : e.displayNom;
    _valeurCtrl.text = e.valeur != null ? formatEuros(e.valeur!) : '';
    _qtCtrl.text = '${e.quantite}';
    _descCtrl.text = e.description ?? '';
    _photos = List.from(e.photos);
    _valeurAchatCtrl.text = e.valeurAchat != null
        ? formatEuros(e.valeurAchat!)
        : '';
    _dateAcquisition = e.dateAcquisition;
    _categorieVetuste = e.categorieVetuste;
    _dansAnnonce = e.dansAnnonce;
  }

  /// Vérifie qu'un article du même nom n'existe pas déjà au même emplacement
  /// (immeuble + chambre/pièce). Retourne true si l'enregistrement peut
  /// continuer (pas de doublon, ou l'utilisateur confirme malgré tout).
  Future<bool> _checkDuplicate(String nom) async {
    try {
      final existing = await InventaireDatasource.listByImmeuble(_immeuble!.id);
      final n = nom.toLowerCase().trim();
      final dup = existing.where(
        (it) =>
            it.id != (widget.existing?.id ?? -1) &&
            it.chambreId == _chambre?.id &&
            it.pieceId == _piece?.id &&
            it.displayNom.toLowerCase().trim() == n,
      );
      if (dup.isEmpty) return true;
      if (!mounted) return false;
      final lieu = _chambre?.roomName ?? _piece?.nom ?? 'parties communes';
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.copy_all_outlined,
            color: AppColors.secondary,
            size: 32,
          ),
          title: const Text('Article déjà présent'),
          content: Text(
            "« $nom » existe déjà dans « $lieu » de cet immeuble.\n\n"
            "Voulez-vous quand même l'ajouter une seconde fois ?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ajouter quand même'),
            ),
          ],
        ),
      );
      return ok == true;
    } catch (_) {
      return true; // en cas d'erreur de lecture, ne pas bloquer
    }
  }

  Future<void> _save() async {
    if (_immeuble == null) {
      _snack('Sélectionnez un immeuble.');
      return;
    }
    final nom = _nomText.trim();
    if (nom.isEmpty) {
      _snack("Saisissez le nom de l'article.");
      return;
    }

    // Vérification de doublon (nom + emplacement).
    if (!await _checkDuplicate(nom)) return;
    if (!mounted) return;

    setState(() => _isSaving = true);
    try {
      final model = InventaireModel(
        id: widget.existing?.id ?? 0,
        immeubleId: _immeuble!.id,
        chambreId: _chambre?.id,
        pieceId: _piece?.id,
        // Nom choisi dans le catalogue → meubleRefId ; sinon nom libre.
        meubleRefId: _meubleRef?.id,
        nomCustom: _meubleRef == null ? nom : null,
        valeur: parseEuros(_valeurCtrl.text),
        quantite: int.tryParse(_qtCtrl.text.trim()) ?? 1,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        photos: _photos,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        dansAnnonce: _dansAnnonce,
        dateAcquisition: _dateAcquisition,
        valeurAchat: parseEuros(_valeurAchatCtrl.text),
        categorieVetusteCustom: _categorieVetuste,
      );

      if (widget.isEditing) {
        await InventaireDatasource.update(model.id, model);
      } else {
        await InventaireDatasource.create(model);
      }

      if (mounted) {
        _dirty = false;
        widget.onClose(true);
      }
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Fermeture avec garde « modifications non enregistrées ».
  Future<void> _handleClose() async {
    if (!_dirty) {
      widget.onClose(false);
      return;
    }
    final choice = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (choice) {
      case UnsavedChoice.cancel:
        return;
      case UnsavedChoice.discard:
        widget.onClose(false);
      case UnsavedChoice.save:
        await _save();
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _meubleDisplayText(MeubleReferenceModel r) => r.nom;

  Widget _label(String text, {String? help}) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Flexible(
          child: Text(
            text,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (help != null) ...[
          const SizedBox(width: AppSpacing.xs),
          fieldHelpIcon(help),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FormBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // Erreur ≠ « aucun immeuble » : sans ce garde, le formulaire s'ouvre
        // avec des listes vides et paraît cassé.
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur de chargement : ${snapshot.error}'),
          );
        }
        final bundle =
            snapshot.data ??
            const _FormBundle(
              immeubles: [],
              allChambres: [],
              allPieces: [],
              refs: [],
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _handleClose,
                    tooltip: 'Retour',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.isEditing
                          ? 'Modifier l\'article'
                          : 'Ajouter un article',
                      style: AppTypography.titleLg,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Nom de l'article ──────────────────────────
                        _label("NOM DE L'ARTICLE"),
                        Autocomplete<MeubleReferenceModel>(
                          initialValue: TextEditingValue(text: _nomText),
                          displayStringForOption: _meubleDisplayText,
                          optionsBuilder: (tev) {
                            final q = tev.text.toLowerCase().trim();
                            if (q.isEmpty) return bundle.refs.take(30);
                            return bundle.refs.where(
                              (r) =>
                                  r.nom.toLowerCase().contains(q) ||
                                  (r.categorie?.toLowerCase().contains(q) ??
                                      false),
                            );
                          },
                          onSelected: (r) => setState(() {
                            _meubleRef = r;
                            _nomText = r.nom;
                            // Hérite de la catégorie du meuble pour la vétusté.
                            if (r.categorie != null) {
                              _categorieVetuste = r.categorie;
                            }
                            _markDirty();
                          }),
                          fieldViewBuilder: (ctx, ctrl, focus, submit) {
                            return TextField(
                              controller: ctrl,
                              focusNode: focus,
                              decoration: InputDecoration(
                                hintText: 'Saisir ou choisir un nom…',
                                helperText:
                                    "Choisissez un nom existant ou saisissez-en un nouveau.",
                                suffixIcon: ctrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        tooltip: 'Effacer',
                                        onPressed: () {
                                          ctrl.clear();
                                          setState(() {
                                            _meubleRef = null;
                                            _nomText = '';
                                            _markDirty();
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (v) {
                                // Le texte saisi devient le nom ; s'il correspond
                                // exactement à une référence du catalogue, on la lie
                                // (meubleRefId), sinon c'est un nom libre (nomCustom).
                                final match = bundle.refs
                                    .where(
                                      (r) =>
                                          r.nom.toLowerCase() ==
                                          v.toLowerCase().trim(),
                                    )
                                    .firstOrNull;
                                setState(() {
                                  _nomText = v;
                                  _meubleRef = match;
                                  _markDirty();
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Immeuble ──────────────────────────────────
                        _label('IMMEUBLE'),
                        DropdownButtonFormField<ImmeublesModel>(
                          key: ValueKey('immeuble_${_immeuble?.id}'),
                          initialValue: _immeuble,
                          isExpanded: true,
                          hint: const Text('Sélectionner un immeuble…'),
                          items: bundle.immeubles
                              .map(
                                (i) => DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    i.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: widget.prefilledImmeubleId != null
                              ? null
                              : (v) {
                                  setState(() {
                                    _markDirty();
                                    _immeuble = v;
                                    _chambre = null;
                                    _piece = null;
                                    _chambresForImmeuble = v != null
                                        ? bundle.allChambres
                                              .where(
                                                (c) => c.immeubleId == v.id,
                                              )
                                              .toList()
                                        : [];
                                    _piecesForImmeuble = v != null
                                        ? bundle.allPieces
                                              .where(
                                                (p) => p.immeubleId == v.id,
                                              )
                                              .toList()
                                        : [];
                                  });
                                },
                          decoration: const InputDecoration(),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Chambre + Pièce ───────────────────────────
                        if (_immeuble != null &&
                            (_chambresForImmeuble.isNotEmpty ||
                                _piecesForImmeuble.isNotEmpty)) ...[
                          if (_chambresForImmeuble.isNotEmpty &&
                              _piecesForImmeuble.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _label('CHAMBRE'),
                                      DropdownButtonFormField<ChambreModel>(
                                        key: ValueKey(
                                          'chambre_${_immeuble?.id}_${_chambre?.id}',
                                        ),
                                        initialValue: _chambre,
                                        isExpanded: true,
                                        hint: const Text('—'),
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child: Text('—'),
                                          ),
                                          ..._chambresForImmeuble.map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c.roomName,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged:
                                            (_piece != null ||
                                                widget.prefilledChambreId !=
                                                    null)
                                            ? null
                                            : (v) => setState(() {
                                                _markDirty();
                                                _chambre = v;
                                              }),
                                        decoration: const InputDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _label('PIÈCE'),
                                      DropdownButtonFormField<PieceModel>(
                                        key: ValueKey(
                                          'piece_${_immeuble?.id}_${_piece?.id}',
                                        ),
                                        initialValue: _piece,
                                        isExpanded: true,
                                        hint: const Text('—'),
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child: Text('—'),
                                          ),
                                          ..._piecesForImmeuble.map(
                                            (p) => DropdownMenuItem(
                                              value: p,
                                              child: Text(
                                                p.nom,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: _chambre != null
                                            ? null
                                            : (v) => setState(() {
                                                _markDirty();
                                                _piece = v;
                                              }),
                                        decoration: const InputDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else if (_chambresForImmeuble.isNotEmpty) ...[
                            _label('CHAMBRE'),
                            DropdownButtonFormField<ChambreModel>(
                              key: ValueKey(
                                'chambre_${_immeuble?.id}_${_chambre?.id}',
                              ),
                              initialValue: _chambre,
                              isExpanded: true,
                              hint: const Text('—'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('—'),
                                ),
                                ..._chambresForImmeuble.map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c.roomName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: widget.prefilledChambreId != null
                                  ? null
                                  : (v) => setState(() {
                                      _markDirty();
                                      _chambre = v;
                                    }),
                              decoration: const InputDecoration(),
                            ),
                          ] else ...[
                            _label('PIÈCE'),
                            DropdownButtonFormField<PieceModel>(
                              key: ValueKey(
                                'piece_${_immeuble?.id}_${_piece?.id}',
                              ),
                              initialValue: _piece,
                              isExpanded: true,
                              hint: const Text('—'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('—'),
                                ),
                                ..._piecesForImmeuble.map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(
                                      p.nom,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _markDirty();
                                _piece = v;
                              }),
                              decoration: const InputDecoration(),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // ── Valeur ────────────────────────────────────
                        _label(
                          'VALEUR (€)',
                          help:
                              "Valeur actuelle (de remplacement) du bien, affichée dans l'inventaire.",
                        ),
                        TextField(
                          controller: _valeurCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [CurrencyInputFormatter()],
                          onChanged: (_) => setState(_markDirty),
                          decoration: const InputDecoration(
                            prefixText: '€ ',
                            hintText: '0,00',
                          ),
                        ),
                        // Aperçu formaté (lisible) sous le champ.
                        Builder(
                          builder: (_) {
                            final v = parseEuros(_valeurCtrl.text);
                            if (v == null || v <= 0) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: Text(
                                '= ${formatEuros(v)}',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Quantité ──────────────────────────────────
                        _label('QUANTITÉ'),
                        TextField(
                          controller: _qtCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => _markDirty(),
                          decoration: const InputDecoration(hintText: '1'),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Description ───────────────────────────────
                        _label('DESCRIPTION (optionnel)'),
                        TextField(
                          controller: _descCtrl,
                          maxLines: 3,
                          onChanged: (_) => _markDirty(),
                          decoration: const InputDecoration(
                            hintText: 'État, marque, remarques…',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Afficher dans l'annonce ───────────────────
                        CheckboxListTile(
                          value: _dansAnnonce,
                          onChanged: (v) => setState(() {
                            _dansAnnonce = v ?? false;
                            _markDirty();
                          }),
                          title: const Text("Afficher dans l'annonce"),
                          subtitle: const Text(
                            "Cet article apparaîtra sur la carte publique de la chambre.",
                          ),
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Vétusté (pour le décompte de réparations) ──
                        _label(
                          'VALEUR D\'ACHAT (€) — vétusté',
                          help:
                              "Prix d'achat d'origine. Avec la date d'acquisition, sert au calcul de la vétusté (abattement) à la sortie. Différent de la « Valeur » (valeur actuelle).",
                        ),
                        TextField(
                          controller: _valeurAchatCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [CurrencyInputFormatter()],
                          onChanged: (_) => setState(_markDirty),
                          decoration: const InputDecoration(
                            prefixText: '€ ',
                            hintText: '0,00',
                            helperText:
                                "Prix d'achat — sert au calcul de la valeur résiduelle.",
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        _label('DATE D\'ACQUISITION'),
                        InkWell(
                          onTap: () async {
                            final d = await showAppDatePicker(
                              context,
                              initial: _dateAcquisition ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) {
                              setState(() {
                                _dateAcquisition = d;
                                _markDirty();
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.event_outlined),
                              suffixIcon: _dateAcquisition != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      tooltip: 'Effacer',
                                      onPressed: () => setState(() {
                                        _dateAcquisition = null;
                                        _markDirty();
                                      }),
                                    )
                                  : null,
                            ),
                            child: Text(
                              _dateAcquisition != null
                                  ? _fmtDate(_dateAcquisition!)
                                  : 'Sélectionner une date…',
                              style: _dateAcquisition != null
                                  ? AppTypography.bodyMd
                                  : AppTypography.bodyMd.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        _label('CATÉGORIE DE VÉTUSTÉ'),
                        DropdownButtonFormField<String>(
                          key: ValueKey('catvet_$_categorieVetuste'),
                          initialValue:
                              bundle.categories.contains(_categorieVetuste)
                              ? _categorieVetuste
                              : null,
                          isExpanded: true,
                          hint: const Text('Choisir une catégorie…'),
                          decoration: const InputDecoration(
                            helperText:
                                'Détermine le barème de vétusté appliqué.',
                          ),
                          items: bundle.categories
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _categorieVetuste = v;
                            _markDirty();
                          }),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Photos ────────────────────────────────────
                        _label('PHOTOS (optionnel)'),
                        PhotoPickerField(
                          folder: 'inventaire',
                          initialPhotos: _photos,
                          onChanged: (urls) => setState(() {
                            _photos = urls;
                            _markDirty();
                          }),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isSaving ? null : _save,
                            child: _isSaving
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                : Text(
                                    widget.isEditing
                                        ? 'Enregistrer les modifications'
                                        : 'Ajouter à l\'inventaire',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PageData {
  final List<ImmeublesModel> immeubles;
  final List<InventaireModel> items;

  const _PageData({required this.immeubles, required this.items});
}

class _FormBundle {
  final List<ImmeublesModel> immeubles;
  final List<ChambreModel> allChambres;
  final List<PieceModel> allPieces;
  final List<MeubleReferenceModel> refs;
  final List<String> categories;

  const _FormBundle({
    required this.immeubles,
    required this.allChambres,
    required this.allPieces,
    required this.refs,
    this.categories = const [],
  });
}
