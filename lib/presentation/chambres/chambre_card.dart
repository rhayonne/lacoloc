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

  /// Mapa optionId → nom para exibir os nomes das options. Vazio = só contagem.
  final Map<int, String> optionNames;

  /// Máximo de chips de options listados antes do indicador "+N".
  static const _maxOptionChips = 5;

  const ChambreCard({
    super.key,
    required this.chambre,
    required this.onTap,
    this.optionNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final cover = chambre.roomPhotos.isNotEmpty
        ? chambre.roomPhotos.first
        : null;

    // Nomes das options selecionadas (ignora ids sem nome conhecido).
    final optionLabels = [
      for (final id in chambre.selectedOptionIds)
        if (optionNames[id] != null) optionNames[id]!,
    ];
    final shown = optionLabels.take(_maxOptionChips).toList();
    final extra = optionLabels.length - shown.length;

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
                      placeholder: (_, _) =>
                          Container(color: AppColors.surfaceContainerLow),
                      errorWidget: (_, _, _) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
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
                    if (chambre.immeubleName != null) ...[
                      const SizedBox(height: AppSpacing.xs),
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
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    // Pills (m² + options) au bas du card. Flexible + ClipRect :
                    // empêche tout débordement vertical si la liste passe à la
                    // ligne (hauteur du card fixe dans la grille).
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
                                _Pill(
                                    label:
                                        '${chambre.m2!.toStringAsFixed(0)} m²'),
                              // Options nomeadas (até 5). Sem nomes conhecidos,
                              // mostra a contagem total como fallback.
                              if (shown.isNotEmpty)
                                ...shown.map((l) => _Pill(label: l))
                              else if (chambre.selectedOptionIds.isNotEmpty)
                                _Pill(
                                  label:
                                      '${chambre.selectedOptionIds.length} options',
                                ),
                              // Indicador de mais opções → leva ao detalhe.
                              if (extra > 0)
                                _Pill(label: '+$extra', highlighted: true),
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
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
    child: const Icon(Icons.bed_outlined, size: 48, color: AppColors.outline),
  );
}

class _Pill extends StatelessWidget {
  final String label;

  /// Quando true, usa a cor primária (ex.: indicador "+N" / voir plus).
  final bool highlighted;

  const _Pill({required this.label, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primary : AppColors.primaryFixed,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color:
              highlighted ? AppColors.onPrimary : AppColors.onPrimaryFixedVariant,
        ),
      ),
    );
  }
}
