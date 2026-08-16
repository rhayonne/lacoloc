import 'package:flutter/material.dart';
import 'package:habitafrance/presentation/widgets/app_date_picker.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/datasources/immeubles.dart';
import 'package:habitafrance/data/datasources/plages_ouverture.dart';
import 'package:habitafrance/data/datasources/visites.dart';
import 'package:habitafrance/data/models/immeubles.dart';
import 'package:habitafrance/data/models/plage_ouverture.dart';
import 'package:habitafrance/data/models/users_client.dart';
import 'package:habitafrance/data/models/visite.dart';
import 'package:habitafrance/data/permissions/permissions_service.dart';
import 'package:habitafrance/presentation/widgets/locataire_search_field.dart';
import 'package:habitafrance/presentation/widgets/permission_gate.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';

// ── Constantes d'affichage ───────────────────────────────────────────────────
const int _startHour = 7;
const int _endHour = 21;
const double _hourH = 62.4; // 30 % plus haut que 48 px
const double _timeColW = 56.0;

const _moisNoms = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const _joursNoms = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
];
const _joursAbbr = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

// Couleurs de fond des créneaux — issues du thème, pas figées : un jaune et
// un gris clairs en dur restaient éclatants en thème sombre, avec par-dessus
// un texte devenu clair lui aussi (donc illisible).
//  • pause  → la famille « information/état » (ambre) ;
//  • hors   → une simple surface neutre, plus haute que la case disponible.
Color get _cPause => AppColors.secondaryFixed;
Color get _cHors => AppColors.surfaceContainerHigh;

enum AgendaView { liste, journee, semaine, mois }

enum _SlotKind { dispo, pause, hors }

