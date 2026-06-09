import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/demandes_contact.dart';
import 'package:lacoloc_front/data/cache/realtime_refresh_mixin.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/demande_contact.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/notification_model.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/interactions_page.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class VueGeneralePage extends StatefulWidget {
  const VueGeneralePage({super.key});

  @override
  State<VueGeneralePage> createState() => _VueGeneralePageState();
}

class _VueGeneralePageState extends State<VueGeneralePage>
    with RealtimeRefreshMixin {
  late Future<_VueData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void onRealtimeChange() {
    final f = _load();
    setState(() => _future = f);
  }

  Future<_VueData> _load() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return _VueData.empty();

    final immeubles = await ImmeublesDatasource.listByOwner(ownerId);
    final ids = immeubles.map((i) => i.id).toList();
    final chambres = ids.isEmpty
        ? <ChambreModel>[]
        : await ChambresDatasource.listByImmeubles(ids);
    final demandes = await DemandesContactDatasource.listByOwner();
    final pending = demandes.where((d) => !d.contactEtabli).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    List<NotificationModel> notifs = [];
    try {
      final all = await NotificationsDatasource.listByOwner(limit: 5);
      notifs = all.where((n) => !n.isRead).toList();
    } catch (_) {}

    return _VueData(
      immeubles: immeubles,
      chambres: chambres,
      pendingDemandes: pending,
      notifications: notifs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vue générale', style: AppTypography.headlineMd),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Résumé de votre patrimoine immobilier.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualiser',
                onPressed: () {
                  final f = _load();
                  setState(() {
                    _future = f;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: FutureBuilder<_VueData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur : ${snapshot.error}',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.error),
                    ),
                  );
                }
                final data = snapshot.data!;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatCards(
                        immeubles: data.immeubles,
                        chambres: data.chambres,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (data.notifications.isNotEmpty) ...[
                        _NotificationsSection(
                          notifications: data.notifications,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      _PendingDemandesSection(
                        demandes: data.pendingDemandes,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatCards extends StatelessWidget {
  final List<ImmeublesModel> immeubles;
  final List<ChambreModel> chambres;

  const _StatCards({required this.immeubles, required this.chambres});

  @override
  Widget build(BuildContext context) {
    final louees = chambres.where((c) => c.estLoue).length;
    final disponibles = chambres.where((c) => !c.estLoue && c.isActive).length;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _StatCard(
          icon: Icons.apartment_outlined,
          label: 'Immeubles',
          value: '${immeubles.length}',
          color: AppColors.primary,
        ),
        _StatCard(
          icon: Icons.bed_outlined,
          label: 'Chambres',
          value: '${chambres.length}',
          color: AppColors.secondary,
        ),
        _StatCard(
          icon: Icons.key_outlined,
          label: 'Louées',
          value: '$louees',
          color: AppColors.tertiary,
        ),
        _StatCard(
          icon: Icons.lock_open_outlined,
          label: 'Disponibles',
          value: '$disponibles',
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowTint.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.headlineMd.copyWith(color: color),
          ),
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PendingDemandesSection extends StatelessWidget {
  final List<DemandeContactModel> demandes;

  const _PendingDemandesSection({required this.demandes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              "Nouvelles demandes d'interactions",
              style: AppTypography.titleLg,
            ),
            if (demandes.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Badge(
                label: Text('${demandes.length}'),
                backgroundColor: AppColors.error,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (demandes.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.tertiary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Aucune nouvelle demande de contact.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ...demandes.map((d) => _PendingCard(demande: d)),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  final DemandeContactModel demande;

  const _PendingCard({required this.demande});

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  @override
  Widget build(BuildContext context) {
    final bien = [demande.chambreName, demande.immeubleName]
        .whereType<String>()
        .join(' — ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.15),
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  demande.locataireFullName ?? '—',
                  style: AppTypography.labelMd,
                ),
                if (bien.isNotEmpty)
                  Text(
                    bien,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatDate(demande.createdAt),
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsSection extends StatelessWidget {
  final List<NotificationModel> notifications;
  const _NotificationsSection({required this.notifications});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_active_outlined,
                size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text('Notifications récentes', style: AppTypography.titleLg),
            const SizedBox(width: AppSpacing.sm),
            Chip(
              label: Text('${notifications.length}'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final n in notifications)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: NotificationCard(notification: n),
          ),
      ],
    );
  }
}

class _VueData {
  final List<ImmeublesModel> immeubles;
  final List<ChambreModel> chambres;
  final List<DemandeContactModel> pendingDemandes;
  final List<NotificationModel> notifications;

  const _VueData({
    required this.immeubles,
    required this.chambres,
    required this.pendingDemandes,
    this.notifications = const [],
  });

  factory _VueData.empty() => const _VueData(
    immeubles: [],
    chambres: [],
    pendingDemandes: [],
  );
}
