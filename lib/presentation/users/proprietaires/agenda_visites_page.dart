import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/fournisseurs.dart';
import 'package:lacoloc_front/data/datasources/visites.dart';
import 'package:lacoloc_front/data/models/fournisseur.dart';
import 'package:lacoloc_front/data/models/visite.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/phone_field.dart';

// ─────────────────────────────────────────────────────────────────────────────

class AgendaVisitesPage extends StatefulWidget {
  const AgendaVisitesPage({super.key});

  @override
  State<AgendaVisitesPage> createState() => _AgendaVisitesPageState();
}

class _AgendaVisitesPageState extends State<AgendaVisitesPage> {
  bool _loading = true;
  String? _error;
  List<VisiteModel> _visites = [];
  List<FournisseurModel> _fournisseurs = [];
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ownerId = AuthService.currentUser?.id;
      final visites = await VisitesDatasource.listByOwner();
      final fournisseurs = ownerId != null
          ? await FournisseursDatasource.listActiveByOwner(ownerId)
          : <FournisseurModel>[];
      if (mounted) {
        setState(() {
          _visites = visites;
          _fournisseurs = fournisseurs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openForm([VisiteModel? existing]) async {
    final result = await showDialog<VisiteModel>(
      context: context,
      builder: (_) => _VisiteFormDialog(
        visite: existing,
        fournisseurs: _fournisseurs,
      ),
    );
    if (result != null) await _load();
  }

  Future<void> _delete(VisiteModel v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la visite ?'),
        content: Text(
          '${typeVisiteLabel(v.typeVisite)} — ${v.nomVisiteur}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await VisitesDatasource.delete(v.id);
      await _load();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agenda — Visites', style: AppTypography.headlineMd),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Planification et suivi des visites.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton.icon(
                onPressed: _loading ? null : () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle visite'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(height: 1),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Erreur : $_error',
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.error),
                  ),
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
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Calendrier ──
          Row(
            children: [
              Text('Calendrier $_year', style: AppTypography.titleLg),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Année précédente',
                onPressed: () => setState(() => _year--),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Année suivante',
                onPressed: () => setState(() => _year++),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCalendarSection(),
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),

          // ── Tableau des visites ──
          Row(
            children: [
              Text(
                'Visites (${_visites.length})',
                style: AppTypography.titleLg,
              ),
              const Spacer(),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
                tooltip: 'Actualiser',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTable(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  // ── Calendar section ────────────────────────────────────────────────────────

  Widget _buildCalendarSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 750;
        final calendar = _AnnualCalendarGrid(year: _year, visites: _visites);
        const legend = _VisiteLegend();

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: calendar),
              const SizedBox(width: AppSpacing.xl),
              legend,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            calendar,
            const SizedBox(height: AppSpacing.lg),
            legend,
          ],
        );
      },
    );
  }

  // ── Visites table ───────────────────────────────────────────────────────────

  Widget _buildTable() {
    if (_visites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy_outlined,
                size: 52,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Aucune visite planifiée.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          AppColors.surfaceContainerHighest,
        ),
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Nom du visiteur')),
          DataColumn(label: Text('Téléphone')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _visites.map(_buildRow).toList(),
      ),
    );
  }

  DataRow _buildRow(VisiteModel v) => DataRow(
        cells: [
          DataCell(_TypeChip(type: v.typeVisite)),
          DataCell(Text(v.nomVisiteur)),
          DataCell(Text(v.telephone ?? '—')),
          DataCell(Text(_fmtDate(v.dateVisite))),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Modifier',
                  onPressed: () => _openForm(v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Supprimer',
                  color: AppColors.error,
                  onPressed: () => _delete(v),
                ),
              ],
            ),
          ),
        ],
      );

  static String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Annual calendar
// ─────────────────────────────────────────────────────────────────────────────

class _AnnualCalendarGrid extends StatelessWidget {
  final int year;
  final List<VisiteModel> visites;

  const _AnnualCalendarGrid({required this.year, required this.visites});