// ─────────────────────────────────────────────────────────────────────────────

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  bool _loading = true;
  String? _error;
  List<VisiteModel> _visites = [];
  List<PlageOuverture> _plages = [];
  List<ImmeublesModel> _immeubles = [];

  AgendaView _view = AgendaView.semaine;

  // Décidé via LayoutBuilder (largeur réelle du widget, pas MediaQuery — la
  // sidebar consomme une partie de l'écran). Mis à jour à chaque build().
  bool _isMobile = false;

  // Position globale du dernier appui — capturée dans `onTapDown` puis utilisée
  // dans `onTap` pour ancrer le popover. On agit sur `onTap` (et non `onTapUp`)
  // car c'est le callback de tap canonique, fiable au **toucher** (mobile) ;
  // `onTapUp` seul pouvait ne pas se déclencher dans une zone défilable tactile.
  Offset _tapGlobal = Offset.zero;
  late DateTime _anchor; // date de référence (jour, sans heure)

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ownerId = AuthService.currentUser?.id;
      final visites = await VisitesDatasource.listByOwner(refresh: true);
      final plages = await PlagesOuvertureDatasource.listByOwner();
      final immeubles = ownerId != null
          ? await ImmeublesDatasource.listByOwner(ownerId)
          : <ImmeublesModel>[];
      if (!mounted) return;
      setState(() {
        _visites = visites;
        _plages = plages;
        _immeubles = immeubles;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _today() => setState(() {
        final n = DateTime.now();
        _anchor = DateTime(n.year, n.month, n.day);
      });

  void _shift(int dir) {
    setState(() {
      // En mobile, Journée ET Semaine sont affichées comme une vue « un jour
      // à la fois » (grille en colonnes fixes inutilisable <450px) : on avance
      // donc jour par jour dans les deux cas.
      if (_isMobile &&
          (_view == AgendaView.semaine || _view == AgendaView.journee)) {
        _anchor = _anchor.add(Duration(days: dir));
        return;
      }
      _anchor = switch (_view) {
        AgendaView.semaine => _anchor.add(Duration(days: 7 * dir)),
        AgendaView.journee => _anchor.add(Duration(days: dir)),
        AgendaView.mois => DateTime(_anchor.year, _anchor.month + dir, 1),
        AgendaView.liste => _anchor.add(Duration(days: 7 * dir)),
      };
    });
  }

  DateTime _weekStart(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  String _periodLabel() {
    switch (_view) {
      case AgendaView.journee:
        return _fmtDate(_anchor);
      case AgendaView.mois:
        return '${_moisNoms[_anchor.month - 1]} ${_anchor.year}';
      case AgendaView.liste:
        return 'Tous les rendez-vous';
      case AgendaView.semaine:
        // Mobile : la « Semaine » est affichée jour par jour (voir _shift).
        if (_isMobile) return _fmtDate(_anchor);
        final s = _weekStart(_anchor);
        final e = s.add(const Duration(days: 6));
        if (s.month == e.month) {
          return '${s.day} - ${e.day} ${_moisNoms[s.month - 1]} ${s.year}';
        }
        return '${s.day} ${_moisNoms[s.month - 1]} - '
            '${e.day} ${_moisNoms[e.month - 1]} ${e.year}';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Décision responsive via LayoutBuilder (largeur réelle du widget) —
    // jamais MediaQuery, qui compterait aussi la largeur consommée par la
    // sidebar. Breakpoint MOBILE < 450px (voir CLAUDE.md).
    return LayoutBuilder(
      builder: (context, constraints) {
        _isMobile = constraints.maxWidth < 450;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            if (_loading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Erreur : $_error',
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.error)),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildBody()),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          // Groupe gauche : Aujourd'hui + navigation + période (cliquable).
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: _today,
                child: const Text("Aujourd'hui"),
              ),
              if (_view != AgendaView.liste) ...[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Précédent',
                  onPressed: () => _shift(-1),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Suivant',
                  onPressed: () => _shift(1),
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              // La période ouvre un sélecteur (mois / semaines / jours).
              if (_view == AgendaView.liste)
                Text(_periodLabel(), style: AppTypography.titleLg)
              else
                InkWell(
                  borderRadius: AppRadius.borderSm,
                  onTapDown: (d) => _tapGlobal = d.globalPosition,
                  onTap: () => _openPeriodPicker(_tapGlobal),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_periodLabel(), style: AppTypography.titleLg),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // Bouton plages (peut passer à la ligne indépendamment).
          // En mobile : icône seule (avec tooltip) pour économiser la place.
          PermissionGate(
            permission: Perm.visitesEdit,
            child: _isMobile
                ? IconButton(
                    onPressed: _openPlagesDialog,
                    icon: const Icon(Icons.tune),
                    tooltip: "Modifier les plages d'ouverture",
                  )
                : OutlinedButton.icon(
                    onPressed: _openPlagesDialog,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text("Modifier les plages d'ouverture"),
                  ),
          ),
          // Sélecteur de vue (icônes seules en mobile pour éviter le débord).
          SegmentedButton<AgendaView>(
            segments: [
              ButtonSegment(
                value: AgendaView.liste,
                icon: const Icon(Icons.list, size: 18),
                label: _isMobile ? null : const Text('Liste'),
              ),
              ButtonSegment(
                value: AgendaView.journee,
                icon: const Icon(Icons.view_day_outlined, size: 18),
                label: _isMobile ? null : const Text('Journée'),
              ),
              ButtonSegment(
                value: AgendaView.semaine,
                icon: const Icon(Icons.view_week_outlined, size: 18),
                label: _isMobile ? null : const Text('Semaine'),
              ),
              ButtonSegment(
                value: AgendaView.mois,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: _isMobile ? null : const Text('Mois'),
              ),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_view) {
      case AgendaView.liste:
        return _ListeView(
          visites: _visites,
          immeubles: _immeubles,
          onOpen: (v, pos) => _openRdvPopover(pos, existing: v),
        );
      case AgendaView.mois:
        return _MoisView(
          anchor: _anchor,
          visites: _visites,
          onSelectDay: (d) => setState(() {
            _anchor = d;
            _view = AgendaView.journee;
          }),
        );
      case AgendaView.journee:
        return _isMobile
            ? _buildMobileDayView(_anchor)
            : _buildDaysView([_anchor]);
      case AgendaView.semaine:
        // La grille en colonnes fixes est inutilisable <450px : on retombe
        // sur la même vue « un jour à la fois » qu'en Journée (navigation
        // jour par jour via _shift, cf. plus haut).
        if (_isMobile) return _buildMobileDayView(_anchor);
        final s = _weekStart(_anchor);
        return _buildDaysView(
            List.generate(7, (i) => s.add(Duration(days: i))));
    }
  }

  // ── Vue mobile (< 450px) : un jour à la fois, en cards verticales ────────
  // Remplace la grille semaine/journée (colonnes fixes) par la liste des
  // rendez-vous du jour affiché, réutilisant _ListeView/_ListeRow (mêmes
  // cards, même popover de création/édition) — pas de logique dupliquée.
  Widget _buildMobileDayView(DateTime day) {
    final dayVisites = _visites.where((v) => _sameDay(v.debut, day)).toList();
    final isToday = _sameDay(day, DateTime.now());
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final isTomorrow = _sameDay(day, tomorrowDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    OutlinedButton(
                      onPressed: isToday ? null : _today,
                      child: const Text("Aujourd'hui"),
                    ),
                    OutlinedButton(
                      onPressed: isTomorrow
                          ? null
                          : () => setState(() => _anchor = tomorrowDate),
                      child: const Text('Demain'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PermissionGate(
                permission: Perm.visitesCreate,
                child: FilledButton.tonalIcon(
                  onPressed: () => _openRdvPopover(Offset.zero,
                      start: _defaultNewStart(day)),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _ListeView(
            visites: dayVisites,
            immeubles: _immeubles,
            onOpen: (v, pos) => _openRdvPopover(pos, existing: v),
          ),
        ),
      ],
    );
  }

  /// Heure de départ par défaut pour un nouveau rendez-vous créé depuis la
  /// vue mobile (pas de grille à taper) : demi-heure suivante si c'est
  /// aujourd'hui et dans la plage horaire affichée, sinon un horaire médian.
  DateTime _defaultNewStart(DateTime day) {
    final now = DateTime.now();
    if (_sameDay(day, now)) {
      var hour = now.hour;
      var minute = now.minute < 30 ? 30 : 0;
      if (minute == 0) hour += 1;
      if (hour < _startHour || hour >= _endHour) hour = _startHour + 2;
      return DateTime(day.year, day.month, day.day, hour, minute);
    }
    return DateTime(day.year, day.month, day.day, _startHour + 2, 0);
  }

  // ── Vue jours (semaine / journée) ────────────────────────────────────────
  Widget _buildDaysView(List<DateTime> days) {
    final today = DateTime.now();
    final bodyH = (_endHour - _startHour) * _hourH;
    return Column(
      children: [
        // En-tête des jours.
        Row(
          children: [
            const SizedBox(width: _timeColW),
            ...days.map((d) {
              final isToday = d.year == today.year &&
                  d.month == today.month &&
                  d.day == today.day;
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(
                        left: BorderSide(color: AppColors.outlineVariant)),
                    color: isToday
                        ? AppColors.primaryFixed.withValues(alpha: 0.4)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text('${_joursAbbr[d.weekday - 1]} ${d.day}',
                          style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isToday ? AppColors.primary : null)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              height: bodyH,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeColumn(),
                      ...days.map((d) => Expanded(child: _buildDayBody(d))),
                    ],
                  ),
                  ..._fullWidthNowLine(days),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeColumn() {
    return SizedBox(
      width: _timeColW,
      child: Column(
        children: [
          for (int h = _startHour; h < _endHour; h++)
            SizedBox(
              height: _hourH,
              child: Padding(
                padding: const EdgeInsets.only(right: 6, top: 2),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text('${h.toString().padLeft(2, '0')}:00',
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayBody(DateTime day) {
    // Créneaux de fond (2 par heure).
    final slots = <Widget>[];
    for (int h = _startHour; h < _endHour; h++) {
      for (int half = 0; half < 2; half++) {
        final startMin = h * 60 + half * 30;
        final kind = _slotClass(day.weekday, startMin);
        slots.add(_slotWidget(day, h, half, kind));
      }
    }

    // Rendez-vous du jour + mise en page en lanes.
    final dayVisites = _visites
        .where((v) => _sameDay(v.debut, day))
        .toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));
    final lanes = _layoutLanes(dayVisites);

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (ctx, cons) {
          final colW = cons.maxWidth;
          return Stack(
            children: [
              Column(children: slots),
              // Blocs de rendez-vous.
              ...dayVisites.map((v) {
                final lane = lanes[v.id]!;
                return _rdvBlock(v, lane.$1, lane.$2, colW);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _slotWidget(DateTime day, int hour, int half, _SlotKind kind) {
    return _SlotCell(
      kind: kind,
      isHourEnd: half == 1,
      onTap: (globalPos) {
        final start = DateTime(day.year, day.month, day.day, hour, half * 30);
        _openRdvPopover(globalPos, start: start);
      },
    );
  }

  /// Ligne « maintenant » traversant **toute la largeur** des colonnes de jours
  /// (dès que la période affichée contient aujourd'hui) — pas seulement la
  /// colonne du jour courant.
  List<Widget> _fullWidthNowLine(List<DateTime> days) {
    final now = DateTime.now();
    if (!days.any((d) => _sameDay(d, now))) return const [];
    final top = ((now.hour * 60 + now.minute) - _startHour * 60) * _hourH / 60;
    if (top < 0 || top > (_endHour - _startHour) * _hourH) return const [];
    return [
      Positioned(
        top: top - 4,
        left: _timeColW - 4,
        right: 0,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: AppColors.error, shape: BoxShape.circle),
            ),
            Expanded(child: Container(height: 2, color: AppColors.error)),
          ],
        ),
      ),
    ];
  }

  Widget _rdvBlock(VisiteModel v, int lane, int laneCount, double colW) {
    final startMin = v.debut.hour * 60 + v.debut.minute;
    final top = (startMin - _startHour * 60) * _hourH / 60;
    final durMin = v.fin.difference(v.debut).inMinutes.clamp(30, 24 * 60);
    final height = (durMin * _hourH / 60).clamp(22.0, double.infinity);
    final color = typeVisiteColor(v.typeVisite);
    const gap = 2.0;
    final laneW = (colW - gap) / laneCount;
    final left = lane * laneW + gap;
    final tall = height >= 34;
    final titre = v.nomVisiteur.isEmpty
        ? typeVisiteLabel(v.typeVisite)
        : v.nomVisiteur;
    return Positioned(
      top: top < 0 ? 0 : top,
      left: left,
      width: (laneW - gap).clamp(24.0, double.infinity),
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _tapGlobal = d.globalPosition,
        onTap: () => _openRdvPopover(_tapGlobal, existing: v),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            border: Border(left: BorderSide(color: color, width: 3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tall)
                  Text(_fmtHeure(v.debut),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AppTypography.labelSm.copyWith(color: color)),
                Text(titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Classification d'un créneau de 30 min ────────────────────────────────
  _SlotKind _slotClass(int weekday, int startMin) {
    final endMin = startMin + 30;
    final dayPlages = _plages.where((p) => p.jourSemaine == weekday);
    // Pause si chevauchement avec une plage 'pause'.
    for (final p in dayPlages) {
      if (p.isPause && startMin < p.finMin && endMin > p.debutMin) {
        return _SlotKind.pause;
      }
    }
    // Dispo si entièrement inclus dans une plage 'ouverture'.
    for (final p in dayPlages) {
      if (!p.isPause && startMin >= p.debutMin && endMin <= p.finMin) {
        return _SlotKind.dispo;
      }
    }
    return _SlotKind.hors;
  }

  // Lanes pour les rendez-vous qui se chevauchent : renvoie id -> (lane, total).
  Map<int, (int, int)> _layoutLanes(List<VisiteModel> visites) {
    final result = <int, (int, int)>{};
    // Groupes de chevauchement.
    final sorted = [...visites]..sort((a, b) => a.debut.compareTo(b.debut));
    var i = 0;
    while (i < sorted.length) {
      final group = <VisiteModel>[sorted[i]];
      var groupEnd = sorted[i].fin;
      var j = i + 1;
      while (j < sorted.length && sorted[j].debut.isBefore(groupEnd)) {
        group.add(sorted[j]);
        if (sorted[j].fin.isAfter(groupEnd)) groupEnd = sorted[j].fin;
        j++;
      }
      // Assignation gloutonne des lanes dans le groupe.
      final laneEnds = <DateTime>[];
      final laneOf = <int, int>{};
      for (final v in group) {
        var placed = false;
        for (var l = 0; l < laneEnds.length; l++) {
          if (!v.debut.isBefore(laneEnds[l])) {
            laneEnds[l] = v.fin;
            laneOf[v.id] = l;
            placed = true;
            break;
          }
        }
        if (!placed) {
          laneOf[v.id] = laneEnds.length;
          laneEnds.add(v.fin);
        }
      }
      final total = laneEnds.length;
      for (final v in group) {
        result[v.id] = (laneOf[v.id]!, total);
      }
      i = j;
    }
    return result;
  }

  // ── Popover création / édition ───────────────────────────────────────────
  Future<void> _openRdvPopover(Offset globalPos,
      {VisiteModel? existing, DateTime? start}) async {
    final canCreate = PermissionsService.instance.can(Perm.visitesCreate);
    if (existing == null && !canCreate) return;

    final size = MediaQuery.sizeOf(context);
    // En mobile, la boîte est centrée à l'écran (largeur/hauteur adaptées) —
    // la position du tap (souvent un bouton "Ajouter" ou une card, pas une
    // cellule de grille) n'a plus de sens comme point d'ancrage, et un ancrage
    // fixe à 380px pourrait dépasser l'écran (clamp invalide → crash).
    final w = _isMobile ? (size.width - 24).clamp(240.0, 380.0).toDouble() : 380.0;
    final h = _isMobile ? (size.height - 48).clamp(320.0, 520.0).toDouble() : 520.0;
    final left = _isMobile
        ? (size.width - w) / 2
        : globalPos.dx.clamp(8.0, size.width - w - 8).toDouble();
    final top = _isMobile
        ? (size.height - h) / 2
        : globalPos.dy.clamp(8.0, size.height - h - 8).toDouble();

    final changed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.15),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, _) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: w,
              child: Material(
                elevation: 12,
                borderRadius: AppRadius.borderLg,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: h),
                  child: _RdvForm(
                    existing: existing,
                    initialStart: start,
                    immeubles: _immeubles,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (changed == true) await _load();
  }

  Future<void> _openPlagesDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PlagesDialog(initial: _plages),
    );
    if (changed == true) await _load();
  }

  // ── Sélecteur de période (menu suspendu ancré au libellé) ────────────────
  Future<void> _openPeriodPicker(Offset globalPos) async {
    final size = MediaQuery.sizeOf(context);
    // Même logique défensive que _openRdvPopover : centré en mobile pour
    // éviter un débord d'écran (et un clamp invalide sur les très petits
    // écrans).
    final w = _isMobile ? (size.width - 24).clamp(240.0, 340.0).toDouble() : 340.0;
    final h = _isMobile ? (size.height - 48).clamp(280.0, 420.0).toDouble() : 420.0;
    final left = _isMobile
        ? (size.width - w) / 2
        : globalPos.dx.clamp(8.0, size.width - w - 8).toDouble();
    final top = _isMobile
        ? (size.height - h) / 2
        : (globalPos.dy + 8).clamp(8.0, size.height - h - 8).toDouble();

    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: w,
            child: Material(
              elevation: 12,
              borderRadius: AppRadius.borderLg,
              clipBehavior: Clip.antiAlias,
              child: _PeriodPickerContent(view: _view, anchor: _anchor),
            ),
          ),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() => _anchor = DateTime(picked.year, picked.month, picked.day));
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur de période (contenu du menu suspendu)
// Mois → grille de mois (flèches = année) ; Semaine → liste de semaines
// (flèches = mois) ; Journée → calendrier de jours (flèches = mois).
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodPickerContent extends StatefulWidget {
  final AgendaView view;
  final DateTime anchor;
  const _PeriodPickerContent({required this.view, required this.anchor});

  @override
  State<_PeriodPickerContent> createState() => _PeriodPickerContentState();
}

class _PeriodPickerContentState extends State<_PeriodPickerContent> {
  late DateTime _browse; // mois (ou année) parcouru

  bool get _isMois => widget.view == AgendaView.mois;

  @override
  void initState() {
    super.initState();
    _browse = DateTime(widget.anchor.year, widget.anchor.month, 1);
  }

  void _step(int dir) => setState(() {
        _browse = _isMois
            ? DateTime(_browse.year + dir, _browse.month, 1)
            : DateTime(_browse.year, _browse.month + dir, 1);
      });

  DateTime _weekStart(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final title = _isMois
        ? '${_browse.year}'
        : '${_moisNoms[_browse.month - 1]} ${_browse.year}';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Précédent',
                onPressed: () => _step(-1),
              ),
              Expanded(
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLg),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Suivant',
                onPressed: () => _step(1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          switch (widget.view) {
            AgendaView.mois => _buildMonths(),
            AgendaView.semaine => _buildWeeks(),
            _ => _buildDays(),
          },
        ],
      ),
    );
  }

  Widget _buildMonths() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(12, (i) {
        final m = i + 1;
        final selected = m == widget.anchor.month &&
            _browse.year == widget.anchor.year;
        return SizedBox(
          width: 96,
          child: selected
              ? FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, DateTime(_browse.year, m, 1)),
                  child: Text(_moisNoms[i]))
              : OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(context, DateTime(_browse.year, m, 1)),
                  child: Text(_moisNoms[i], overflow: TextOverflow.ellipsis)),
        );
      }),
    );
  }

  Widget _buildWeeks() {
    // Semaines (lundi→dimanche) qui intersectent le mois parcouru.
    final firstOfMonth = DateTime(_browse.year, _browse.month, 1);
    final lastOfMonth = DateTime(_browse.year, _browse.month + 1, 0);
    var monday = _weekStart(firstOfMonth);
    final anchorMonday = _weekStart(widget.anchor);
    final rows = <Widget>[];
    while (!monday.isAfter(lastOfMonth)) {
      final sunday = monday.add(const Duration(days: 6));
      final selected = monday == anchorMonday;
      final label = 'Semaine du ${monday.day} ${_moisNoms[monday.month - 1]}'
          ' au ${sunday.day} ${_moisNoms[sunday.month - 1]}';
      final m = monday;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: selected
            ? FilledButton(
                onPressed: () => Navigator.pop(context, m),
                child: Align(
                    alignment: Alignment.centerLeft, child: Text(label)))
            : OutlinedButton(
                onPressed: () => Navigator.pop(context, m),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(label, overflow: TextOverflow.ellipsis))),
      ));
      monday = monday.add(const Duration(days: 7));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _buildDays() {
    final daysInMonth = DateTime(_browse.year, _browse.month + 1, 0).day;
    final startOffset = DateTime(_browse.year, _browse.month, 1).weekday - 1;
    final cells = <Widget>[];
    for (var i = 0; i < startOffset; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final selected = d == widget.anchor.day &&
          _browse.month == widget.anchor.month &&
          _browse.year == widget.anchor.year;
      cells.add(InkWell(
        onTap: () =>
            Navigator.pop(context, DateTime(_browse.year, _browse.month, d)),
        borderRadius: AppRadius.borderFull,
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.primary : null,
          ),
          child: Text('$d',
              style: AppTypography.bodyMd.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.onSurface,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal)),
        ),
      ));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: _joursAbbr
              .map((j) => Expanded(
                    child: Center(
                      child: Text(j[0].toUpperCase(),
                          style: AppTypography.labelSm
                              .copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: cells,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cellule de créneau (30 min) avec survol (hover) bien marqué
// ─────────────────────────────────────────────────────────────────────────────

class _SlotCell extends StatefulWidget {
  final _SlotKind kind;
  final bool isHourEnd; // seconde moitié d'heure → séparateur plus marqué
  final void Function(Offset globalPos) onTap;

  const _SlotCell({
    required this.kind,
    required this.isHourEnd,
    required this.onTap,
  });

  @override
  State<_SlotCell> createState() => _SlotCellState();
}

class _SlotCellState extends State<_SlotCell> {
  bool _hover = false;
  // Position de l'appui (voir note sur `_tapGlobal` dans _AgendaPageState).
  Offset _tapGlobal = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final bg = switch (kind) {
      _SlotKind.dispo => AppColors.surfaceContainerLowest,
      _SlotKind.pause => _cPause,
      _SlotKind.hors => _cHors,
    };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _tapGlobal = d.globalPosition,
        onTap: () => widget.onTap(_tapGlobal),
        child: Container(
          height: _hourH / 2,
          decoration: BoxDecoration(
            color: kind == _SlotKind.hors ? null : bg,
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant
                    .withValues(alpha: widget.isHourEnd ? 1 : 0.4),
                width: 0.5,
              ),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (kind == _SlotKind.hors)
                CustomPaint(
                    painter: _HatchPainter(), child: const SizedBox.expand()),
              // Survol : superposition bien visible (« sobressaliente »),
              // couleur définie dans le thème (AppColors.hoverCell).
              if (_hover)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.hoverCell,
                    border: Border.all(
                        color: AppColors.hoverCellBorder, width: 1),
                  ),
                  child: Center(
                    child: Icon(Icons.add,
                        size: 16, color: AppColors.hoverCellBorder),
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
// Peinture des hachures (créneaux hors plage)
// ─────────────────────────────────────────────────────────────────────────────

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.6)
      ..strokeWidth = 0.7;
    const gap = 7.0;
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Vue Mois
// ─────────────────────────────────────────────────────────────────────────────

class _MoisView extends StatelessWidget {
  final DateTime anchor;
  final List<VisiteModel> visites;
  final ValueChanged<DateTime> onSelectDay;

  const _MoisView({
    required this.anchor,
    required this.visites,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(anchor.year, anchor.month, 1);
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final startOffset = first.weekday - 1;
    final today = DateTime.now();

    final byDay = <int, List<VisiteModel>>{};
    for (final v in visites) {
      if (v.debut.year == anchor.year && v.debut.month == anchor.month) {
        (byDay[v.debut.day] ??= []).add(v);
      }
    }

    final cells = <Widget?>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(_dayCell(d, byDay[d] ?? [], today));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: _joursAbbr
                .map((j) => Expanded(
                      child: Center(
                        child: Text(j,
                            style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GridView.count(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
              children: cells
                  .map((c) => c ?? const SizedBox.shrink())
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(int day, List<VisiteModel> vs, DateTime today) {
    final isToday = today.year == anchor.year &&
        today.month == anchor.month &&
        today.day == day;
    return _MoisDayCell(
      day: day,
      visites: vs,
      isToday: isToday,
      onTap: () => onSelectDay(DateTime(anchor.year, anchor.month, day)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cellule de jour de la vue Mois (survol bien marqué)
// ─────────────────────────────────────────────────────────────────────────────

class _MoisDayCell extends StatefulWidget {
  final int day;
  final List<VisiteModel> visites;
  final bool isToday;
  final VoidCallback onTap;

  const _MoisDayCell({
    required this.day,
    required this.visites,
    required this.isToday,
    required this.onTap,
  });

  @override
  State<_MoisDayCell> createState() => _MoisDayCellState();
}

class _MoisDayCellState extends State<_MoisDayCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isToday = widget.isToday;
    final vs = widget.visites;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderSm,
            border: Border.all(
              color: _hover ? AppColors.hoverCellBorder : AppColors.outlineVariant,
              width: _hover ? 2 : 1,
            ),
            // Survol bien visible : superpose la teinte de hover du thème.
            color: _hover
                ? AppColors.hoverCell
                : isToday
                    ? AppColors.primaryFixed.withValues(alpha: 0.4)
                    : AppColors.surfaceContainerLowest,
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${widget.day}',
                      style: AppTypography.labelMd.copyWith(
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? AppColors.primary : null)),
                  const Spacer(),
                  if (_hover)
                    Icon(Icons.add,
                        size: 14, color: AppColors.hoverCellBorder),
                ],
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: vs
                      .take(4)
                      .map((v) => Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: typeVisiteColor(v.typeVisite),
                                shape: BoxShape.circle),
                          ))
                      .toList(),
                ),
              ),
              if (vs.length > 4)
                Text('+${vs.length - 4}',
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vue Liste
// ─────────────────────────────────────────────────────────────────────────────

class _ListeView extends StatelessWidget {
  final List<VisiteModel> visites;
  final List<ImmeublesModel> immeubles;
  final void Function(VisiteModel, Offset) onOpen;

  const _ListeView({
    required this.visites,
    required this.immeubles,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (visites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined,
                size: 52, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text('Aucun rendez-vous planifié.',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }
    final sorted = [...visites]..sort((a, b) => a.debut.compareTo(b.debut));
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final v = sorted[i];
        final imm = immeubles.where((m) => m.id == v.immeubleId).firstOrNull;
        return _ListeRow(
          visite: v,
          immeuble: imm,
          onOpen: onOpen,
        );
      },
    );
  }
}

/// Ligne de la vue Liste — widget dédié pour que la position de l'appui
/// (`_tapGlobal`) soit un **champ de State** stable entre `onTapDown` et
/// `onTap`. Avec une variable locale dans un `Builder`, un rebuild (ex. un
/// événement Realtime) la remettait à zéro et le popover s'ouvrait en (0,0).
class _ListeRow extends StatefulWidget {
  final VisiteModel visite;
  final ImmeublesModel? immeuble;
  final void Function(VisiteModel, Offset) onOpen;

  const _ListeRow({
    required this.visite,
    required this.immeuble,
    required this.onOpen,
  });

  @override
  State<_ListeRow> createState() => _ListeRowState();
}

class _ListeRowState extends State<_ListeRow> {
  Offset _tapGlobal = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final v = widget.visite;
    final imm = widget.immeuble;
    final color = typeVisiteColor(v.typeVisite);
    return InkWell(
      onTapDown: (d) => _tapGlobal = d.globalPosition,
      onTap: () => widget.onOpen(v, _tapGlobal),
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: AppColors.outlineVariant),
          color: AppColors.surfaceContainerLowest,
        ),
        child: Row(
          children: [
            Container(width: 4, height: 40, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(typeVisiteLabel(v.typeVisite),
                      style: AppTypography.labelSm.copyWith(color: color)),
                  Text(v.nomVisiteur.isEmpty ? '—' : v.nomVisiteur,
                      style: AppTypography.titleLg),
                  if (imm != null)
                    Text(imm.name,
                        style: AppTypography.labelMd
                            .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmtDate(v.debut), style: AppTypography.labelMd),
                Text('${_fmtHeure(v.debut)} – ${_fmtHeure(v.fin)}',
                    style: AppTypography.bodyMd),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulaire du rendez-vous (contenu du popover)
// ─────────────────────────────────────────────────────────────────────────────

class _RdvForm extends StatefulWidget {
  final VisiteModel? existing;
  final DateTime? initialStart;
  final List<ImmeublesModel> immeubles;

  const _RdvForm({
    this.existing,
    this.initialStart,
    required this.immeubles,
  });

  @override
  State<_RdvForm> createState() => _RdvFormState();
}

class _RdvFormState extends State<_RdvForm> {
  late String _type;
  late DateTime _date;
  late TimeOfDay _startTod;
  late TimeOfDay _endTod;
  int? _immeubleId;
  final _notesCtrl = TextEditingController();

  // Contact
  String? _locataireId;
  String _contactNom = '';
  String? _inviteEmail;
  bool _guestMode = false;
  final _guestNomCtrl = TextEditingController();
  final _guestEmailCtrl = TextEditingController();

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.typeVisite;
      _date = DateTime(e.debut.year, e.debut.month, e.debut.day);
      _startTod = TimeOfDay.fromDateTime(e.debut);
      _endTod = TimeOfDay.fromDateTime(e.fin);
      _immeubleId = e.immeubleId;
      _notesCtrl.text = e.notes ?? '';
      _locataireId = e.locataireId;
      _contactNom = e.nomVisiteur;
      _inviteEmail = e.inviteEmail;
    } else {
      _type = kTypesVisite.first;
      final s = widget.initialStart ?? DateTime.now();
      _date = DateTime(s.year, s.month, s.day);
      _startTod = TimeOfDay(hour: s.hour, minute: s.minute);
      final end = s.add(const Duration(hours: 1));
      _endTod = TimeOfDay(hour: end.hour, minute: end.minute);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _guestNomCtrl.dispose();
    _guestEmailCtrl.dispose();
    super.dispose();
  }

  bool get _hasContact =>
      _locataireId != null || (_inviteEmail?.isNotEmpty ?? false);

  int _todMin(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTod : _endTod,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startTod = picked;
        if (_todMin(_endTod) <= _todMin(_startTod)) {
          final e = _todMin(_startTod) + 60;
          _endTod = TimeOfDay(hour: (e ~/ 60) % 24, minute: e % 60);
        }
      } else {
        _endTod = picked;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context,
      initial: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _applyGuest() {
    final nom = _guestNomCtrl.text.trim();
    final email = _guestEmailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("L'e-mail de l'invité est requis.")));
      return;
    }
    setState(() {
      _locataireId = null;
      _inviteEmail = email;
      _contactNom = nom.isEmpty ? email : nom;
      _guestMode = false;
    });
  }

  void _clearContact() => setState(() {
        _locataireId = null;
        _inviteEmail = null;
        _contactNom = '';
      });

  Future<void> _save() async {
    if (!_hasContact) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sélectionnez un contact ou invitez par e-mail.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final ownerId = AuthService.currentUser!.id;
      var debut =
          DateTime(_date.year, _date.month, _date.day, _startTod.hour, _startTod.minute);
      var fin =
          DateTime(_date.year, _date.month, _date.day, _endTod.hour, _endTod.minute);
      if (!fin.isAfter(debut)) fin = debut.add(const Duration(hours: 1));

      final draft = VisiteModel(
        id: widget.existing?.id ?? 0,
        ownerId: ownerId,
        typeVisite: _type,
        nomVisiteur: _contactNom,
        dateVisite: _date,
        heureDebut: debut,
        heureFin: fin,
        locataireId: _locataireId,
        inviteEmail: _inviteEmail,
        inviteNom: _locataireId == null ? _contactNom : null,
        immeubleId: _immeubleId,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      final saved = _isEdit
          ? await VisitesDatasource.update(draft)
          : await VisitesDatasource.create(draft);
      // E-mail au contact (best-effort).
      await VisitesDatasource.notifyRendezvous(saved.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le rendez-vous ?'),
        content: Text('${typeVisiteLabel(_type)} — $_contactNom'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            style: AppTheme.deleteButtonStyle,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await VisitesDatasource.delete(widget.existing!.id);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_isEdit ? 'Rendez-vous' : 'Nouveau rendez-vous',
                    style: AppTypography.titleLg),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(false),
                tooltip: 'Fermer',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Type
          _label('TYPE'),
          DropdownButtonFormField<String>(
            initialValue: _type,
            isDense: true,
            items: kTypesVisite
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: typeVisiteColor(t),
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(typeVisiteLabel(t)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Contact
          _label('CONTACT'),
          if (_hasContact)
            _contactChip()
          else if (_guestMode)
            _guestFields()
          else
            LocataireSearchField(
              multiSelect: false,
              hintText: 'Rechercher un contact (nom, e-mail)…',
              createNewLabel: 'Inviter un contact par e-mail',
              onSelect: (UsersClient u) {
                setState(() {
                  _locataireId = u.id;
                  _contactNom = u.fullName ?? u.email;
                  _inviteEmail = null;
                });
              },
              onCreateNew: () => setState(() => _guestMode = true),
            ),
          const SizedBox(height: AppSpacing.sm),

          // Date + horaires
          _label('QUAND'),
          InkWell(
            onTap: _pickDate,
            child: _boxRow(Icons.calendar_today_outlined, _fmtDate(_date)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(true),
                  child: _boxRow(Icons.schedule, _fmtTod(_startTod)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('→'),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(false),
                  child: _boxRow(Icons.schedule, _fmtTod(_endTod)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Lieu
          _label('LIEU'),
          DropdownButtonFormField<int?>(
            initialValue: _immeubleId,
            isDense: true,
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('Aucun / à définir')),
              ...widget.immeubles.map((m) => DropdownMenuItem<int?>(
                    value: m.id,
                    child: Text(m.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => setState(() => _immeubleId = v),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Notes
          _label('NOTES'),
          TextField(
            controller: _notesCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'Facultatif'),
          ),
          const SizedBox(height: AppSpacing.md),

          // Actions
          Row(
            children: [
              if (_isEdit)
                PermissionGate(
                  permission: Perm.visitesDelete,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error,
                    tooltip: 'Supprimer',
                    onPressed: _saving ? null : _delete,
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed:
                    _saving ? null : () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                style: AppTheme.saveButtonStyle,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onTertiaryFixed))
                    : Text(_isEdit ? 'Enregistrer' : 'Créer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.outlineVariant),
        color: AppColors.surfaceContainerLow,
      ),
      child: Row(
        children: [
          Icon(_locataireId != null ? Icons.person : Icons.mail_outline,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_contactNom.isEmpty ? '—' : _contactNom,
                    style: AppTypography.bodyMd),
                if (_inviteEmail != null)
                  Text(_inviteEmail!,
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                if (_locataireId != null)
                  Text('Locataire enregistré',
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Changer',
            onPressed: _clearContact,
          ),
        ],
      ),
    );
  }

  Widget _guestFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _guestNomCtrl,
          decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'Nom (facultatif)'),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _guestEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'E-mail de l\'invité'),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _guestMode = false),
              child: const Text('Retour'),
            ),
            const Spacer(),
            FilledButton.tonal(
              onPressed: _applyGuest,
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 2),
        child: Text(t,
            style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant, letterSpacing: 1.1)),
      );

  Widget _boxRow(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, style: AppTypography.bodyMd)),
            Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
          ],
        ),
      );

  static String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogue « Modifier les plages d'ouverture »
// ─────────────────────────────────────────────────────────────────────────────

class _EditablePlage {
  int debutMin;
  int finMin;
  String type;
  _EditablePlage(this.debutMin, this.finMin, this.type);
}

class _PlagesDialog extends StatefulWidget {
  final List<PlageOuverture> initial;
  const _PlagesDialog({required this.initial});

  @override
  State<_PlagesDialog> createState() => _PlagesDialogState();
}

class _PlagesDialogState extends State<_PlagesDialog> {
  late Map<int, List<_EditablePlage>> _byDay;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _byDay = {for (var d = 1; d <= 7; d++) d: []};
    for (final p in widget.initial) {
      _byDay[p.jourSemaine]!.add(_EditablePlage(p.debutMin, p.finMin, p.type));
    }
  }

  void _loadTemplate() {
    setState(() {
      _byDay = {for (var d = 1; d <= 7; d++) d: []};
      for (final p in defaultPlagesTemplate()) {
        _byDay[p.jourSemaine]!
            .add(_EditablePlage(p.debutMin, p.finMin, p.type));
      }
    });
  }

  Future<void> _pickTime(_EditablePlage p, bool start) async {
    final cur = start ? p.debutMin : p.finMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (start) {
        p.debutMin = m;
        if (p.finMin <= p.debutMin) p.finMin = (p.debutMin + 60).clamp(0, 1439);
      } else {
        p.finMin = m;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final all = <PlageOuverture>[];
      final ownerId = AuthService.currentUser!.id;
      _byDay.forEach((day, list) {
        for (final p in list) {
          if (p.finMin > p.debutMin) {
            all.add(PlageOuverture(
              id: 0,
              ownerId: ownerId,
              jourSemaine: day,
              debutMin: p.debutMin,
              finMin: p.finMin,
              type: p.type,
            ));
          }
        }
      });
      await PlagesOuvertureDatasource.replaceAll(all);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Plages d'ouverture"),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Définissez vos disponibilités par jour. Les plages « Ouverture » '
                'sont réservables ; « Pause » (déjeuner…) est indisponible.',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loadTemplate,
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Charger un modèle (Lun–Ven 9h–18h)'),
                ),
              ),
              const Divider(),
              for (var d = 1; d <= 7; d++) _dayBlock(d),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: AppTheme.saveButtonStyle,
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.onTertiaryFixed))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _dayBlock(int day) {
    final list = _byDay[day]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(_joursNoms[day - 1],
                    style: AppTypography.labelMd
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() =>
                    list.add(_EditablePlage(9 * 60, 12 * 60, 'ouverture'))),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text('Indisponible',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ...list.map((p) => _plageRow(list, p)),
          const Divider(),
        ],
      ),
    );
  }

  Widget _plageRow(List<_EditablePlage> list, _EditablePlage p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: DropdownButtonFormField<String>(
              initialValue: p.type,
              isDense: true,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'ouverture', child: Text('Ouverture')),
                DropdownMenuItem(value: 'pause', child: Text('Pause')),
              ],
              onChanged: (v) => setState(() => p.type = v ?? p.type),
            ),
          ),
          const SizedBox(width: 8),
          _timeBtn(_fmtMin(p.debutMin), () => _pickTime(p, true)),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4), child: Text('–')),
          _timeBtn(_fmtMin(p.finMin), () => _pickTime(p, false)),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.error,
            onPressed: () => setState(() => list.remove(p)),
          ),
        ],
      ),
    );
  }

  Widget _timeBtn(String text, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(64, AppButtonSizes.minTouchTarget)),
        child: Text(text),
      );

  static String _fmtMin(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

// ── Helpers de format partagés ───────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${_joursNoms[d.weekday - 1]} ${d.day} ${_moisNoms[d.month - 1]} ${d.year}';

String _fmtHeure(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
