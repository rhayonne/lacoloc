import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/datasources/chambres.dart';
import 'package:habitafrance/data/datasources/etat_de_lieux.dart';
import 'package:habitafrance/data/cache/realtime_refresh_mixin.dart';
import 'package:habitafrance/data/datasources/immeubles.dart';
import 'package:habitafrance/data/datasources/notifications.dart';
import 'package:habitafrance/data/datasources/signatures.dart';
import 'package:habitafrance/data/models/chambre.dart';
import 'package:habitafrance/data/models/etat_de_lieux.dart';
import 'package:habitafrance/data/models/immeubles.dart';
import 'package:habitafrance/data/models/notification_model.dart';
import 'package:habitafrance/data/models/users_client.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/presentation/widgets/notification_card.dart';
import 'package:habitafrance/presentation/widgets/bail_requirements_dialog.dart';
import 'package:habitafrance/presentation/widgets/readiness_checklist.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/utils/signature_pad.dart';

class VueGeneralePage extends StatefulWidget {
  /// Liens de la checklist « Conditions pour louer » vers les sections.
  final VoidCallback? onCompleterProfil;
  final VoidCallback? onCreerImmeuble;
  final VoidCallback? onGererChambres;

  /// Lien vers la section « État des lieux » (depuis le bloc « Baux à signer »).
  final VoidCallback? onAllerEtatsDesLieux;

