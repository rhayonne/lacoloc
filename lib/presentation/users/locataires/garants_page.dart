import 'package:flutter/material.dart';
import 'package:habitafrance/presentation/widgets/app_date_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/datasources/garants.dart';
import 'package:habitafrance/data/datasources/etat_de_lieux.dart';
import 'package:habitafrance/data/models/address_suggestion.dart';
import 'package:habitafrance/data/models/garant.dart';
import 'package:habitafrance/presentation/widgets/app_list_search_field.dart';
import 'package:habitafrance/presentation/widgets/address_autocomplete_field.dart';
import 'package:habitafrance/presentation/widgets/unsaved_changes_dialog.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/utils/phone_field.dart';

class GarantsPage extends StatefulWidget {
  const GarantsPage({super.key});

  @override
  State<GarantsPage> createState() => _GarantsPageState();
}

class _GarantsPageState extends State<GarantsPage> {
  late Future<List<GarantModel>> _future;
  String _search = '';
  bool _showForm = false;
  GarantModel? _editing;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final f = GarantsDatasource.listByLocataire(uid);
    setState(() { _future = f; });
  }

  void _openCreation() => setState(() {
        _editing = null;
        _showForm = true;
      });

  void _openEdition(GarantModel g) => setState(() {
        _editing = g;
        _showForm = true;
      });

  void _closeForm() => setState(() {
        _showForm = false;
        _editing = null;
      });

  void _onSaved() {
    _closeForm();
    _reload();
  }

  Future<void> _toggleActive(GarantModel g) async {
    final nowActive = !g.isActive;
    try {
      await GarantsDatasource.setActive(g.id, active: nowActive);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
      return;
    }
    // Activation → rattache automatiquement ce garant aux baux en cours
    // d'édition du locataire qui exigent un garant (sans en toucher un signé).
    if (nowActive) {
      try {
        await EtatDesLieuxDatasource.autoLinkGarantsForLocataire(g.locataireId);
      } catch (_) {
        // Best-effort, mais on prévient : la promesse « inséré automatiquement
        // dans le bail » n'a pas pu être tenue cette fois.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Garant activé, mais le rattachement automatique au bail a '
                  'échoué — ouvrez le bail pour le rattacher.')));
        }
      }
    }
    _reload();
  }

  Future<void> _confirmDelete(GarantModel g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce garant ?'),
        content: Text('Voulez-vous supprimer « ${g.displayName} » ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.deleteButtonStyle,
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GarantsDatasource.delete(g.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showForm) {
      return _GarantFormWithBack(
        garant: _editing,
        locataireId: AuthService.currentUser?.id ?? '',
        onBack: _closeForm,
        onSaved: _onSaved,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── En-tête ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Garants', style: AppTypography.headlineLg),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Vos garants (caution) pour vos contrats de location. '
                      'Les garants activés sont automatiquement ajoutés aux baux générés.',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _openCreation,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau garant'),
              ),
            ],
          ),
        ),

        // ── Recherche ──────────────────────────────────────────────────────
        AppListSearchField(
          hint: 'Rechercher par nom ou e-mail…',
          onChanged: (q) => setState(() => _search = q),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Liste ──────────────────────────────────────────────────────────
        Expanded(
          child: FutureBuilder<List<GarantModel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erreur : ${snap.error}'));
              }
              final all = snap.data ?? [];
              final list = _search.isEmpty
                  ? all
                  : all.where((g) {
                      final q = _search;
                      return g.displayName.toLowerCase().contains(q) ||
                          (g.email?.toLowerCase().contains(q) ?? false) ||
                          (g.telephone?.toLowerCase().contains(q) ?? false);
                    }).toList();

              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 56, color: AppColors.outline),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucun garant enregistré',
                          style: AppTypography.titleLg),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Ajoutez vos garants pour les associer à vos baux.',
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _openCreation,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Ajouter un garant'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _GarantCard(
                  garant: list[i],
                  onEdit: () => _openEdition(list[i]),
                  onDelete: () => _confirmDelete(list[i]),
                  onToggle: () => _toggleActive(list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card garant (style Utilisateurs & Groupes)

class _GarantCard extends StatefulWidget {
  final GarantModel garant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _GarantCard({
    required this.garant,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  State<_GarantCard> createState() => _GarantCardState();
}

class _GarantCardState extends State<_GarantCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.garant;
    final initials = g.displayName.isNotEmpty
        ? g.displayName.trim()[0].toUpperCase()
        : '?';

    return Column(
      children: [
        // ── Ligne principale ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: g.isActive
                    ? AppColors.primaryFixed
                    : AppColors.surfaceContainerHighest,
                child: Text(initials,
                    style: AppTypography.labelMd.copyWith(
                        color: g.isActive
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant)),
              ),
              const SizedBox(width: AppSpacing.md),

              // Nom + type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.displayName, style: AppTypography.bodyMd),
                    Row(
                      children: [
                        if (g.email != null)
                          Text(g.email!,
                              style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant)),
                        if (g.email != null && g.telephone != null)
                          Text(' · ',
                              style: AppTypography.labelSm
                                  .copyWith(color: AppColors.onSurfaceVariant)),
                        if (g.telephone != null)
                          Text(g.telephone!,
                              style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '${g.typeGarantLabel} · ${g.typeCautionLabel}',
                          style: AppTypography.labelSm
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Statut chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: g.isActive
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.outline.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  g.isActive ? 'Actif' : 'Inactif',
                  style: AppTypography.labelSm.copyWith(
                      color: g.isActive
                          ? AppColors.success
                          : AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Bouton « Données » (accordion)
              OutlinedButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_outlined, size: 16),
                    const SizedBox(width: 4),
                    const Text('Données'),
                    const SizedBox(width: 4),
                    Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Bouton modifier
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Modifier',
                onPressed: widget.onEdit,
              ),

              // Toggle actif/inactif
              Tooltip(
                message: g.isActive
                    ? 'Désactiver (ne sera plus ajouté aux baux générés)'
                    : 'Activer (sera ajouté automatiquement aux baux générés)',
                child: Switch(
                  value: g.isActive,
                  onChanged: (_) => widget.onToggle(),
                ),
              ),

              // Supprimer
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Supprimer',
                color: AppColors.error,
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ),

        // ── Accordion données ──────────────────────────────────────────────
        if (_expanded)
          _GarantDonneesPanel(garant: g),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panneau dépliable des données du garant

class _GarantDonneesPanel extends StatelessWidget {
  final GarantModel garant;
  const _GarantDonneesPanel({required this.garant});

  @override
  Widget build(BuildContext context) {
    final g = garant;
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Container(
      margin: const EdgeInsets.only(
          left: AppSpacing.xl, bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: AppRadius.borderMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section identité
          _DonneeSection(
            title: 'Identité',
            rows: [
              _DonneeRow('Nom', g.nom),
              if (g.prenom != null) _DonneeRow('Prénom', g.prenom!),
              if (g.dateNaissance != null)
                _DonneeRow('Date de naissance', g.dateNaissanceFormatted!),
              if (g.lieuNaissance != null)
                _DonneeRow('Lieu de naissance', g.lieuNaissance!),
              if (g.nationalite != null)
                _DonneeRow('Nationalité', g.nationalite!),
            ],
          ),
          if (g.typeGarant == 'morale') ...[
            const SizedBox(height: AppSpacing.sm),
            _DonneeSection(
              title: 'Personne morale',
              rows: [
                if (g.raisonSociale != null)
                  _DonneeRow('Raison sociale', g.raisonSociale!),
                if (g.siret != null) _DonneeRow('SIRET', g.siret!),
                if (g.representantLegal != null)
                  _DonneeRow('Représentant légal', g.representantLegal!),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _DonneeSection(
            title: 'Coordonnées',
            rows: [
              if (g.adresse != null) _DonneeRow('Adresse', g.adresse!),
              if (g.codePostal != null) _DonneeRow('Code postal', g.codePostal!),
              if (g.ville != null) _DonneeRow('Ville', g.ville!),
              if (g.email != null) _DonneeRow('E-mail', g.email!),
              if (g.telephone != null) _DonneeRow('Téléphone', g.telephone!),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DonneeSection(
            title: 'Situation professionnelle',
            rows: [
              if (g.profession != null) _DonneeRow('Profession', g.profession!),
              if (g.employeur != null) _DonneeRow('Employeur', g.employeur!),
              if (g.revenuMensuelNet != null)
                _DonneeRow(
                    'Revenu mensuel net', fmt.format(g.revenuMensuelNet!)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DonneeSection(
            title: 'Données bancaires (RIB)',
            rows: [
              if (g.titulaireCompte != null)
                _DonneeRow('Titulaire', g.titulaireCompte!),
              if (g.iban != null) _DonneeRow('IBAN', g.iban!),
              if (g.bic != null) _DonneeRow('BIC', g.bic!),
            ],
          ),
          if (g.notes?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            _DonneeSection(
              title: 'Notes',
              rows: [_DonneeRow('', g.notes!)],
            ),
          ],
        ],
      ),
    );
  }
}

class _DonneeSection extends StatelessWidget {
  final String title;
  final List<_DonneeRow> rows;
  const _DonneeSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xs),
        ...rows,
      ],
    );
  }
}

class _DonneeRow extends StatelessWidget {
  final String label;
  final String value;
  const _DonneeRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 160,
              child: Text(label,
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ],
          Expanded(
              child: Text(value, style: AppTypography.bodyMd)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulaire garant (avec bouton retour)

class _GarantFormWithBack extends StatefulWidget {
  final GarantModel? garant;
  final String locataireId;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  const _GarantFormWithBack({
    required this.locataireId,
    required this.onBack,
    required this.onSaved,
    this.garant,
  });

  @override
  State<_GarantFormWithBack> createState() => _GarantFormWithBackState();
}

class _GarantFormWithBackState extends State<_GarantFormWithBack> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isSubmitting = false;
  bool _dirty = false;
  String _typeGarant = 'physique';

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  /// Aligne 2 champs sur une ligne (desktop/tablette, le formulaire fait au
  /// plus 600px de large) ; les empile en colonne sur mobile pour éviter des
  /// champs trop étroits (ex. « Code postal » à largeur fixe qui écrasait
  /// « Ville » sur petit écran). [flexes] permet des largeurs proportionnelles
  /// différentes (ex. Code postal plus étroit que Ville).
  Widget _responsiveFields(List<Widget> fields, {List<int>? flexes}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
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
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(flex: flexes?[i] ?? 1, child: fields[i]),
            ],
          ],
        );
      },
    );
  }

  /// Retour avec confirmation si des modifications non sauvegardées existent.
  Future<void> _handleBack() async {
    if (!_dirty) {
      widget.onBack();
      return;
    }
    final choice = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (choice) {
      case UnsavedChoice.cancel:
        return;
      case UnsavedChoice.discard:
        widget.onBack();
      case UnsavedChoice.save:
        await _submit();
    }
  }

  // Contrôleurs pour les champs hors FormBuilder
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _codePostalCtrl;
  late final TextEditingController _villeCtrl;
  DateTime? _dateNaissance;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get _isEditing => widget.garant != null;

  @override
  void initState() {
    super.initState();
    _typeGarant = widget.garant?.typeGarant ?? 'physique';
    _adresseCtrl = TextEditingController(text: widget.garant?.adresse ?? '');
    _codePostalCtrl = TextEditingController(text: widget.garant?.codePostal ?? '');
    _villeCtrl = TextEditingController(text: widget.garant?.ville ?? '');
    _dateNaissance = widget.garant?.dateNaissance;
    for (final c in [_adresseCtrl, _codePostalCtrl, _villeCtrl]) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _adresseCtrl.dispose();
    _codePostalCtrl.dispose();
    _villeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateNaissance() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context,
      initial: _dateNaissance ?? DateTime(now.year - 30),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 16, now.month, now.day),
    );
    if (picked != null && mounted) setState(() => _dateNaissance = picked);
  }

  void _onAddressSelected(AddressSuggestion s) {
    _adresseCtrl.text = s.label;
    _codePostalCtrl.text = s.postcode;
    _villeCtrl.text = s.city;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final v = _formKey.currentState!.value;
    setState(() => _isSubmitting = true);

    try {
      final garant = GarantModel(
        id: widget.garant?.id ?? 0,
        locataireId: widget.locataireId,
        typeGarant: _typeGarant,
        typeCaution: v['type_caution'] as String? ?? 'solidaire',
        isActive: widget.garant?.isActive ?? true,
        nom: (v['nom'] as String).trim(),
        prenom: (v['prenom'] as String?)?.trim().nullIfEmpty,
        dateNaissance: _dateNaissance,
        lieuNaissance: (v['lieu_naissance'] as String?)?.trim().nullIfEmpty,
        nationalite: (v['nationalite'] as String?)?.trim().nullIfEmpty,
        adresse: _adresseCtrl.text.trim().nullIfEmpty,
        codePostal: _codePostalCtrl.text.trim().nullIfEmpty,
        ville: _villeCtrl.text.trim().nullIfEmpty,
        email: (v['email'] as String?)?.trim().nullIfEmpty,
        telephone: PhoneField.fullNumberFromState(_formKey.currentState!, 'telephone')?.nullIfEmpty,
        profession: (v['profession'] as String?)?.trim().nullIfEmpty,
        employeur: (v['employeur'] as String?)?.trim().nullIfEmpty,
        revenuMensuelNet: double.tryParse(
            (v['revenu_mensuel_net'] as String?)?.trim() ?? ''),
        iban: (v['iban'] as String?)?.trim().nullIfEmpty,
        bic: (v['bic'] as String?)?.trim().nullIfEmpty,
        titulaireCompte: (v['titulaire_compte'] as String?)?.trim().nullIfEmpty,
        raisonSociale: (v['raison_sociale'] as String?)?.trim().nullIfEmpty,
        siret: (v['siret'] as String?)?.trim().nullIfEmpty,
        representantLegal:
            (v['representant_legal'] as String?)?.trim().nullIfEmpty,
        notes: (v['notes'] as String?)?.trim().nullIfEmpty,
        createdAt: widget.garant?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await GarantsDatasource.update(garant);
      } else {
        await GarantsDatasource.create(garant);
      }

      // Garant actif → insertion automatique dans les baux en cours d'édition
      // du locataire qui exigent un garant (les baux signés ne sont pas touchés).
      if (garant.isActive) {
        try {
          await EtatDesLieuxDatasource.autoLinkGarantsForLocataire(
              widget.locataireId);
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing ? 'Garant modifié' : 'Garant ajouté'),
      ));
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.garant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg,
              AppSpacing.xl, 0),
          child: Row(
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBack,
                tooltip: 'Retour à la liste',
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                _isEditing ? 'Modifier le garant' : 'Nouveau garant',
                style: AppTypography.titleLg,
              ),
            ],
          ),
        ),
        // Formulaire
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: FormBuilder(
                  key: _formKey,
                  onChanged: _markDirty,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Type de garant ───────────────────────────────────
                      Text('Type de garant', style: AppTypography.labelMd),
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'physique',
                              label: Text('Personne physique'),
                              icon: Icon(Icons.person_outline)),
                          ButtonSegment(
                              value: 'morale',
                              label: Text('Personne morale'),
                              icon: Icon(Icons.business_outlined)),
                        ],
                        selected: {_typeGarant},
                        onSelectionChanged: (s) =>
                            setState(() => _typeGarant = s.first),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Type de caution ──────────────────────────────────
                      FormBuilderDropdown<String>(
                        name: 'type_caution',
                        initialValue: g?.typeCaution ?? 'solidaire',
                        decoration: const InputDecoration(
                            labelText: 'Type de caution *'),
                        items: const [
                          DropdownMenuItem(
                              value: 'solidaire',
                              child: Text('Caution solidaire (recommandée)')),
                          DropdownMenuItem(
                              value: 'simple',
                              child: Text('Caution simple')),
                        ],
                        validator: FormBuilderValidators.required(),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Identité ─────────────────────────────────────────
                      _SectionHeader(
                        icon: Icons.badge_outlined,
                        label: _typeGarant == 'morale'
                            ? 'Informations entreprise'
                            : 'Identité',
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Nom (toujours présent — label adapté au type) ───
                      FormBuilderTextField(
                        name: 'nom',
                        initialValue: g?.nom,
                        decoration: InputDecoration(
                          labelText: _typeGarant == 'morale'
                              ? 'Nom de contact *'
                              : 'Nom *',
                        ),
                        validator: FormBuilderValidators.required(),
                        textCapitalization: TextCapitalization.characters,
                      ),

                      // ── Personne physique : prénom + dates ───────────────
                      if (_typeGarant == 'physique') ...[
                        const SizedBox(height: AppSpacing.md),
                        FormBuilderTextField(
                          name: 'prenom',
                          initialValue: g?.prenom,
                          decoration:
                              const InputDecoration(labelText: 'Prénom'),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _responsiveFields([
                          TextFormField(
                            readOnly: true,
                            onTap: _pickDateNaissance,
                            decoration: InputDecoration(
                              labelText: 'Date de naissance',
                              hintText: 'jj/mm/aaaa',
                              suffixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18),
                            ),
                            controller: TextEditingController(
                              text: _dateNaissance != null
                                  ? _dateFmt.format(_dateNaissance!)
                                  : '',
                            ),
                          ),
                          FormBuilderTextField(
                            name: 'lieu_naissance',
                            initialValue: g?.lieuNaissance,
                            decoration: const InputDecoration(
                                labelText: 'Lieu de naissance'),
                          ),
                        ]),
                        const SizedBox(height: AppSpacing.md),
                        FormBuilderTextField(
                          name: 'nationalite',
                          initialValue: g?.nationalite ?? 'Française',
                          decoration:
                              const InputDecoration(labelText: 'Nationalité'),
                        ),
                      ],

                      // ── Personne morale : raison sociale, SIRET, représentant
                      if (_typeGarant == 'morale') ...[
                        const SizedBox(height: AppSpacing.md),
                        FormBuilderTextField(
                          name: 'raison_sociale',
                          initialValue: g?.raisonSociale,
                          decoration: const InputDecoration(
                              labelText: 'Raison sociale *'),
                          validator: FormBuilderValidators.required(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FormBuilderTextField(
                          name: 'siret',
                          initialValue: g?.siret,
                          decoration:
                              const InputDecoration(labelText: 'SIRET'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(14),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FormBuilderTextField(
                          name: 'representant_legal',
                          initialValue: g?.representantLegal,
                          decoration: const InputDecoration(
                              labelText: 'Représentant légal'),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),

                      // ── Coordonnées ──────────────────────────────────────
                      const _SectionHeader(
                          icon: Icons.location_on_outlined,
                          label: 'Coordonnées'),
                      const SizedBox(height: AppSpacing.md),
                      // Autocomplete via API Adresse (BAN) — remplit CP + ville automatiquement
                      AddressAutocompleteField(
                        initialValue: _adresseCtrl.text,
                        onChanged: (v) => _adresseCtrl.text = v,
                        onSuggestionSelected: _onAddressSelected,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _responsiveFields([
                        TextFormField(
                          controller: _codePostalCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Code postal'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                        ),
                        TextFormField(
                          controller: _villeCtrl,
                          decoration: const InputDecoration(labelText: 'Ville'),
                        ),
                      ], flexes: const [1, 2]),
                      const SizedBox(height: AppSpacing.md),
                      FormBuilderTextField(
                        name: 'email',
                        initialValue: g?.email,
                        decoration: const InputDecoration(
                            labelText: 'E-mail',
                            hintText: 'contact@exemple.fr'),
                        keyboardType: TextInputType.emailAddress,
                        validator: FormBuilderValidators.compose([
                          (v) {
                            if (v != null &&
                                v.isNotEmpty &&
                                !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) {
                              return 'Adresse e-mail invalide';
                            }
                            return null;
                          }
                        ]),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PhoneField(
                        name: 'telephone',
                        initialValue: g?.telephone,
                        labelText: 'Téléphone',
                        required: false,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Situation professionnelle ─────────────────────────
                      const _SectionHeader(
                          icon: Icons.work_outline,
                          label: 'Situation professionnelle'),
                      const SizedBox(height: AppSpacing.md),
                      FormBuilderTextField(
                        name: 'profession',
                        initialValue: g?.profession,
                        decoration:
                            const InputDecoration(labelText: 'Profession'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FormBuilderTextField(
                        name: 'employeur',
                        initialValue: g?.employeur,
                        decoration:
                            const InputDecoration(labelText: 'Employeur'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FormBuilderTextField(
                        name: 'revenu_mensuel_net',
                        initialValue: g?.revenuMensuelNet?.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Revenu mensuel net (€)',
                          suffixText: '€',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Données bancaires ─────────────────────────────────
                      const _SectionHeader(
                          icon: Icons.account_balance_outlined,
                          label: 'Données bancaires (RIB)'),
                      const SizedBox(height: AppSpacing.md),
                      FormBuilderTextField(
                        name: 'titulaire_compte',
                        initialValue: g?.titulaireCompte,
                        decoration: const InputDecoration(
                            labelText: 'Titulaire du compte'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FormBuilderTextField(
                        name: 'iban',
                        initialValue: g?.iban,
                        decoration: const InputDecoration(
                            labelText: 'IBAN',
                            hintText: 'FR76 …'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FormBuilderTextField(
                        name: 'bic',
                        initialValue: g?.bic,
                        decoration:
                            const InputDecoration(labelText: 'BIC / SWIFT'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Notes ─────────────────────────────────────────────
                      FormBuilderTextField(
                        name: 'notes',
                        initialValue: g?.notes,
                        decoration:
                            const InputDecoration(labelText: 'Notes internes'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Actions ───────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: widget.onBack,
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            style: AppTheme.saveButtonStyle,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(_isEditing
                                ? 'Enregistrer'
                                : 'Ajouter le garant'),
                          ),
                        ],
                      ),
                    ],
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(label,
            style:
                AppTypography.titleLg.copyWith(color: AppColors.primary)),
        const SizedBox(width: AppSpacing.md),
        const Expanded(child: Divider()),
      ],
    );
  }
}

extension _StrExt on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
