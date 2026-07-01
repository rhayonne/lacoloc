import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/address_search.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/charges_reference.dart';
import 'package:lacoloc_front/data/datasources/commons_seeder.dart';
import 'package:lacoloc_front/data/datasources/immeuble_charges.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/reference.dart';
import 'package:lacoloc_front/data/pieces_communes_seed.dart';
import 'package:lacoloc_front/data/models/address_suggestion.dart';
import 'package:lacoloc_front/data/models/charge_reference.dart';
import 'package:lacoloc_front/data/models/immeuble_charge.dart';
import 'package:lacoloc_front/data/models/immeuble_draft.dart';
import 'package:lacoloc_front/data/models/immeuble_type.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:lacoloc_front/presentation/widgets/address_autocomplete_field.dart';
import 'package:lacoloc_front/presentation/widgets/charges_selector.dart';
import 'package:lacoloc_front/presentation/widgets/electromenager_dialog.dart';
import 'package:lacoloc_front/presentation/widgets/form_page_header.dart';
import 'package:lacoloc_front/presentation/widgets/number_stepper_field.dart';
import 'package:lacoloc_front/presentation/widgets/photo_picker_field.dart';
import 'package:lacoloc_front/presentation/widgets/quantity_stepper.dart';
import 'package:lacoloc_front/presentation/widgets/unsaved_changes_dialog.dart';
import 'package:lacoloc_front/theme/card_delete_button.dart';
import 'package:lacoloc_front/utils/currency.dart';
import 'package:lacoloc_front/presentation/tour/guided_tours.dart';
import 'package:lacoloc_front/theme/app_accordion.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class NouveauImmeublePage extends StatefulWidget {
  final ImmeublesModel? immeuble;
  final VoidCallback? onSaved;
  final VoidCallback? onBack;

  /// Démarre automatiquement le **tour guidé** à l'ouverture (lien du manuel
  /// `?tour=immeuble` ou bouton « Oui » de la boîte de dialogue d'accueil).
  final bool startTour;

  const NouveauImmeublePage({
    super.key,
    this.immeuble,
    this.onSaved,
    this.onBack,
    this.startTour = false,
  });

  @override
  State<NouveauImmeublePage> createState() => _NouveauImmeublePageState();
}

class _NouveauImmeublePageState extends State<NouveauImmeublePage> {
  final _formKey = GlobalKey<FormBuilderState>();

  late Future<List<ImmeubleTypeModel>> _typesFuture;
  late Future<_Bundle> _bundleFuture;

  ImmeubleTypeModel? _selectedType;
  String _address = '';
  String? _codePostal;
  List<String> _photos = [];
  String? _mainPhoto;
  bool _isSubmitting = false;
  bool _isBailLocation = false;

  // Charges sélectionnées
  List<ChargeSelection> _charges = [];

  // Valeurs « live » de champs qui pilotent l'UI (réactivité).
  bool? _meuble; // location meublée ? (déverrouille le dépôt de garantie)
  String? _dpe; // classe DPE sélectionnée (pour afficher la croix « effacer »)

  // Brouillon en mémoire (pièces communes + électroménager), persisté au save.
  final ImmeubleDraft _draft = ImmeubleDraft();

  // Parties communes
  ImmeublesModel? _createdImmeuble;

  ImmeublesModel? get _persistedImmeuble => widget.immeuble ?? _createdImmeuble;
  bool get _isEditing => _persistedImmeuble != null;

  // ── Tour guidé ─────────────────────────────────────────────────────────────
  bool _tourActive = false;
  final _kHeader = GlobalKey();
  final _kType = GlobalKey();
  final _kAddress = GlobalKey();
  final _kBail = GlobalKey();
  final _kPhotos = GlobalKey();
  final _kCommunes = GlobalKey();

