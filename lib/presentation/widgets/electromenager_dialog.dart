import 'package:flutter/material.dart';
import 'package:lacoloc_front/presentation/widgets/app_date_picker.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/models/immeuble_draft.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:lacoloc_front/presentation/widgets/field_help_icon.dart';
import 'package:lacoloc_front/presentation/widgets/photo_picker_field.dart';
import 'package:lacoloc_front/presentation/widgets/quantity_stepper.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/currency.dart';

/// Pop-up « Ajouter un électroménager » : reprend les champs du formulaire
/// d'article (nom via autocomplete Meubles_Reference, quantité, valeur,
/// description, photos) **sans** le sélecteur d'immeuble — l'article est
/// rattaché automatiquement à l'immeuble en cours de création.
///
/// Ne touche pas la base : renvoie un [ArticleDraft] (les photos sont déjà
/// uploadées dans le bucket public `photos`).
Future<ArticleDraft?> showElectromenagerDialog(BuildContext context) {
  return showDialog<ArticleDraft>(
    context: context,
    builder: (_) => const Dialog(child: _ElectromenagerForm()),
  );
}

class _ElectromenagerForm extends StatefulWidget {
  const _ElectromenagerForm();

  @override
  State<_ElectromenagerForm> createState() => _ElectromenagerFormState();
}

class _ElectromenagerFormState extends State<_ElectromenagerForm> {
  late final Future<List<MeubleReferenceModel>> _refsFuture;

  MeubleReferenceModel? _ref;
  String _nom = '';
  int _quantite = 1;
  List<String> _photos = [];
  final _valeurCtrl = TextEditingController();
  final _valeurAchatCtrl = TextEditingController();
  DateTime? _dateAcquisition;
  final _descCtrl = TextEditingController();

  /// Ne garde que les meubles de la catégorie « Électroménager »
  /// (comparaison insensible à la casse/aux accents).
  static bool _isElectro(MeubleReferenceModel r) {
    final c = (r.categorie ?? '').toLowerCase();
    return c.contains('lectrom'); // « électroménager » / « electromenager »
  }

  @override
  void initState() {
    super.initState();
    _refsFuture = InventaireDatasource.listMeubleReferences();
  }

  @override
  void dispose() {
    _valeurCtrl.dispose();
    _valeurAchatCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final nom = _nom.trim();
    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saisissez le nom de l'électroménager.")),
      );
      return;
    }
    Navigator.pop(
      context,
      ArticleDraft(
        ref: _ref,
        nomCustom: _ref == null ? nom : null,
        quantite: _quantite,
        valeur: parseEuros(_valeurCtrl.text),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        photos: _photos,
        valeurAchat: parseEuros(_valeurAchatCtrl.text),
        dateAcquisition: _dateAcquisition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: FutureBuilder<List<MeubleReferenceModel>>(
          future: _refsFuture,
          builder: (context, snap) {
            final refs =
                (snap.data ?? const <MeubleReferenceModel>[]).where(_isElectro);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.kitchen_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text('Ajouter un électroménager',
                          style: AppTypography.titleLg),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Annuler',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Nom (autocomplete Meubles_Reference) ──────────────
                Autocomplete<MeubleReferenceModel>(
                  displayStringForOption: (r) => r.nom,
                  optionsBuilder: (tev) {
                    final q = tev.text.toLowerCase().trim();
                    if (q.isEmpty) return refs.take(30);
                    return refs.where((r) =>
                        r.nom.toLowerCase().contains(q) ||
                        (r.categorie?.toLowerCase().contains(q) ?? false));
                  },
                  onSelected: (r) => setState(() {
                    _ref = r;
                    _nom = r.nom;
                  }),
                  fieldViewBuilder: (ctx, ctrl, focus, submit) => TextField(
                    controller: ctrl,
                    focusNode: focus,
                    decoration: const InputDecoration(
                      labelText: "Nom de l'électroménager",
                      hintText: 'Saisir ou choisir un nom…',
                    ),
                    onChanged: (v) {
                      final match = refs
                          .where((r) =>
                              r.nom.toLowerCase() == v.toLowerCase().trim())
                          .firstOrNull;
                      setState(() {
                        _nom = v;
                        _ref = match;
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                Row(
                  children: [
                    Text('Quantité', style: AppTypography.labelMd),
                    const SizedBox(width: AppSpacing.md),
                    QuantityStepper(
                      value: _quantite,
                      onChanged: (v) => setState(() => _quantite = v),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                TextField(
                  controller: _valeurCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valeur (€)',
                    prefixText: '€ ',
                    suffixIcon: fieldHelpIcon(
                      'Valeur actuelle (de remplacement) du bien, '
                      "affichée dans l'inventaire.",
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                TextField(
                  controller: _valeurAchatCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Valeur d'achat (€) — vétusté",
                    prefixText: '€ ',
                    suffixIcon: fieldHelpIcon(
                      "Prix d'achat d'origine. Avec la date d'acquisition, "
                      'sert au calcul de la vétusté (abattement) lors d\'un '
                      'état des lieux de sortie.',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                InkWell(
                  onTap: () async {
                    final d = await showAppDatePicker(
                      context,
                      initial: _dateAcquisition ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _dateAcquisition = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Date d'acquisition",
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(
                      _dateAcquisition != null
                          ? '${_dateAcquisition!.day.toString().padLeft(2, '0')}/${_dateAcquisition!.month.toString().padLeft(2, '0')}/${_dateAcquisition!.year}'
                          : 'Sélectionner…',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                PhotoPickerField(
                  folder: 'photos',
                  initialPhotos: _photos,
                  onChanged: (urls) => _photos = urls,
                ),
                const SizedBox(height: AppSpacing.lg),

                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Ajouter'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
