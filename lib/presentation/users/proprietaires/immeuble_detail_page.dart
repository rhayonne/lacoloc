import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/factures.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/pieces.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/facture.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:lacoloc_front/data/models/piece.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/creer_piece_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/inventaire_page.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/currency.dart';

class ImmeubleDetailPage extends StatefulWidget {
  final ImmeublesModel immeuble;
  final List<ChambreModel> chambres;
  final VoidCallback onModifierImmeuble;
  final ValueChanged<ChambreModel> onModifierChambre;
  final VoidCallback onAjouterFacture;
  final VoidCallback? onBack;

  const ImmeubleDetailPage({
    super.key,
    required this.immeuble,
    required this.chambres,
    required this.onModifierImmeuble,
    required this.onModifierChambre,
    required this.onAjouterFacture,
    this.onBack,
  });

  @override
  State<ImmeubleDetailPage> createState() => _ImmeubleDetailPageState();
}

class _ImmeubleDetailPageState extends State<ImmeubleDetailPage> {
  late Future<List<FactureModel>> _facturesFuture;
  late Future<List<PieceModel>> _piecesFuture;
  late Future<List<InventaireModel>> _inventaireFuture;

  @override
  void initState() {
    super.initState();
    _facturesFuture = FacturesDatasource.listByImmeuble(widget.immeuble.id);
    _piecesFuture = PiecesDatasource.listByImmeuble(widget.immeuble.id);
    _inventaireFuture = InventaireDatasource.listByImmeuble(widget.immeuble.id);
  }

