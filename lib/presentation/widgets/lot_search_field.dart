import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/immeuble_lot.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Champ de recherche de lot de copropriété, réutilisable — même famille que
/// [LocataireSearchField] : liste de résultats **en ligne** (pas d'overlay).
/// Filtre côté client sur [lots] (catalogue déjà chargé, cache) par numéro de
/// lot / nom de copropriété.
class LotSearchField extends StatefulWidget {
  final List<ImmeubleLotModel> lots;
  final Set<int> selectedIds;
  final ValueChanged<ImmeubleLotModel> onSelect;

  /// « Ajouter un lot » — ouvre le formulaire de création (l'appelant gère la
  /// persistance et l'ajout à la sélection).
  final VoidCallback? onCreateNew;

  final String hintText;

  const LotSearchField({
    super.key,
    required this.lots,
    required this.onSelect,
    this.selectedIds = const {},
    this.onCreateNew,
    this.hintText = 'Rechercher un lot (numéro, copropriété…)…',
  });

  @override
  State<LotSearchField> createState() => _LotSearchFieldState();
}

class _LotSearchFieldState extends State<LotSearchField> {
  final _ctrl = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<ImmeubleLotModel> get _results {
    final q = _ctrl.text.trim().toLowerCase();
    final all = widget.lots;
    if (q.isEmpty) return all;
    return all.where((l) {
      return l.numeroLot.toLowerCase().contains(q) ||
          (l.nomCopropriete?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _clear() {
    _ctrl.clear();
    setState(() => _open = false);
  }

  void _pick(ImmeubleLotModel lot) {
    if (widget.selectedIds.contains(lot.id)) return;
    widget.onSelect(lot);
    _clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctrl,
          onChanged: (_) => setState(() => _open = true),
          onTap: () => setState(() => _open = true),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Effacer la recherche',
                    onPressed: _clear,
                  )
                : null,
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
    final results = _results;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: AppRadius.borderSm,
        color: AppColors.surfaceContainerLowest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.lots.isEmpty
                      ? 'Aucun lot dans votre catalogue.'
                      : 'Aucun lot trouvé.',
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            )
          else
            ...results.take(8).map((l) {
              final already = widget.selectedIds.contains(l.id);
              return ListTile(
                dense: true,
                enabled: !already,
                title: Text(l.displayLabel),
                subtitle: Text(
                  [l.typeLot.label, if (l.immeubleNom != null) 'rattaché à ${l.immeubleNom}']
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: already
                    ? const Icon(Icons.check, size: 18, color: AppColors.primary)
                    : null,
                onTap: already ? null : () => _pick(l),
              );
            }),
          if (widget.onCreateNew != null) ...[
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, size: 20, color: AppColors.primary),
              title: Text('Ajouter un lot',
                  style: AppTypography.labelMd.copyWith(color: AppColors.primary)),
              onTap: widget.onCreateNew,
            ),
          ],
        ],
      ),
    );
  }
}