  @override
  Widget build(BuildContext context) {
    // Key: 'month-day' (within current year only)
    final byDay = <String, List<VisiteModel>>{};
    for (final v in visites) {
      if (v.dateVisite.year != year) continue;
      final key = '${v.dateVisite.month}-${v.dateVisite.day}';
      (byDay[key] ??= []).add(v);
    }

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: List.generate(
        12,
        (i) => _MonthGrid(year: year, month: i + 1, visitsByDay: byDay),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, List<VisiteModel>> visitsByDay;

  const _MonthGrid({
    required this.year,
    required this.month,
    required this.visitsByDay,
  });

  static const _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _monthNames = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  static const double _cellW = 28.0;
  static const double _cellH = 30.0;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = firstDay.weekday - 1; // Mon = 0

    // Build all cells
    final cells = <Widget>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox(width: _cellW, height: _cellH));
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final key = '$month-$d';
      final dayVisites = visitsByDay[key] ?? [];
      final isToday = year == today.year &&
          month == today.month &&
          d == today.day;
      cells.add(_DayCell(day: d, isToday: isToday, visites: dayVisites));
    }
    // Pad to full weeks
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox(width: _cellW, height: _cellH));
    }

    // Chunk into rows of 7
    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: cells.sublist(i, min(i + 7, cells.length)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _monthNames[month - 1],
            style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _dayLabels
                .map(
                  (h) => SizedBox(
                    width: _cellW,
                    height: 18,
                    child: Center(
                      child: Text(
                        h,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          ...rows,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final List<VisiteModel> visites;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.visites,
  });

  void _showVisitePopup(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final position = box.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.sizeOf(context);
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + box.size.height,
        screenSize.width - position.dx - box.size.width,
        screenSize.height - position.dy - box.size.height,
      ),
      items: visites
          .map(
            (v) => PopupMenuItem<void>(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: typeVisiteColor(v.typeVisite),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        typeVisiteLabel(v.typeVisite),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(v.nomVisiteur, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = visites.map((v) => v.typeVisite).toSet().toList();
    Color? highlightColor;
    if (isToday) {
      highlightColor = AppColors.tertiary;
    } else if (visites.isNotEmpty) {
      highlightColor = typeVisiteColor(types.first);
    }

    final cell = SizedBox(
      width: 28,
      height: 30,
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: highlightColor != null
              ? BoxDecoration(color: highlightColor, shape: BoxShape.circle)
              : null,
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 10,
              color: highlightColor != null ? Colors.white : AppColors.onSurface,
              fontWeight:
                  highlightColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );

    if (visites.isEmpty) return cell;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showVisitePopup(context),
        child: cell,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend
// ─────────────────────────────────────────────────────────────────────────────

class _VisiteLegend extends StatelessWidget {
  const _VisiteLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Légende', style: AppTypography.labelMd),
          const SizedBox(height: AppSpacing.sm),
          _LegendItem(color: AppColors.tertiary, label: "Aujourd'hui"),
          const Divider(height: AppSpacing.lg),
          ...kTypesVisite.map(
            (t) => _LegendItem(
              color: typeVisiteColor(t),
              label: typeVisiteLabel(t),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: AppTypography.bodyMd),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Type chip (for the table)
// ─────────────────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = typeVisiteColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        typeVisiteLabel(type),
        style: AppTypography.labelSm.copyWith(color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form dialog (create / edit)
// ─────────────────────────────────────────────────────────────────────────────

class _VisiteFormDialog extends StatefulWidget {
  final VisiteModel? visite;
  final List<FournisseurModel> fournisseurs;

  const _VisiteFormDialog({this.visite, required this.fournisseurs});

  @override
  State<_VisiteFormDialog> createState() => _VisiteFormDialogState();
}

class _VisiteFormDialogState extends State<_VisiteFormDialog> {
  bool _saving = false;
  String _type = kTypesVisite.first;

  // Nom
  String _nomValue = '';
  String? _nomError;
  FournisseurModel? _selectedFournisseur;

  String _phoneInitValue = '';
  GlobalKey<FormBuilderState> _phoneFormKey = GlobalKey<FormBuilderState>();

  // Date
  DateTime? _date;

  bool get _isReparation => _type == 'reparation';

  @override
  void initState() {
    super.initState();
    final v = widget.visite;
    if (v != null) {
      _type = v.typeVisite;
      _nomValue = v.nomVisiteur;
      _phoneInitValue = v.telephone ?? '';
      _date = v.dateVisite;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('fr'),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    // Validate nom
    if (_nomValue.trim().isEmpty) {
      setState(() => _nomError = 'Ce champ est requis.');
      return;
    }
    // Validate date
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ownerId = AuthService.currentUser!.id;
      final phone =
          PhoneField.fullNumberFromState(_phoneFormKey.currentState, 'phone') ??
          '';
      final draft = VisiteModel(
        id: widget.visite?.id ?? 0,
        ownerId: ownerId,
        typeVisite: _type,
        nomVisiteur: _nomValue.trim(),
        telephone: phone.isEmpty ? null : phone,
        dateVisite: _date!,
        fournisseurId: _isReparation ? _selectedFournisseur?.id : null,
        createdAt: widget.visite?.createdAt ?? DateTime.now(),
      );

      final saved = widget.visite == null
          ? await VisitesDatasource.create(draft)
          : await VisitesDatasource.update(draft);

      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.visite == null ? 'Nouvelle visite' : 'Modifier la visite',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Type de visite ──
              _fieldLabel('TYPE DE VISITE'),
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: kTypesVisite
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(typeVisiteLabel(t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _type = v;
                    if (v != 'reparation') {
                      _selectedFournisseur = null;
                    }
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Nom complet ──
              _fieldLabel('NOM COMPLET DU VISITEUR'),
              if (_isReparation)
                _FournisseurAutocomplete(
                  fournisseurs: widget.fournisseurs,
                  initialText: _nomValue,
                  onSelected: (f) {
                    setState(() {
                      _selectedFournisseur = f;
                      _nomValue = f.nom;
                      _nomError = null;
                      _phoneInitValue = f.telephone ?? '';
                      // New key forces FormBuilder to rebuild with the
                      // fournisseur's phone as initialValue.
                      _phoneFormKey = GlobalKey<FormBuilderState>();
                    });
                  },
                  onChanged: (text) {
                    _nomValue = text;
                    if (_selectedFournisseur?.nom != text) {
                      setState(() => _selectedFournisseur = null);
                    }
                    if (_nomError != null && text.trim().isNotEmpty) {
                      setState(() => _nomError = null);
                    }
                  },
                )
              else
                TextFormField(
                  initialValue: _nomValue,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Jean Dupont'),
                  onChanged: (v) {
                    _nomValue = v;
                    if (_nomError != null && v.trim().isNotEmpty) {
                      setState(() => _nomError = null);
                    }
                  },
                ),
              if (_nomError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    _nomError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),

              _fieldLabel('TÉLÉPHONE'),
              FormBuilder(
                key: _phoneFormKey,
                child: PhoneField(
                  name: 'phone',
                  initialValue: _phoneInitValue,
                  enabled: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Date de la visite ──
              _fieldLabel('DATE DE LA VISITE'),
              InkWell(
                onTap: _pickDate,
                borderRadius: AppRadius.borderSm,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.outlineVariant),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _date == null
                              ? 'Sélectionner une date'
                              : _fmtDate(_date!),
                          style: _date == null
                              ? AppTypography.bodyMd.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                )
                              : AppTypography.bodyMd,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.visite == null ? 'Créer' : 'Enregistrer'),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          text,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
      );

  static String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Fournisseur autocomplete (used when type = réparation)
// ─────────────────────────────────────────────────────────────────────────────

class _FournisseurAutocomplete extends StatelessWidget {
  final List<FournisseurModel> fournisseurs;
  final String initialText;
  final ValueChanged<FournisseurModel> onSelected;
  final ValueChanged<String> onChanged;

  const _FournisseurAutocomplete({
    required this.fournisseurs,
    required this.initialText,
    required this.onSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<FournisseurModel>(
      initialValue: TextEditingValue(text: initialText),
      optionsBuilder: (value) {
        if (value.text.isEmpty) return fournisseurs;
        return fournisseurs.where(
          (f) => f.nom.toLowerCase().contains(value.text.toLowerCase()),
        );
      },
      displayStringForOption: (f) => f.nom,
      onSelected: onSelected,
      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) => TextFormField(
        controller: ctrl,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'Rechercher un fournisseur...',
          suffixIcon: Icon(Icons.search, size: 18),
        ),
      ),
      optionsViewBuilder: (ctx, onAutoSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: AppRadius.borderMd,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (ctx, i) {
                final f = options.elementAt(i);
                return ListTile(
                  title: Text(f.nom),
                  subtitle: f.categorie != null ? Text(f.categorie!) : null,
                  trailing: f.telephone != null
                      ? Text(
                          f.telephone!,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        )
                      : null,
                  onTap: () => onAutoSelected(f),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
