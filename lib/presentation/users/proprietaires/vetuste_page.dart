import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/data/datasources/recettes.dart';
import 'package:lacoloc_front/data/datasources/vetuste.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/edl_details.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/vetuste.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/vetuste_pdf_builder.dart';
import 'package:lacoloc_front/presentation/widgets/document_pdf_button.dart';
import 'package:lacoloc_front/presentation/widgets/form_page_header.dart';
import 'package:lacoloc_front/utils/vetuste_calc.dart';
import 'package:lacoloc_front/theme/app_accordion.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/currency.dart';

/// Après la finalisation d'un EDL de **sortie**, compare entrée→sortie ; s'il y
/// a des dégradations, propose de créer le décompte de vétusté (groupé par EDL).
/// Idempotent (ne propose pas si un décompte existe déjà).
Future<void> proposerVetusteSiDegradation(
    BuildContext context, int sortieEdlId) async {
  final sortie = await EtatDesLieuxDatasource.findById(sortieEdlId);
  if (sortie == null ||
      sortie.typeEdl != 'sortie' ||
      sortie.edlEntreeId == null) {
    return;
  }
  final uid = AuthService.currentUser?.id;
  if (uid == null) return;
  if (await VetusteDatasource.findByEdl(sortie.id) != null) return;

  final bareme = await VetusteDatasource.listBareme(uid);
  final inventaire =
      await VetusteDatasource.inventairePourImmeuble(sortie.immeubleId);
  final candidats = await VetusteDatasource.buildCandidatesForSortie(
    sortie,
    bareme: bareme,
    inventaire: inventaire,
  );
  if (candidats.isEmpty || !context.mounted) return;

  final total = candidats
      .where((l) => l.imputable)
      .fold<double>(0, (s, l) => s + l.valeurResiduelle);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.report_problem_outlined,
          color: AppColors.error, size: 32),
      title: const Text('Dégradation détectée'),
      content: Text(
        '${candidats.length} équipement(s) se sont dégradés par rapport à '
        "l'état des lieux d'entrée.\n\n"
        'Voulez-vous créer un décompte de réparations (vétusté) ? '
        'Montant estimé : ${formatEuros(total)}.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Plus tard')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Créer le décompte')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await VetusteDatasource.createDecompteFromSortie(sortie, candidats);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Décompte de vétusté créé (onglet « Vétusté »).'),
      ),
    );
  }
}

/// Onglet « Vétusté » (proprietaire) : barème éditable + liste des décomptes
/// de réparations locatives (groupés par EDL).
class VetustePage extends StatefulWidget {
  const VetustePage({super.key});

  @override
  State<VetustePage> createState() => _VetustePageState();
}

class _VetustePageState extends State<VetustePage> {
  late Future<_VetusteData> _future;

  /// Décompte ouvert en édition (rendu dans le frame, sans nouvelle route).
  VetusteDecompteModel? _detail;
  List<VetusteBaremeModel> _bareme = const [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_VetusteData> _load() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return const _VetusteData(bareme: [], decomptes: []);
    final bareme = await VetusteDatasource.listBareme(uid);
    final decomptes = await VetusteDatasource.listDecomptes(uid);
    _bareme = bareme;
    return _VetusteData(bareme: bareme, decomptes: decomptes);
  }

  Future<void> _reload() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  void _openDetail(VetusteDecompteModel d) => setState(() => _detail = d);

  /// Création manuelle : choisir immeuble (+ chambre) puis ouvrir l'éditeur.
  Future<void> _ajouterManuel() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final immeubles = await ImmeublesDatasource.listByOwner(uid);
    if (!mounted || immeubles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun immeuble.')),
        );
      }
      return;
    }
    final choix = await showDialog<({int immeubleId, int? chambreId})>(
      context: context,
      builder: (_) => _ChoixImmeubleChambreDialog(immeubles: immeubles),
    );
    if (choix == null || !mounted) return;
    final id = await VetusteDatasource.createDecompte(
      VetusteDecompteModel(
        id: 0,
        ownerId: uid,
        immeubleId: choix.immeubleId,
        chambreId: choix.chambreId,
        titre: 'Décompte manuel',
        statut: 'brouillon',
        createdAt: DateTime.now(),
      ),
      const [],
    );
    // Recharge la liste et ouvre l'éditeur du décompte créé.
    final decomptes = await VetusteDatasource.listDecomptes(uid, refresh: true);
    final d = decomptes.where((x) => x.id == id).firstOrNull;
    if (d != null && mounted) _openDetail(d);
  }

  Future<void> _closeDetail() async {
    setState(() => _detail = null);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_detail != null) {
      return _DecompteEditor(
        key: ValueKey(_detail!.id),
        decompte: _detail!,
        bareme: _bareme,
        onClose: _closeDetail,
      );
    }
    return FutureBuilder<_VetusteData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // Erreur ≠ « aucune donnée » : afficher le problème + réessayer.
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Erreur de chargement : ${snap.error}'),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }
        final data = snap.data ?? const _VetusteData(bareme: [], decomptes: []);
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppAccordion(
              icon: Icons.tune,
              title: 'Barème de vétusté',
              subtitle:
                  'Durée de vie, franchise, coefficient annuel et résiduel minimum par catégorie.',
              children: [
                _BaremeTable(bareme: data.bareme),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text('Décomptes de réparations',
                      style: AppTypography.titleLg),
                ),
                OutlinedButton.icon(
                  onPressed: _ajouterManuel,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une vétusté'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (data.decomptes.isEmpty)
              Text(
                'Aucun décompte. Un décompte est proposé automatiquement à la '
                'finalisation d\'un état des lieux de sortie présentant des dégradations.',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              )
            else
              ...data.decomptes
                  .map((d) => _DecompteCard(decompte: d, onTap: () => _openDetail(d))),
          ],
          ),
        );
      },
    );
  }
}

