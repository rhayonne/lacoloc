import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/reference.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/reference.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class ChambreDetailPage extends StatefulWidget {
  final int chambreId;
  const ChambreDetailPage({super.key, required this.chambreId});

  @override
  State<ChambreDetailPage> createState() => _ChambreDetailPageState();
}

class _ChambreDetailPageState extends State<ChambreDetailPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SidebarXController _navCtrl;
  late Future<_DetailBundle> _future;

  @override
  void initState() {
    super.initState();
    _navCtrl = SidebarXController(selectedIndex: 0, extended: true);
    _navCtrl.addListener(_onNavChanged);
    _future = _load();
  }

  @override
  void dispose() {
    _navCtrl.removeListener(_onNavChanged);
    _navCtrl.dispose();
    super.dispose();
  }

  void _onNavChanged() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<void> _doLogout() async {
    await AuthService.signOut();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<_DetailBundle> _load() async {
    final chambre = await ChambresDatasource.byId(widget.chambreId);
    if (chambre == null) throw Exception('Chambre introuvable');
    final immeuble = await ImmeublesDatasource.byId(chambre.immeubleId);
    final options = await ReferenceDatasource.roomOptions();
    return _DetailBundle(chambre: chambre, immeuble: immeuble, options: options);
  }

  Widget _buildSidebar({required bool isNarrow}) {
    final user = AuthService.currentUser;
    final isLoggedIn = AuthService.isLoggedIn;
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: user?.email,
      items: const [
        SidebarXItem(icon: Icons.home_outlined, label: 'Accueil'),
        SidebarXItem(icon: Icons.apartment_outlined, label: 'Immeubles'),
      ],
      footerBuilder: (ctx, extended) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoggedIn) ...[
            SidebarActionButton(
              extended: extended,
              icon: Icons.manage_accounts_outlined,
              label: 'Mon espace',
              onTap: () {
                if (isNarrow) Navigator.of(ctx).pop();
                Navigator.of(ctx).pushNamed('/profile');
              },
            ),
            SidebarActionButton(
              extended: extended,
              icon: Icons.logout,
              label: 'Se déconnecter',
              onTap: _doLogout,
              color: AppColors.error,
            ),
          ] else
            SidebarActionButton(
              extended: extended,
              icon: Icons.login,
              label: 'Se connecter',
              onTap: () {
                if (isNarrow) Navigator.of(ctx).pop();
                Navigator.of(ctx).pushNamed('/login');
              },
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 800;
    final sidebar = _buildSidebar(isNarrow: isNarrow);

    final body = FutureBuilder<_DetailBundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Erreur : ${snapshot.error}'),
            ),
          );
        }
        return _DetailContent(bundle: snapshot.data!);
      },
    );

    if (isNarrow) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: sidebar,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              if (!_navCtrl.extended) _navCtrl.setExtended(true);
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          title: const Text('Détails de la chambre'),
        ),
        body: body,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DetailBundle {
  final ChambreModel chambre;
  final ImmeublesModel? immeuble;
  final List<ReferenceItem> options;
  _DetailBundle({
    required this.chambre,
    required this.immeuble,
    required this.options,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class _DetailContent extends StatelessWidget {
  final _DetailBundle bundle;
  const _DetailContent({required this.bundle});

  List<String> _orderedPhotos(ChambreModel c) {
    if (c.mainPhoto == null || !c.roomPhotos.contains(c.mainPhoto)) {
      return c.roomPhotos;
    }
    return [c.mainPhoto!, ...c.roomPhotos.where((p) => p != c.mainPhoto)];
  }

  @override
  Widget build(BuildContext context) {
    final chambre = bundle.chambre;
    final selected =
        bundle.options.where((o) => chambre.selectedOptionIds.contains(o.id));
    final photos = _orderedPhotos(chambre);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Retour'),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Photo carousel
                ClipRRect(
                  borderRadius: AppRadius.borderLg,
                  child: _PhotoCarousel(photos: photos),
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(chambre.roomName, style: AppTypography.headlineMd),
                if (bundle.immeuble != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    bundle.immeuble!.address ?? bundle.immeuble!.name,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),

                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (chambre.m2 != null)
                      _Stat(
                        icon: Icons.square_foot,
                        label: '${chambre.m2!.toStringAsFixed(0)} m²',
                      ),
                    if (bundle.immeuble?.type != null)
                      _Stat(
                        icon: Icons.apartment,
                        label: bundle.immeuble!.type!.typeName,
                      ),
                    if (bundle.immeuble?.bailLabel != null)
                      _Stat(
                        icon: Icons.description_outlined,
                        label: bundle.immeuble!.bailLabel!,
                      ),
                  ],
                ),

                if (chambre.description != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Description', style: AppTypography.titleLg),
                  const SizedBox(height: AppSpacing.sm),
                  Text(chambre.description!, style: AppTypography.bodyMd),
                ],

                const SizedBox(height: AppSpacing.lg),
                Text('Équipements', style: AppTypography.titleLg),
                const SizedBox(height: AppSpacing.sm),
                if (selected.isEmpty)
                  Text(
                    'Aucun équipement renseigné.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  )
                else
                  Column(
                    children:
                        selected.map((o) => _OptionRow(label: o.name)).toList(),
                  ),

                if (bundle.immeuble != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showImmeuble(context, bundle.immeuble!),
                    icon: const Icon(Icons.location_city),
                    label: const Text("Voir l'immeuble"),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImmeuble(BuildContext context, ImmeublesModel imm) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  0,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_city,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(imm.name, style: AppTypography.titleLg),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imm.commonPhotos.isNotEmpty)
                        ClipRRect(
                          borderRadius: AppRadius.borderMd,
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: CachedNetworkImage(
                              imageUrl:
                                  imm.mainPhoto ?? imm.commonPhotos.first,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                  color: AppColors.surfaceContainerLow),
                            ),
                          ),
                        ),
                      if (imm.commonPhotos.isNotEmpty)
                        const SizedBox(height: AppSpacing.md),
                      if (imm.address != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 16,
                                color: AppColors.onSurfaceVariant),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(imm.address!,
                                  style: AppTypography.bodyMd),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          if (imm.type != null)
                            _Stat(
                              icon: Icons.home_work_outlined,
                              label: imm.type!.typeName,
                            ),
                          if (imm.totalM2 != null)
                            _Stat(
                              icon: Icons.square_foot,
                              label:
                                  '${imm.totalM2!.toStringAsFixed(0)} m²',
                            ),
                          if (imm.bailLabel != null)
                            _Stat(
                              icon: Icons.description_outlined,
                              label: imm.bailLabel!,
                            ),
                        ],
                      ),
                      if (imm.description != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text('Description', style: AppTypography.titleLg),
                        const SizedBox(height: AppSpacing.sm),
                        Text(imm.description!,
                            style: AppTypography.bodyMd),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PhotoCarousel extends StatefulWidget {
  final List<String> photos;
  const _PhotoCarousel({required this.photos});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _index = 0;
  final CarouselSliderController _ctrl = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        height: 280,
        color: AppColors.surfaceContainerLow,
        alignment: Alignment.center,
        child: const Icon(Icons.photo_library_outlined,
            size: 56, color: AppColors.outline),
      );
    }

    return Stack(
      children: [
        CarouselSlider(
          carouselController: _ctrl,
          items: widget.photos.asMap().entries.map((entry) {
            return GestureDetector(
              onTap: () => _openFullscreen(context, entry.key),
              child: CachedNetworkImage(
                imageUrl: entry.value,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            );
          }).toList(),
          options: CarouselOptions(
            height: 360,
            viewportFraction: 1,
            enableInfiniteScroll: widget.photos.length > 1,
            onPageChanged: (i, _) => setState(() => _index = i),
          ),
        ),

        // Counter top-right: "1 / N"
        if (widget.photos.length > 1)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: AppRadius.borderFull,
              ),
              child: Text(
                '${_index + 1} / ${widget.photos.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

        // Prev arrow
        if (widget.photos.length > 1)
          Positioned(
            left: AppSpacing.sm,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ArrowButton(
                icon: Icons.chevron_left,
                onTap: () => _ctrl.previousPage(),
              ),
            ),
          ),

        // Next arrow
        if (widget.photos.length > 1)
          Positioned(
            right: AppSpacing.sm,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ArrowButton(
                icon: Icons.chevron_right,
                onTap: () => _ctrl.nextPage(),
              ),
            ),
          ),
      ],
    );
  }

  void _openFullscreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenGallery(
          photos: widget.photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenGallery extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const _FullscreenGallery(
      {required this.photos, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late int _index;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.photos[i],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Counter bottom center
          if (widget.photos.length > 1)
            Positioned(
              bottom: AppSpacing.xl,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.photos.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),

          // Close button top-right
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTypography.labelMd),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  const _OptionRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              size: 18, color: AppColors.tertiaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTypography.bodyMd),
        ],
      ),
    );
  }
}
