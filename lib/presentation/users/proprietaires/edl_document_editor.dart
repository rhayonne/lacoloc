import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/edl_details.dart';
import 'package:lacoloc_front/data/models/edl_details.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║ Sections réutilisables du document EDL, intégrées comme étapes (steps)    ║
// ║ du formulaire « Nouvel état des lieux ».                                  ║
// ║  • EdlPreneursSection   — preneurs / colocataires                          ║
// ║  • EdlRelevesSection     — compteurs, chauffage, eau chaude (collectif)    ║
// ║  • EdlClesSection        — remise des clés (privatif)                      ║
// ║  • EdlCompositionSection — pièces + lignes d'équipement (état N/B/U/M)     ║
// ║ Chaque section charge ses données et persiste via EdlDetailsDatasource.   ║
// ╚══════════════════════════════════════════════════════════════════════════╝

const _dateFmt = _Fmt();

class _Fmt {
  const _Fmt();
  String format(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
}

Widget _dlgField(TextEditingController c, String label,
        {TextInputType? keyboard, int maxLines = 1}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );

Widget _etatDropdown(String? value, ValueChanged<String?> onChanged) =>
    DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration:
          const InputDecoration(labelText: "État d'usure", isDense: true),
      items: [
        const DropdownMenuItem(value: null, child: Text('—')),
        ...kEtatsUsure.map(
          (e) => DropdownMenuItem(value: e, child: Text('$e — ${etatUsureLabel(e)}')),
        ),
      ],
      onChanged: onChanged,
    );

Widget _emptyHint(String t) => Padding(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  child: Text(
    t,
    style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
  ),
);

// ════════════════════════════════════════════════════════════════════════════
// PRENEURS
// ════════════════════════════════════════════════════════════════════════════

class EdlPreneursSection extends StatefulWidget {
  final int edlId;
  const EdlPreneursSection({super.key, required this.edlId});

  @override
  State<EdlPreneursSection> createState() => _EdlPreneursSectionState();
}

class _EdlPreneursSectionState extends State<EdlPreneursSection> {
  List<EdlPreneur> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await EdlDetailsDatasource.listPreneurs(widget.edlId);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _edit(EdlPreneur? p) async {
    final nom = TextEditingController(text: p?.nom ?? '');
    final adr = TextEditingController(text: p?.adresse ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p == null ? 'Nouveau preneur' : 'Modifier le preneur'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dlgField(nom, 'Nom complet'),
            _dlgField(adr, 'Adresse (demeurant)'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true) return;
    final model = EdlPreneur(
      id: p?.id,
      etatDesLieuxId: widget.edlId,
      locataireId: p?.locataireId,
      nom: nom.text.trim().isEmpty ? null : nom.text.trim(),
      adresse: adr.text.trim().isEmpty ? null : adr.text.trim(),
      ordre: p?.ordre ?? _items.length,
    );
    if (p?.id == null) {
      await EdlDetailsDatasource.createPreneur(model);
    } else {
      await EdlDetailsDatasource.updatePreneur(p!.id!, model);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_items.isEmpty) _emptyHint('Aucun preneur. Ajoutez les colocataires.'),
        ..._items.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.nom ?? '—'),
              subtitle: p.adresse != null ? Text(p.adresse!) : null,
              trailing: _editDelete(() => _edit(p), () async {
                if (p.id != null) {
                  await EdlDetailsDatasource.deletePreneur(p.id!);
                  await _load();
                }
              }),
            )),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter un preneur'),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RELEVÉS (compteurs / chauffage / eau chaude)
// ════════════════════════════════════════════════════════════════════════════

class EdlRelevesSection extends StatefulWidget {
  final int edlId;
  const EdlRelevesSection({super.key, required this.edlId});

  @override
  State<EdlRelevesSection> createState() => _EdlRelevesSectionState();
}