class _VetusteData {
  final List<VetusteBaremeModel> bareme;
  final List<VetusteDecompteModel> decomptes;
  const _VetusteData({required this.bareme, required this.decomptes});
}

// ── Barème éditable ──────────────────────────────────────────────────────────

class _BaremeTable extends StatelessWidget {
  final List<VetusteBaremeModel> bareme;
  const _BaremeTable({required this.bareme});

  @override
  Widget build(BuildContext context) {
    if (bareme.isEmpty) {
      return Text('Aucune catégorie.',
          style: AppTypography.bodyMd
              .copyWith(color: AppColors.onSurfaceVariant));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              const Expanded(flex: 4, child: _Head('CATÉGORIE')),
              const Expanded(flex: 3, child: _Head('DURÉE (ans)')),
              const Expanded(flex: 3, child: _Head('FRANCHISE')),
              const Expanded(flex: 3, child: _Head('COEF %/an')),
              const Expanded(flex: 3, child: _Head('RÉSIDUEL %')),
            ],
          ),
        ),
        for (final b in bareme) _BaremeRow(key: ValueKey(b.id), bareme: b),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  final String text;
  const _Head(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant));
}

class _BaremeRow extends StatefulWidget {
  final VetusteBaremeModel bareme;
  const _BaremeRow({super.key, required this.bareme});

  @override
  State<_BaremeRow> createState() => _BaremeRowState();
}

class _BaremeRowState extends State<_BaremeRow> {
  late final _duree = TextEditingController(text: '${widget.bareme.dureeVieAnnees}');
  late final _franchise =
      TextEditingController(text: '${widget.bareme.franchiseAnnees}');
  late final _coef =
      TextEditingController(text: _numStr(widget.bareme.coefficientAnnuel));
  late final _residuel =
      TextEditingController(text: _numStr(widget.bareme.residuelMinPct));

  static String _numStr(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _duree.dispose();
    _franchise.dispose();
    _coef.dispose();
    _residuel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = widget.bareme.copyWith(
      dureeVieAnnees: int.tryParse(_duree.text) ?? widget.bareme.dureeVieAnnees,
      franchiseAnnees:
          int.tryParse(_franchise.text) ?? widget.bareme.franchiseAnnees,
      coefficientAnnuel: double.tryParse(_coef.text.replaceAll(',', '.')) ??
          widget.bareme.coefficientAnnuel,
      residuelMinPct: double.tryParse(_residuel.text.replaceAll(',', '.')) ??
          widget.bareme.residuelMinPct,
    );
    await VetusteDatasource.upsertBareme(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(widget.bareme.categorie, style: AppTypography.bodyMd),
          ),
          Expanded(flex: 3, child: _num(_duree, decimal: false)),
          Expanded(flex: 3, child: _num(_franchise, decimal: false)),
          Expanded(flex: 3, child: _num(_coef, decimal: true)),
          Expanded(flex: 3, child: _num(_residuel, decimal: true)),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c, {required bool decimal}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
          ],
          textAlign: TextAlign.center,
          decoration: const InputDecoration(isDense: true),
          onTapOutside: (_) {
            FocusScope.of(context).unfocus();
            _save();
          },
          onSubmitted: (_) => _save(),
        ),
      );
}

// ── Carte d'un décompte ──────────────────────────────────────────────────────

class _DecompteCard extends StatelessWidget {
  final VetusteDecompteModel decompte;
  final VoidCallback onTap;
  const _DecompteCard({required this.decompte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lieu = [decompte.immeubleNom, decompte.chambreNom]
        .whereType<String>()
        .join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(decompte.titre ?? 'Décompte de réparations'),
        subtitle: Text(
          [
            if (lieu.isNotEmpty) lieu,
            if (decompte.locataireNom != null) decompte.locataireNom!,
            '${decompte.lignes.length} ligne(s)',
            if (decompte.isGenere) 'À recevoir généré',
          ].join(' · '),
        ),
        trailing: Text(
          formatEuros(decompte.totalMontant),
          style: AppTypography.titleLs,
        ),
      ),
    );
  }
}

