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

  const _PiecesTable({required this.pieces, required this.onModifier});

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
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Modifier',
            onPressed: () => onModifier(p),
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

class _InventaireDetailTable extends StatelessWidget {
  final List<InventaireModel> items;

  const _InventaireDetailTable({required this.items});

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
          4: FlexColumnWidth(2),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration:
                const BoxDecoration(color: AppColors.surfaceContainerLow),
            children: [
              _HeaderCell('Article'),
              _HeaderCell('Catégorie'),
              _HeaderCell('Lieu'),
              _HeaderCell('Qté'),
              _HeaderCell('Valeur'),
            ],
          ),
          ...items.map(_buildRow),
        ],
      ),
    );
  }

  TableRow _buildRow(InventaireModel item) {
    return TableRow(
      decoration:
          const BoxDecoration(color: AppColors.surfaceContainerLowest),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(item.displayNom, style: AppTypography.labelMd),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child:
              Text(item.meubleCategorie ?? '—', style: AppTypography.bodyMd),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(item.displayLieu, style: AppTypography.bodyMd),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('${item.quantite}', style: AppTypography.bodyMd),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            item.valeur != null
                ? formatFrenchCurrency(item.valeur!.round())
                : '—',
            style: AppTypography.bodyMd,
          ),
        ),
      ],
    );
  }
}
