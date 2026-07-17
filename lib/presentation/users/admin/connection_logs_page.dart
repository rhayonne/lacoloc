import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/connection_logs.dart';
import 'package:lacoloc_front/data/models/connection_log.dart';
import 'package:lacoloc_front/presentation/widgets/edl_date_range_picker.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/presentation/widgets/app_top_bar.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

final _dateFmt = DateFormat('dd/MM/yyyy', 'fr');

// Types d'utilisateurs disponibles dans le filtre
const _kUserTypes = [
  ('Tous les types', null),
  ('Super Admin', 'super_admin'),
  ('Propriétaire', 'proprietaire'),
  ('Locataire', 'locataire'),
  ('Admin Groupe', 'admin_groupe'),
];

class ConnectionLogsPage extends StatefulWidget {
  const ConnectionLogsPage({super.key});

  @override
  State<ConnectionLogsPage> createState() => _ConnectionLogsPageState();
}

class _ConnectionLogsPageState extends State<ConnectionLogsPage> {
  final _searchCtrl = TextEditingController();
  String? _selectedType;
  DateTime? _fromDate;
  DateTime? _toDate;

  late Future<List<ConnectionLog>> _future;
  Timer? _debounce;

  static const _pageSize = 100;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _load() {
    final f = ConnectionLogsDatasource.list(
      limit: _pageSize,
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      userType: _selectedType,
      from: _fromDate,
      to: _toDate,
    );
    setState(() { _future = f; });
  }

  Future<void> _pickDateRange() async {
    final result = await showEdlDateRangePicker(
      context,
      initial: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (result == null) return; // annulé
    setState(() {
      _fromDate = result.range?.start;
      _toDate = result.range?.end;
    });
    _load();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _selectedType = null;
      _fromDate = null;
      _toDate = null;
    });
    _load();
  }

  bool get _hasFilters =>
      _searchCtrl.text.isNotEmpty ||
      _selectedType != null ||
      _fromDate != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        _buildFilterBar(),
        Expanded(child: _buildTable()),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Journal des connexions',
          trailing: IconButton.outlined(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
          child: Text(
            'Chaque connexion réussie est enregistrée ici.',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Recherche
          SizedBox(
            width: 240,
            height: 40,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, e-mail, IP…)',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.borderSm,
                ),
              ),
              style: AppTypography.bodyMd,
            ),
          ),

          // Filtre type utilisateur
          SizedBox(
            height: 40,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedType,
                isDense: true,
                borderRadius: AppRadius.borderSm,
                items: _kUserTypes
                    .map(
                      (t) => DropdownMenuItem<String?>(
                        value: t.$2,
                        child: Text(t.$1, style: AppTypography.bodyMd),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedType = v);
                  _load();
                },
              ),
            ),
          ),

          // Filtre date
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderSm,
              ),
            ),
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(
              _fromDate != null && _toDate != null
                  ? '${_dateFmt.format(_fromDate!)} → ${_dateFmt.format(_toDate!)}'
                  : 'Période',
              style: AppTypography.bodyMd,
            ),
          ),

          // Effacer filtres
          if (_hasFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Effacer'),
            ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return FutureBuilder<List<ConnectionLog>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Erreur : ${snap.error}',
              style: AppTypography.bodyMd.copyWith(color: AppColors.error),
            ),
          );
        }
        final logs = snap.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_outlined, size: 48,
                    color: AppColors.onSurfaceVariant),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _hasFilters
                      ? 'Aucun résultat pour ces filtres.'
                      : 'Aucune connexion enregistrée.',
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            return isNarrow
                ? _buildCardList(logs)
                : _buildDataTable(logs);
          },
        );
      },
    );
  }

  // ── Vue table (large écran) ────────────────────────────────────────────────

  Widget _buildDataTable(List<ConnectionLog> logs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          AppColors.surfaceContainerLow,
        ),
        columnSpacing: AppSpacing.lg,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        columns: const [
          DataColumn(label: Text('DATE / HEURE')),
          DataColumn(label: Text('UTILISATEUR')),
          DataColumn(label: Text('TYPE')),
          DataColumn(label: Text('IP')),
          DataColumn(label: Text('APPAREIL')),
          DataColumn(label: Text('FUSEAU')),
        ],
        rows: logs.map((log) => _buildRow(log)).toList(),
      ),
    );
  }

  DataRow _buildRow(ConnectionLog log) {
    return DataRow(
      cells: [
        // Date/heure
        DataCell(
          Text(log.createdAtLabel, style: AppTypography.bodyMd),
        ),

        // Utilisateur
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (log.userName != null && log.userName!.isNotEmpty)
                Text(
                  log.userName!,
                  style: AppTypography.bodyMd
                      .copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              Text(
                log.userEmail ?? '—',
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),

        // Type
        DataCell(_TypeChip(userType: log.userType)),

        // IP + WHOIS
        DataCell(_IpCell(log: log)),

        // Appareil / navigateur
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (log.device != null && log.device != 'Inconnu')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _deviceIcon(log.device!),
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(log.device!, style: AppTypography.bodyMd),
                  ],
                ),
              if (log.browser != null && log.browser != 'Inconnu')
                Text(
                  log.browser!,
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
            ],
          ),
        ),

        // Fuseau
        DataCell(
          Text(
            log.timezone ?? '—',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  // ── Vue cartes (petit écran) ───────────────────────────────────────────────

  Widget _buildCardList(List<ConnectionLog> logs) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: logs.length,
      separatorBuilder: (context, i) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _LogCard(log: logs[i]),
    );
  }
}

// ── Widgets utilitaires ────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String? userType;
  const _TypeChip({this.userType});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelColor(userType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (String, Color) _labelColor(String? t) => switch (t) {
        'super_admin' => ('Super Admin', AppColors.error),
        'proprietaire' => ('Propriétaire', AppColors.primary),
        'locataire' => ('Locataire', Colors.teal),
        'admin_groupe' => ('Admin Groupe', Colors.orange),
        _ => (t ?? '—', AppColors.onSurfaceVariant),
      };
}

class _IpCell extends StatelessWidget {
  final ConnectionLog log;
  const _IpCell({required this.log});

  @override
  Widget build(BuildContext context) {
    final ip = log.ipAddress ?? '—';
    final url = log.whoisUrl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ip,
          style: AppTypography.bodyMd.copyWith(
            fontFamily: 'monospace',
            fontSize: 12.5,
          ),
        ),
        if (url != null) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: 'Voir sur ipinfo.io',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => launchUrl(Uri.parse(url)),
              child: Icon(
                Icons.open_in_new,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  final ConnectionLog log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeChip(userType: log.userType),
                const Spacer(),
                Text(
                  log.createdAtLabel,
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (log.userName != null && log.userName!.isNotEmpty)
              Text(
                log.userName!,
                style: AppTypography.bodyMd
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            if (log.userEmail != null)
              Text(
                log.userEmail!,
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            const SizedBox(height: AppSpacing.sm),
            _IpCell(log: log),
            if (log.displayDevice.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    _deviceIcon(log.device ?? ''),
                    size: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    log.displayDevice,
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
            if (log.timezone != null) ...[
              const SizedBox(height: 4),
              Text(
                log.timezone!,
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _deviceIcon(String device) => switch (device) {
      'iPhone' || 'Android' => Icons.smartphone_outlined,
      'iPad' => Icons.tablet_outlined,
      'Mac' => Icons.laptop_mac_outlined,
      'Windows' => Icons.computer_outlined,
      'ChromeOS' => Icons.laptop_chromebook_outlined,
      _ => Icons.devices_outlined,
    };
