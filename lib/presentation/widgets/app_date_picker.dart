import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/app_theme.dart';

/// Sélecteur de **date unique** — LE sélecteur de date standard de l'app.
///
/// Même langage visuel que [showEdlDateRangePicker] (pop-up centré, fond flouté,
/// champ de date, calendrier mensuel avec flèches, raccourcis, pied
/// Annuler/Enregistrer), mais en **sélection simple**. À utiliser **partout**
/// à la place de `showDatePicker` natif.
///
/// Retour : la date choisie, ou `null` si annulé.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showGeneralDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (context, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (context, _, _) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Center(
        child: _DatePopup(
          initial: initial,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
      ),
    ),
  );
}

class _DatePopup extends StatefulWidget {
  final DateTime? initial;
  final DateTime? firstDate;
  final DateTime? lastDate;
  const _DatePopup({this.initial, this.firstDate, this.lastDate});

  @override
  State<_DatePopup> createState() => _DatePopupState();
}

class _DatePopupState extends State<_DatePopup> {
  DateTime? _selected;
  late DateTime _month; // 1er du mois affiché

  static final _fieldFmt = DateFormat('EEEE dd MMMM yyyy', 'fr');
  static final _monthFmt = DateFormat('MMMM yyyy', 'fr');

  static DateTime _dOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial != null ? _dOnly(widget.initial!) : null;
    final anchor = _selected ?? DateTime.now();
    _month = DateTime(anchor.year, anchor.month);
  }

  bool _disabled(DateTime day) {
    if (widget.firstDate != null && day.isBefore(_dOnly(widget.firstDate!))) {
      return true;
    }
    if (widget.lastDate != null && day.isAfter(_dOnly(widget.lastDate!))) {
      return true;
    }
    return false;
  }

  void _jumpTo(DateTime day) {
    if (_disabled(day)) return;
    setState(() {
      _selected = _dOnly(day);
      _month = DateTime(day.year, day.month);
    });
  }

  void _save() {
    if (_selected == null) return;
    Navigator.of(context).pop(_selected);
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
              _field(),
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
          onPressed: () => setState(() => _selected = null),
          child: const Text('Réinitialiser'),
        ),
      ],
    );
  }

  Widget _field() {
    final value =
        _selected != null ? _capitalize(_fieldFmt.format(_selected!)) : '—';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.primary, width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DATE',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 2),
          Text(value,
              style:
                  AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
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
        Text(_capitalize(label), style: AppTypography.titleLg),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mois précédent',
          onPressed: () => setState(
              () => _month = DateTime(_month.year, _month.month - 1)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Mois suivant',
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
    final leading = first.weekday - 1;
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
      rows.add(Row(children: [
        for (var j = i; j < i + 7; j++) Expanded(child: cells[j]),
      ]));
    }
    return Column(children: rows);
  }

  Widget _dayCell(DateTime day) {
    final selected = _selected != null && _same(day, _selected!);
    final isToday = _same(day, DateTime.now());
    final disabled = _disabled(day);
    return InkWell(
      onTap: disabled ? null : () => _jumpTo(day),
      child: AspectRatio(
        aspectRatio: 1,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: selected
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
                color: disabled
                    ? AppColors.outline
                    : selected
                        ? AppColors.onPrimary
                        : (isToday ? AppColors.primary : AppColors.onSurface),
                fontWeight: selected || isToday ? FontWeight.w700 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickChips() {
    final today = _dOnly(DateTime.now());
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _chip("Aujourd'hui", _selected != null && _same(_selected!, today),
            () => _jumpTo(today)),
        _chip(
            'Demain',
            _selected != null &&
                _same(_selected!, today.add(const Duration(days: 1))),
            () => _jumpTo(today.add(const Duration(days: 1)))),
        _chip(
            'Dans 7 j',
            _selected != null &&
                _same(_selected!, today.add(const Duration(days: 7))),
            () => _jumpTo(today.add(const Duration(days: 7)))),
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
              color: active ? AppColors.primary : AppColors.outlineVariant),
        ),
        child: Text(label,
            style: AppTypography.labelMd.copyWith(
              color: active ? AppColors.onPrimary : AppColors.onSurface,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }

  Widget _footer() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _selected != null ? 'Date sélectionnée' : 'Aucune date',
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
          onPressed: _selected == null ? null : _save,
          style: AppTheme.saveButtonStyle,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
