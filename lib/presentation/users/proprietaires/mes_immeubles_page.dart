import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class MesImmeublesPage extends StatefulWidget {
  final VoidCallback onAjouter;
  final ValueChanged<ImmeublesModel> onModifier;
  final void Function(ImmeublesModel immeuble, List<ChambreModel> chambres)
      onVoirDetail;

  const MesImmeublesPage({
    super.key,
    required this.onAjouter,
    required this.onModifier,
    required this.onVoirDetail,
  });

  @override
  State<MesImmeublesPage> createState() => _MesImmeublesPageState();
}

class _MesImmeublesPageState extends State<MesImmeublesPage> {
  late Future<_Bundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Bundle> _load() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return _Bundle(immeubles: [], chambres: []);
    final immeubles = await ImmeublesDatasource.listByOwner(ownerId);
    final ids = immeubles.map((i) => i.id).toList();
    final chambres = await ChambresDatasource.listByImmeubles(ids);
    return _Bundle(immeubles: immeubles, chambres: chambres);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Bundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final bundle = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text('Mes Propriétés', style: AppTypography.headlineMd),
            ),
            const Divider(height: 1),
            Expanded(
              child: bundle.immeubles.isEmpty
                  ? _EmptyState(onAjouter: widget.onAjouter)
                  : _Grid(
                      bundle: bundle,
                      onModifier: widget.onModifier,
                      onVoirDetail: widget.onVoirDetail,
                      onAjouter: widget.onAjouter,
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Grid extends StatelessWidget {
  final _Bundle bundle;
  final ValueChanged<ImmeublesModel> onModifier;
  final void Function(ImmeublesModel, List<ChambreModel>) onVoirDetail;
  final VoidCallback onAjouter;

  const _Grid({
    required this.bundle,
    required this.onModifier,
    required this.onVoirDetail,
    required this.onAjouter,
  });

  @override
  Widget build(BuildContext context) {
    final chambresByImmeuble = <int, List<ChambreModel>>{};
    for (final c in bundle.chambres) {
      chambresByImmeuble.putIfAbsent(c.immeubleId, () => []).add(c);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 480
                  ? 1
                  : constraints.maxWidth < 820
                      ? 2
                      : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.4,
                ),
                itemCount: bundle.immeubles.length,
                itemBuilder: (context, index) {
                  final imm = bundle.immeubles[index];
                  final chList = chambresByImmeuble[imm.id] ?? [];
                  return _ImmeubleCard(
                    immeuble: imm,
                    chambres: chList,
                    onModifier: () => onModifier(imm),
                    onVoirDetail: () => onVoirDetail(imm, chList),
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: onAjouter,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un immeuble'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ImmeubleCard extends StatelessWidget {
  final ImmeublesModel immeuble;
  final List<ChambreModel> chambres;
  final VoidCallback onModifier;
  final VoidCallback onVoirDetail;

  const _ImmeubleCard({
    required this.immeuble,
    required this.chambres,
    required this.onModifier,
    required this.onVoirDetail,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = immeuble.address ?? immeuble.type?.typeName ?? '—';
    final totalOccupied = chambres.where((c) => !c.isActive).length;
    // Todas as chambres inativas = imóvel completamente ocupado → fundo verde
    final allOccupied =
        chambres.isNotEmpty && chambres.every((c) => !c.isActive);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: allOccupied
            ? AppColors.tertiaryFixed.withValues(alpha: 0.35)
            : immeuble.isActive
                ? AppColors.surfaceContainerLowest
                : AppColors.surfaceContainerLow,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: allOccupied
              ? AppColors.tertiary.withValues(alpha: 0.45)
              : immeuble.isActive
                  ? AppColors.outlineVariant
                  : AppColors.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : icône + nom + badge inactif
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: AppRadius.borderMd,
                ),
                child: const Icon(Icons.apartment,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(immeuble.name,
                        style: AppTypography.titleLg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(subtitle,
                        style: AppTypography.labelMd
                            .copyWith(color: AppColors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (allOccupied)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryFixed,
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text('Complet',
                      style: AppTypography.labelSm.copyWith(
                          color: AppColors.onTertiaryFixedVariant)),
                )
              else if (!immeuble.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text('Inactif',
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onErrorContainer)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Miniatures des chambres
          if (chambres.isNotEmpty)
            _ChambreThumbnailStrip(chambres: chambres)
          else
            Text(
              'Aucune chambre',
              style:
                  AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
            ),
          const Spacer(),
          // Compteur
          Text(
            '${chambres.length} chambre${chambres.length != 1 ? 's' : ''}'
            ' · $totalOccupied désactivée${totalOccupied != 1 ? 's' : ''}',
            style: AppTypography.labelMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onVoirDetail,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  child: const Text('Voir détails'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: onModifier,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 0),
                ),
                child: const Icon(Icons.edit_outlined, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChambreThumbnailStrip extends StatelessWidget {
  final List<ChambreModel> chambres;
  const _ChambreThumbnailStrip({required this.chambres});

  @override
  Widget build(BuildContext context) {
    final shown = chambres.take(5).toList();
    return Row(
      children: shown.map((c) {
        final photo = c.roomPhotos.isNotEmpty ? c.roomPhotos.first : null;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.borderSm,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.borderSm,
              child: photo != null
                  ? CachedNetworkImage(
                      imageUrl: photo,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const Icon(
                          Icons.bed_outlined,
                          size: 18,
                          color: AppColors.outline),
                    )
                  : const Icon(Icons.bed_outlined,
                      size: 18, color: AppColors.outline),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAjouter;
  const _EmptyState({required this.onAjouter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_work_outlined,
                size: 64, color: AppColors.outline),
            const SizedBox(height: AppSpacing.md),
            Text('Aucun immeuble enregistré', style: AppTypography.titleLg),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ajoutez votre premier immeuble pour commencer.',
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onAjouter,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un immeuble'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Bundle {
  final List<ImmeublesModel> immeubles;
  final List<ChambreModel> chambres;
  _Bundle({required this.immeubles, required this.chambres});
}
