import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/pieces.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:lacoloc_front/data/models/piece.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/currency.dart';

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
          widget.prefilledImmeubleId!);
    } else if (widget.prefilledChambreId != null) {
      items = await InventaireDatasource.listByChambre(
          widget.prefilledChambreId!);
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
            // En-tête
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.md, 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Inventaire', style: AppTypography.titleLg),
                  ),
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      _editing = null;
                      _showForm = true;
                    }),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter'),
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
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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

class _InventaireTable extends StatelessWidget {
  final List<InventaireModel> items;
  final ValueChanged<InventaireModel> onEdit;
  final ValueChanged<InventaireModel> onDelete;

  const _InventaireTable({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  static const _hStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 12,
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              color: AppColors.surfaceContainerLow,
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Article', style: _hStyle)),
                  Expanded(flex: 2, child: Text('Lieu', style: _hStyle)),
                  Expanded(flex: 1, child: Text('Qté', style: _hStyle)),
                  Expanded(flex: 2, child: Text('Valeur', style: _hStyle)),
                  SizedBox(width: 80),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _InventaireRow(
                  item: items[i],
                  onEdit: () => onEdit(items[i]),
                  onDelete: () => onDelete(items[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventaireRow extends StatelessWidget {
  final InventaireModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InventaireRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final valeur = item.valeur != null
        ? formatFrenchCurrency(item.valeur!.round())
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayNom, style: AppTypography.labelMd),
                if (item.meubleCategorie != null)
                  Text(
                    item.meubleCategorie!,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
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
          Expanded(
            flex: 2,
            child: Text(valeur, style: AppTypography.bodyMd),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Modifier',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Supprimer',
                  color: AppColors.error,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
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
  MeubleReferenceModel? _meubleRef;

  final _valeurCtrl = TextEditingController();
  final _qtCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();

  List<ChambreModel> _chambresForImmeuble = [];
  List<PieceModel> _piecesForImmeuble = [];

  bool _isSaving = false;

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
    );

    // Pre-fill immeuble/chambre after loading
    if (mounted) {
      final preImmId = widget.existing?.immeubleId ?? widget.prefilledImmeubleId;
      if (preImmId != null) {
        final imm = immeubles.where((i) => i.id == preImmId).firstOrNull;
        if (imm != null) {
          setState(() {
            _immeuble = imm;
            _chambresForImmeuble =
                chambres.where((c) => c.immeubleId == imm.id).toList();
            _piecesForImmeuble =
                pieces.where((p) => p.immeubleId == imm.id).toList();
          });
        }
      }
      final preChId = widget.existing?.chambreId ?? widget.prefilledChambreId;
      if (preChId != null) {
        final ch = chambres.where((c) => c.id == preChId).firstOrNull;
        if (ch != null) setState(() => _chambre = ch);
      }
      if (widget.existing?.pieceId != null) {
        final p = pieces.where((p) => p.id == widget.existing!.pieceId).firstOrNull;
        if (p != null) setState(() => _piece = p);
      }
      if (widget.existing?.meubleRefId != null) {
        final ref = refs.where((r) => r.id == widget.existing!.meubleRefId).firstOrNull;
        if (ref != null) setState(() => _meubleRef = ref);
      }
    }

    return bundle;
  }

  void _initFromExisting() {
    final e = widget.existing;
    if (e == null) return;
    _valeurCtrl.text = e.valeur?.toStringAsFixed(2) ?? '';
    _qtCtrl.text = '${e.quantite}';
    _descCtrl.text = e.description ?? '';
  }

  Future<void> _save() async {
    if (_immeuble == null) {
      _snack('Sélectionnez un immeuble.');
      return;
    }
    if (_meubleRef == null) {
      _snack('Sélectionnez un type de meuble.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final model = InventaireModel(
        id: widget.existing?.id ?? 0,
        immeubleId: _immeuble!.id,
        chambreId: _chambre?.id,
        pieceId: _piece?.id,
        meubleRefId: _meubleRef?.id,
        valeur: double.tryParse(
            _valeurCtrl.text.trim().replaceAll(',', '.')),
        quantite: int.tryParse(_qtCtrl.text.trim()) ?? 1,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        photos: [],
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      if (widget.isEditing) {
        await InventaireDatasource.update(model.id, model);
      } else {
        await InventaireDatasource.create(model);
      }

      if (mounted) widget.onClose(true);
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  String _meubleDisplayText(MeubleReferenceModel r) => r.nom;

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          text,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
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
        final bundle = snapshot.data ??
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
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
              ),
              child: Row(
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => widget.onClose(false),
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
                        // ── Type de meuble ────────────────────────────
                        _label('TYPE DE MEUBLE'),
                        Autocomplete<MeubleReferenceModel>(
                          initialValue: _meubleRef != null
                              ? TextEditingValue(
                                  text: _meubleDisplayText(_meubleRef!))
                              : TextEditingValue.empty,
                          displayStringForOption: _meubleDisplayText,
                          optionsBuilder: (tev) {
                            final q = tev.text.toLowerCase();
                            if (q.isEmpty) return bundle.refs;
                            return bundle.refs.where((r) =>
                                r.nom.toLowerCase().contains(q) ||
                                (r.categorie?.toLowerCase().contains(q) ??
                                    false));
                          },
                          onSelected: (r) => setState(() => _meubleRef = r),
                          fieldViewBuilder: (ctx, ctrl, focus, submit) {
                            return TextField(
                              controller: ctrl,
                              focusNode: focus,
                              decoration: InputDecoration(
                                hintText: 'Rechercher un type de meuble…',
                                suffixIcon: _meubleRef != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        tooltip: 'Effacer',
                                        onPressed: () {
                                          ctrl.clear();
                                          setState(() => _meubleRef = null);
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (v) {
                                if (_meubleRef != null &&
                                    v != _meubleDisplayText(_meubleRef!)) {
                                  setState(() => _meubleRef = null);
                                }
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
                              .map((i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                      i.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: widget.prefilledImmeubleId != null
                              ? null
                              : (v) {
                                  setState(() {
                                    _immeuble = v;
                                    _chambre = null;
                                    _piece = null;
                                    _chambresForImmeuble = v != null
                                        ? bundle.allChambres
                                            .where((c) => c.immeubleId == v.id)
                                            .toList()
                                        : [];
                                    _piecesForImmeuble = v != null
                                        ? bundle.allPieces
                                            .where((p) => p.immeubleId == v.id)
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
                                            'chambre_${_immeuble?.id}_${_chambre?.id}'),
                                        initialValue: _chambre,
                                        isExpanded: true,
                                        hint: const Text('—'),
                                        items: [
                                          const DropdownMenuItem(
                                              value: null,
                                              child: Text('—')),
                                          ..._chambresForImmeuble.map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c.roomName,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ),
                                          ),
                                        ],
                                        onChanged: (_piece != null ||
                                                widget.prefilledChambreId !=
                                                    null)
                                            ? null
                                            : (v) => setState(
                                                () => _chambre = v),
                                        decoration:
                                            const InputDecoration(),
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
                                            'piece_${_immeuble?.id}_${_piece?.id}'),
                                        initialValue: _piece,
                                        isExpanded: true,
                                        hint: const Text('—'),
                                        items: [
                                          const DropdownMenuItem(
                                              value: null,
                                              child: Text('—')),
                                          ..._piecesForImmeuble.map(
                                            (p) => DropdownMenuItem(
                                              value: p,
                                              child: Text(p.nom,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ),
                                          ),
                                        ],
                                        onChanged:
                                            _chambre != null ? null : (v) =>
                                                setState(() => _piece = v),
                                        decoration:
                                            const InputDecoration(),
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
                                  'chambre_${_immeuble?.id}_${_chambre?.id}'),
                              initialValue: _chambre,
                              isExpanded: true,
                              hint: const Text('—'),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('—')),
                                ..._chambresForImmeuble.map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.roomName,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                              onChanged: widget.prefilledChambreId != null
                                  ? null
                                  : (v) => setState(() => _chambre = v),
                              decoration: const InputDecoration(),
                            ),
                          ] else ...[
                            _label('PIÈCE'),
                            DropdownButtonFormField<PieceModel>(
                              key: ValueKey(
                                  'piece_${_immeuble?.id}_${_piece?.id}'),
                              initialValue: _piece,
                              isExpanded: true,
                              hint: const Text('—'),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('—')),
                                ..._piecesForImmeuble.map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.nom,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() => _piece = v),
                              decoration: const InputDecoration(),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // ── Valeur ────────────────────────────────────
                        _label('VALEUR (€)'),
                        TextField(
                          controller: _valeurCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*[,.]?\d{0,2}')),
                          ],
                          decoration: const InputDecoration(
                            prefixText: '€ ',
                            hintText: '0.00',
                          ),
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
                          decoration: const InputDecoration(hintText: '1'),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Description ───────────────────────────────
                        _label('DESCRIPTION (optionnel)'),
                        TextField(
                          controller: _descCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'État, marque, remarques…',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _isSaving ? null : _save,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                : Text(widget.isEditing
                                    ? 'Enregistrer les modifications'
                                    : 'Ajouter à l\'inventaire'),
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

  const _FormBundle({
    required this.immeubles,
    required this.allChambres,
    required this.allPieces,
    required this.refs,
  });
}
