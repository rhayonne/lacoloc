import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Une étape du tour guidé : un widget cible (via [GlobalKey]) + un titre et un
/// texte explicatif affichés dans une bulle.
class TourStep {
  final GlobalKey key;
  final String title;
  final String text;
  final ContentAlign align;
  const TourStep({
    required this.key,
    required this.title,
    required this.text,
    this.align = ContentAlign.bottom,
  });
}

/// Service générique de **tour guidé** (coachmarks) basé sur
/// `tutorial_coach_mark`. Met en surbrillance des widgets réels de l'écran et
/// affiche une bulle « étape N/total » avec un bouton Suivant/Terminer.
///
/// Usage : poser des `GlobalKey` sur les widgets cibles, puis appeler
/// [GuidedTour.show] avec la liste d'étapes. Les étapes dont la cible n'est pas
/// montée sont ignorées (robustesse responsive).
class GuidedTour {
  GuidedTour._();

  static void show(
    BuildContext context,
    List<TourStep> steps, {
    VoidCallback? onFinish,
    VoidCallback? onSkip,
  }) {
    // On ne garde que les cibles réellement présentes à l'écran.
    final valid = steps.where((s) => s.key.currentContext != null).toList();
    if (valid.isEmpty) {
      onFinish?.call();
      return;
    }

    final targets = <TargetFocus>[
      for (var i = 0; i < valid.length; i++)
        TargetFocus(
          identify: 'step_$i',
          keyTarget: valid[i].key,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          contents: [
            TargetContent(
              align: valid[i].align,
              builder: (ctx, controller) => _Bubble(
                step: valid[i],
                index: i + 1,
                total: valid.length,
                isLast: i == valid.length - 1,
                onNext: controller.next,
                onSkip: controller.skip,
              ),
            ),
          ],
        ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: AppColors.primary,
      opacityShadow: 0.82,
      hideSkip: false,
      textSkip: 'PASSER',
      paddingFocus: 8,
      onFinish: () => onFinish?.call(),
      onSkip: () {
        onSkip?.call();
        return true;
      },
    ).show(context: context);
  }
}

class _Bubble extends StatelessWidget {
  final TourStep step;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _Bubble({
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Étape $index/$total',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            step.title,
            style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(step.text, style: AppTypography.bodyMd),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                child: const Text('Quitter'),
              ),
              FilledButton(
                onPressed: onNext,
                child: Text(isLast ? 'Terminer' : 'Suivant'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
