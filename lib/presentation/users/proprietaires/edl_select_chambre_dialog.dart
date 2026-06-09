import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Dialog de sélection d'une chambre pour un EDL individuel (l'unité louée est
/// la chambre). Affiche les chambres de l'immeuble avec m² / prix / statut.
///
/// [chambresAvecEdl] : ids des chambres qui ont déjà un EDL d'entrée ouvert →
/// la tuile est **désactivée** (non cliquable) avec un message explicatif.
///
/// Retour : `null` = annulé (X / hors du pop-up) ; `(chambre: c, back: false)` =
/// chambre choisie ; `(chambre: null, back: true)` = bouton **Retour** (revient
/// à la sélection d'immeuble).
Future<({ChambreModel? chambre, bool back})?> showSelectChambreDialog(
  BuildContext context,
  List<ChambreModel> chambres, {
  Set<int> chambresAvecEdl = const {},
}) {
  return showDialog<({ChambreModel? chambre, bool back})>(
    context: context,
    builder: (_) => _SelectChambreDialog(
      chambres: chambres,
      chambresAvecEdl: chambresAvecEdl,
    ),
  );
}

class _SelectChambreDialog extends StatefulWidget {
  final List<ChambreModel> chambres;
  final Set<int> chambresAvecEdl;
  const _SelectChambreDialog({
    required this.chambres,
    this.chambresAvecEdl = const {},
  });

  @override
  State<_SelectChambreDialog> createState() => _SelectChambreDialogState();
}

class _SelectChambreDialogState extends State<_SelectChambreDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.chambres
        : widget.chambres
            .where((c) => c.roomName.toLowerCase().contains(q))
            .toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  // Retour à la sélection de l'immeuble.
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Retour',
                    onPressed: () => Navigator.of(context)
                        .pop((chambre: null, back: true)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text('Sélectionner une chambre',
                        style: AppTypography.titleLg),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Annuler',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (widget.chambres.length > 6)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher une chambre…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'Aucune chambre dans cet immeuble.',
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _ChambreTile(
                        chambre: filtered[i],
                        hasEdl: widget.chambresAvecEdl.contains(filtered[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChambreTile extends StatelessWidget {
  final ChambreModel chambre;
  /// La chambre a déjà un EDL d'entrée ouvert → tuile désactivée.
  final bool hasEdl;
  const _ChambreTile({required this.chambre, this.hasEdl = false});

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (chambre.m2 != null) '${chambre.m2!.toStringAsFixed(0)} m²',
      if (chambre.prixLoyer != null)
        '${chambre.prixLoyer!.toStringAsFixed(0)} €',
    ].join(' · ');
    final loue = chambre.estLoue == true;

    return Opacity(
      opacity: hasEdl ? 0.6 : 1,
      child: InkWell(
        // Désactivée si un EDL d'entrée existe déjà pour cette chambre.
        onTap: hasEdl
            ? null
            : () => Navigator.of(context)
                .pop((chambre: chambre, back: false)),
        borderRadius: AppRadius.borderMd,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderMd,
            border: Border.all(
              color: hasEdl ? AppColors.error.withValues(alpha: 0.4)
                  : AppColors.outlineVariant,
            ),
            color: hasEdl ? AppColors.error.withValues(alpha: 0.04) : null,
          ),
          child: Row(
            children: [
              Icon(hasEdl ? Icons.lock_outline : Icons.bed_outlined,
                  color: hasEdl ? AppColors.error : AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chambre.roomName,
                        style: AppTypography.titleLg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (meta.isNotEmpty)
                      Text(meta,
                          style: AppTypography.labelSm
                              .copyWith(color: AppColors.onSurfaceVariant)),
                    if (hasEdl) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 13, color: AppColors.error),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "Un état des lieux d'entrée est déjà ouvert",
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (hasEdl)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text(
                    "EDL d'entrée existant",
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: loue
                        ? AppColors.error.withValues(alpha: 0.12)
                        : AppColors.tertiaryFixed,
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text(
                    loue ? 'Louée' : 'Libre',
                    style: AppTypography.labelSm.copyWith(
                      color:
                          loue ? AppColors.error : AppColors.onTertiaryFixed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right,
                    color: AppColors.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
