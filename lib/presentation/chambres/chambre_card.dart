import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/chambre_charge.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Card visual de um quarto na grid pública.
class ChambreCard extends StatelessWidget {
  final ChambreModel chambre;
  final VoidCallback onTap;

  /// Équipements à afficher (articles d'inventaire « dans l'annonce » de cette
  /// chambre). Vide = aucun chip d'équipement.
  final List<String> equipementLabels;

  /// Charges locatives associées à cette chambre.
  final List<ChambreChargeModel> charges;

  /// Máximo de chips de équipements listados antes do indicador "+N".
  static const _maxOptionChips = 4;

  const ChambreCard({
    super.key,
    required this.chambre,
    required this.onTap,
    this.equipementLabels = const [],
    this.charges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cover = chambre.roomPhotos.isNotEmpty ? chambre.roomPhotos.first : null;

    final shown = equipementLabels.take(_maxOptionChips).toList();
    final extra = equipementLabels.length - shown.length;

    // Résumé des charges (inclus + variable + fixe avec montant)
    final inclus    = charges.where((c) => c.type == 'inclus').toList();
    final hasVar    = charges.any((c) => c.type == 'variable');
    final fixe      = charges.where((c) => c.type == 'fixe').toList();
    final totalFixe = fixe.fold<double>(0, (s, c) => s + (c.montant ?? 0));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo ─────────────────────────────────────────────────────────
            AspectRatio(
              aspectRatio: 16 / 9,
              child: cover != null
                  ? CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: AppColors.surfaceContainerLow),
                      errorWidget: (_, _, _) => _placeholder(),
                    )
                  : _placeholder(),
            ),

            // ── Contenu ───────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chambre.roomName,
                      style: AppTypography.titleLg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (chambre.immeubleName != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        chambre.immeubleAddress != null
                            ? '${chambre.immeubleName} • ${chambre.immeubleAddress}'
                            : chambre.immeubleName!,
                        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // ── Badge charges ─────────────────────────────────────────
                    if (charges.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _ChargesBadge(
                        inclus: inclus.length,
                        hasVariable: hasVar,
                        totalFixe: totalFixe,
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
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (chambre.m2 != null)
                                _Pill(label: '${chambre.m2!.toStringAsFixed(0)} m²'),
                              ...shown.map((l) => _Pill(label: l)),
                              if (extra > 0) _Pill(label: '+$extra', highlighted: true),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bouton ────────────────────────────────────────────────────────
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

  Widget _placeholder() => Container(
        color: AppColors.surfaceContainerLow,
        child: Icon(Icons.bed_outlined, size: 48, color: AppColors.outline),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

/// Badge synthétique indiquant si des charges sont incluses ou leur montant total.
class _ChargesBadge extends StatelessWidget {
  final int inclus;
  final bool hasVariable;
  final double totalFixe;

  const _ChargesBadge({
    required this.inclus,
    required this.hasVariable,
    required this.totalFixe,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    final Color fg;

    if (inclus > 0 && totalFixe == 0 && !hasVariable) {
      label = 'Charges incluses';
      bg = AppColors.tertiaryFixed;
      fg = AppColors.onTertiaryFixedVariant;
    } else if (inclus > 0 && totalFixe > 0) {
      label = 'Incluses + ${totalFixe.toStringAsFixed(0)} €/mois';
      bg = AppColors.tertiaryFixed;
      fg = AppColors.onTertiaryFixedVariant;
    } else if (inclus > 0 && hasVariable) {
      label = 'Incluses + variables';
      bg = AppColors.tertiaryFixed;
      fg = AppColors.onTertiaryFixedVariant;
    } else if (hasVariable && totalFixe > 0) {
      label = 'Variables + ${totalFixe.toStringAsFixed(0)} €/mois';
      bg = AppColors.surfaceContainerHigh;
      fg = AppColors.onSurface;
    } else if (hasVariable) {
      label = 'Charges variables';
      bg = AppColors.surfaceContainerHigh;
      fg = AppColors.onSurface;
    } else {
      label = '${totalFixe.toStringAsFixed(0)} €/mois de charges';
      bg = AppColors.surfaceContainerHigh;
      fg = AppColors.onSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 12, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTypography.labelSm.copyWith(color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final bool highlighted;

  const _Pill({required this.label, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primary : AppColors.primaryFixed,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: highlighted ? AppColors.onPrimary : AppColors.onPrimaryFixedVariant,
        ),
      ),
    );
  }
}
