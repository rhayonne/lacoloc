import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/cache/realtime_refresh_mixin.dart';
import 'package:lacoloc_front/data/datasources/demandes_contact.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/data/models/demande_contact.dart';
import 'package:lacoloc_front/data/models/notification_model.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_detail_page.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class InteractionsPage extends StatefulWidget {
  const InteractionsPage({super.key});

  @override
  State<InteractionsPage> createState() => _InteractionsPageState();
}

class _InteractionsPageState extends State<InteractionsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Interactions', style: AppTypography.headlineMd),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Suivi des échanges avec vos locataires.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Demandes de contact'),
                  Tab(text: 'Notifications'),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              _DemandesContactTab(),
              _NotificationsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DemandesContactTab extends StatefulWidget {
  const _DemandesContactTab();

  @override
  State<_DemandesContactTab> createState() => _DemandesContactTabState();
}

class _DemandesContactTabState extends State<_DemandesContactTab>
    with RealtimeRefreshMixin {
  bool _loading = true;
  String? _error;
  List<DemandeContactModel> _demandes = [];
  final Set<int> _toggling = {};

  // Coluna 7 = "Contact établi", ascending = pending (false) primeiro
  int _sortCol = 7;
  bool _sortAsc = true;

  @override
  Set<String> get watchedEntities => {'demandes'};

  @override
  void onRealtimeChange() => _load();

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
      final data = await DemandesContactDatasource.listByOwner();
      if (mounted) {
        setState(() {
          _demandes = data;
          _loading = false;
          _applySort();
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

  void _applySort() {
    _demandes.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case 0: // Nom
          cmp = (a.locataireFullName ?? '').compareTo(
            b.locataireFullName ?? '',
          );
        case 1: // Âge
          cmp = (a.calculatedAge ?? 0).compareTo(b.calculatedAge ?? 0);
        case 5: // Date
          cmp = a.createdAt.compareTo(b.createdAt);
        case 7: // Contact établi — false (pending) deve vir primeiro quando asc
          cmp = a.contactEtabli == b.contactEtabli
              ? 0
              : a.contactEtabli
              ? 1
              : -1;
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
  }

  void _onSort(int col, bool asc) {
    setState(() {
      _sortCol = col;
      _sortAsc = asc;
      _applySort();
    });
  }

  Future<void> _toggleContact(
    DemandeContactModel demande,
    bool newValue,
  ) async {
    setState(() => _toggling.add(demande.id));
    try {
      await DemandesContactDatasource.updateContactEtabli(
        demande.id,
        value: newValue,
      );
      if (mounted) {
        setState(() {
          final idx = _demandes.indexWhere((d) => d.id == demande.id);
          if (idx >= 0) {
            _demandes[idx] = demande.copyWith(contactEtabli: newValue);
          }
          _toggling.remove(demande.id);
          _applySort();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _toggling.remove(demande.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  void _voirDetails(DemandeContactModel demande) {
    if (demande.chambreId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChambreDetailPage(chambreId: demande.chambreId!),
      ),
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.outlined(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
              onPressed: _load,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Erreur : $_error',
              style: AppTypography.bodyMd.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_demandes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Aucune demande de contact pour le moment.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return _SortableDemandesTable(
      demandes: _demandes,
      toggling: _toggling,
      sortCol: _sortCol,
      sortAsc: _sortAsc,
      onSort: _onSort,
      onToggle: _toggleContact,
      onVoirDetails: _voirDetails,
      formatDate: _formatDate,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SortableDemandesTable extends StatelessWidget {
  final List<DemandeContactModel> demandes;
  final Set<int> toggling;
  final int sortCol;
  final bool sortAsc;
  final void Function(int col, bool asc) onSort;
  final void Function(DemandeContactModel, bool) onToggle;
  final void Function(DemandeContactModel) onVoirDetails;
  final String Function(DateTime) formatDate;

  const _SortableDemandesTable({
    required this.demandes,
    required this.toggling,
    required this.sortCol,
    required this.sortAsc,
    required this.onSort,
    required this.onToggle,
    required this.onVoirDetails,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: sortCol,
          sortAscending: sortAsc,
          columnSpacing: 20,
          headingRowColor: WidgetStatePropertyAll(
            AppColors.surfaceContainerHighest,
          ),
          columns: [
            DataColumn(
              label: const Text('Nom complet'),
              headingRowAlignment: MainAxisAlignment.center,
              onSort: onSort,
            ),
            DataColumn(
              label: const Text('Âge'),
              numeric: true,
              headingRowAlignment: MainAxisAlignment.center,
              onSort: onSort,
            ),
            const DataColumn(
              label: Text('Téléphone'),
              headingRowAlignment: MainAxisAlignment.center,
            ),
            const DataColumn(
              label: Text('E-mail'),
              headingRowAlignment: MainAxisAlignment.center,
            ),
            const DataColumn(
              label: Text('Chambre / Immeuble'),
              headingRowAlignment: MainAxisAlignment.center,
            ),
            DataColumn(
              label: const Text('Date'),
              headingRowAlignment: MainAxisAlignment.center,
              onSort: onSort,
            ),
            const DataColumn(
              label: Text('Détails'),
              headingRowAlignment: MainAxisAlignment.center,
            ),
            DataColumn(
              label: const Text('Contact établi'),
              headingRowAlignment: MainAxisAlignment.center,
              onSort: onSort,
            ),
          ],
          rows: demandes.map((d) => _buildRow(context, d)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, DemandeContactModel d) {
    final isToggling = toggling.contains(d.id);
    final bien = [d.chambreName, d.immeubleName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' — ');

    return DataRow(
      color: d.contactEtabli
          ? WidgetStatePropertyAll(
              AppColors.primaryContainer.withValues(alpha: 0.25),
            )
          : null,
      cells: [
        DataCell(Center(child: Text(d.locataireFullName ?? '—'))),
        DataCell(
          Center(child: Text(d.calculatedAge?.toString() ?? '—')),
        ),
        DataCell(Center(child: Text(d.locatairePhone ?? '—'))),
        DataCell(Center(child: Text(d.locataireEmail ?? '—'))),
        DataCell(Center(child: Text(bien.isEmpty ? '—' : bien))),
        DataCell(Center(child: Text(formatDate(d.createdAt)))),
        DataCell(
          d.chambreId != null
              ? Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Voir Annonce'),
                    onPressed: () => onVoirDetails(d),
                  ),
                )
              : const Center(child: Text('—')),
        ),
        DataCell(
          isToggling
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Center(
                  child: Switch(
                    value: d.contactEtabli,
                    onChanged: (v) => onToggle(d, v),
                  ),
                ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Onglet Notifications
// ═════════════════════════════════════════════════════════════════════════════

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab>
    with RealtimeRefreshMixin {
  bool _loading = true;
  String? _error;
  List<NotificationModel> _items = [];

  @override
  Set<String> get watchedEntities => {'notifications'};

  @override
  void onRealtimeChange() => _load();

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
      final data = await NotificationsDatasource.listByOwner();
      if (!mounted) return;
      setState(() => _items = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(NotificationModel n) async {
    if (n.isRead) return;
    await NotificationsDatasource.markRead(n.id);
    await _load();
  }

  Future<void> _markAllRead() async {
    await NotificationsDatasource.markAllRead();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Erreur : $_error'));
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_none,
                  size: 48, color: AppColors.onSurfaceVariant),
              const SizedBox(height: AppSpacing.md),
              Text('Aucune notification.',
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    final hasUnread = _items.any((n) => !n.isRead);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (hasUnread)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _markAllRead,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Tout marquer comme lu'),
              ),
            ),
          for (final n in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: NotificationCard(notification: n, onTap: () => _markRead(n)),
            ),
        ],
      ),
    );
  }
}

/// Carte de notification réutilisable (Interactions + Vue générale).
class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const NotificationCard({super.key, required this.notification, this.onTap});

  IconData get _icon => switch (notification.type) {
        'edl_accepte' => Icons.verified_outlined,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(
      notification.createdAt.toLocal(),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: unread
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.borderMd,
          border: Border.all(
            color: unread
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: AppTypography.titleLg.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      )),
                  if (notification.body != null &&
                      notification.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(notification.body!,
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(dateStr,
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4, left: AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
