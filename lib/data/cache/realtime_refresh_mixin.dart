import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';

/// Mixin pour qu'une page se rafraîchisse quand le Realtime signale un
/// changement (le cache a déjà été invalidé par [RealtimeService]).
///
/// Usage :
/// ```dart
/// class _MyPageState extends State<MyPage> with RealtimeRefreshMixin {
///   @override
///   void onRealtimeChange() => _reload(); // refait le fetch (cache vide → DB)
/// }
/// ```
///
/// Optionnel : surcharger [watchedEntities] pour ne réagir qu'à certaines
/// entités (ex. `{'immeubles', 'chambres'}`). Par défaut, réagit à tout.
mixin RealtimeRefreshMixin<T extends StatefulWidget> on State<T> {
  late final VoidCallback _listener;
  ValueListenable<int>? _source;

  /// Entités surveillées (préfixes sans « : », ex. `immeubles`). Vide = tout.
  Set<String> get watchedEntities => const {};

  /// Appelé (post-frame) quand un changement pertinent est détecté.
  void onRealtimeChange();

  @override
  void initState() {
    super.initState();
    final entities = watchedEntities;
    if (entities.isEmpty) {
      _source = RealtimeService.instance.revision;
    } else if (entities.length == 1) {
      _source = RealtimeService.instance.entityRevision(entities.first);
    } else {
      // Plusieurs entités : on écoute la révision globale (plus simple).
      _source = RealtimeService.instance.revision;
    }
    _listener = () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onRealtimeChange();
      });
    };
    _source!.addListener(_listener);
  }

  @override
  void dispose() {
    _source?.removeListener(_listener);
    super.dispose();
  }
}