// ── Éditeur d'un décompte ────────────────────────────────────────────────────

class _LigneEdit {
  final TextEditingController equipement;
  final TextEditingController valeurAchat;
  String? categorie;
  DateTime? dateAcquisition;
  double ageAnnees;
  String? etatEntree;
  String? etatSortie;
  double abattementPct;
  double valeurResiduelle;
  bool imputable;

  _LigneEdit({
    required this.equipement,
    required this.valeurAchat,
    this.categorie,
    this.dateAcquisition,
    this.ageAnnees = 0,
    this.etatEntree,
    this.etatSortie,
    this.abattementPct = 0,
    this.valeurResiduelle = 0,
    this.imputable = true,
  });

  void dispose() {
    equipement.dispose();
    valeurAchat.dispose();
  }
}

class _DecompteEditor extends StatefulWidget {
  final VetusteDecompteModel decompte;
  final List<VetusteBaremeModel> bareme;
  final Future<void> Function() onClose;

  const _DecompteEditor({
    super.key,
    required this.decompte,
    required this.bareme,
    required this.onClose,
  });

  @override
  State<_DecompteEditor> createState() => _DecompteEditorState();
}

class _DecompteEditorState extends State<_DecompteEditor> {
  late final List<_LigneEdit> _lignes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lignes = widget.decompte.lignes
        .map((l) => _LigneEdit(
              equipement: TextEditingController(text: l.equipement),
              valeurAchat: TextEditingController(
                  text: l.valeurAchat > 0 ? formatEuros(l.valeurAchat) : ''),
              categorie: l.categorie,
              dateAcquisition: l.dateAcquisition,
              ageAnnees: l.ageAnnees,
              etatEntree: l.etatEntree,
              etatSortie: l.etatSortie,
              abattementPct: l.abattementPct,
              valeurResiduelle: l.valeurResiduelle,
              imputable: l.imputable,
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final l in _lignes) {
      l.dispose();
    }
    super.dispose();
  }

  List<String> get _categories =>
      widget.bareme.map((b) => b.categorie).toList();

  void _recompute(_LigneEdit l) {
    final valeur = parseEuros(l.valeurAchat.text) ?? 0;
    final b =
        widget.bareme.where((x) => x.categorie == l.categorie).firstOrNull;
    l.abattementPct = VetusteCalc.abattementPct(b, l.ageAnnees);
    l.valeurResiduelle = VetusteCalc.valeurResiduelle(valeur, l.abattementPct);
    setState(() {});
  }

  double get _total => _lignes
      .where((l) => l.imputable)
      .fold<double>(0, (s, l) => s + l.valeurResiduelle);

