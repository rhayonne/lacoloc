import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Card visual de um quarto na grid pública.
class ChambreCard extends StatelessWidget {
  final ChambreModel chambre;
  final VoidCallback onTap;

  const ChambreCard({super.key, required this.chambre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = chambre.roomPhotos.isNotEmpty ? chambre.roomPhotos.first : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: cover != null
                  ? CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: AppColors.surfaceContainerLow,
                      ),
                      errorWidget: (_, _, _) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chambre.roomName,
                    style: AppTypography.titleLg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (chambre.immeubleName != null)
                    Text(
                      chambre.immeubleAddress != null
                          ? '${chambre.immeubleName} • ${chambre.immeubleAddress}'
                          : chambre.immeubleName!,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      if (chambre.m2 != null)
                        _Pill(label: '${chambre.m2!.toStringAsFixed(0)} m²'),
                      if (chambre.selectedOptionIds.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _Pill(
                          label:
                              '${chambre.selectedOptionIds.length} options',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  label: const Text('Voir détails'),
                  icon: const Icon(Icons.remove_red_eye, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.surfaceContainerLow,
        child: const Icon(
          Icons.bed_outlined,
          size: 48,
          color: AppColors.outline,
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onPrimaryFixedVariant,
        ),
      ),
    );
  }
}
