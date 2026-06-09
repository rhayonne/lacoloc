import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Pop-up de sélection d'un immeuble pour démarrer un nouvel état des lieux.
/// Champ de recherche + vignette photo + chips bail (collectif/individuel) et
/// location (meublée/non meublée). Retourne l'immeuble choisi ou null.
///
/// [chambreStats] : par immeuble (bail individuel), nombre de chambres
/// disponibles / total → affiché sous l'adresse.
Future<ImmeublesModel?> showSelectImmeubleDialog(
  BuildContext context,
  List<ImmeublesModel> immeubles, {
  Map<int, ({int total, int available})> chambreStats = const {},
}) {
  return showDialog<ImmeublesModel>(
    context: context,
    builder: (_) => _SelectImmeubleDialog(
      immeubles: immeubles,
      chambreStats: chambreStats,
    ),
  );
}

class _SelectImmeubleDialog extends StatefulWidget {
  final List<ImmeublesModel> immeubles;
  final Map<int, ({int total, int available})> chambreStats;

  const _SelectImmeubleDialog({
    required this.immeubles,
    this.chambreStats = const {},
  });

  @override
  State<_SelectImmeubleDialog> createState() => _SelectImmeubleDialogState();
}

class _SelectImmeubleDialogState extends State<_SelectImmeubleDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ImmeublesModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.immeubles;
    return widget.immeubles.where((i) {
      final hay = [
        i.name,
        i.address ?? '',
        i.city ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Sélectionner l'immeuble", style: AppTypography.titleLg),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "Choisissez l'immeuble pour démarrer l'état des lieux.",
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Champ de recherche
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Rechercher (nom, adresse, ville)…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.immeubles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    "Aucun immeuble enregistré.",
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    "Aucun immeuble ne correspond à « $_query ».",
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final imm = filtered[i];
                      return _ImmeubleTile(
                        immeuble: imm,
                        stats: widget.chambreStats[imm.id],
                        onTap: () => Navigator.of(context).pop(imm),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImmeubleTile extends StatelessWidget {
  final ImmeublesModel immeuble;
  final VoidCallback onTap;
  /// Chambres disponibles / total (bail individuel). Null = pas d'info.
  final ({int total, int available})? stats;

  const _ImmeubleTile({
    required this.immeuble,
    required this.onTap,
    this.stats,
  });

  String? get _photo {
    if (immeuble.mainPhoto != null && immeuble.mainPhoto!.isNotEmpty) {
      return immeuble.mainPhoto;
    }
    if (immeuble.commonPhotos.isNotEmpty) return immeuble.commonPhotos.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bailLabel =
        immeuble.bailIndividuel ? 'Bail individuel' : 'Bail collectif';
    final meubleLabel = switch (immeuble.locationMeuble) {
      true => 'Meublée',
      false => 'Non meublée',
      _ => 'Location ?',
    };
    final lieu = [immeuble.address, immeuble.city]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Thumb(url: _photo),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    immeuble.name,
                    style: AppTypography.titleLg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (lieu.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      lieu,
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Disponibilité des chambres (bail individuel) sous l'adresse.
                  if (immeuble.bailIndividuel && stats != null) ...[
                    const SizedBox(height: 4),
                    _DispoBadge(
                        available: stats!.available, total: stats!.total),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _Chip(label: bailLabel),
                      _Chip(label: meubleLabel),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Vignette photo de l'immeuble (placeholder si absente).
class _Thumb extends StatelessWidget {
  final String? url;
  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    return ClipRRect(
      borderRadius: AppRadius.borderSm,
      child: SizedBox(
        width: size,
        height: size,
        child: (url == null || url!.isEmpty)
            ? Container(
                color: AppColors.surfaceContainerHighest,
                child: const Icon(Icons.apartment_outlined,
                    color: AppColors.onSurfaceVariant),
              )
            : CachedNetworkImage(
                imageUrl: url!.trim(),
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: AppColors.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  color: AppColors.surfaceContainerHighest,
                  child: const Icon(Icons.apartment_outlined,
                      color: AppColors.onSurfaceVariant),
                ),
              ),
      ),
    );
  }
}

/// Petit badge sous l'adresse : « X/Y chambres disponibles » (vert) ou
/// « Aucune chambre disponible » (rouge) si tout est occupé.
class _DispoBadge extends StatelessWidget {
  final int available;
  final int total;
  const _DispoBadge({required this.available, required this.total});

  @override
  Widget build(BuildContext context) {
    final none = available == 0;
    final color = none ? AppColors.error : AppColors.primary;
    final text = none
        ? 'Aucune chambre disponible'
        : '$available/$total chambre${total > 1 ? 's' : ''} disponible${available > 1 ? 's' : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(none ? Icons.error_outline : Icons.meeting_room_outlined,
              size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: AppTypography.labelSm
                  .copyWith(color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