  List<VetusteDecompteLigneModel> _toModels() {
    var ordre = 0;
    return _lignes
        .map((l) => VetusteDecompteLigneModel(
              id: 0,
              decompteId: widget.decompte.id,
              equipement: l.equipement.text.trim(),
              categorie: l.categorie,
              valeurAchat: parseEuros(l.valeurAchat.text) ?? 0,
              dateAcquisition: l.dateAcquisition,
              ageAnnees: l.ageAnnees,
              etatEntree: l.etatEntree,
              etatSortie: l.etatSortie,
              abattementPct: l.abattementPct,
              valeurResiduelle: l.valeurResiduelle,
              imputable: l.imputable,
              ordre: ordre++,
            ))
        .toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await VetusteDatasource.replaceLignes(widget.decompte.id, _toModels());
      await VetusteDatasource.updateDecompte(widget.decompte.id,
          totalMontant: _total);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Décompte enregistré.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addLigne() {
    setState(() {
      _lignes.add(_LigneEdit(
        equipement: TextEditingController(),
        valeurAchat: TextEditingController(),
      ));
    });
  }

  Future<void> _genererARecevoir() async {
    final d = widget.decompte;
    if (d.locataireId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Aucun locataire associé : impossible de générer l\'à recevoir.'),
      ));
      return;
    }
    // Sauvegarde d'abord pour figer le total.
    await _save();
    if (!mounted) return;
    final total = _total;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Le total est nul : rien à recevoir.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Générer l\'à recevoir'),
        content: Text(
          'Créer une somme à recevoir de ${formatEuros(total)} pour le '
          'locataire ? Elle apparaîtra dans Finances (vous et le locataire).',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Générer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await RecettesDatasource.createManual(
        ownerId: d.ownerId,
        immeubleId: d.immeubleId,
        chambreId: d.chambreId,
        locataireId: d.locataireId,
        edlId: d.etatDeLieuxId,
        montant: total,
        dateEcheance: DateTime.now().add(const Duration(days: 30)),
        notes: 'Décompte de réparations locatives (vétusté)',
      );
      await VetusteDatasource.updateDecompte(d.id, statut: 'genere');
      if (d.etatDeLieuxId != null) {
        await NotificationsDatasource.notifyEdlLocataire(
          edlId: d.etatDeLieuxId!,
          type: 'vetuste_a_recevoir',
          title: 'Décompte de réparations',
          body:
              'Un décompte de réparations de ${formatEuros(total)} vous a été adressé. '
              'Voir Finances.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('À recevoir généré (visible dans Finances).')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.decompte;
    final lieu = [d.immeubleNom, d.chambreNom].whereType<String>().join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormPageHeader(
          title: d.titre ?? 'Décompte de réparations',
          trailing: FormHeaderActions(
            onSave: _saving ? null : _save,
            onClose: () => widget.onClose(),
            isSaving: _saving,
            extraActions: [
              DocumentPdfButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VetustePdfPreviewPage(
                      header: widget.decompte,
                      lignes: _toModels(),
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _genererARecevoir,
                style: AppTheme.saveButtonStyle,
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('Générer l\'à recevoir'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (lieu.isNotEmpty || d.locataireNom != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    [lieu, if (d.locataireNom != null) d.locataireNom!]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ..._lignes.asMap().entries.map((e) => _ligneCard(e.key, e.value)),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _addLigne,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une ligne'),
                ),
              ),
              const Divider(height: AppSpacing.xl * 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Total à la charge du locataire : ',
                      style: AppTypography.titleLs),
                  Text(formatEuros(_total),
                      style: AppTypography.titleLg
                          .copyWith(color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ligneCard(int index, _LigneEdit l) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Checkbox(
                  value: l.imputable,
                  onChanged: (v) =>
                      setState(() => l.imputable = v ?? true),
                ),
                const Text('Imputable'),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'Supprimer',
                  onPressed: () => setState(() {
                    _lignes.removeAt(index).dispose();
                  }),
                ),
              ],
            ),
            TextField(
              controller: l.equipement,
              decoration: const InputDecoration(labelText: 'Équipement'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _categories.contains(l.categorie) ? l.categorie : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: _categories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      l.categorie = v;
                      _recompute(l);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: l.valeurAchat,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: const InputDecoration(
                        labelText: 'Valeur d\'achat', prefixText: '€ '),
                    onChanged: (_) => _recompute(l),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                if (l.etatEntree != null && l.etatSortie != null)
                  'État ${etatUsureLabel(l.etatEntree)} → ${etatUsureLabel(l.etatSortie)}',
                'Âge ${l.ageAnnees.toStringAsFixed(1)} an(s)',
                'Abattement ${l.abattementPct.toStringAsFixed(0)} %',
                'Résiduelle ${formatEuros(l.valeurResiduelle)}',
              ].join(' · '),
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialogue : choix immeuble + chambre (ajout manuel) ───────────────────────

class _ChoixImmeubleChambreDialog extends StatefulWidget {
  final List<ImmeublesModel> immeubles;
  const _ChoixImmeubleChambreDialog({required this.immeubles});

  @override
  State<_ChoixImmeubleChambreDialog> createState() =>
      _ChoixImmeubleChambreDialogState();
}

class _ChoixImmeubleChambreDialogState
    extends State<_ChoixImmeubleChambreDialog> {
  ImmeublesModel? _immeuble;
  ChambreModel? _chambre;
  List<ChambreModel> _chambres = [];
  bool _loadingChambres = false;

  Future<void> _loadChambres(int immeubleId) async {
    setState(() => _loadingChambres = true);
    final list = await ChambresDatasource.listByImmeuble(immeubleId);
    if (mounted) {
      setState(() {
        _chambres = list;
        _loadingChambres = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle vétusté'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<ImmeublesModel>(
            initialValue: _immeuble,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Immeuble'),
            items: widget.immeubles
                .map((i) =>
                    DropdownMenuItem(value: i, child: Text(i.name)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _immeuble = v;
                _chambre = null;
                _chambres = [];
              });
              if (v != null) _loadChambres(v.id);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<ChambreModel?>(
            initialValue: _chambre,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Chambre (optionnel)',
              helperText: _loadingChambres ? 'Chargement…' : null,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('— Aucune —')),
              ..._chambres.map((c) =>
                  DropdownMenuItem(value: c, child: Text(c.roomName))),
            ],
            onChanged: (v) => setState(() => _chambre = v),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: AppTheme.saveButtonStyle,
          onPressed: _immeuble == null
              ? null
              : () => Navigator.pop(context,
                  (immeubleId: _immeuble!.id, chambreId: _chambre?.id)),
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
