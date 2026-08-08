import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:habitafrance/data/models/etat_de_lieux.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Résultat du dialogue de sélection d'année scolaire pour un nouveau privatif.
///
/// - [collectif] non-null + ouvert → réutiliser ce collectif.
/// - [collectif] non-null + finalisé → avenant sur ce collectif.
/// - [collectif] null + [forceNew] true → créer un nouveau collectif.
class CollectifChoice {
  final EtatDesLieuxModel? collectif;
  final bool forceNew;

  const CollectifChoice.reuse(EtatDesLieuxModel c)
      : collectif = c,
        forceNew = false;

  const CollectifChoice.avenant(EtatDesLieuxModel c)
      : collectif = c,
        forceNew = false;

  const CollectifChoice.nouveau()
      : collectif = null,
        forceNew = true;

  bool get isAvenant =>
      collectif != null && collectif!.situation == SituationEdl.finalise;
}

/// Calcule l'année scolaire (sept–août) à partir d'une date.
/// Ex. : 2024-09-01 → "2024-2025" · 2025-06-15 → "2024-2025".
String anneeLetive(DateTime date) {
  final startYear = date.month >= 9 ? date.year : date.year - 1;
  return '$startYear–${startYear + 1}';
}

bool memeAnneeLetive(DateTime a, DateTime b) {
  final aStart = a.month >= 9 ? a.year : a.year - 1;
  final bStart = b.month >= 9 ? b.year : b.year - 1;
  return aStart == bStart;
}

/// Dialogue « Contrat de base » affiché lors de la création d'un nouvel EDL
/// individuel quand il existe déjà des collectifs pour cet immeuble.
///
/// Retourne [CollectifChoice] ou null si l'utilisateur annule.
Future<CollectifChoice?> showSelectAnneeDialog(
  BuildContext context, {
  required String immeubleNom,
  required List<EtatDesLieuxModel> collectifs,
}) {
  final dateFmt = DateFormat('dd/MM/yyyy');
  final now = DateTime.now();
  final anneeActuelle = anneeLetive(now);

  return showDialog<CollectifChoice>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                'Contrat de base — $immeubleNom',
                style: AppTypography.titleLg,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Choisissez à quel contrat rattacher cette chambre.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  // Option « Nouveau contrat [année actuelle] »
                  _CollectifTile(
                    label: 'Nouveau contrat',
                    sublabel: anneeActuelle,
                    icon: Icons.add_circle_outline,
                    badgeText: anneeActuelle,
                    badgeColor: AppColors.primaryFixed,
                    badgeTextColor: AppColors.onPrimaryFixedVariant,
                    isNew: true,
                    onTap: () =>
                        Navigator.pop(ctx, const CollectifChoice.nouveau()),
                  ),
                  const Divider(height: 1),
                  // Collectifs existants
                  for (final c in collectifs) ...[
                    _CollectifExistantTile(
                      collectif: c,
                      dateFmt: dateFmt,
                      isSameYear: memeAnneeLetive(c.dateEtatLieux, now),
                      onTap: () => Navigator.pop(
                        ctx,
                        c.situation == SituationEdl.finalise
                            ? CollectifChoice.avenant(c)
                            : CollectifChoice.reuse(c),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
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

class _CollectifTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final String badgeText;
  final Color badgeColor;
  final Color badgeTextColor;
  final bool isNew;
  final VoidCallback onTap;

  const _CollectifTile({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.isNew,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isNew ? AppColors.primary : AppColors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isNew ? AppColors.primary : null,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _Badge(
              text: badgeText,
              color: badgeColor,
              textColor: badgeTextColor,
            ),
            Icon(Icons.chevron_right,
                color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _CollectifExistantTile extends StatelessWidget {
  final EtatDesLieuxModel collectif;
  final DateFormat dateFmt;
  final bool isSameYear;
  final VoidCallback onTap;

  const _CollectifExistantTile({
    required this.collectif,
    required this.dateFmt,
    required this.isSameYear,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = collectif;
    final annee = anneeLetive(c.dateEtatLieux);
    final isFinalise = c.situation == SituationEdl.finalise;
    final badgeColor =
        isFinalise ? AppColors.surfaceVariant : AppColors.successContainer;
    final badgeTextColor =
        isFinalise ? AppColors.onSurfaceVariant : AppColors.onSuccessContainer;
    final statusLabel = isFinalise ? 'Finalisé' : 'En cours';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              color: isSameYear
                  ? AppColors.onSurfaceVariant
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        annee,
                        style: AppTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSameYear
                              ? null
                              : AppColors.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                      if (!isSameYear) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '(année précédente)',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    'EDL du ${dateFmt.format(c.dateEtatLieux)}'
                    '${isFinalise ? ' · avenant' : ''}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _Badge(
              text: statusLabel,
              color: badgeColor,
              textColor: badgeTextColor,
            ),
            Icon(Icons.chevron_right,
                color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(
        text,
        style: AppTypography.labelSm.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
