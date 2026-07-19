import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/fournisseurs.dart';
import 'package:lacoloc_front/data/datasources/immeuble_lots.dart';
import 'package:lacoloc_front/data/models/fournisseur.dart';
import 'package:lacoloc_front/data/models/immeuble_lot.dart';
import 'package:lacoloc_front/presentation/widgets/field_help_icon.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Pop-up « Ajouter/modifier un lot de copropriété » : formulaire complet
/// (désignation légale, tantièmes, copropriété + syndic). Persiste **directement**
/// en base (le lot est un catalogue indépendant, pas un simple brouillon) et
/// renvoie le [ImmeubleLotModel] créé/modifié.
Future<ImmeubleLotModel?> showLotDialog(
  BuildContext context, {
  required String ownerId,
  int? immeubleId,
  ImmeubleLotModel? existing,
}) {
  return showDialog<ImmeubleLotModel>(
    context: context,
    builder: (_) => Dialog(
      child: _LotForm(
        ownerId: ownerId,
        immeubleId: immeubleId,
        existing: existing,
      ),
    ),
  );
}

class _LotForm extends StatefulWidget {
  final String ownerId;
  final int? immeubleId;
  final ImmeubleLotModel? existing;
  const _LotForm({required this.ownerId, this.immeubleId, this.existing});

  @override
  State<_LotForm> createState() => _LotFormState();
}

class _LotFormState extends State<_LotForm> {
  late final Future<List<FournisseurModel>> _syndicsFuture;
  bool _saving = false;

  final _numeroCtrl = TextEditingController();
  final _batimentCtrl = TextEditingController();
  final _etageCtrl = TextEditingController();
  final _porteCtrl = TextEditingController();
  final _cadastreCtrl = TextEditingController();
  final _tantiemesCtrl = TextEditingController();
  final _tantiemesTotalCtrl = TextEditingController();
  final _nomCoproCtrl = TextEditingController();
  final _adresseCoproCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  LotType _type = LotType.habitation;
  int? _syndicId;

