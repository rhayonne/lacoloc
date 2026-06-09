import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Dialogue de sélection du contrat collectif (finalisé) à amender (avenant).
///
/// Reçoit la liste des [AmendableCollectif] (collectifs finalisés ayant encore
/// des chambres libres). Pour chacun, affiche l'immeuble, la **date de l'EDL**,
/// la **date du premier contrat signé** et le nombre de chambres libres.
/// Retourne l'option choisie (ou null si annulé).
Future<AmendableCollectif?> showSelectCollectifAvenantDialog(
  BuildContext context,
  List<AmendableCollectif> options,
) {
  final dateFmt = DateFormat('dd/MM/yyyy');
  return showDialog<AmendableCollectif>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text('Avenant — choisir le contrat collectif',
                  style: AppTypography.titleLg),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final o = options[i];
                  final c = o.collectif;
                  final firstSigned = o.firstSignedDate != null
                      ? dateFmt.format(o.firstSignedDate!)
                      : '—';
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, o),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.apartment_outlined,
                              color: AppColors.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.immeubleNom ?? 'Immeuble',
                                  style: AppTypography.bodyMd
                                      .copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'EDL du ${dateFmt.format(c.dateEtatLieux)} · '
                                  '1er contrat signé : $firstSigned',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixed,
                              borderRadius: AppRadius.borderFull,
                            ),
                            child: Text(
                              '${o.freeChambres.length} libre'
                              '${o.freeChambres.length > 1 ? 's' : ''}',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onPrimaryFixedVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: AppColors.onSurfaceVariant),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