  @override
  void initState() {
    super.initState();
    _typesFuture = ReferenceDatasource.immeubleTypes();
    _bundleFuture = _loadBundle();
    final imm = widget.immeuble;
    if (imm != null) {
      _address = imm.address ?? '';
      _codePostal = imm.codePostal;
      _photos = List.from(imm.commonPhotos);
      _mainPhoto = imm.mainPhoto;
      _isBailLocation = imm.bailLocation;
      _meuble = imm.locationMeuble;
      _dpe = imm.dpeClasse;
      _typesFuture.then((types) {
        if (!mounted) return;
        final match = types.where((t) => t.id == imm.typeId).firstOrNull;
        if (match != null) {
          setState(() => _selectedType = match);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _formKey.currentState?.fields['type']?.didChange(match);
          });
        }
      });
    }
    // Démarrage automatique du tour guidé (lien manuel / dialogue d'accueil).
    if (widget.startTour) {
      _tourActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Petit délai : laisse les FutureBuilder (types, charges) se rendre.
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted) _startTour();
        });
      });
    }
  }

  // ── Tour guidé ─────────────────────────────────────────────────────────────

  /// Demande à l'utilisateur s'il veut suivre le tour guidé, puis le lance.
  Future<void> _askStartTour() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.school_outlined,
          color: AppColors.primary,
          size: 34,
        ),
        title: const Text('Tour guidé'),
        content: const Text(
          "Voulez-vous être guidé pas à pas pour créer votre premier immeuble ?\n\n"
          "Nous mettrons en surbrillance chaque étape. À la fin, vous pourrez "
          "conserver l'immeuble créé ou le supprimer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non merci'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, me guider'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _tourActive = true;
      _startTour();
    }
  }

  void _startTour() {
    GuidedTour.show(context, [
      TourStep(
        key: _kType,
        title: "Type & nom",
        text:
            "Choisissez le type d'immeuble (appartement, maison…) et donnez-lui un nom reconnaissable.",
      ),
      TourStep(
        key: _kAddress,
        title: "Adresse",
        text:
            "Saisissez l'adresse : la ville, le département et la région se remplissent automatiquement.",
      ),
      TourStep(
        key: _kBail,
        title: "Type de bail",
        text:
            "« Location » = un seul contrat pour tout l'immeuble. « Bail individuel » = un contrat par chambre (colocation).",
      ),
      TourStep(
        key: _kPhotos,
        title: "Photos",
        text:
            "Ajoutez des photos des espaces communs. L'étoile définit la photo principale de l'annonce.",
      ),
      TourStep(
        key: _kCommunes,
        title: "Parties communes",
        text:
            "Optionnel : générez automatiquement les pièces communes (et leur inventaire si la location est meublée).",
      ),
      TourStep(
        key: _kHeader,
        title: "Enregistrer",
        text:
            "Quand tout est prêt, cliquez sur « Enregistrer » ici en haut pour créer l'immeuble.",
      ),
    ]);
  }

  /// Après une création **pendant le tour**, propose de conserver ou supprimer
  /// l'immeuble d'essai. Retourne true si on doit poursuivre la fermeture.
  Future<void> _askKeepOrDeleteAfterTour(int immeubleId) async {
    final choix = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.celebration_outlined,
          color: AppColors.primary,
          size: 34,
        ),
        title: const Text('Immeuble créé 🎉'),
        content: const Text(
          "Vous avez créé cet immeuble pendant le tour guidé.\n\n"
          "• « Conserver » : il restera dans votre liste comme un immeuble réel.\n"
          "• « Supprimer » : il sera effacé (ainsi que les pièces/inventaire créés pendant l'essai).\n\n"
          "Que souhaitez-vous faire ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Supprimer l\'essai'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('Conserver'),
          ),
        ],
      ),
    );
    if (choix == 'delete') {
      try {
        await ImmeublesDatasource.delete(immeubleId);
        _snack('Immeuble d\'essai supprimé.');
      } catch (e) {
        _snack('Suppression impossible : $e');
      }
    }
  }

  Future<_Bundle> _loadBundle() async {
    final chargesRef = await ChargesReferenceDatasource.listAll(
      activeOnly: true,
    );
    List<ImmeubleChargeModel> existing = [];
    final imm = widget.immeuble;
    if (imm != null) {
      existing = await ImmeubleChargesDatasource.listByImmeuble(imm.id);
    }
    // Convertir en ChargeSelection initiales
    final initSel = existing
        .map((ic) {
          final ref = chargesRef
              .where((r) => r.id == ic.chargeRefId)
              .firstOrNull;
          if (ref == null) return null;
          return ChargeSelection(ref: ref, type: ic.type, montant: ic.montant);
        })
        .whereType<ChargeSelection>()
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _charges = initSel);
    });

    return _Bundle(chargesRef: chargesRef);
  }

  void _onAddressSuggested(AddressSuggestion s) {
    setState(() {
      _address = s.label;
      if (s.postcode.isNotEmpty) _codePostal = s.postcode;
    });
    _formKey.currentState?.fields['city']?.didChange(s.city);
    _formKey.currentState?.fields['department']?.didChange(s.department);
    _formKey.currentState?.fields['region']?.didChange(s.region);
  }

  Future<void> _ensureLocationData() async {
    final state = _formKey.currentState;
    if (state == null) return;
    final dept = (state.fields['department']?.value as String?)?.trim() ?? '';
    final region = (state.fields['region']?.value as String?)?.trim() ?? '';
    final cp = _codePostal?.trim() ?? '';
    final address = _address.trim();
    if (address.isEmpty) return;
    if (dept.isNotEmpty && region.isNotEmpty && cp.isNotEmpty) return;
    final results = await AddressSearchService.search(address);
    if (results.isEmpty || !mounted) return;
    final s = results.first;
    if (dept.isEmpty && s.department.isNotEmpty) {
      state.fields['department']?.didChange(s.department);
    }
    if (region.isEmpty && s.region.isNotEmpty) {
      state.fields['region']?.didChange(s.region);
    }
    if ((state.fields['city']?.value as String?)?.trim().isEmpty != false &&
        s.city.isNotEmpty) {
      state.fields['city']?.didChange(s.city);
    }
    if (cp.isEmpty && s.postcode.isNotEmpty) _codePostal = s.postcode;
  }

  Future<void> _handleBack() async {
    final isDirty = _formKey.currentState?.isDirty ?? false;
    if (!isDirty) {
      widget.onBack?.call();
      return;
    }
    final choice = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (choice) {
      case UnsavedChoice.cancel:
        return;
      case UnsavedChoice.discard:
        widget.onBack?.call();
      case UnsavedChoice.save:
        await _submit();
    }
  }

  ImmeublesModel _buildModel(
    Map<String, dynamic> values,
    ImmeubleTypeModel type,
  ) {
    String? trimOrNull(String? v) =>
        v?.trim().isEmpty == true ? null : v?.trim();
    final meuble = values['location_meuble'] as bool?;
    return ImmeublesModel(
      id: _persistedImmeuble?.id ?? 0,
      name: values['name'] as String,
      ownerId: AuthService.currentUser?.id,
      typeId: type.id,
      address: _address.trim().isEmpty ? null : _address.trim(),
      city: trimOrNull(values['city'] as String?),
      region: trimOrNull(values['region'] as String?),
      department: trimOrNull(values['department'] as String?),
      codePostal: trimOrNull(_codePostal),
      totalM2: double.tryParse(
        ((values['total_m2'] as String?) ?? '').replaceAll(',', '.'),
      ),
      description: trimOrNull(values['description'] as String?),
      commonPhotos: _photos,
      isActive: !((values['desactiver'] as bool?) ?? false),
      mainPhoto: _mainPhoto,
      bailLocation: (values['bail_location'] as bool?) ?? false,
      bailIndividuel: (values['bail_individuel'] as bool?) ?? false,
      prixLoyer: _isBailLocation
          ? double.tryParse(
              ((values['prix_loyer'] as String?) ?? '').replaceAll(',', '.'),
            )
          : null,
      locationMeuble: meuble,
      depotGarantieMois: double.tryParse(
        ((values['depot_garantie_mois'] as String?) ?? '').replaceAll(',', '.'),
      ),
      dpeClasse: trimOrNull(values['dpe_classe'] as String?),
      irlReference: trimOrNull(values['irl_reference'] as String?),
      dureeBailMois: int.tryParse((values['duree_bail_mois'] as String?) ?? ''),
    );
  }

  Future<void> _saveCharges(int immeubleId) async {
    // Supprimer les charges existantes puis insérer les nouvelles.
    await ImmeubleChargesDatasource.deleteByImmeuble(immeubleId);
    for (final sel in _charges) {
      await ImmeubleChargesDatasource.upsert(
        ImmeubleChargeModel(
          id: 0,
          immeubleId: immeubleId,
          chargeRefId: sel.ref.id,
          type: sel.type,
          montant: sel.montant,
        ),
      );
    }
  }

  /// Persiste le brouillon (pièces communes sélectionnées + leur inventaire,
  /// puis l'électroménager au niveau immeuble) après création de l'immeuble.
  Future<void> _persistDraft(int immeubleId) async {
    if (_draft.pieces.isNotEmpty) {
      await CommonsSeeder.seedSelection(
        immeubleId,
        meuble: _meuble ?? false,
        selection: [
          for (final p in _draft.pieces) (nom: p.nom, quantite: p.quantite),
        ],
      );
    }
    if (_draft.electromenager.isNotEmpty) {
      await InventaireDatasource.createMany([
        for (final a in _draft.electromenager) _articleToModel(a, immeubleId),
      ]);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    final type = values['type'] as ImmeubleTypeModel?;
    if (type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sélectionnez un type d'immeuble")),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _ensureLocationData();
      final model = _buildModel(_formKey.currentState!.value, type);
      ImmeublesModel saved;
      if (_isEditing) {
        await ImmeublesDatasource.update(model);
        saved = model;
      } else {
        saved = await ImmeublesDatasource.create(model);
      }
      await _saveCharges(saved.id);
      // À la création : matérialiser le brouillon (pièces communes + inventaire
      // + électroménager) et le rattacher à l'immeuble.
      if (widget.immeuble == null) {
        await _persistDraft(saved.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Immeuble modifié avec succès'
                : 'Immeuble créé avec succès',
          ),
        ),
      );
      // Création pendant le tour guidé → proposer de conserver ou supprimer.
      if (_tourActive && widget.immeuble == null) {
        await _askKeepOrDeleteAfterTour(saved.id);
        _tourActive = false;
      }
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Parties communes (sélection en brouillon) ─────────────────────────────

  /// Sélection courante d'une pièce du modèle (null = non cochée).
  PieceDraft? _pieceDraftPour(String nom) =>
      _draft.pieces.where((p) => p.nom == nom).firstOrNull;

  void _togglePiece(String nom, bool selected) {
    setState(() {
      _draft.pieces.removeWhere((p) => p.nom == nom);
      if (selected) _draft.pieces.add(PieceDraft(nom: nom, quantite: 1));
      _draft.inventaireGenere = false; // la sélection a changé
    });
  }

  void _setQuantitePiece(String nom, int q) {
    setState(() {
      _pieceDraftPour(nom)?.quantite = q;
      _draft.inventaireGenere = false;
    });
  }

  /// Nombre total de pièces (somme des quantités) et d'articles d'inventaire
  /// qui seront créés à l'enregistrement, d'après la sélection courante.
  ({int pieces, int articles}) _recapCommunes() {
    var pieces = 0;
    var articles = 0;
    for (final p in _draft.pieces) {
      pieces += p.quantite;
      if (_meuble == true) {
        articles +=
            p.quantite * (CommonsSeeder.equipementsParNom[p.nom]?.length ?? 0);
      }
    }
    return (pieces: pieces, articles: articles);
  }

  /// « Génère » la sélection dans le brouillon (aucune écriture en base — la
  /// création réelle a lieu au clic « Enregistrer »).
  void _genererCommunesDraft() {
    if (_meuble == null) {
      _snack('Sélectionnez « Location meublée ? » d\'abord.');
      return;
    }
    if (_draft.pieces.isEmpty) {
      _snack('Sélectionnez au moins une pièce commune.');
      return;
    }
    setState(() => _draft.inventaireGenere = true);
    final r = _recapCommunes();
    _snack(
      _meuble == true
          ? '${r.pieces} pièce(s) et ${r.articles} article(s) seront créés à l\'enregistrement.'
          : '${r.pieces} pièce(s) seront créées à l\'enregistrement.',
    );
  }

  // En création, les électroménagers vivent dans le brouillon (créés au save) ;
  // en édition, l'immeuble existe → on les crée tout de suite dans son
  // inventaire et on les affiche dans la liste de session.
  final List<ArticleDraft> _electroAddedInEdit = [];

  InventaireModel _articleToModel(ArticleDraft a, int immeubleId) =>
      InventaireModel(
        id: 0,
        immeubleId: immeubleId,
        meubleRefId: a.ref?.id,
        nomCustom: a.ref == null ? a.nomCustom : null,
        valeur: a.valeur,
        quantite: a.quantite,
        description: a.description,
        photos: a.photos,
        createdAt: DateTime.now(),
        valeurAchat: a.valeurAchat,
        dateAcquisition: a.dateAcquisition,
        categorieVetusteCustom: a.categorieVetuste,
      );

  Future<void> _ajouterElectromenager() async {
    final article = await showElectromenagerDialog(context);
    if (article == null || !mounted) return;
    final imm = _persistedImmeuble;
    if (imm != null) {
      // Édition : persiste immédiatement dans l'inventaire de l'immeuble.
      try {
        await InventaireDatasource.createMany([_articleToModel(article, imm.id)]);
        if (!mounted) return;
        setState(() => _electroAddedInEdit.add(article));
        _snack('Électroménager ajouté à l\'inventaire.');
      } catch (e) {
        if (mounted) _snack('Erreur : $e');
      }
    } else {
      setState(() => _draft.electromenager.add(article));
    }
  }

  // ── Sections « brouillon » (création seulement) ──────────────────────────

  /// En édition, les pièces/inventaire existent déjà : on renvoie une note qui
  /// renvoie vers la fiche de l'immeuble plutôt que de risquer un doublon.
  Widget _editNote(String texte) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(
        Icons.info_outline,
        size: 16,
        color: AppColors.onSurfaceVariant,
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Text(
          texte,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );

  Widget _partiesCommunesBody() {
    if (widget.immeuble != null) {
      return _editNote(
        'Les pièces communes se gèrent dans la fiche de l\'immeuble.',
      );
    }
    final r = _recapCommunes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sélectionnez les pièces communes à créer automatiquement '
          '(avec leur inventaire si la location est meublée). '
          'Indiquez une quantité pour en créer plusieurs (ex. 2 WC).',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Disposition en colonnes pour limiter la hauteur ; le sélecteur de
        // quantité n'apparaît qu'une fois la pièce cochée, à côté de la case.
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
            const gap = AppSpacing.md;
            final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: AppSpacing.xs,
              children: [
                for (final seed in kPiecesCommunesSeed)
                  SizedBox(
                    width: cols == 1 ? c.maxWidth : itemW,
                    child: _PieceSelectRow(
                      nom: seed.nom,
                      draft: _pieceDraftPour(seed.nom),
                      onToggle: (v) => _togglePiece(seed.nom, v),
                      onQuantite: (q) => _setQuantitePiece(seed.nom, q),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: KeyedSubtree(
            key: _kCommunes,
            child: OutlinedButton.icon(
              onPressed: _genererCommunesDraft,
              icon: const Icon(Icons.meeting_room_outlined),
              label: const Text('Ajouter les pièces communes et inventaire'),
            ),
          ),
        ),
        if (_draft.inventaireGenere) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: AppColors.tertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _meuble == true
                      ? '${r.pieces} pièce(s) et ${r.articles} article(s) seront créés à l\'enregistrement.'
                      : '${r.pieces} pièce(s) seront créées à l\'enregistrement.',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.tertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _electromenagerBody() {
    final editing = widget.immeuble != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          editing
              ? "Ajoutez un électroménager : il sera rattaché à l'inventaire "
                  'de cet immeuble.'
              : 'Ajoutez les électroménagers : ils seront rattachés à cet immeuble.',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Création : liste du brouillon ; édition : ajoutés dans cette session.
        if (!editing && _draft.electromenager.isNotEmpty) ...[
          _electroTableHeader(),
          ..._draft.electromenager.asMap().entries.map((e) {
            final a = e.value;
            return _electroTableRow(
              nom: a.displayNom,
              categorie: a.ref?.categorie ?? '—',
              quantite: a.quantite,
              valeur: a.valeur,
              onDelete: () =>
                  setState(() => _draft.electromenager.removeAt(e.key)),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (editing && _electroAddedInEdit.isNotEmpty) ...[
          _electroTableHeader(),
          ..._electroAddedInEdit.map((a) => _electroTableRow(
                nom: a.displayNom,
                categorie: a.ref?.categorie ?? '—',
                quantite: a.quantite,
                valeur: a.valeur,
                onDelete: null,
              )),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Gérez tout l\'inventaire (modifier/supprimer) depuis l\'onglet '
            'Inventaire de l\'immeuble.',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _ajouterElectromenager,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un électroménager'),
          ),
        ),
      ],
    );
  }

  // Table d'électroménager : Nom · Catégorie · Qté · (€) · suppression.
  static const _electroFlex = [4, 3, 2, 3];

  Widget _electroTableHeader() => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    child: Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            flex: _electroFlex[i],
            child: Text(
              const ['NOM', 'CATÉGORIE', 'QTÉ', 'VALEUR'][i],
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(width: 40),
      ],
    ),
  );

  Widget _electroTableRow({
    required String nom,
    required String categorie,
    required int quantite,
    required double? valeur,
    required VoidCallback? onDelete,
  }) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            flex: _electroFlex[0],
            child: Text(nom, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: _electroFlex[1],
            child: Text(
              categorie,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(flex: _electroFlex[2], child: Text('$quantite')),
          Expanded(
            flex: _electroFlex[3],
            child: Text(valeur != null ? formatEuros(valeur) : '—'),
          ),
          SizedBox(
            width: 40,
            child: onDelete == null
                ? null
                : CardDeleteButton(onPressed: onDelete),
          ),
        ],
      ),
    ),
  );

  Widget _chargesAccordion(_Bundle? bundle) {
    final Widget body;
    if (bundle == null) {
      body = const LinearProgressIndicator();
    } else if (bundle.chargesRef.isEmpty) {
      body = Text(
        'Aucune charge disponible. Contactez le super admin.',
        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
      );
    } else {
      body = ChargesSelector(
        available: bundle.chargesRef,
        initial: _charges,
        onChanged: (sel) => setState(() => _charges = sel),
      );
    }
    return AppAccordion(
      icon: Icons.receipt_long_outlined,
      title: 'Charges locatives',
      subtitle: widget.immeuble?.bailIndividuel == true
          ? 'Copiées automatiquement dans chaque nouvelle chambre.'
          : 'Définissez les charges pour ce bien.',
      children: [body],
    );
  }

  // ── Helpers de mise en page ───────────────────────────────────────────────

  Widget _twoColumns(
    Widget left,
    Widget right, {
    bool wide = true,
    int flexLeft = 1,
    int flexRight = 1,
  }) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const SizedBox(height: AppSpacing.md),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(flex: flexLeft, child: left),
        const SizedBox(width: AppSpacing.md),
        Flexible(flex: flexRight, child: right),
      ],
    );
  }

  Widget _threeColumns(Widget a, Widget b, Widget c, {bool wide = true}) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          a,
          const SizedBox(height: AppSpacing.md),
          b,
          const SizedBox(height: AppSpacing.md),
          c,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: b),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: c),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: AppTypography.labelMd),
  );

  /// Dépôt de garantie : verrouillé tant que « Location meublée ? » n'est pas
  /// choisi ; sinon champ éditable avec le plafond légal correspondant.
  Widget _depotField() {
    if (_meuble == null) {
      return TextField(
        enabled: false,
        decoration: const InputDecoration(
          labelText: 'Dépôt de garantie (mois)',
          helperText: 'Sélectionnez d\'abord « Location meublée ? »',
          prefixIcon: Icon(Icons.lock_outline),
        ),
      );
    }
    // Plafond légal selon le type de location (meublé = 2, non meublé = 1).
    final maxMois = _meuble == true ? 2 : 1;
    return NumberStepperField(
      // La clé force la reconstruction (et donc la valeur initiale) au passage
      // verrouillé → déverrouillé et au changement meublé/non-meublé.
      key: ValueKey('depot_$_meuble'),
      name: 'depot_garantie_mois',
      // Par défaut, on pré-remplit le maximum légal (1 ou 2 mois) ; en édition,
      // on conserve la valeur enregistrée si elle existe.
      initialValue:
          widget.immeuble?.depotGarantieMois?.toString() ?? '$maxMois',
      labelText: 'Dépôt de garantie (mois)',
      helperText: _meuble == true
          ? 'Max légal : 2 mois (meublé)'
          : 'Max légal : 1 mois (non meublé)',
      prefixIcon: Icons.lock_open_outlined,
      min: 0,
      max: maxMois.toDouble(),
    );
  }

  /// Champ Classe DPE avec une croix pour vider la valeur (DPE inconnu).
  Widget _dpeField() => FormBuilderDropdown<String>(
    name: 'dpe_classe',
    initialValue: widget.immeuble?.dpeClasse,
    decoration: InputDecoration(
      labelText: 'Classe DPE',
      helperText: 'Diagnostic de Performance Énergétique',
      prefixIcon: const Icon(Icons.eco_outlined),
      suffixIcon: _dpe != null
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Effacer (DPE inconnu)',
              onPressed: () {
                _formKey.currentState?.fields['dpe_classe']?.didChange(null);
                setState(() => _dpe = null);
              },
            )
          : null,
    ),
    onChanged: (v) => setState(() => _dpe = v),
    items: ['A', 'B', 'C', 'D', 'E', 'F', 'G']
        .map(
          (c) => DropdownMenuItem(
            value: c,
            child: Row(
              children: [
                _DpeChip(classe: c),
                const SizedBox(width: AppSpacing.sm),
                Text(c),
              ],
            ),
          ),
        )
        .toList(),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: _kHeader,
          child: FormPageHeader(
            title: _isEditing ? "Modifier l'immeuble" : "Nouvel immeuble",
            trailing: FormHeaderActions(
              onSave: _submit,
              onClose: _handleBack,
              isSaving: _isSubmitting,
              saveLabel: _isEditing
                  ? 'Enregistrer les modifications'
                  : 'Enregistrer',
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: FormBuilder(
                    key: _formKey,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 560;
                        return FutureBuilder<_Bundle>(
                          future: _bundleFuture,
                          builder: (ctx, snap) {
                            final bundle = snap.data;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Accès au tour guidé (aide pas à pas).
                                if (!_isEditing)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: _askStartTour,
                                      icon: const Icon(
                                        Icons.school_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Faire tour guidé'),
                                    ),
                                  ),
                                if (!_isEditing)
                                  const SizedBox(height: AppSpacing.md),

                                // ══ 1 — Identification ══════════════════════
                                _sectionLabel("Identification"),
                                KeyedSubtree(
                                  key: _kType,
                                  child: _twoColumns(
                                    wide: wide,
                                    flexLeft: 1,
                                    flexRight: 2,
                                    FutureBuilder<List<ImmeubleTypeModel>>(
                                      future: _typesFuture,
                                      builder: (context, snapshot) {
                                        final items = snapshot.data ?? [];
                                        return FormBuilderDropdown<
                                          ImmeubleTypeModel
                                        >(
                                          key: ValueKey(_selectedType?.id),
                                          name: 'type',
                                          initialValue: _selectedType,
                                          decoration: const InputDecoration(
                                            labelText: "Type d'immeuble",
                                          ),
                                          items: items
                                              .map(
                                                (t) => DropdownMenuItem(
                                                  value: t,
                                                  child: Text(t.typeName),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) =>
                                              setState(() => _selectedType = v),
                                        );
                                      },
                                    ),
                                    FormBuilderTextField(
                                      name: 'name',
                                      initialValue: widget.immeuble?.name,
                                      decoration: const InputDecoration(
                                        labelText: 'Nom',
                                      ),
                                      validator:
                                          FormBuilderValidators.required(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 2 — Localisation ════════════════════════
                                _sectionLabel("Localisation"),
                                KeyedSubtree(
                                  key: _kAddress,
                                  child: AddressAutocompleteField(
                                    initialValue: _address,
                                    onChanged: (v) => _address = v,
                                    onSuggestionSelected: _onAddressSuggested,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                wide
                                    ? _threeColumns(
                                        wide: true,
                                        FormBuilderTextField(
                                          name: 'city',
                                          initialValue: widget.immeuble?.city,
                                          decoration: const InputDecoration(
                                            labelText: 'Ville',
                                          ),
                                        ),
                                        FormBuilderTextField(
                                          name: 'department',
                                          initialValue:
                                              widget.immeuble?.department,
                                          decoration: const InputDecoration(
                                            labelText: 'Département',
                                          ),
                                        ),
                                        FormBuilderTextField(
                                          name: 'region',
                                          initialValue: widget.immeuble?.region,
                                          decoration: const InputDecoration(
                                            labelText: 'Région',
                                          ),
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: FormBuilderTextField(
                                                  name: 'city',
                                                  initialValue:
                                                      widget.immeuble?.city,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Ville',
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.md,
                                              ),
                                              Expanded(
                                                child: FormBuilderTextField(
                                                  name: 'department',
                                                  initialValue: widget
                                                      .immeuble
                                                      ?.department,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'Département',
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          FormBuilderTextField(
                                            name: 'region',
                                            initialValue:
                                                widget.immeuble?.region,
                                            decoration: const InputDecoration(
                                              labelText: 'Région',
                                            ),
                                          ),
                                        ],
                                      ),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 3 — Caractéristiques ════════════════════
                                _sectionLabel("Caractéristiques"),
                                wide
                                    ? Row(
                                        children: [
                                          Expanded(
                                            child: FormBuilderTextField(
                                              name: 'total_m2',
                                              initialValue: widget
                                                  .immeuble
                                                  ?.totalM2
                                                  ?.toStringAsFixed(2),
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Surface totale (m²)',
                                              ),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          const Expanded(child: SizedBox()),
                                        ],
                                      )
                                    : FormBuilderTextField(
                                        name: 'total_m2',
                                        initialValue: widget.immeuble?.totalM2
                                            ?.toStringAsFixed(2),
                                        decoration: const InputDecoration(
                                          labelText: 'Surface totale (m²)',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                      ),
                                const SizedBox(height: AppSpacing.md),
                                FormBuilderTextField(
                                  name: 'description',
                                  initialValue: widget.immeuble?.description,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                    alignLabelWithHint: true,
                                  ),
                                  maxLines: 4,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 4 — Photos ══════════════════════════════
                                _sectionLabel("Photos des espaces communs"),
                                KeyedSubtree(
                                  key: _kPhotos,
                                  child: PhotoPickerField(
                                    folder: 'immeubles',
                                    initialPhotos: _photos,
                                    initialMainPhoto: _mainPhoto,
                                    onChanged: (urls) =>
                                        setState(() => _photos = urls),
                                    onMainPhotoChanged: (url) =>
                                        setState(() => _mainPhoto = url),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 5 — Type de bail ════════════════════════
                                _sectionLabel("Type de bail"),
                                KeyedSubtree(
                                  key: _kBail,
                                  child: _twoColumns(
                                    wide: wide,
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 360,
                                      ),
                                      child: FormBuilderCheckbox(
                                        name: 'bail_location',
                                        initialValue:
                                            widget.immeuble?.bailLocation ??
                                            false,
                                        title: const Text('Location'),
                                        subtitle: const Text(
                                          'Un seul contrat pour toutes les chambres de l\'immeuble.',
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        onChanged: (v) {
                                          setState(
                                            () => _isBailLocation = v ?? false,
                                          );
                                          if (v == true) {
                                            _formKey
                                                .currentState
                                                ?.fields['bail_individuel']
                                                ?.didChange(false);
                                          }
                                        },
                                      ),
                                    ),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 360,
                                      ),
                                      child: FormBuilderCheckbox(
                                        name: 'bail_individuel',
                                        initialValue:
                                            widget.immeuble?.bailIndividuel ??
                                            false,
                                        title: const Text(
                                          'Bail individuel (Colocation)',
                                        ),
                                        subtitle: const Text(
                                          'Contrat séparé pour chaque chambre.',
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        onChanged: (v) {
                                          if (v == true) {
                                            setState(
                                              () => _isBailLocation = false,
                                            );
                                            _formKey
                                                .currentState
                                                ?.fields['bail_location']
                                                ?.didChange(false);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                if (_isBailLocation) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  wide
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: FormBuilderTextField(
                                                name: 'prix_loyer',
                                                initialValue: widget
                                                    .immeuble
                                                    ?.prixLoyer
                                                    ?.toStringAsFixed(2),
                                                decoration: const InputDecoration(
                                                  labelText:
                                                      'Valeur du loyer (€/mois)',
                                                  prefixText: '€ ',
                                                ),
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.md,
                                            ),
                                            const Expanded(child: SizedBox()),
                                          ],
                                        )
                                      : FormBuilderTextField(
                                          name: 'prix_loyer',
                                          initialValue: widget
                                              .immeuble
                                              ?.prixLoyer
                                              ?.toStringAsFixed(2),
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Valeur du loyer (€/mois)',
                                            prefixText: '€ ',
                                          ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                ],
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 6 — Informations contractuelles ═════════
                                _sectionLabel("Informations contractuelles"),
                                _twoColumns(
                                  wide: wide,
                                  FormBuilderDropdown<bool>(
                                    name: 'location_meuble',
                                    initialValue: _meuble,
                                    decoration: const InputDecoration(
                                      labelText: 'Location meublée ?',
                                      prefixIcon: Icon(Icons.chair_outlined),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: true,
                                        child: Text('Oui'),
                                      ),
                                      DropdownMenuItem(
                                        value: false,
                                        child: Text('Non'),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _meuble = v),
                                  ),
                                  const SizedBox.shrink(),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _twoColumns(
                                  wide: wide,
                                  _depotField(),
                                  NumberStepperField(
                                    name: 'duree_bail_mois',
                                    initialValue:
                                        widget.immeuble?.dureeBailMois
                                            ?.toString() ??
                                        (_meuble == true ? '12' : '36'),
                                    labelText: 'Durée du bail (mois)',
                                    helperText:
                                        'Minimum légal : 12 mois (meublé) · 36 mois (non meublé)',
                                    prefixIcon: Icons.calendar_month_outlined,
                                    min: 1,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _twoColumns(
                                  wide: wide,
                                  _dpeField(),
                                  FormBuilderTextField(
                                    name: 'irl_reference',
                                    initialValue: widget.immeuble?.irlReference,
                                    decoration: const InputDecoration(
                                      labelText: 'Référence IRL',
                                      helperText: 'Ex. : T2 2025 — 145,56',
                                      prefixIcon: Icon(
                                        Icons.trending_up_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 7 — Parties communes ════════════════════
                                _sectionLabel("Parties communes"),
                                _partiesCommunesBody(),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 7b — Électroménager ═════════════════════
                                _sectionLabel("Électroménager"),
                                _electromenagerBody(),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.md),

                                // ══ 8 — Charges locatives ═══════════════════
                                _chargesAccordion(bundle),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.sm),

                                // ══ 9 — Statut ══════════════════════════════
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 480,
                                  ),
                                  child: FormBuilderCheckbox(
                                    name: 'desactiver',
                                    initialValue:
                                        !(widget.immeuble?.isActive ?? true),
                                    title: const Text('Désactiver immeuble'),
                                    subtitle: const Text(
                                      'Le Immeuble et toutes les chambres seront masquées du site public.',
                                    ),
                                    activeColor: AppColors.error,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Bundle {
  final List<ChargeReferenceModel> chargesRef;
  _Bundle({required this.chargesRef});
}

/// Ligne de sélection d'une pièce commune : case à cocher + nom, et — une fois
/// cochée — le sélecteur de quantité juste à côté.
class _PieceSelectRow extends StatelessWidget {
  final String nom;
  final PieceDraft? draft;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onQuantite;

  const _PieceSelectRow({
    required this.nom,
    required this.draft,
    required this.onToggle,
    required this.onQuantite,
  });

  @override
  Widget build(BuildContext context) {
    final selected = draft != null;
    return Row(
      children: [
        Checkbox(
          value: selected,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (v) => onToggle(v ?? false),
        ),
        Expanded(
          child: Text(
            nom,
            style: AppTypography.bodyMd,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (selected) ...[
          const SizedBox(width: AppSpacing.xs),
          QuantityStepper(value: draft!.quantite, onChanged: onQuantite),
        ],
      ],
    );
  }
}

/// Chip coloré selon la classe DPE (A=vert foncé → G=rouge foncé).
class _DpeChip extends StatelessWidget {
  final String classe;
  const _DpeChip({required this.classe});

  static const _colors = {
    'A': Color(0xFF1A7A3A),
    'B': Color(0xFF4CAF50),
    'C': Color(0xFFA5C727),
    'D': Color(0xFFF9C74F),
    'E': Color(0xFFF4A261),
    'F': Color(0xFFE76F51),
    'G': Color(0xFFAB2328),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[classe] ?? Colors.grey;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        classe,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