class _EdlRelevesSectionState extends State<EdlRelevesSection> {
  List<EdlReleve> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await EdlDetailsDatasource.listReleves(widget.edlId);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _edit(EdlReleve? r) async {
    var cat = r?.categorie ?? ReleveCategorie.eauGaz;
    final type = TextEditingController(text: r?.type ?? '');
    final serie = TextEditingController(text: r?.numeroSerie ?? '');
    final index = TextEditingController(text: r?.valeurIndex?.toString() ?? '');
    final unite = TextEditingController(text: r?.unite ?? '');
    var etat = r?.etatUsure;
    final fonc = TextEditingController(text: r?.fonctionnement ?? '');
    final obs = TextEditingController(text: r?.observations ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(r == null ? 'Nouveau relevé' : 'Modifier le relevé'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<ReleveCategorie>(
                  initialValue: cat,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Catégorie', isDense: true),
                  items: ReleveCategorie.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) => setLocal(() => cat = v ?? cat),
                ),
                const SizedBox(height: AppSpacing.sm),
                _dlgField(type, 'Type (ex: Collectif gaz de ville)'),
                _dlgField(serie, 'N° de série'),
                _dlgField(index, 'Index (M3 / KW)', keyboard: TextInputType.number),
                _dlgField(unite, 'Unité (M3 / KW)'),
                _etatDropdown(etat, (v) => setLocal(() => etat = v)),
                const SizedBox(height: AppSpacing.sm),
                _dlgField(fonc, 'Fonctionnement (ex: OK)'),
                _dlgField(obs, 'Observations'),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final model = EdlReleve(
      id: r?.id,
      etatDesLieuxId: widget.edlId,
      categorie: cat,
      type: type.text.trim().isEmpty ? null : type.text.trim(),
      numeroSerie: serie.text.trim().isEmpty ? null : serie.text.trim(),
      valeurIndex: double.tryParse(index.text.replaceAll(',', '.')),
      unite: unite.text.trim().isEmpty ? null : unite.text.trim(),
      etatUsure: etat,
      fonctionnement: fonc.text.trim().isEmpty ? null : fonc.text.trim(),
      observations: obs.text.trim().isEmpty ? null : obs.text.trim(),
      ordre: r?.ordre ?? _items.length,
    );
    if (r?.id == null) {
      await EdlDetailsDatasource.createReleve(model);
    } else {
      await EdlDetailsDatasource.updateReleve(r!.id!, model);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_items.isEmpty)
          _emptyHint('Compteurs eau/gaz/électrique, chauffage, eau chaude.'),
        ..._items.map((r) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.type ?? r.categorie.label),
              subtitle: Text([
                r.categorie.label,
                if (r.valeurIndex != null) '${r.valeurIndex} ${r.unite ?? ''}',
                if (r.etatUsure != null) etatUsureLabel(r.etatUsure),
                if (r.fonctionnement != null) r.fonctionnement!,
              ].join(' · ')),
              trailing: _editDelete(() => _edit(r), () async {
                if (r.id != null) {
                  await EdlDetailsDatasource.deleteReleve(r.id!);
                  await _load();
                }
              }),
            )),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter un relevé'),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CLÉS
// ════════════════════════════════════════════════════════════════════════════

class EdlClesSection extends StatefulWidget {
  final int edlId;
  const EdlClesSection({super.key, required this.edlId});

  @override
  State<EdlClesSection> createState() => _EdlClesSectionState();
}

class _EdlClesSectionState extends State<EdlClesSection> {
  List<EdlCle> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await EdlDetailsDatasource.listCles(widget.edlId);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _edit(EdlCle? c) async {
    final type = TextEditingController(text: c?.typeCle ?? '');
    final nombre = TextEditingController(text: c?.nombre?.toString() ?? '');
    final comm = TextEditingController(text: c?.commentaire ?? '');
    var remise = c?.remiseCeJour ?? false;
    var date = c?.dateRemise;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(c == null ? 'Nouvelle clé' : 'Modifier la clé'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _dlgField(type, 'Type de clé (ex: Badge accès)'),
                _dlgField(nombre, 'Nombre', keyboard: TextInputType.number),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remise ce jour'),
                  value: remise,
                  onChanged: (v) => setLocal(() => remise = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(date == null ? 'Date de remise' : _dateFmt.format(date!)),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date ?? now,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 5),
                      locale: const Locale('fr'),
                    );
                    if (picked != null) setLocal(() => date = picked);
                  },
                ),
                _dlgField(comm, 'Commentaire'),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true || type.text.trim().isEmpty) return;
    final model = EdlCle(
      id: c?.id,
      etatDesLieuxId: widget.edlId,
      typeCle: type.text.trim(),
      nombre: int.tryParse(nombre.text),
      remiseCeJour: remise,
      dateRemise: date,
      commentaire: comm.text.trim().isEmpty ? null : comm.text.trim(),
      ordre: c?.ordre ?? _items.length,
    );
    if (c?.id == null) {
      await EdlDetailsDatasource.createCle(model);
    } else {
      await EdlDetailsDatasource.updateCle(c!.id!, model);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_items.isEmpty) _emptyHint('Badge, clés chambre, boîte aux lettres…'),
        ..._items.map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.typeCle),
              subtitle: Text([
                if (c.nombre != null) 'x${c.nombre}',
                if (c.remiseCeJour) 'remise ce jour',
                if (c.dateRemise != null) _dateFmt.format(c.dateRemise!),
                if (c.commentaire != null) c.commentaire!,
              ].join(' · ')),
              trailing: _editDelete(() => _edit(c), () async {
                if (c.id != null) {
                  await EdlDetailsDatasource.deleteCle(c.id!);
                  await _load();
                }
              }),
            )),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter une clé'),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// COMPOSITION (sections + lignes)
