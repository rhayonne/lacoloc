import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lacoloc_front/presentation/widgets/bail_requirements_dialog.dart';
import 'package:lacoloc_front/utils/media_embed.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/cache/realtime_refresh_mixin.dart';
import 'package:lacoloc_front/data/datasources/demandes_contact.dart';
import 'package:lacoloc_front/data/datasources/messages.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/presentation/widgets/conversation_view.dart';
import 'package:lacoloc_front/data/permissions/permissions_service.dart';
import 'package:lacoloc_front/presentation/widgets/permission_gate.dart';
import 'package:lacoloc_front/data/models/demande_contact.dart';
import 'package:lacoloc_front/data/models/notification_model.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_detail_page.dart';
import 'package:lacoloc_front/theme/app_breakpoints.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/presentation/widgets/app_top_bar.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/app_tab_bar.dart';

class InteractionsPage extends StatefulWidget {
  final int initialTab;
  final bool showTabBar;
  const InteractionsPage({super.key, this.initialTab = 0, this.showTabBar = true});

  @override
  State<InteractionsPage> createState() => _InteractionsPageState();
}

class _InteractionsPageState extends State<InteractionsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Titre de la barre : nom du sous-menu quand la navigation est pilotée par
    // la sidebar ; sinon titre générique de la section.
    const subLabels = ['Demandes de contact', 'Notifications'];
    final barTitle = widget.showTabBar
        ? 'Interactions'
        : subLabels[widget.initialTab.clamp(0, 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTopBar(title: barTitle),
        if (widget.showTabBar) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: AppTabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Demandes de contact'),
                Tab(text: 'Notifications'),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
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

  /// Messages non lus par demande (pastille sur le bouton Discussion).
  Map<int, int> _unread = const {};

  /// Fil ouvert : rendu **dans le cadre**, à la place de la liste.
  DemandeContactModel? _conversation;

  // Coluna 7 = "Contact établi", ascending = pending (false) primeiro
  int _sortCol = 7;
  bool _sortAsc = true;

  @override
  Set<String> get watchedEntities => {'demandes', 'messages'};

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
      final unread = await MessagesDatasource.unreadCountByDemande(
        refresh: true,
      );
      if (mounted) {
        setState(() {
          _demandes = data;
          _unread = unread;
          _loading = false;
          _applySort();
          // Garder le fil ouvert à jour (ex. la demande vient d'être acceptée).
          final open = _conversation;
          if (open != null) {
            final idx = _demandes.indexWhere((d) => d.id == open.id);
            _conversation = idx >= 0 ? _demandes[idx] : null;
          }
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

  /// Ouvre le fil **dans le cadre** (le menu reste à gauche) — pas de
  /// `Navigator.push`, conformément à la convention des fiches détail.
  void _ouvrirDiscussion(DemandeContactModel demande) {
    setState(() => _conversation = demande);
  }

  void _fermerDiscussion() {
    setState(() => _conversation = null);
    _load(); // rafraîchit les pastilles « non lus »
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
    // Fil ouvert → il prend la place de la liste (le menu reste à gauche).
    final conv = _conversation;
    if (conv != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConversationView(demande: conv, onClose: _fermerDiscussion),
      );
    }

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
            Icon(
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
      unread: _unread,
      sortCol: _sortCol,
      sortAsc: _sortAsc,
      onSort: _onSort,
      onToggle: _toggleContact,
      onVoirDetails: _voirDetails,
      onDiscussion: _ouvrirDiscussion,
      formatDate: _formatDate,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SortableDemandesTable extends StatelessWidget {
  final List<DemandeContactModel> demandes;
  final Set<int> toggling;
  final Map<int, int> unread;
  final int sortCol;
  final bool sortAsc;
  final void Function(int col, bool asc) onSort;
  final void Function(DemandeContactModel, bool) onToggle;
  final void Function(DemandeContactModel) onVoirDetails;
  final void Function(DemandeContactModel) onDiscussion;
  final String Function(DateTime) formatDate;

  const _SortableDemandesTable({
    required this.demandes,
    required this.toggling,
    required this.unread,
    required this.sortCol,
    required this.sortAsc,
    required this.onSort,
    required this.onToggle,
    required this.onVoirDetails,
    required this.onDiscussion,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    // Tablette/mobile : la DataTable dense devient une liste de cartes lisibles
    // et tactiles ; au-dessus du seuil, on garde le tableau triable.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.tableToCards) {
          return _buildCards(context);
        }
        return _buildTable(context);
      },
    );
  }

  Widget _buildCards(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: demandes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _DemandeCard(
        demande: demandes[i],
        isToggling: toggling.contains(demandes[i].id),
        unread: unread[demandes[i].id] ?? 0,
        onToggle: onToggle,
        onVoirDetails: onVoirDetails,
        onDiscussion: onDiscussion,
        formatDate: formatDate,
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
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
            const DataColumn(
              label: Text('Discussion'),
              headingRowAlignment: MainAxisAlignment.center,
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
                  child: PermissionGate(
                    permission: Perm.demandesManage,
                    fallback: Switch(value: d.contactEtabli, onChanged: null),
                    child: Switch(
                      value: d.contactEtabli,
                      onChanged: (v) => onToggle(d, v),
                    ),
                  ),
                ),
        ),
        DataCell(
          Center(
            child: DiscussionButton(
              demande: d,
              unread: unread[d.id] ?? 0,
              onPressed: () => onDiscussion(d),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton d'accès au fil de discussion d'une demande, avec pastille de messages
/// non lus. Désactivé tant que la demande n'est pas acceptée — c'est
/// l'acceptation qui ouvre le fil (la RLS de `Messages` s'appuie dessus).
///
/// Partagé par le tableau, les cartes et l'écran locataire : une seule règle
/// d'activation, un seul visuel.
class DiscussionButton extends StatelessWidget {
  final DemandeContactModel demande;
  final int unread;
  final VoidCallback onPressed;

  const DiscussionButton({
    super.key,
    required this.demande,
    required this.unread,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final ouverte = demande.discussionOuverte;
    final icone = Icon(
      ouverte ? Icons.forum_outlined : Icons.lock_outline,
      size: 18,
    );
    return Tooltip(
      message: ouverte
          ? 'Ouvrir la discussion'
          : 'Acceptez la demande (« Contact établi ») pour discuter',
      child: TextButton.icon(
        onPressed: ouverte ? onPressed : null,
        icon: unread > 0
            ? Badge(label: Text('$unread'), child: icone)
            : icone,
        label: const Text('Discuter'),
      ),
    );
  }
}

/// Carte d'une demande de contact (tablette/mobile) — équivalent d'une ligne du
/// tableau, mais empilée et tactile.
class _DemandeCard extends StatelessWidget {
  final DemandeContactModel demande;
  final bool isToggling;
  final int unread;
  final void Function(DemandeContactModel, bool) onToggle;
  final void Function(DemandeContactModel) onVoirDetails;
  final void Function(DemandeContactModel) onDiscussion;
  final String Function(DateTime) formatDate;

  const _DemandeCard({
    required this.demande,
    required this.isToggling,
    required this.unread,
    required this.onToggle,
    required this.onVoirDetails,
    required this.onDiscussion,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final bien = [d.chambreName, d.immeubleName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' — ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: d.contactEtabli
            ? AppColors.primaryContainer.withValues(alpha: 0.25)
            : AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.locataireFullName ?? '—',
                  style:
                      AppTypography.titleLg.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (d.calculatedAge != null)
                Text('${d.calculatedAge} ans',
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          if (bien.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(bien,
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (d.locatairePhone != null)
            _line(Icons.phone_outlined, d.locatairePhone!),
          if (d.locataireEmail != null)
            _line(Icons.mail_outline, d.locataireEmail!),
          _line(Icons.event_outlined, formatDate(d.createdAt)),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (d.chambreId != null)
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Voir Annonce'),
                  onPressed: () => onVoirDetails(d),
                ),
              const Spacer(),
              Text('Contact établi',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
              isToggling
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : PermissionGate(
                      permission: Perm.demandesManage,
                      fallback:
                          Switch(value: d.contactEtabli, onChanged: null),
                      child: Switch(
                        value: d.contactEtabli,
                        onChanged: (v) => onToggle(d, v),
                      ),
                    ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: DiscussionButton(
              demande: d,
              unread: unread,
              onPressed: () => onDiscussion(d),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(text,
                  style: AppTypography.bodyMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
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

  /// Tap sur une notification : marque comme lue + ouvre le pop-up des
  /// documents requis du bail pour les notifications liées à un EDL.
  Future<void> _onNotifTap(NotificationModel n) async {
    await _markRead(n);
    if (!mounted) return;
    if (n.etatDeLieuxId != null && _isBailNotif(n.type)) {
      await showBailRequirementsDialog(context,
          edlId: n.etatDeLieuxId!, asProprietaire: true);
      if (mounted) _load();
    }
  }

  static bool _isBailNotif(String type) => const {
        'bail_garant_requis',
        'bail_remplissage',
        'edl_a_signer',
        'edl_accepte',
      }.contains(type);

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
              Icon(Icons.notifications_none,
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
              child: NotificationCard(notification: n, onTap: () => _onNotifTap(n)),
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
        'admin_message' => Icons.campaign_outlined,
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
                    // Rendu Markdown (sans HTML brut → pas d'injection XSS).
                    MarkdownBody(
                      data: notification.body!,
                      onTapLink: (text, href, title) {
                        if (href != null) {
                          launchUrl(Uri.parse(href),
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                  if (notification.mediaType != null &&
                      notification.mediaUrl != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    MessageMediaView(
                      mediaType: notification.mediaType,
                      mediaUrl: notification.mediaUrl,
                      height: 200,
                    ),
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
                decoration: BoxDecoration(
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
