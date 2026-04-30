import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/presentation/widgets/filter_panel.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Page publique listant les immeubles actifs qui ont au moins une chambre active.
class ImmeublesListPage extends StatefulWidget {
  const ImmeublesListPage({super.key});

  @override
  State<ImmeublesListPage> createState() => _ImmeublesListPageState();
}

class _ImmeublesListPageState extends State<ImmeublesListPage> {
  late Future<List<ImmeublesModel>> _future;
  ChambreFilter _filter = ChambreFilter.empty;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ImmeublesModel>> _load() async {
    final results = await Future.wait([
      ImmeublesDatasource.listAll(),
      ChambresDatasource.activeImmeubleIds(),
    ]);
    final immeubles = results[0] as List<ImmeublesModel>;
    final activeIds = results[1] as Set<int>;
    // Apenas imóveis com pelo menos uma chambre activa
    return immeubles.where((i) => activeIds.contains(i.id)).toList();
  }

  bool _matchesFilter(ImmeublesModel imm) {
    final f = _filter;
    if (f.city.isNotEmpty) {
      if (!(imm.city?.toLowerCase().contains(f.city.toLowerCase()) ?? false)) {
        return false;
      }
    }
    if (f.region.isNotEmpty) {
      if (!(imm.region?.toLowerCase().contains(f.region.toLowerCase()) ??
          false)) {
        return false;
      }
    }
    if (f.department.isNotEmpty) {
      if (!(imm.department
              ?.toLowerCase()
              .contains(f.department.toLowerCase()) ??
          false)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterPanel(
          filter: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: FutureBuilder<List<ImmeublesModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('Erreur : ${snapshot.error}',
                        style: AppTypography.bodyMd),
                  ),
                );
              }

              final all = snapshot.data ?? [];
              final filtered =
                  _filter.isEmpty ? all : all.where(_matchesFilter).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    _filter.isEmpty
                        ? 'Aucun immeuble disponible.'
                        : 'Aucun immeuble ne correspond aux filtres.',
                    style: AppTypography.bodyLg,
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  mainAxisExtent: 340,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) =>
                    _ImmeubleCard(immeuble: filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ImmeubleCard extends StatelessWidget {
  final ImmeublesModel immeuble;
  const _ImmeubleCard({required this.immeuble});

  String? get _coverUrl {
    final imm = immeuble;
    if (imm.mainPhoto != null) return imm.mainPhoto;
    if (imm.commonPhotos.isNotEmpty) return imm.commonPhotos.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cover = _coverUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
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
                  immeuble.name,
                  style: AppTypography.titleLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (immeuble.city != null || immeuble.address != null)
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 14, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _locationLine(),
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _locationLine() {
    final parts = <String>[
      if (immeuble.city != null) immeuble.city!,
      if (immeuble.region != null) immeuble.region!,
    ];
    return parts.isNotEmpty
        ? parts.join(', ')
        : (immeuble.address ?? '');
  }

  Widget _placeholder() => Container(
        color: AppColors.surfaceContainerLow,
        child: const Center(
          child: Icon(Icons.apartment_outlined,
              size: 48, color: AppColors.outline),
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