// ════════════════════════════════════════════════════════════════════════════

class EdlCompositionSection extends StatefulWidget {
  final int edlId;
  const EdlCompositionSection({super.key, required this.edlId});

  @override
  State<EdlCompositionSection> createState() => _EdlCompositionSectionState();
}

class _EdlCompositionSectionState extends State<EdlCompositionSection> {
  List<EdlSection> _sections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await EdlDetailsDatasource.listSections(widget.edlId);
    if (mounted) {
      setState(() {
        _sections = s;
        _loading = false;
      });
    }
  }

  Future<void> _addSection() async {
    final nom = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle pièce'),
        content: SizedBox(
          width: 420,
          child: _dlgField(nom, 'Nom (ex: SEJOUR, CUISINE, CHAMBRE)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
        ],
      ),
    );
    if (ok != true || nom.text.trim().isEmpty) return;
    await EdlDetailsDatasource.createSection(EdlSection(
      etatDesLieuxId: widget.edlId,
      nom: nom.text.trim(),
      ordre: _sections.length,
    ));
    await _load();
  }

  Future<void> _editComment(EdlSection s) async {
    final ctrl = TextEditingController(text: s.commentaireGlobal ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Commentaire — ${s.nom}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Commentaire global sur la pièce'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true || s.id == null) return;
    await EdlDetailsDatasource.updateSection(
      s.id!,
      EdlSection(
        etatDesLieuxId: widget.edlId,
        nom: s.nom,
        ordre: s.ordre,
        commentaireGlobal: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
      ),
    );
    await _load();
  }

  Future<void> _deleteSection(EdlSection s) async {
    if (s.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer « ${s.nom} » ?'),
        content: const Text('Toutes les lignes de cette pièce seront supprimées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: AppTheme.deleteButtonStyle,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await EdlDetailsDatasource.deleteSection(s.id!);
    await _load();
  }

  Future<void> _editLigne(EdlSection s, EdlLigne? l) async {
    final equip = TextEditingController(text: l?.equipement ?? '');
    final nature = TextEditingController(text: l?.natureNombre ?? '');
    var etat = l?.etatUsure;
    final fonc = TextEditingController(text: l?.fonctionnement ?? '');
    final comm = TextEditingController(text: l?.commentaires ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l == null ? 'Nouvelle ligne' : "Modifier l'équipement"),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _dlgField(equip, 'Équipement (ex: SOL, MUR A, TV)'),
                _dlgField(nature, 'Nature / Nombre'),
                _etatDropdown(etat, (v) => setLocal(() => etat = v)),
                const SizedBox(height: AppSpacing.sm),
                _dlgField(fonc, 'Fonctionnement (ex: OK)'),
                _dlgField(comm, 'Commentaires'),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true || s.id == null || equip.text.trim().isEmpty) return;
    final model = EdlLigne(
      id: l?.id,
      sectionId: s.id!,
      equipement: equip.text.trim(),
      natureNombre: nature.text.trim().isEmpty ? null : nature.text.trim(),
      etatUsure: etat,
      fonctionnement: fonc.text.trim().isEmpty ? null : fonc.text.trim(),
      commentaires: comm.text.trim().isEmpty ? null : comm.text.trim(),
      ordre: l?.ordre ?? s.lignes.length,
    );
    if (l?.id == null) {
      await EdlDetailsDatasource.createLigne(model);
    } else {
      await EdlDetailsDatasource.updateLigne(l!.id!, model);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_sections.isEmpty)
          _emptyHint('Aucune pièce. Les équipements liés à l\'inventaire sont '
              'importés automatiquement ; ajoutez les éléments structurels '
              '(SOL, MURs, PLAFOND…).'),
        ..._sections.map(_sectionTile),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addSection,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter une pièce'),
          ),
        ),
      ],
    );
  }

  Widget _sectionTile(EdlSection s) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(s.nom, style: AppTypography.titleLg),
        subtitle: Text('${s.lignes.length} ligne(s)',
            style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
        children: [
          ...s.lignes.map((l) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.equipement),
                subtitle: Text([
                  if (l.natureNombre != null && l.natureNombre!.isNotEmpty) 'n: ${l.natureNombre}',
                  if (l.etatUsure != null) 'état: ${l.etatUsure}',
                  if (l.fonctionnement != null) l.fonctionnement!,
                  if (l.commentaires != null) l.commentaires!,
                ].join(' · ')),
                trailing: _editDelete(() => _editLigne(s, l), () async {
                  if (l.id != null) {
                    await EdlDetailsDatasource.deleteLigne(l.id!);
                    await _load();
                  }
                }),
              )),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ligne'),
                  onPressed: () => _editLigne(s, null),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.comment_outlined, size: 16),
                  label: const Text('Commentaire global'),
                  onPressed: () => _editComment(s),
                ),
                TextButton.icon(
                  icon: Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                  label: Text('Supprimer', style: TextStyle(color: AppColors.error)),
                  onPressed: () => _deleteSection(s),
                ),
              ],
            ),
          ),
          if (s.commentaireGlobal != null && s.commentaireGlobal!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('« ${s.commentaireGlobal!} »',
                  style: AppTypography.bodyMd.copyWith(
                      fontStyle: FontStyle.italic, color: AppColors.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

// ── helper commun ───────────────────────────────────────────────────────────
Widget _editDelete(VoidCallback onEdit, VoidCallback onDelete) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
    IconButton(
      icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
      onPressed: onDelete,
    ),
  ],
);

// ════════════════════════════════════════════════════════════════════════════
// COMPOSITION — TABLE ÉDITABLE (par pièce / chambre)
// ════════════════════════════════════════════════════════════════════════════

/// Tableau éditable des lignes d'équipement d'un EDL, groupées par section
/// (pièce / chambre). Colonnes : Nom · Nombre/№ · État d'usure (N/B/U/M) ·
/// Fonctionnement · Observations. Chaque modification est persistée en base.
///
/// Si [readOnly] est vrai (côté locataire), l'édition est désactivée.
class EdlCompositionTable extends StatefulWidget {
  final int edlId;
  final bool readOnly;
  const EdlCompositionTable({
    super.key,
    required this.edlId,
    this.readOnly = false,
  });

  @override
  State<EdlCompositionTable> createState() => _EdlCompositionTableState();
}

class _EdlCompositionTableState extends State<EdlCompositionTable> {
  late Future<List<EdlSection>> _future;

  @override
  void initState() {
    super.initState();
    _future = EdlDetailsDatasource.listSections(widget.edlId);
  }

  void _reload() {
    final f = EdlDetailsDatasource.listSections(widget.edlId);
    setState(() => _future = f);
  }

  Future<void> _addSection() async {
    final ctrl = TextEditingController();
    final nom = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle pièce'),
        content: _dlgField(ctrl, 'Nom de la pièce'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: AppTheme.cancelButtonStyle,
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (nom == null || nom.isEmpty) return;
    final sections = await _future;
    await EdlDetailsDatasource.createSection(EdlSection(
      etatDesLieuxId: widget.edlId,
      nom: nom.toUpperCase(),
      ordre: sections.length,
    ));
    _reload();
  }

  Future<void> _deleteSection(int id) async {
    await EdlDetailsDatasource.deleteSection(id);
    _reload();
  }

  Future<void> _addLigne(EdlSection section) async {
    await EdlDetailsDatasource.createLigne(EdlLigne(
      sectionId: section.id!,
      equipement: 'Nouvel élément',
      ordre: section.lignes.length,
    ));
    _reload();
  }

  Future<void> _saveLigne(EdlLigne ligne) async {
    if (ligne.id == null) return;
    await EdlDetailsDatasource.updateLigne(ligne.id!, ligne);
  }

  Future<void> _deleteLigne(int id) async {
    await EdlDetailsDatasource.deleteLigne(id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EdlSection>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final sections = snap.data ?? [];
        if (sections.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _emptyHint('Aucune pièce. Ajoutez-en une pour commencer.'),
              if (!widget.readOnly)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addSection,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter une pièce'),
                  ),
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in sections)
              _SectionTable(
                key: ValueKey('sec-${s.id}'),
                section: s,
                readOnly: widget.readOnly,
                onAddLigne: () => _addLigne(s),
                onDeleteSection: () => _deleteSection(s.id!),
                onSaveLigne: _saveLigne,
                onDeleteLigne: _deleteLigne,
              ),
            if (!widget.readOnly) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _addSection,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter une pièce'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionTable extends StatelessWidget {
  final EdlSection section;
  final bool readOnly;
  final VoidCallback onAddLigne;
  final VoidCallback onDeleteSection;
  final Future<void> Function(EdlLigne) onSaveLigne;
  final void Function(int) onDeleteLigne;

  const _SectionTable({
    super.key,
    required this.section,
    required this.readOnly,
    required this.onAddLigne,
    required this.onDeleteSection,
    required this.onSaveLigne,
    required this.onDeleteLigne,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête de la section (nom de la pièce)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F6FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.meeting_room_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(section.nom,
                      style: AppTypography.titleLg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (!readOnly)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    tooltip: 'Supprimer la pièce',
                    onPressed: onDeleteSection,
                  ),
              ],
            ),
          ),
          // Tableau des lignes (scroll horizontal sur petit écran).
          // Largeur = somme des colonnes (cellules à largeur fixe) ; on
          // shrink-wrap (crossAxisAlignment: start). Pas de `stretch` ni de
          // ConstrainedBox(minWidth) : sous un scroll horizontal la largeur est
          // NON bornée, ce qui ferait planter le layout.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LigneHeaderRow(),
                if (section.lignes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text('Aucun élément.',
                        style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant)),
                  )
                else
                  for (final l in section.lignes)
                    _LigneRow(
                      key: ValueKey('lig-${l.id}'),
                      ligne: l,
                      readOnly: readOnly,
                      onSave: onSaveLigne,
                      onDelete: () => onDeleteLigne(l.id!),
                    ),
              ],
            ),
          ),
          if (!readOnly)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAddLigne,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter un élément'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tableau d'inventaire (lignes) d'UNE section, **sans** en-tête de section —
