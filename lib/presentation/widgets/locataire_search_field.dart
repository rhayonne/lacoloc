import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Champ de recherche de locataire **réutilisable**, avec liste de résultats
/// rendue **en ligne** (sous le champ) — fiable dans tout layout (pas
/// d'OverlayPortal). Utilisé dans les EDL collectif **et** individuel.
///
/// ── PARAMÈTRES ──────────────────────────────────────────────────────────────
/// - [multiSelect] : **différencie le mode de fonctionnement**.
///     • `true`  → bail **collectif** : on peut ajouter PLUSIEURS locataires.
///       Le champ reste ouvert après chaque sélection (on enchaîne les ajouts).
///     • `false` → bail **individuel** : UN SEUL locataire. Après la sélection,
///       le champ se vide et la liste se referme.
/// - [selectedIds] : ids des locataires déjà sélectionnés. Ils apparaissent
///   marqués « déjà ajouté » et ne sont pas re-sélectionnables.
/// - [onSelect] : appelé quand l'utilisateur choisit un locataire dans la liste
///   (c'est l'appelant qui l'ajoute réellement, p.ex. crée le preneur).
/// - [onCreateNew] : appelé via « Enregistrer un nouveau locataire » (ouvre le
///   dialogue de création/invitation côté appelant).
/// - [search] : fonction de recherche. Par défaut
///   [EtatDesLieuxDatasource.searchLocataires]. Injectable pour les tests.
/// - [hintText] : texte d'aide du champ.
/// - [enabled] : si false, le champ est désactivé (lecture seule).
///
/// L'erreur de recherche n'est pas avalée : elle est affichée via un SnackBar.
class LocataireSearchField extends StatefulWidget {
  final bool multiSelect;
  final Set<String> selectedIds;
  final ValueChanged<UsersClient> onSelect;
  final VoidCallback onCreateNew;
  final Future<List<UsersClient>> Function(String query)? search;
  final String hintText;
  final bool enabled;

  const LocataireSearchField({
    super.key,
    required this.onSelect,
    required this.onCreateNew,
    this.multiSelect = true,
    this.selectedIds = const {},
    this.search,
    this.hintText = 'Rechercher un locataire (nom, e-mail)…',
    this.enabled = true,
  });

  @override
  State<LocataireSearchField> createState() => _LocataireSearchFieldState();
}

class _LocataireSearchFieldState extends State<LocataireSearchField> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<UsersClient> _results = [];
  bool _searching = false;
  bool _open = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<List<UsersClient>> _runSearch(String q) =>
      (widget.search ?? EtatDesLieuxDatasource.searchLocataires)(q);

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() => _open = true);
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final r = await _runSearch(q);
        if (!mounted) return;
        setState(() => _results = r);
      } catch (e) {
        if (!mounted) return;
        setState(() => _results = []);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Recherche indisponible : $e')));
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _clear() {
    _ctrl.clear();
    setState(() {
      _results = [];
      _open = false;
    });
  }

  void _pick(UsersClient u) {
    if (widget.selectedIds.contains(u.id)) return;
    widget.onSelect(u);
    // Individuel (un seul) → on referme ; collectif → on garde ouvert pour
    // enchaîner les ajouts (on vide juste le texte).
    if (widget.multiSelect) {
      _ctrl.clear();
      setState(() => _results = []);
    } else {
      _clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctrl,
          enabled: widget.enabled,
          onChanged: _onChanged,
          onTap: () => setState(() => _open = true),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clear,
                      )
                    : null),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildResults(),
        ],
      ],
    );
  }

  Widget _buildResults() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: AppRadius.borderSm,
        color: AppColors.surfaceContainerLowest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _ctrl.text.trim().isEmpty
                      ? 'Tapez un nom ou un e-mail…'
                      : 'Aucun locataire trouvé.',
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._results.take(6).map((u) {
              final already = widget.selectedIds.contains(u.id);
              return ListTile(
                dense: true,
                enabled: !already,
                title: Text(u.fullName ?? u.email),
                subtitle: Text(u.email,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: already
                    ? const Icon(Icons.check, size: 18, color: AppColors.primary)
                    : null,
                onTap: already ? null : () => _pick(u),
              );
            }),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_add_outlined,
                size: 20, color: AppColors.primary),
            title: Text('Enregistrer un nouveau locataire',
                style: AppTypography.labelMd.copyWith(color: AppColors.primary)),
            onTap: widget.onCreateNew,
          ),
        ],
      ),
    );
  }
}
