import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Pastille SITUATION **ciente do parcours** du contrat — partagée par la
/// Vision générale du proprietaire ET la table du locataire. Elle ne montre
/// pas seulement `situation` :
///  1. **En cours / À venir** (EDL pas finalisé) ;
///  2. **« À signer »** : finalisé, le locataire n'a pas encore signé l'EDL ;
///  3. **« Bail à signer »** : EDL signé des deux parties, mais le BAIL attend
///     encore une/des signature(s) — le sous-libellé précise QUI (bailleur,
///     locataire ou les deux) ;
///  4. **« Bail signé »** : les deux signatures du bail sont posées ;
///  5. **« Finalisé »** (EDL non éligible à un bail : sortie, etc.).
class EdlParcoursBadge extends StatelessWidget {
  final EtatDesLieuxModel edl;
  const EdlParcoursBadge({super.key, required this.edl});

  @override
  Widget build(BuildContext context) {
    if (edl.situation != SituationEdl.finalise) {
      return _pill(situation: edl.situation);
    }
    if (!edl.locataireAccepte) {
      return _pill(
        label: 'À signer',
        tooltip: 'Finalisé — en attente de la signature (EDL) du locataire',
        fg: AppColors.onTertiaryFixedVariant,
        bg: AppColors.tertiaryFixed.withValues(alpha: 0.5),
        bordered: true,
      );
    }
    if (edl.isBailEligible) {
      if (edl.bailResilie) {
        return _pill(
          label: 'Bail résilié',
          tooltip: edl.bailFinEffective != null
              ? 'Bail résilié — fin effective le '
                  '${edl.bailFinEffective!.day.toString().padLeft(2, '0')}/'
                  '${edl.bailFinEffective!.month.toString().padLeft(2, '0')}/'
                  '${edl.bailFinEffective!.year}'
              : 'Bail résilié',
          fg: AppColors.onErrorContainer,
          bg: AppColors.errorContainer,
        );
      }
      final proprioManque = !edl.bailSignedBy('proprietaire');
      final locataireManque = !edl.bailSignedBy('locataire');
      if (proprioManque || locataireManque) {
        final qui = proprioManque && locataireManque
            ? 'bailleur + locataire'
            : (proprioManque ? 'bailleur' : 'locataire');
        return _pill(
          label: 'Bail à signer',
          subLabel: qui,
          tooltip: 'EDL signé — le bail attend la signature : $qui',
          fg: AppColors.onTertiaryFixedVariant,
          bg: AppColors.tertiaryFixed.withValues(alpha: 0.5),
          bordered: true,
        );
      }
      return _pill(
        label: 'Bail signé',
        tooltip: 'Bail signé par les deux parties',
        fg: AppColors.onSuccessContainer,
        bg: AppColors.successContainer,
      );
    }
    return _pill(situation: edl.situation);
  }

  /// Pastille « point + libellé » (+ sous-libellé). Tronque au lieu de
  /// déborder : les colonnes SITUATION sont étroites.
  Widget _pill({
    SituationEdl? situation,
    String? label,
    String? tooltip,
    String? subLabel,
    Color? fg,
    Color? bg,
    bool bordered = false,
  }) {
    final (bgc, fgc) = situation != null
        ? switch (situation) {
            SituationEdl.enCours => (
                AppColors.primaryFixed,
                AppColors.onPrimaryFixedVariant,
              ),
            SituationEdl.aVenir => (
                AppColors.tertiaryFixed,
                AppColors.onTertiaryFixedVariant,
              ),
            SituationEdl.finalise => (
                AppColors.secondaryFixed,
                AppColors.onSecondaryFixedVariant,
              ),
          }
        : (bg!, fg!);
    final text = label ?? situation!.label;

    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgc,
        borderRadius: AppRadius.borderFull,
        border: bordered
            ? Border.all(color: fgc.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fgc, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm.copyWith(
                color: fgc,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    final content = subLabel == null
        ? pill
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              pill,
              const SizedBox(height: 2),
              Text(
                subLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          );

    return tooltip == null
        ? content
        : Tooltip(message: tooltip, child: content);
  }
}