/// conçu pour être intégré dans l'accordéon d'une pièce/chambre (le nom de la
/// pièce est déjà affiché par l'accordéon). Les sections/lignes sont chargées
/// une seule fois côté page (rapide) puis passées ici via [section] ; le CRUD
/// remonte via les callbacks.
class EdlLignesTable extends StatefulWidget {
  final EdlSection section;
  final bool readOnly;
  final VoidCallback onAddLigne;
  final Future<void> Function(EdlLigne) onSaveLigne;
  final void Function(int) onDeleteLigne;

  const EdlLignesTable({
    super.key,
    required this.section,
    required this.readOnly,
    required this.onAddLigne,
    required this.onSaveLigne,
    required this.onDeleteLigne,
  });

  @override
  State<EdlLignesTable> createState() => _EdlLignesTableState();
}

class _EdlLignesTableState extends State<EdlLignesTable> {
  final _hCtrl = ScrollController();

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  EdlSection get section => widget.section;
  bool get readOnly => widget.readOnly;
  VoidCallback get onAddLigne => widget.onAddLigne;
  Future<void> Function(EdlLigne) get onSaveLigne => widget.onSaveLigne;
  void Function(int) get onDeleteLigne => widget.onDeleteLigne;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scrollbar visible + glisser à la souris (drag) pour faire défiler le
        // tableau horizontalement sur les petits écrans.
        Scrollbar(
          controller: _hCtrl,
          thumbVisibility: true,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: SingleChildScrollView(
          controller: _hCtrl,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Container(
            // Bordure extérieure : délimite tout le tableau (grille).
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: AppRadius.borderSm,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LigneHeaderRow(),
                if (section.lignes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text('Aucun élément.',
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  )
                else
                  for (final l in section.lignes)
                    _LigneRow(
                      key: ValueKey('lig-${l.id}'),
                      ligne: l,
                      readOnly: readOnly,
                      onSave: onSaveLigne,
                      onDelete: () => onDeleteLigne(l.id!),
                    ),
              ],
            ),
          ),
            ),
          ),
        ),
        if (!readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddLigne,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter un élément'),
            ),
          ),
      ],
    );
  }
}

