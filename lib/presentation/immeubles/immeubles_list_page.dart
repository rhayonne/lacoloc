import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/presentation/widgets/filter_panel.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Page publique listant les immeubles actifs qui ont au moins une chambre active.
class ImmeublesListPage extends StatefulWidget {
  /// Ouverture de la fiche détail (rendue dans le cadre principal). Si null,
  /// la carte n'est pas cliquable.
  final void Function(int immeubleId)? onTapImmeuble;

  const ImmeublesListPage({super.key, this.onTapImmeuble});

  @override
  State<ImmeublesListPage> createState() => _ImmeublesListPageState();
}

class _ImmeublesListPageState extends State<ImmeublesListPage> {
  late Future<List<ImmeublesModel>> _future;
  ChambreFilter _filter = ChambreFilter.empty;

  /// immeubleId → union des équipements (« dans l'annonce ») de ses chambres
  /// actives (pour le filtre `équipements` côté immeubles).
  Map<int, Set<String>> _immeubleOptions = const {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ImmeublesModel>> _load() async {
    final results = await Future.wait([
      ImmeublesDatasource.listAll(),
      ChambresDatasource.listAll(),
    ]);
    final immeubles = results[0] as List<ImmeublesModel>;
    final chambres = results[1] as List<ChambreModel>;

    // ids de imóveis com ao menos uma chambre ativa + mapa
    // immeubleId → équipements (nomes) « dans l'annonce » das suas chambres.
    final activeIds = <int>{};
    final activeChambres = chambres.where((c) => c.isActive).toList();
    for (final c in activeChambres) {
      activeIds.add(c.immeubleId);
    }
    final equipByChambre = await InventaireDatasource.annonceLabelsByChambre(
        activeChambres.map((c) => c.id).toList());
    final optsByImmeuble = <int, Set<String>>{};
    for (final c in activeChambres) {
      final labels = equipByChambre[c.id];
      if (labels == null || labels.isEmpty) continue;
      optsByImmeuble.putIfAbsent(c.immeubleId, () => <String>{}).addAll(labels);
    }
    _immeubleOptions = optsByImmeuble;

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
    if (f.bailType == BailTypeFilter.collectif && !imm.bailLocation) {
      return false;
    }
    if (f.bailType == BailTypeFilter.individuel && !imm.bailIndividuel) {
      return false;
    }
    if (f.meuble != null && imm.locationMeuble != f.meuble) return false;
    if (f.immeubleTypeId != null && imm.typeId != f.immeubleTypeId) {
      return false;
    }
    if (f.equipements.isNotEmpty) {
      final opts = _immeubleOptions[imm.id] ?? const <String>{};
      if (!f.equipements.every(opts.contains)) return false;
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
          modules: const {
            FilterModule.localisation,
            FilterModule.bail,
            FilterModule.meuble,
            FilterModule.typeImmeuble,
            FilterModule.equipements,
          },
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
                  mainAxisExtent: 420,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final imm = filtered[index];
                  return _ImmeubleCard(
                    immeuble: imm,
                    onTap: () => widget.onTapImmeuble?.call(imm.id),
                  );
                },
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
  final VoidCallback onTap;
  const _ImmeubleCard({required this.immeuble, required this.onTap});

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