  const VueGeneralePage({
    super.key,
    this.onCompleterProfil,
    this.onCreerImmeuble,
    this.onGererChambres,
    this.onAllerEtatsDesLieux,
  });

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
    setState(() {
      _future = f;
    });
  }

  /// Charge le tableau de bord.
  ///
  /// `refresh: true` partout **volontairement** : c'est la page d'atterrissage,
  /// on l'ouvre pour savoir où on en est. Servir un cache de 5 minutes y
  /// afficherait un résumé périmé — d'où l'ancien bouton « Actualiser », qui
  /// faisait faire à l'utilisateur le travail de l'app. Le bouton a disparu ;
  /// c'est l'ouverture de la page qui recharge.
  Future<_VueData> _load() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return _VueData.empty();

    final immeubles = await ImmeublesDatasource.listByOwner(
      ownerId,
      refresh: true,
    );
    final ids = immeubles.map((i) => i.id).toList();
    final chambres = ids.isEmpty
        ? <ChambreModel>[]
        : await ChambresDatasource.listByImmeubles(ids, refresh: true);

    // Notifications non lues — inclut désormais les nouvelles demandes de
    // contact (notify_nouvelle_demande), qui n'ont plus de bloc dédié.
    List<NotificationModel> notifs = [];
    try {
      final all = await NotificationsDatasource.listByOwner(refresh: true);
      notifs = all.where((n) => !n.isRead).toList();
    } catch (_) {}

    // Baux en attente de la signature du propriétaire : EDL d'entrée éligibles,
    // acceptés par le locataire, mais que le bailleur n'a pas encore signés.
    List<EtatDesLieuxModel> bauxASigner = [];
    try {
      final edls = await EtatDesLieuxDatasource.listByProprietaire(
        ownerId,
        refresh: true,
      );
      bauxASigner = edls
          .where(
            (e) =>
                e.isBailEligible &&
                e.locataireAccepte &&
                !e.bailSignedBy('proprietaire'),
          )
          .toList();
    } catch (_) {}

    final profile = await AuthService.loadCurrentProfile();
    final signatureUrl = await SignaturesDatasource.getSavedUrl();

    return _VueData(
      immeubles: immeubles,
      chambres: chambres,
      notifications: notifs,
      bauxASigner: bauxASigner,
      profile: profile,
      hasSignature: signatureUrl != null,
    );
  }

  /// Ouvre le pop-up de création de signature et l'enregistre comme signature
  /// par défaut, puis rafraîchit la checklist.
  Future<void> _createSignature() async {
    final res = await showSignatureDialog(context);
    if (res == null || !mounted) return;
    try {
      await SignaturesDatasource.saveUrl(res.url);
      final f = _load();
      setState(() {
        _future = f;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _markNotifRead(NotificationModel n) async {
    if (n.isRead) return;
    await NotificationsDatasource.markRead(n.id);
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  /// Tap sur une notification : marque comme lue + ouvre le pop-up des
  /// documents requis du bail pour celles liées à un EDL.
  Future<void> _onNotifTap(NotificationModel n) async {
    await _markNotifRead(n);
    if (!mounted) return;
    const bailTypes = {
      'bail_garant_requis',
      'bail_remplissage',
      'edl_a_signer',
      'edl_accepte',
    };
    if (n.etatDeLieuxId != null && bailTypes.contains(n.type)) {
      await showBailRequirementsDialog(
        context,
        edlId: n.etatDeLieuxId!,
        asProprietaire: true,
      );
      if (mounted) {
        final f = _load();
        setState(() {
          _future = f;
        });
      }
    }
  }

  Future<void> _markAllNotifsRead() async {
    await NotificationsDatasource.markAllRead();
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  /// Conditions « prêt à louer » du propriétaire.
  List<ChecklistItem> _checklistItems(_VueData data) {
    final p = data.profile;
    final profilComplet =
        (p?.fullName?.trim().isNotEmpty ?? false) &&
        (p?.phone?.trim().isNotEmpty ?? false);
    return [
      ChecklistItem(
        label: 'Compléter mon profil',
        hint: 'Nom et téléphone',
        done: profilComplet,
        actionLabel: 'Compléter',
        onAction: widget.onCompleterProfil,
      ),
      ChecklistItem(
        label: 'Enregistrer ma signature électronique',
        hint: 'Nécessaire pour finaliser les états des lieux et baux',
        done: data.hasSignature,
        actionLabel: 'Créer ma signature',
        onAction: _createSignature,
      ),
      ChecklistItem(
        label: 'Créer au moins un immeuble',
        hint: 'Votre bien à louer',
        done: data.immeubles.isNotEmpty,
        actionLabel: 'Ajouter un immeuble',
        onAction: widget.onCreerImmeuble,
      ),
      ChecklistItem(
        label: 'Créer au moins une chambre',
        hint: 'L\'unité louée (chambre ou logement)',
        done: data.chambres.isNotEmpty,
        actionLabel: 'Gérer les chambres',
        onAction: widget.onGererChambres,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barre standard du système — même gabarit que « Mes Propriétés ».
        const AppTopBar(
          title: 'Vue générale',
          subtitle: 'Résumé de votre patrimoine immobilier.',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  );
                }
                final data = snapshot.data!;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReadinessChecklist(items: _checklistItems(data)),
                      const SizedBox(height: AppSpacing.xl),
                      _StatCards(
                        immeubles: data.immeubles,
                        chambres: data.chambres,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (data.bauxASigner.isNotEmpty) ...[
                        _BauxASignerSection(
                          baux: data.bauxASigner,
                          onAller: widget.onAllerEtatsDesLieux,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      if (data.notifications.isNotEmpty) ...[
                        _NotificationsSection(
                          notifications: data.notifications,
                          onTapNotif: _onNotifTap,
                          onMarkAllRead: _markAllNotifsRead,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
          Text(value, style: AppTypography.headlineMd.copyWith(color: color)),
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

/// Bloc « Notifications » du tableau de bord : réunit tout ce qui doit être
/// notifié au propriétaire (nouvelles demandes de contact, garant requis,
/// bail à signer…) — remplace l'ancien bloc ad-hoc « Nouvelles demandes
/// d'interactions » qui ne couvrait que les demandes de contact.
class _NotificationsSection extends StatelessWidget {
  final List<NotificationModel> notifications;
  final ValueChanged<NotificationModel> onTapNotif;
  final VoidCallback onMarkAllRead;

  const _NotificationsSection({
    required this.notifications,
    required this.onTapNotif,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('Notifications', style: AppTypography.titleLg),
            ),
            Chip(
              label: Text('${notifications.length}'),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton.icon(
              onPressed: onMarkAllRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Tout marquer comme lu'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final n in notifications)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: NotificationCard(
              notification: n,
              onTap: () => onTapNotif(n),
            ),
          ),
      ],
    );
  }
}

/// Bloc « Baux à signer » : baux acceptés par le locataire en attente de la
/// signature du bailleur. Carte d'alerte (orange) cliquable → section EDL.
class _BauxASignerSection extends StatelessWidget {
  final List<EtatDesLieuxModel> baux;
  final VoidCallback? onAller;
  const _BauxASignerSection({required this.baux, this.onAller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.draw_outlined, size: 20, color: AppColors.secondary),
            const SizedBox(width: AppSpacing.sm),
            Text('Baux à signer', style: AppTypography.titleLg),
            const SizedBox(width: AppSpacing.sm),
            Chip(
              label: Text('${baux.length}'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final e in baux)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Material(
              color: AppColors.secondaryContainer,
              borderRadius: AppRadius.borderMd,
              child: InkWell(
                onTap: onAller,
                borderRadius: AppRadius.borderMd,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 20,
                        color: scheme.onSurface,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.locataireNom ?? 'Locataire',
                              style: AppTypography.bodyLg.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${e.immeubleNom ?? 'Bien'} — en attente de votre signature',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _VueData {
  final List<ImmeublesModel> immeubles;
  final List<ChambreModel> chambres;
  final List<NotificationModel> notifications;
  final List<EtatDesLieuxModel> bauxASigner;
  final UsersClient? profile;
  final bool hasSignature;

  const _VueData({
    required this.immeubles,
    required this.chambres,
    this.notifications = const [],
    this.bauxASigner = const [],
    this.profile,
    this.hasSignature = false,
  });

  factory _VueData.empty() => const _VueData(immeubles: [], chambres: []);
}
