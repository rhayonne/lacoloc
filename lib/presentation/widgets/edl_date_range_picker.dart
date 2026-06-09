import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Sélecteur de plage de dates **personnalisé** (filtres EDL de la Vision
/// générale). Pop-up centré avec arrière-plan flouté : champs Début/Fin, un
/// calendrier mensuel avec bande de plage, des raccourcis (7/14/30 jours, ce
/// mois-ci) et un pied « N jours sélectionnés ».
///
/// Retour : `null` = annulé (aucun changement) ; un record `(range: …)` quand
/// l'utilisateur valide — `range` peut être `null` (filtre réinitialisé).
Future<({DateTimeRange? range})?> showEdlDateRangePicker(
  BuildContext context, {
  DateTimeRange? initial,
}) {
  return showGeneralDialog<({DateTimeRange? range})>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (context, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (context, _, _) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Center(child: _DateRangePopup(initial: initial)),
    ),
  );
}

class _DateRangePopup extends StatefulWidget {
  final DateTimeRange? initial;
  const _DateRangePopup({this.initial});

  @override
  State<_DateRangePopup> createState() => _DateRangePopupState();
}

class _DateRangePopupState extends State<_DateRangePopup> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _month; // 1er du mois affiché

  static final _fieldFmt = DateFormat('dd MMM yyyy', 'fr');
  static final _monthFmt = DateFormat('MMMM yyyy', 'fr');

  @override
  void initState() {
    super.initState();
    _start = widget.initial?.start;
    _end = widget.initial?.end;
    final anchor = _start ?? DateTime.now();
    _month = DateTime(anchor.year, anchor.month);
  }

  static DateTime _dOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int get _count =>
      (_start != null && _end != null) ? _end!.difference(_start!).inDays : 0;

  void _onDayTap(DateTime day) {
    setState(() {
      if (_start == null || _end != null) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  void _applyDays(int days) {
    final today = _dOnly(DateTime.now());
    setState(() {
      _start = today;
      _end = today.add(Duration(days: days));
      _month = DateTime(today.year, today.month);
    });
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    setState(() {
      _start = DateTime(now.year, now.month, 1);
      _end = DateTime(now.year, now.month + 1, 0);
      _month = DateTime(now.year, now.month);
    });
  }

  bool _isDaysActive(int days) {
    final today = _dOnly(DateTime.now());
    return _start != null &&
        _end != null &&
        _same(_start!, today) &&
        _same(_end!, today.add(Duration(days: days)));
  }

  bool get _isThisMonthActive {
    final now = DateTime.now();
    return _start != null &&
        _end != null &&
        _same(_start!, DateTime(now.year, now.month, 1)) &&
        _same(_end!, DateTime(now.year, now.month + 1, 0));
  }

  void _save() {
    if (_start == null) {
      Navigator.of(context).pop((range: null)); // réinitialisé → efface
      return;
    }
    final end = _end ?? _start!;
    Navigator.of(context)
        .pop((range: DateTimeRange(start: _start!, end: end)));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.borderLg,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: AppSpacing.md),
              _fields(),
              const SizedBox(height: AppSpacing.md),
              _monthNav(),
              const SizedBox(height: AppSpacing.sm),
              _weekdays(),
              const SizedBox(height: AppSpacing.xs),
              _grid(),
              const SizedBox(height: AppSpacing.md),
              _quickChips(),
              const Divider(height: AppSpacing.xl),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Fermer',
        ),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() {
            _start = null;
            _end = null;
          }),
          child: const Text('Réinitialiser'),
        ),
      ],
    );
  }

  Widget _fields() {
    final selectingEnd = _start != null && _end == null;
    return Row(
      children: [
        Expanded(
          child: _dateField(
            label: 'DÉBUT',
            value: _start != null ? _fieldFmt.format(_start!) : '—',
            active: !selectingEnd,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Icon(Icons.arrow_forward, size: 18,
              color: AppColors.onSurfaceVariant),
        ),
        Expanded(
          child: _dateField(
            label: 'FIN',
            value: _end != null ? _fieldFmt.format(_end!) : '—',
            active: selectingEnd,
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderMd,
        color: active ? null : AppColors.surfaceContainerLow,
        border: Border.all(
          color: active ? AppColors.primary : AppColors.outlineVariant,
          width: active ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 2),
          Text(value,
              style: AppTypography.bodyMd
                  .copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _monthNav() {
    final label = _monthFmt.format(_month);
    return Row(
      children: [
        Text(
          '${label[0].toUpperCase()}${label.substring(1)}',
          style: AppTypography.titleLg,
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(
              () => _month = DateTime(_month.year, _month.month - 1)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(
              () => _month = DateTime(_month.year, _month.month + 1)),
        ),
      ],
    );
  }

  Widget _weekdays() {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(l,
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ),
      ],
    );
  }

  Widget _grid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1; // lundi = 1
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(_dayCell(DateTime(_month.year, _month.month, d)));
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(Row(
        children: [
          for (var j = i; j < i + 7; j++) Expanded(child: cells[j]),
        ],
      ));
    }
    return Column(children: rows);
  }

  Widget _dayCell(DateTime day) {
    final isStart = _start != null && _same(day, _start!);
    final isEnd = _end != null && _same(day, _end!);
    final edge = isStart || isEnd;
    final inRange = _start != null &&
        _end != null &&
        day.isAfter(_start!) &&
        day.isBefore(_end!);
    final isToday = _same(day, DateTime.now());
    final hasRange = _start != null && _end != null && !_same(_start!, _end!);

    const bandColor = Color(0x1A006685); // primary @ ~10 %

    Widget? band;
    if (inRange) {
      band = Container(color: bandColor);
    } else if (isStart && hasRange) {
      band = Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
            widthFactor: 0.5, heightFactor: 1, child: Container(color: bandColor)),
      );
    } else if (isEnd && hasRange) {
      band = Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
            widthFactor: 0.5, heightFactor: 1, child: Container(color: bandColor)),
      );
    }

    return InkWell(
      onTap: () => _onDayTap(day),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (band != null) Positioned.fill(child: band),
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: edge
                  ? const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle)
                  : (isToday
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary))
                      : null),
              child: Text(
                '${day.day}',
                style: AppTypography.bodyMd.copyWith(
                  color: edge
                      ? AppColors.onPrimary
                      : (isToday ? AppColors.primary : AppColors.onSurface),
                  fontWeight: edge || isToday ? FontWeight.w700 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _chip('7 jours', _isDaysActive(7), () => _applyDays(7)),
        _chip('14 jours', _isDaysActive(14), () => _applyDays(14)),
        _chip('30 jours', _isDaysActive(30), () => _applyDays(30)),
        _chip('Ce mois-ci', _isThisMonthActive, _applyThisMonth),
      ],
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderFull,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : null,
          borderRadius: AppRadius.borderFull,
          border: Border.all(
            color: active ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            color: active ? AppColors.onPrimary : AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _count > 0
                ? '$_count jour${_count > 1 ? 's' : ''} sélectionné${_count > 1 ? 's' : ''}'
                : 'Aucune plage',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
