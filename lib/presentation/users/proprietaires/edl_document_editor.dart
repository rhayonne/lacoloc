import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/edl_details.dart';
import 'package:lacoloc_front/data/models/edl_details.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
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