  @override
  void initState() {
    super.initState();
    _syndicsFuture = FournisseursDatasource.listActiveByOwner(widget.ownerId)
        .then((list) => list.where((f) => f.categorie == 'Syndic / Copropriété').toList());
    final e = widget.existing;
    if (e != null) {
      _numeroCtrl.text = e.numeroLot;
      _type = e.typeLot;
      _batimentCtrl.text = e.batiment ?? '';
      _etageCtrl.text = e.etage ?? '';
      _porteCtrl.text = e.porte ?? '';
      _cadastreCtrl.text = e.referenceCadastrale ?? '';
      _tantiemesCtrl.text = e.tantiemes?.toString() ?? '';
      _tantiemesTotalCtrl.text = e.tantiemesTotal?.toString() ?? '';
      _nomCoproCtrl.text = e.nomCopropriete ?? '';
      _adresseCoproCtrl.text = e.adresseCopropriete ?? '';
      _descCtrl.text = e.description ?? '';
      _syndicId = e.syndicFournisseurId;
    }
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _batimentCtrl.dispose();
    _etageCtrl.dispose();
    _porteCtrl.dispose();
    _cadastreCtrl.dispose();
    _tantiemesCtrl.dispose();
    _tantiemesTotalCtrl.dispose();
    _nomCoproCtrl.dispose();
    _adresseCoproCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final numero = _numeroCtrl.text.trim();
    if (numero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez le numéro de lot.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final model = ImmeubleLotModel(
        id: existing?.id ?? 0,
        ownerId: widget.ownerId,
        immeubleId: existing?.immeubleId ?? widget.immeubleId,
        numeroLot: numero,
        typeLot: _type,
        batiment: _text(_batimentCtrl),
        etage: _text(_etageCtrl),
        porte: _text(_porteCtrl),
        referenceCadastrale: _text(_cadastreCtrl),
        tantiemes: double.tryParse(_tantiemesCtrl.text.replaceAll(',', '.')),
        tantiemesTotal:
            double.tryParse(_tantiemesTotalCtrl.text.replaceAll(',', '.')),
        nomCopropriete: _text(_nomCoproCtrl),
        adresseCopropriete: _text(_adresseCoproCtrl),
        syndicFournisseurId: _syndicId,
        description: _text(_descCtrl),
      );
      final result = existing == null
          ? await ImmeubleLotsDatasource.create(model)
          : await ImmeubleLotsDatasource.update(existing.id, model);
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Seuil d'empilement propre à ce dialogue (dont la largeur max est de
  /// 560px, donc bien en-dessous de [AppBreakpoints.compact]) : en dessous,
  /// 2-3 champs côte à côte deviendraient trop étroits/illisibles.
  static const double _stackBelow = 400;

  /// Aligne 2-3 champs sur une ligne (desktop/tablette) ; les empile en
  /// colonne sur mobile pour éviter des champs trop étroits/illisibles (le
  /// dialogue peut faire ~280px de large utile sur un petit téléphone).
  Widget _responsiveFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _stackBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                fields[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: fields[i]),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.apartment_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? 'Ajouter un lot de copropriété'
                        : 'Modifier le lot',
                    style: AppTypography.titleLg,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Annuler',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            Text('Copropriété', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nomCoproCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom de la copropriété',
                prefixIcon: Icon(Icons.domain_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _adresseCoproCtrl,
              decoration: const InputDecoration(
                labelText: 'Adresse de la copropriété',
                helperText: 'Si différente de celle du bien loué',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<FournisseurModel>>(
              future: _syndicsFuture,
              builder: (context, snap) {
                final syndics = snap.data ?? const <FournisseurModel>[];
                return DropdownButtonFormField<int?>(
                  initialValue: _syndicId,
                  decoration: InputDecoration(
                    labelText: 'Syndic (gestionnaire de la copropriété)',
                    helperText: syndics.isEmpty
                        ? "Aucun fournisseur de catégorie « Syndic / Copropriété » — créez-en un dans Fournisseurs."
                        : 'Sélectionnez le fournisseur qui gère cette copropriété.',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon: fieldHelpIcon(
                      "Le syndic est la personne ou société qui administre la "
                      "copropriété : elle organise les assemblées générales, "
                      "gère le budget et l'entretien des parties communes. "
                      "Choisissez-le parmi vos Fournisseurs (catégorie "
                      "« Syndic / Copropriété ») — si besoin, créez-le d'abord "
                      "depuis le menu Fournisseurs.",
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Aucun')),
                    ...syndics.map(
                      (f) => DropdownMenuItem(value: f.id, child: Text(f.nom)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _syndicId = v),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('Désignation du lot', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            _responsiveFields([
              TextField(
                controller: _numeroCtrl,
                decoration: const InputDecoration(
                  labelText: 'Numéro de lot',
                  helperText: 'Règlement de copropriété',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
              ),
              DropdownButtonFormField<LotType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type de lot',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: LotType.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            _responsiveFields([
              TextField(
                controller: _batimentCtrl,
                decoration: const InputDecoration(labelText: 'Bâtiment'),
              ),
              TextField(
                controller: _etageCtrl,
                decoration: const InputDecoration(labelText: 'Étage'),
              ),
              TextField(
                controller: _porteCtrl,
                decoration: const InputDecoration(labelText: 'Porte'),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _cadastreCtrl,
              decoration: const InputDecoration(
                labelText: 'Référence cadastrale',
                helperText: 'Ex. « AB 123 »',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('Quote-part de charges', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            _responsiveFields([
              TextField(
                controller: _tantiemesCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Tantièmes du lot',
                  prefixIcon: Icon(Icons.pie_chart_outline),
                ),
              ),
              TextField(
                controller: _tantiemesTotalCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total copropriété',
                  helperText: 'Ex. 10 000èmes',
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(widget.existing == null ? 'Ajouter' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
