import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';

/// Carrousel de photos réutilisable (fiches immeuble & chambre) :
/// - **défilement automatique** toutes les 5 s ;
/// - **barre de progression** blanche fine en bas (indique le prochain
///   changement de photo) ;
/// - **flèches** ‹ › et compteur ;
/// - **clic = plein écran** zoomable (`InteractiveViewer`) avec flèches pour
///   changer de photo. Le défilement automatique **s'arrête** pendant le zoom
///   plein écran et reprend à la fermeture.
class PhotoCarousel extends StatefulWidget {
  final List<String> photos;
  final double height;
  final IconData placeholderIcon;

  const PhotoCarousel({
    super.key,
    required this.photos,
    this.height = 360,
    this.placeholderIcon = Icons.photo_library_outlined,
  });

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  final CarouselSliderController _ctrl = CarouselSliderController();
  late final AnimationController _progress;
  bool _paused = false;

  static const _interval = Duration(seconds: 5);

  bool get _multi => widget.photos.length > 1;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _interval)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && !_paused) {
          _ctrl.nextPage(duration: const Duration(milliseconds: 450));
        }
      });
    if (_multi) _progress.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _onPage(int i) {
    setState(() => _index = i);
    if (_multi && !_paused) _progress.forward(from: 0);
  }

  Future<void> _openFullscreen(int initialIndex) async {
    // Stoppe le défilement auto pendant le zoom.
    _paused = true;
    _progress.stop();
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenGallery(
          photos: widget.photos,
          initialIndex: initialIndex,
        ),
      ),
    );
    if (!mounted) return;
    _paused = false;
    if (_multi) _progress.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        height: widget.height,
        color: AppColors.surfaceContainerLow,
        alignment: Alignment.center,
        child:
            Icon(widget.placeholderIcon, size: 56, color: AppColors.outline),
      );
    }

    return ClipRRect(
      borderRadius: AppRadius.borderLg,
      child: Stack(
        children: [
          CarouselSlider(
            carouselController: _ctrl,
            items: widget.photos.asMap().entries.map((entry) {
              return GestureDetector(
                onTap: () => _openFullscreen(entry.key),
                child: CachedNetworkImage(
                  imageUrl: entry.value,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, _) =>
                      Container(color: AppColors.surfaceContainerLow),
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.surfaceContainerLow,
                    alignment: Alignment.center,
                    child: Icon(widget.placeholderIcon,
                        size: 56, color: AppColors.outline),
                  ),
                ),
              );
            }).toList(),
            options: CarouselOptions(
              height: widget.height,
              viewportFraction: 1,
              enableInfiniteScroll: _multi,
              onPageChanged: (i, _) => _onPage(i),
            ),
          ),

          // Compteur "1 / N"
          if (_multi)
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: _Badge(text: '${_index + 1} / ${widget.photos.length}'),
            ),

          // Flèches
          if (_multi) ...[
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

          // Barre de progression (timelapse) — fine, blanche, en bas.
          if (_multi)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _progress,
                builder: (_, _) => LinearProgressIndicator(
                  value: _progress.value,
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Galerie plein écran zoomable avec flèches pour changer de photo.
class _FullscreenGallery extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const _FullscreenGallery({required this.photos, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late int _index;
  late final PageController _pageCtrl;

  bool get _multi => widget.photos.length > 1;

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

  void _go(int delta) {
    final n = widget.photos.length;
    final next = (_index + delta) % n;
    _pageCtrl.animateToPage(
      next < 0 ? next + n : next,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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

          // Fermer
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: _ArrowButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // Flèches navigation
          if (_multi) ...[
            Positioned(
              left: AppSpacing.md,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ArrowButton(
                  icon: Icons.chevron_left,
                  onTap: () => _go(-1),
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.md,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ArrowButton(
                  icon: Icons.chevron_right,
                  onTap: () => _go(1),
                ),
              ),
            ),
            Positioned(
              bottom: AppSpacing.xl,
              left: 0,
              right: 0,
              child: Center(
                child: _Badge(text: '${_index + 1} / ${widget.photos.length}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
