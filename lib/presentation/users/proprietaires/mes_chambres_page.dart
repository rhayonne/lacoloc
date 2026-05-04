import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
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

class MesChambresPage extends StatefulWidget {
  final ValueChanged<ChambreModel> onModifier;

  const MesChambresPage({super.key, required this.onModifier});

  @override
  State<MesChambresPage> createState() => _MesChambresPageState();
}

class _MesChambresPageState extends State<MesChambresPage> {
  late Future<List<_Group>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_Group>> _load() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return [];
    final immeubles = await ImmeublesDatasource.listByOwner(ownerId);
    final ids = immeubles.map((i) => i.id).toList();
    final allChambres = await ChambresDatasource.listByImmeubles(ids);

    final map = <int, List<ChambreModel>>{};
    for (final c in allChambres) {
      map.putIfAbsent(c.immeubleId, () => []).add(c);
    }

    return immeubles
        .where((i) => (map[i.id]?.isNotEmpty ?? false))
        .map((i) => _Group(immeuble: i, chambres: map[i.id]!))
        .toList();
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_Group>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final groups = snapshot.data!;

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
              child: Text('Mes Chambres', style: AppTypography.headlineMd),
            ),
            const Divider(height: 1),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune chambre enregistrée.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: groups.length,
                      itemBuilder: (context, i) => _ImmeubleGroup(
                        group: groups[i],
                        onModifier: widget.onModifier,
                        onReload: _reload,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ImmeubleGroup extends StatelessWidget {
  final _Group group;
  final ValueChanged<ChambreModel> onModifier;
  final VoidCallback onReload;

  const _ImmeubleGroup({
    required this.group,
    required this.onModifier,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              const Icon(
                Icons.apartment,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(group.immeuble.name, style: AppTypography.titleLg),
              ),
              if (!group.immeuble.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text(
                    'Inactif',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onErrorContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth < 480
                ? 1
                : constraints.maxWidth < 800
                ? 2
                : 3;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.2,
              ),
              itemCount: group.chambres.length,
              itemBuilder: (context, i) => _ChambreCard(
                chambre: group.chambres[i],
                onModifier: () => onModifier(group.chambres[i]),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChambreCard extends StatefulWidget {
  final ChambreModel chambre;
  final VoidCallback onModifier;

  const _ChambreCard({required this.chambre, required this.onModifier});

  @override
  State<_ChambreCard> createState() => _ChambreCardState();
}

class _ChambreCardState extends State<_ChambreCard> {
  int _currentPhoto = 0;
  final CarouselSliderController _carouselCtrl = CarouselSliderController();

  /// Retorna as fotos ordenadas com a foto principal primeiro.
  List<String> get _photos {
    final c = widget.chambre;
    if (c.mainPhoto == null || !c.roomPhotos.contains(c.mainPhoto)) {
      return c.roomPhotos;
    }
    return [c.mainPhoto!, ...c.roomPhotos.where((p) => p != c.mainPhoto)];
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final chambre = widget.chambre;

    return Container(
      decoration: BoxDecoration(
        color: chambre.isActive
            ? AppColors.surfaceContainerLowest
            : AppColors.surfaceContainerLow,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: chambre.isActive
              ? AppColors.outlineVariant
              : AppColors.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carrossel de fotos
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              child: photos.isEmpty
                  ? const _PhotoPlaceholder()
                  : Stack(
                      children: [
                        CarouselSlider(
                          carouselController: _carouselCtrl,
                          options: CarouselOptions(
                            height: double.infinity,
                            viewportFraction: 1.0,
                            enableInfiniteScroll: photos.length > 1,
                            autoPlay: false,
                            onPageChanged: (idx, _) =>
                                setState(() => _currentPhoto = idx),
                          ),
                          items: photos
                              .map(
                                (url) => CachedNetworkImage(
                                  imageUrl: url,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      const _PhotoPlaceholder(),
                                ),
                              )
                              .toList(),
                        ),
                        // Indicadores de página
                        if (photos.length > 1)
                          Positioned(
                            bottom: 6,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                photos.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: _currentPhoto == i ? 12 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _currentPhoto == i
                                        ? Colors.white
                                        : Colors.white54,
                                    borderRadius: AppRadius.borderFull,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Setas de navegação
                        if (photos.length > 1) ...[
                          Positioned(
                            left: 4,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: _CardArrow(
                                icon: Icons.chevron_left,
                                onTap: () => _carouselCtrl.previousPage(),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: _CardArrow(
                                icon: Icons.chevron_right,
                                onTap: () => _carouselCtrl.nextPage(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          // Infos + botão
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chambre.roomName,
                        style: AppTypography.labelMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!chambre.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: AppRadius.borderFull,
                        ),
                        child: Text(
                          'Off',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onErrorContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                if (chambre.m2 != null)
                  Text(
                    '${chambre.m2!.toStringAsFixed(0)} m²',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onModifier,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Modifier'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      textStyle: AppTypography.labelSm,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surfaceContainerLow,
    child: const Center(
      child: Icon(Icons.bed_outlined, size: 32, color: AppColors.outline),
    ),
  );
}

class _CardArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CardArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _Group {
  final ImmeublesModel immeuble;
  final List<ChambreModel> chambres;
  _Group({required this.immeuble, required this.chambres});
}
