import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:habitafrance/data/models/immeubles.dart';
import 'package:habitafrance/presentation/widgets/listing_type_badge.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Card visuelle d'un immeuble (bail location) — même gabarit que [ChambreCard]
/// (photo 16/9, contenu extensible, bouton pleine largeur) pour cohabiter dans
/// une même grille.
class ImmeubleCard extends StatelessWidget {
  final ImmeublesModel immeuble;
  final VoidCallback onTap;

  /// true = superpose un badge « Location » sur la photo (grille mixte de la
  /// home, où Location et Colocation apparaissent ensemble).
  final bool showTypeBadge;

  const ImmeubleCard({
    super.key,
    required this.immeuble,
    required this.onTap,
    this.showTypeBadge = false,
  });

  String? get _coverUrl {
    final imm = immeuble;
    if (imm.mainPhoto != null) return imm.mainPhoto;
    if (imm.commonPhotos.isNotEmpty) return imm.commonPhotos.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cover = _coverUrl;

    // Même mise en page que la carte de chambre (Accueil) : photo 16/9,
    // contenu extensible, bouton « Voir détails » pleine largeur.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover != null
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: AppColors.surfaceContainerLow),
                          errorWidget: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),
                  if (showTypeBadge)
                    const Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: ListingTypeBadge(type: ListingType.location),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      immeuble.name,
                      style: AppTypography.titleLg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (immeuble.city != null || immeuble.address != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _locationLine(),
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Flexible(
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              if (immeuble.type != null)
                                _Pill(label: immeuble.type!.typeName),
                              if (immeuble.department != null)
                                _Pill(label: immeuble.department!),
                              if (immeuble.totalM2 != null)
                                _Pill(
                                    label:
                                        '${immeuble.totalM2!.toStringAsFixed(0)} m²'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
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

  String _locationLine() {
    final parts = <String>[
      if (immeuble.city != null) immeuble.city!,
      if (immeuble.region != null) immeuble.region!,
    ];
    return parts.isNotEmpty ? parts.join(', ') : (immeuble.address ?? '');
  }

  Widget _placeholder() => Container(
        color: AppColors.surfaceContainerLow,
        child: Center(
          child:
              Icon(Icons.apartment_outlined, size: 48, color: AppColors.outline),
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