// Largeurs des colonnes du tableau de composition (compactes).
const double _kColNom = 150;
const double _kColNombre = 64;
const double _kColEtat = 116;
const double _kColFonction = 140;
const double _kColObs = 180;
const double _kColAction = 40;

class _LigneHeaderRow extends StatelessWidget {
  const _LigneHeaderRow();

  Widget _h(String t, double w, {bool last = false}) => Container(
        width: w,
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  right: BorderSide(color: AppColors.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Text(t.toUpperCase(),
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 0.2,
            )),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF0F6FA),
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          _h('Nom', _kColNom),
          _h('Nombre / №', _kColNombre),
          _h("État d'usure", _kColEtat),
          _h('Fonctionnement', _kColFonction),
          _h('Observations', _kColObs),
          const SizedBox(width: _kColAction),
        ],
      ),
    );
  }
}

class _LigneRow extends StatefulWidget {
  final EdlLigne ligne;
  final bool readOnly;
  final Future<void> Function(EdlLigne) onSave;
  final VoidCallback onDelete;

  const _LigneRow({
    super.key,
    required this.ligne,
    required this.readOnly,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_LigneRow> createState() => _LigneRowState();
}

class _LigneRowState extends State<_LigneRow> {
  late final TextEditingController _nom;
  late final TextEditingController _nombre;
  late final TextEditingController _fonction;
  late final TextEditingController _obs;
  late String? _etat;

  @override
  void initState() {
    super.initState();
    _nom = TextEditingController(text: widget.ligne.equipement);
    _nombre = TextEditingController(text: widget.ligne.natureNombre ?? '');
    _fonction = TextEditingController(text: widget.ligne.fonctionnement ?? '');
    _obs = TextEditingController(text: widget.ligne.commentaires ?? '');
    _etat = widget.ligne.etatUsure;
  }

  @override
  void dispose() {
    _nom.dispose();
    _nombre.dispose();
    _fonction.dispose();
    _obs.dispose();
    super.dispose();
  }

  void _persist() {
    widget.onSave(widget.ligne.copyWith(
      equipement: _nom.text.trim().isEmpty ? '—' : _nom.text.trim(),
      natureNombre: _nombre.text.trim(),
      etatUsure: _etat,
      fonctionnement: _fonction.text.trim(),
      commentaires: _obs.text.trim(),
    ));
  }

  Widget _cell(double w, Widget child, {bool last = false}) => Container(
        width: w,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  right: BorderSide(color: AppColors.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: child,
      );

  static const _cellTextStyle = TextStyle(fontSize: 12);

  Widget _text(TextEditingController c, {int maxLines = 1, String? hint}) =>
      TextField(
        controller: c,
        enabled: !widget.readOnly,
        maxLines: maxLines,
        style: _cellTextStyle,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          // Champ sans bordure : c'est la grille du tableau qui délimite.
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        ),
        onEditingComplete: () {
          _persist();
          FocusScope.of(context).unfocus();
        },
        onTapOutside: (_) => _persist(),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      // IntrinsicHeight + stretch : toutes les cellules prennent la hauteur de
      // la ligne → les bordures verticales sont pleine hauteur (cellules fermées).
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(_kColNom, _text(_nom)),
          _cell(_kColNombre, _text(_nombre)),
          _cell(
            _kColEtat,
            DropdownButtonFormField<String>(
              initialValue: _etat,
              isExpanded: true,
              style: _cellTextStyle.copyWith(color: AppColors.onSurface),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
              items: [
                const DropdownMenuItem(
                    value: null,
                    child: Text('—', style: _cellTextStyle)),
                ...kEtatsUsure.map((e) => DropdownMenuItem(
                      value: e,
                      child: Text('$e — ${etatUsureLabel(e)}',
                          style: _cellTextStyle,
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: widget.readOnly
                  ? null
                  : (v) {
                      setState(() => _etat = v);
                      _persist();
                    },
            ),
          ),
          _cell(_kColFonction, _text(_fonction)),
          _cell(_kColObs, _text(_obs, maxLines: 2)),
          SizedBox(
            width: _kColAction,
            child: widget.readOnly
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    tooltip: 'Supprimer',
                    onPressed: widget.onDelete,
                  ),
          ),
        ],
        ),
      ),
    );
  }
}
