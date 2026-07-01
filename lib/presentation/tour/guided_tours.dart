import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Tour guidé en attente (déposé par un deep-link `?tour=...` du manuel avant la
/// navigation, qui efface les query params de l'URL). La page cible (ex.
/// `ProprietaireProfil`) le **consomme** au montage pour lancer le bon tour.
class PendingTour {
  PendingTour._();
  static String? value;

  /// Lit et efface le tour en attente (one-shot).
  static String? consume() {
    final v = value;
    value = null;
    return v;
  }
}

/// Une étape du tour guidé : un widget cible (via [GlobalKey]) + un titre et un
/// texte explicatif affichés dans une bulle. Le champ ciblé reste **interactif**
/// (l'utilisateur peut le remplir pendant le tour).
class TourStep {
  final GlobalKey key;
  final String title;
  final String text;
  const TourStep({
    required this.key,
    required this.title,
    required this.text,
  });
}

/// Service de **tour guidé interactif** (coachmarks maison).
///
/// Contrairement à un coachmark classique, le champ mis en surbrillance **reste
/// cliquable et éditable** : on assombrit tout l'écran *sauf* la zone du champ
/// (le « trou » ne capte aucun geste → les taps atteignent le widget réel).
///
/// À chaque étape, la cible est **automatiquement recentrée** à l'écran
/// (`Scrollable.ensureVisible`, alignement 0.5) — résout les champs hors écran
/// ou trop bas. La position est re-mesurée à chaque frame pour suivre le scroll
/// et les changements de layout (champ qui apparaît après une saisie).
///
/// Usage : poser des `GlobalKey` sur les widgets cibles, puis appeler
/// [GuidedTour.show] avec la liste d'étapes.
class GuidedTour {
  GuidedTour._();

  static void show(
    BuildContext context,
    List<TourStep> steps, {
    VoidCallback? onFinish,
    VoidCallback? onSkip,
  }) {
    if (steps.isEmpty) {
      onFinish?.call();
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TourOverlay(
        steps: steps,
        onFinish: onFinish,
        onSkip: onSkip,
        onRemove: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _TourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback? onFinish;
  final VoidCallback? onSkip;
  final VoidCallback onRemove;

  const _TourOverlay({
    required this.steps,
    required this.onFinish,
    required this.onSkip,
    required this.onRemove,
  });

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay>
    with SingleTickerProviderStateMixin {
  static const double _pad = 8;

  int _index = 0;
  Rect? _hole;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Re-mesure la position de la cible à chaque frame : suit le scroll et les
    // changements de layout (champ révélé après une saisie).
    _ticker = createTicker((_) => _measure())..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(0, initial: true));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── Mesure ─────────────────────────────────────────────────────────────────

  Rect? _rawRect(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _measure() {
    if (!mounted) return;
    final raw = _rawRect(widget.steps[_index].key);
    if (raw == null) return;
    final size = MediaQuery.of(context).size;
    final hole = Rect.fromLTRB(
      (raw.left - _pad).clamp(0.0, size.width),
      (raw.top - _pad).clamp(0.0, size.height),
      (raw.right + _pad).clamp(0.0, size.width),
      (raw.bottom + _pad).clamp(0.0, size.height),
    );
    if (hole != _hole) setState(() => _hole = hole);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Va à l'étape [i] : recentre la cible à l'écran puis re-mesure. Saute les
  /// étapes dont la cible n'est pas (encore) montée.
  Future<void> _goTo(int i, {bool initial = false}) async {
    if (i >= widget.steps.length) {
      _finish();
      return;
    }
    final step = widget.steps[i];
    final ctx = step.key.currentContext;
    if (ctx == null) {
      // Cible absente → étape suivante.
      _goTo(i + 1);
      return;
    }
    setState(() {
      _index = i;
      if (!initial) _hole = null;
    });
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    if (mounted) _measure();
  }

  void _next() => _goTo(_index + 1);

  void _finish() {
    widget.onFinish?.call();
    widget.onRemove();
  }

  void _skip() {
    widget.onSkip?.call();
    widget.onRemove();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hole = _hole;
    final step = widget.steps[_index];
    final isLast = _index == widget.steps.length - 1;

    if (hole == null) {
      // En attente d'une première mesure : voile plein écran.
      return Material(type: MaterialType.transparency, child: _fullVeil());
    }

    final below = hole.center.dy < size.height / 2;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
      children: [
        // Voile sombre en 4 bandes autour du trou (le trou ne capte aucun geste
        // → le champ réel reste cliquable/éditable).
        _veilBand(left: 0, top: 0, width: size.width, height: hole.top),
        _veilBand(
            left: 0,
            top: hole.bottom,
            width: size.width,
            height: size.height - hole.bottom),
        _veilBand(left: 0, top: hole.top, width: hole.left, height: hole.height),
        _veilBand(
            left: hole.right,
            top: hole.top,
            width: size.width - hole.right,
            height: hole.height),

        // Liseré de surbrillance autour du champ (n'intercepte pas les gestes).
        Positioned.fromRect(
          rect: hole,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 2.5),
              ),
            ),
          ),
        ),

        // Bulle explicative, placée du côté opposé au champ.
        Positioned(
          left: 16,
          right: 16,
          top: below ? hole.bottom + 14 : null,
          bottom: below ? null : (size.height - hole.top) + 14,
          child: Align(
            alignment: Alignment.center,
            child: _Bubble(
              step: step,
              index: _index + 1,
              total: widget.steps.length,
              isLast: isLast,
              onNext: _next,
              onSkip: _skip,
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _fullVeil() => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: ColoredBox(
            color: AppColors.primary.withValues(alpha: 0.82),
          ),
        ),
      );

  /// Bande de voile sombre qui **absorbe** les taps (empêche d'interagir hors
  /// du champ ciblé pendant le tour).
  Widget _veilBand({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    if (width <= 0 || height <= 0) return const SizedBox.shrink();
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: AppColors.primary.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final TourStep step;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _Bubble({
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Étape $index/$total',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            step.title,
            style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(step.text, style: AppTypography.bodyMd),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Vous pouvez remplir ce champ maintenant, puis cliquer sur '
            '${isLast ? '« Terminer »' : '« Suivant »'}.',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                child: const Text('Quitter'),
              ),
              FilledButton(
                onPressed: onNext,
                child: Text(isLast ? 'Terminer' : 'Suivant'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