  @override
  void didUpdateWidget(ImmeubleDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.immeuble.id != widget.immeuble.id) {
      _facturesFuture = FacturesDatasource.listByImmeuble(widget.immeuble.id);
      _piecesFuture = PiecesDatasource.listByImmeuble(widget.immeuble.id);
      _inventaireFuture =
          InventaireDatasource.listByImmeuble(widget.immeuble.id);
    }
  }

  void _reloadPieces() {
    setState(() {
      _piecesFuture = PiecesDatasource.listByImmeuble(widget.immeuble.id);
    });
  }

  void _reloadInventaire() {
    setState(() {
      _inventaireFuture =
          InventaireDatasource.listByImmeuble(widget.immeuble.id);
    });
  }

  Future<void> _ouvrirInventaire() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text('Inventaire — ${widget.immeuble.name}'),
          ),
          body: InventairePage(prefilledImmeubleId: widget.immeuble.id),
        ),
      ),
    );
    _reloadInventaire();
  }

  Future<void> _navigerVersFormPiece({PieceModel? existing}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreerPiecePage(
          immeubleId: widget.immeuble.id,
          existing: existing,
        ),
      ),
    );
    if (result == true) _reloadPieces();
  }

  Future<void> _supprimerPiece(PieceModel piece) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la pièce'),
        content: Text(
          'La pièce « ${piece.nom} » et tous les articles d\'inventaire qui '
          'y sont rattachés seront supprimés. Cette action est irréversible.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await InventaireDatasource.deleteByPiece(piece.id);
      await PiecesDatasource.delete(piece.id);
      if (!mounted) return;
      _reloadPieces();
      _reloadInventaire();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLoue = widget.chambres.where((c) => c.estLoue).length;
    final totalLibre = widget.chambres.length - totalLoue;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ────────────────────────────────────────────────────────
          Row(
            children: [
              if (widget.onBack != null) ...[
                IconButton.outlined(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                  tooltip: 'Retour',
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.immeuble.name, style: AppTypography.headlineMd),
                    if (widget.immeuble.address != null)
                      Text(
                        widget.immeuble.address!,
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onModifierImmeuble,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Modifier'),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Résumé rapide ──────────────────────────────────────────────────
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatChip(
                label:
                    '${widget.chambres.length} chambre${widget.chambres.length != 1 ? 's' : ''}',
                icon: Icons.bed_outlined,
                color: AppColors.primary,
              ),
              _StatChip(
                label: '$totalLoue louée${totalLoue != 1 ? 's' : ''}',
                icon: Icons.lock_outlined,
                color: AppColors.tertiary,
              ),
              _StatChip(
                label: '$totalLibre libre${totalLibre != 1 ? 's' : ''}',
                icon: Icons.lock_open_outlined,
                color: AppColors.secondary,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Tableau des chambres ───────────────────────────────────────────
          Text('Chambres', style: AppTypography.titleLg),
          const SizedBox(height: AppSpacing.sm),

          if (widget.chambres.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'Aucune chambre pour cet immeuble.',
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            )
          else
            _ChambresTable(
              chambres: widget.chambres,
              onModifier: widget.onModifierChambre,
            ),

          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.md),

          // ── Pièces ─────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text('Pièces', style: AppTypography.titleLg),
              ),
              FilledButton.icon(
                onPressed: () => _navigerVersFormPiece(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter pièce'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          FutureBuilder<List<PieceModel>>(
            future: _piecesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Erreur : ${snapshot.error}',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.error),
                );
              }
              final pieces = snapshot.data ?? [];
              if (pieces.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'Aucune pièce enregistrée pour cet immeuble.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return _PiecesTable(
                pieces: pieces,
                onModifier: (p) => _navigerVersFormPiece(existing: p),
                onSupprimer: _supprimerPiece,
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.md),

          // ── Factures ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text('Factures', style: AppTypography.titleLg),
              ),
              FilledButton.icon(
                onPressed: widget.onAjouterFacture,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter facture'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          FutureBuilder<List<FactureModel>>(
            future: _facturesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text('Erreur : ${snapshot.error}',
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.error));
              }
              final factures = snapshot.data ?? [];
              if (factures.isEmpty) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'Aucune facture pour cet immeuble.',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                );
              }
              return _FacturesTable(factures: factures);
            },
          ),

          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.md),

          // ── Inventaire ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text('Inventaire', style: AppTypography.titleLg),
              ),
              FilledButton.icon(
                onPressed: _ouvrirInventaire,
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('Gérer l\'inventaire'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          FutureBuilder<List<InventaireModel>>(
            future: _inventaireFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Erreur : ${snapshot.error}',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.error),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'Aucun article dans l\'inventaire.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return _InventaireDetailTable(items: items);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.labelMd.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PiecesTable extends StatelessWidget {
  final List<PieceModel> pieces;
  final ValueChanged<PieceModel> onModifier;
  final ValueChanged<PieceModel> onSupprimer;

  const _PiecesTable({
    required this.pieces,
    required this.onModifier,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Table(
        border: TableBorder.all(
          color: AppColors.outlineVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
          3: IntrinsicColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration:
                const BoxDecoration(color: AppColors.surfaceContainerLow),
            children: [
              _HeaderCell('Pièce'),
              _HeaderCell('Superficie'),
              _HeaderCell('Photos (annonce)'),
              _HeaderCell(''),
            ],
          ),
          ...pieces.map(_buildRow),
        ],
      ),
    );
  }

  TableRow _buildRow(PieceModel p) {
    final superficie = p.m2 != null
        ? '${p.m2!.toStringAsFixed(0)} m²'
        : '—';
    final totalPhotos = p.photos.length;
    final annonce = p.photosAnnonce;
    final photosLabel = totalPhotos == 0
        ? '—'
        : '$totalPhotos photo${totalPhotos > 1 ? 's' : ''}'
          '${annonce > 0 ? ' ($annonce ★)' : ''}';

    return TableRow(
      decoration:
          const BoxDecoration(color: AppColors.surfaceContainerLowest),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nom, style: AppTypography.labelMd),
              if (p.description != null && p.description!.isNotEmpty)
                Text(
                  p.description!,
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(superficie, style: AppTypography.bodyMd),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(photosLabel, style: AppTypography.bodyMd),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Modifier',
                onPressed: () => onModifier(p),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Supprimer',
                color: AppColors.error,
                onPressed: () => onSupprimer(p),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChambresTable extends StatelessWidget {
  final List<ChambreModel> chambres;
  final ValueChanged<ChambreModel> onModifier;

  const _ChambresTable({required this.chambres, required this.onModifier});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Table(
        border: TableBorder.all(
          color: AppColors.outlineVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
          3: IntrinsicColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration:
                const BoxDecoration(color: AppColors.surfaceContainerLow),
            children: [
              _HeaderCell('Chambre'),
              _HeaderCell('Loyer / mois'),
              _HeaderCell('Statut'),
              _HeaderCell(''),
            ],
          ),
          ...chambres.map((c) => _buildChambreRow(c)),
        ],
      ),
    );
  }

  TableRow _buildChambreRow(ChambreModel c) {
    final loyer =
        c.prixLoyer != null ? formatFrenchCurrency(c.prixLoyer!.round()) : '—';

    return TableRow(
      decoration:
          const BoxDecoration(color: AppColors.surfaceContainerLowest),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.roomName, style: AppTypography.labelMd),
              if (c.m2 != null)
                Text(
                  '${c.m2!.toStringAsFixed(0)} m²',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(loyer, style: AppTypography.bodyMd),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _StatutBadge(estLoue: c.estLoue),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Modifier',
            onPressed: () => onModifier(c),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FacturesTable extends StatelessWidget {
  final List<FactureModel> factures;

  const _FacturesTable({required this.factures});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Table(
        border: TableBorder.all(
          color: AppColors.outlineVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(2),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration:
                const BoxDecoration(color: AppColors.surfaceContainerLow),
            children: [
              _HeaderCell('Type'),
              _HeaderCell('Fournisseur'),
              _HeaderCell('Montant TTC'),
              _HeaderCell('Statut'),
            ],
          ),
          ...factures.map(_buildFactureRow),
        ],
      ),
    );
  }

  TableRow _buildFactureRow(FactureModel f) {
    final montant = f.montantTtc != null
        ? formatFrenchCurrency(f.montantTtc!.round())
        : '—';
    final date = f.dateEcheance != null
        ? DateFormat('dd/MM/yyyy').format(f.dateEcheance!)
        : null;

    return TableRow(
      decoration:
          const BoxDecoration(color: AppColors.surfaceContainerLowest),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.typeFacture, style: AppTypography.labelMd),
              if (date != null)
                Text(
                  'Éch. $date',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(f.fournisseur, style: AppTypography.bodyMd),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(montant, style: AppTypography.bodyMd),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _FactureStatutBadge(statut: f.statut),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        text,
        style:
            AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatutBadge extends StatelessWidget {
  final bool estLoue;
  const _StatutBadge({required this.estLoue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: estLoue
            ? AppColors.tertiary.withValues(alpha: 0.15)
            : AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estLoue ? 'Louée' : 'Libre',
        style: AppTypography.labelSm.copyWith(
          color: estLoue ? AppColors.tertiary : AppColors.secondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FactureStatutBadge extends StatelessWidget {
  final String statut;
  const _FactureStatutBadge({required this.statut});

  Color get _color => switch (statut) {
        'Payée' => AppColors.tertiary,
        'En litige' => AppColors.error,
        _ => AppColors.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statut,
        style: AppTypography.labelSm.copyWith(color: _color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _InventaireDetailTable extends StatefulWidget {
  final List<InventaireModel> items;

  const _InventaireDetailTable({required this.items});

  @override
  State<_InventaireDetailTable> createState() => _InventaireDetailTableState();
}

class _InventaireDetailTableState extends State<_InventaireDetailTable> {
  String _query = '';
  String? _filterLieu; // displayLieu sélectionné (null = tous)

  List<InventaireModel> get _filtered => widget.items.where((it) {
    if (_filterLieu != null && it.displayLieu != _filterLieu) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return it.displayNom.toLowerCase().contains(q) ||
        (it.meubleCategorie?.toLowerCase().contains(q) ?? false) ||
        it.displayLieu.toLowerCase().contains(q);
  }).toList();

  /// Lieux distincts (ordre d'apparition) avec leur compteur.
  Map<String, int> get _lieuxCounts {
    final map = <String, int>{};
    for (final it in widget.items) {
      map[it.displayLieu] = (map[it.displayLieu] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final lieux = _lieuxCounts;

    final searchField = TextField(
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Rechercher article, lieu…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _query = ''),
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

    final chips = <Widget>[
      _InventaireFilterChip(
        label: 'Tous',
        count: widget.items.length,
        selected: _filterLieu == null,
        onTap: () => setState(() => _filterLieu = null),
      ),
      ...lieux.entries.map(
        (e) => _InventaireFilterChip(
          label: e.key,
          count: e.value,
          selected: _filterLieu == e.key,
          onTap: () => setState(
            () => _filterLieu = _filterLieu == e.key ? null : e.key,
          ),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final chipsRow = Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: chips,
            );
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: searchField),
                const SizedBox(width: AppSpacing.md),
                Flexible(child: chipsRow),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'Aucun article ne correspond au filtre.',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ligne de titre — fixe
                  const _InvHeaderRow(),
                  const Divider(height: 1),
                  // Corps défilant (hauteur bornée pour garder l'en-tête fixe)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => _InvDataRow(item: filtered[i]),
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

// Largeurs partagées (en-tête fixe + lignes) du tableau d'inventaire.
const int _kFlexArticle = 3;
const int _kFlexCategorie = 2;
const int _kFlexLieu = 2;
const int _kFlexQte = 1;
const int _kFlexValeur = 2;

class _InvHeaderRow extends StatelessWidget {
  const _InvHeaderRow();

  @override
  Widget build(BuildContext context) {
    Widget cell(String t, int flex) => Expanded(
          flex: flex,
          child: Text(
            t,
            style: AppTypography.labelMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        );
    return Container(
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          cell('Article', _kFlexArticle),
          cell('Catégorie', _kFlexCategorie),
          cell('Lieu', _kFlexLieu),
          cell('Qté', _kFlexQte),
          cell('Valeur', _kFlexValeur),
        ],
      ),
    );
  }
}

class _InvDataRow extends StatelessWidget {
  final InventaireModel item;
  const _InvDataRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            flex: _kFlexArticle,
            child: Text(item.displayNom, style: AppTypography.labelMd),
          ),
          Expanded(
            flex: _kFlexCategorie,
            child:
                Text(item.meubleCategorie ?? '—', style: AppTypography.bodyMd),
          ),
          Expanded(
            flex: _kFlexLieu,
            child: Text(item.displayLieu, style: AppTypography.bodyMd),
          ),
          Expanded(
            flex: _kFlexQte,
            child: Text('${item.quantite}', style: AppTypography.bodyMd),
          ),
          Expanded(
            flex: _kFlexValeur,
            child: Text(
              item.valeur != null
                  ? formatFrenchCurrency(item.valeur!.round())
                  : '—',
              style: AppTypography.bodyMd,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip de filtre avec compteur (modèle Vision générale)

class _InventaireFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _InventaireFilterChip({
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
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.labelSm
                  .copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(20),
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
