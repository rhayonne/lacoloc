import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/presentation/widgets/app_list_search_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Pop-up de sélection d'un EDL d'**entrée finalisée** pour créer l'EDL de
/// **sortie** couplé. Liste les entrées éligibles (location commune + privatifs
/// individuels) avec lieu, type et date de finalisation. Retourne l'entrée
/// choisie ou null (annulé).
Future<EtatDesLieuxModel?> showSelectEntreeForSortieDialog(
  BuildContext context,
  List<EtatDesLieuxModel> entrees,
) {
  return showDialog<EtatDesLieuxModel>(
    context: context,
    builder: (_) => _SelectEntreeDialog(entrees: entrees),
  );
}

class _SelectEntreeDialog extends StatefulWidget {
  final List<EtatDesLieuxModel> entrees;
  const _SelectEntreeDialog({required this.entrees});

  @override
  State<_SelectEntreeDialog> createState() => _SelectEntreeDialogState();
}

class _SelectEntreeDialogState extends State<_SelectEntreeDialog> {
  String _query = '';

  @override
  void dispose() {
    super.dispose();
  }

  List<EtatDesLieuxModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.entrees;
    return widget.entrees.where((e) {
      final hay = [
        e.lieuLabel,
        e.displayLocataire,
        e.immeubleTypeLabel,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.logout, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Créer un état des lieux de sortie',
                      style: AppTypography.titleLg,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "Choisissez l'entrée finalisée à partir de laquelle créer la "
                'sortie. La structure sera reprise et les observations '
                "d'entrée affichées en contrepoint.",
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              AppListSearchField(
                hint: 'Rechercher (immeuble, chambre, locataire)…',
                onChanged: (q) => setState(() => _query = q),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Aucune entrée finalisée disponible.',
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) => _EntreeCard(
                          edl: filtered[i],
                          onTap: () => Navigator.pop(context, filtered[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntreeCard extends StatelessWidget {
  final EtatDesLieuxModel edl;
  final VoidCallback onTap;
  const _EntreeCard({required this.edl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFin = edl.dateFinalisationFormatted ?? edl.dateEdlFormatted;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: AppColors.outlineVariant),
          color: AppColors.surfaceContainerLowest,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edl.lieuLabel,
                    style: AppTypography.titleLs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    edl.displayLocataire,
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _pill(edl.typeLabel),
                      _pill(edl.meubleLabel),
                      _pill('Finalisé le $dateFin'),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: AppRadius.borderSm,
        ),
        child: Text(label, style: AppTypography.labelSm),
      );
}
