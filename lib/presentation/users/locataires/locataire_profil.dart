import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/cache/realtime_refresh_mixin.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/datasources/garants.dart';
import 'package:lacoloc_front/presentation/widgets/readiness_checklist.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/data/datasources/recettes.dart';
import 'package:lacoloc_front/data/models/recette.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/garant.dart';
import 'package:lacoloc_front/data/models/notification_model.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/data/permissions/permissions_service.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_card.dart';
import 'package:lacoloc_front/presentation/widgets/permission_gate.dart';
import 'package:lacoloc_front/presentation/widgets/private_image.dart';
import 'package:lacoloc_front/presentation/widgets/edl_filter_bar.dart';
import 'package:lacoloc_front/presentation/widgets/edl_signature_flow.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/etat_de_lieux_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/interactions_page.dart'
    show NotificationCard;
import 'package:lacoloc_front/presentation/chambres/chambre_detail_page.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/presentation/users/locataires/garants_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/bail_pdf_preview_page.dart';
import 'package:lacoloc_front/presentation/widgets/bail_signature_flow.dart';
import 'package:lacoloc_front/presentation/widgets/filter_panel.dart';
import 'package:lacoloc_front/utils/phone_field.dart';
import 'package:lacoloc_front/data/datasources/signatures.dart';
import 'package:lacoloc_front/utils/signature_pad.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class LocataireProfilPage extends StatefulWidget {
  const LocataireProfilPage({super.key});

  @override
  State<LocataireProfilPage> createState() => _LocataireProfilPageState();
}

class _LocataireProfilPageState extends State<LocataireProfilPage>
    with RealtimeRefreshMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _contentKey = GlobalKey();
  late final SidebarXController _navCtrl;

  /// Données chargées (chambres + profil) ; null tant que le 1ᵉʳ chargement
  /// n'est pas terminé.
  _LocBundle? _data;
  String? _error;

  /// Compteurs « à traiter » pour les pastilles de menu (mis à jour au chargement
  /// et sur changement Realtime).
  int _edlBadge = 0; // EDL finalisés non signés
  int _msgBadge = 0; // notifications non lues
  List<EtatDesLieuxModel> _pendingEdls = const [];
  List<NotificationModel> _unreadNotifs = const [];

  /// Au moins un bail exige un garant alors que le locataire n'en a aucun.
  bool _needsGarant = false;

  /// État courant pour la checklist « Conditions pour louer ».
  bool _hasSignature = false;
  bool _hasGarant = false;

  /// Onglet initial de la section Documents (0 = Baux, 1 = Garants) — utilisé
  /// pour ouvrir directement les Garants depuis le raccourci du tableau de bord.
  int _documentsInitialTab = 0;

  int? _selectedChambreId;

  /// Dernier index de menu sélectionné (pour ne rafraîchir que sur un vrai
  /// changement de section, pas au collapse/expand de la sidebar).
  int _lastNavIndex = _idxDashboard;

  // Ordre du menu : Rechercher location (0) · Tableau de bord (1) ·
  // État des lieux (2) · Messages (3) · Documents (4) · Finances (5) ·
  // Mon Profil (6).
  static const _idxChambres = 0;
  static const _idxDashboard = 1;
  static const _idxEdl = 2;
  static const _idxMessages = 3;
  static const _idxDocuments = 4;
  static const _idxFinances = 5;
  static const _idxProfil = 6;

  @override
  Set<String> get watchedEntities => {'notifications', 'edl'};

  @override
  void onRealtimeChange() => _refresh();

  @override
  void initState() {
    super.initState();
    // Atterrissage par défaut sur le Tableau de bord (ce qui est en attente).
    _navCtrl = SidebarXController(selectedIndex: _idxDashboard, extended: true);
    _navCtrl.addListener(_onNavChanged);
    _refresh();
  }

  @override
  void dispose() {
    _navCtrl.removeListener(_onNavChanged);
    _navCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final uid = AuthService.currentUser?.id ?? '';
    try {
      final results = await Future.wait([
        ChambresDatasource.listAll(),
        AuthService.loadCurrentProfile(),
        EtatDesLieuxDatasource.listForLocataire(uid),
        NotificationsDatasource.listByOwner(refresh: true),
        GarantsDatasource.activeByLocataire(uid),
        SignaturesDatasource.getSavedUrl(),
      ]);
      if (!mounted) return;
      final all = results[0] as List<ChambreModel>;
      final profile = results[1] as UsersClient?;
      final edls = results[2] as List<EtatDesLieuxModel>;
      final notifs = results[3] as List<NotificationModel>;
      final garants = results[4] as List<GarantModel>;
      final signatureUrl = results[5] as String?;
      final available = all.where((c) => !c.estLoue && c.isActive).toList();
      final pending = edls
          .where((e) =>
              e.situation == SituationEdl.finalise && !e.locataireAccepte)
          .toList();
      final unread = notifs.where((n) => !n.isRead).toList();
      // Un bail exige un garant mais le locataire n'en a aucun → alerte.
      final needsGarant =
          garants.isEmpty && edls.any((e) => e.bailAvecGarant == true);
      setState(() {
        _data =
            _LocBundle(available: available, total: all.length, profile: profile);
        _pendingEdls = pending;
        _unreadNotifs = unread;
        _edlBadge = pending.length;
        _msgBadge = unread.length;
        _needsGarant = needsGarant;
        _hasSignature = signatureUrl != null;
        _hasGarant = garants.isNotEmpty;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onNavChanged() {
    if (!mounted) return;
    final idx = _navCtrl.selectedIndex;
    // Le listener se déclenche aussi au collapse/expand de la sidebar (sans
    // changer d'index) : on ne rafraîchit que lors d'un vrai changement de
    // section. Revenir sur le tableau de bord après avoir agi ailleurs (profil,
    // signature, garant…) recharge la checklist « Conditions pour louer ».
    final changed = idx != _lastNavIndex;
    _lastNavIndex = idx;
    setState(() => _selectedChambreId = null);
    if (changed && idx == _idxDashboard) _refresh();
  }

  Future<void> _doLogout() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  void _goToChambres() => _navCtrl.selectIndex(_idxChambres);
  void _goToEdl() => _navCtrl.selectIndex(_idxEdl);
  void _goToMessages() => _navCtrl.selectIndex(_idxMessages);

  void _goToProfil() => _navCtrl.selectIndex(_idxProfil);

  /// Ouvre le pop-up de création de signature et l'enregistre comme signature
  /// par défaut, puis rafraîchit la checklist.
  Future<void> _createSignature() async {
    final res = await showSignatureDialog(context);
    if (res == null || !mounted) return;
    try {
      await SignaturesDatasource.saveUrl(res.url);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  /// Ouvre la section Documents directement sur l'onglet « Garants ».
  void _goToGarants() {
    setState(() => _documentsInitialTab = 1);
    _navCtrl.selectIndex(_idxDocuments);
    // Remet l'onglet par défaut (Baux) pour les prochaines ouvertures via menu,
    // sans perturber l'onglet déjà affiché (l'état du TabController est conservé).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _documentsInitialTab = 0);
    });
  }

  Widget _buildSidebar({required bool isNarrow}) {
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      userTypeLabel: 'Locataire',
      items: [
        // Label court : un libellé trop long dépasse la largeur de la sidebar
        // (240 px) une fois en gras (sélectionné). Le titre de page reste long.
        badgedSidebarItem(
            icon: Icons.search_outlined,
            label: 'Rechercher location',
            extended: _navCtrl.extended),
        badgedSidebarItem(
            icon: Icons.dashboard_outlined,
            label: 'Tableau de bord',
            extended: _navCtrl.extended),
        badgedSidebarItem(
          icon: Icons.assignment_outlined,
          label: 'État des lieux',
          count: _edlBadge,
          extended: _navCtrl.extended,
        ),
        badgedSidebarItem(
          icon: Icons.mail_outline,
          label: 'Interactions',
          count: _msgBadge,
          extended: _navCtrl.extended,
        ),
        badgedSidebarItem(
            icon: Icons.folder_outlined,
            label: 'Documents',
            extended: _navCtrl.extended),
        badgedSidebarItem(
            icon: Icons.payments_outlined,
            label: 'Finances',
            extended: _navCtrl.extended),
        badgedSidebarItem(
            icon: Icons.person_outline,
            label: 'Mon Profil',
            extended: _navCtrl.extended),
      ],
      footerBuilder: (ctx, extended) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SidebarActionButton(
            extended: extended,
            icon: Icons.home_outlined,
            label: 'Accueil',
            onTap: () {
              if (isNarrow) Navigator.of(ctx).pop();
              Navigator.of(ctx).pushNamedAndRemoveUntil('/', (r) => false);
            },
          ),
          SidebarActionButton(
            extended: extended,
            icon: Icons.logout,
            label: 'Se déconnecter',
            onTap: _doLogout,
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  void _openChambre(int id) => setState(() => _selectedChambreId = id);
  void _closeChambre() => setState(() => _selectedChambreId = null);

  Widget _buildBody() {
    if (_selectedChambreId != null) {
      return ChambreDetailView(
        chambreId: _selectedChambreId!,
        onBack: _closeChambre,
      );
    }

    if (_error != null) {
      return Center(child: Text('Erreur : $_error'));
    }
    final bundle = _data;
    if (bundle == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return switch (_navCtrl.selectedIndex) {
      _idxDashboard => _DashboardSection(
          bundle: bundle,
          pendingEdls: _pendingEdls,
          unreadNotifs: _unreadNotifs,
          needsGarant: _needsGarant,
          hasSignature: _hasSignature,
          hasGarant: _hasGarant,
          onVoirChambres: _goToChambres,
          onVoirEdl: _goToEdl,
          onVoirMessages: _goToMessages,
          onVoirGarants: _goToGarants,
          onCompleterProfil: _goToProfil,
          onCreerSignature: _createSignature,
        ),
      _idxChambres => _ChambresSection(
          chambres: bundle.available,
          onTap: _openChambre,
        ),
      _idxProfil => _ProfilSection(profile: bundle.profile),
      _idxEdl => const _InteractionsSection(),
      _idxMessages => const _MessagesSection(),
      _idxDocuments => _DocumentsSection(initialTab: _documentsInitialTab),
      _idxFinances => const _FinancesSection(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 800;
    final sidebar = _buildSidebar(isNarrow: isNarrow);
    final body = _buildBody();

    return Scaffold(
      key: _scaffoldKey,
      drawer: isNarrow ? sidebar : null,
      appBar: isNarrow
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  if (!_navCtrl.extended) _navCtrl.setExtended(true);
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              title: const Text('Mon Espace'),
            )
          : null,
      body: Row(
        children: [
          if (!isNarrow) sidebar,
          Expanded(
            child: KeyedSubtree(key: _contentKey, child: body),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LocBundle {
  final List<ChambreModel> available;
  final int total;
  final UsersClient? profile;

  _LocBundle({
    required this.available,
    required this.total,
    required this.profile,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

/// Barre de titre standard des pages du locataire (même style que « Mon Profil »).
/// [title] = nom de la page ; [actions] = boutons optionnels à droite (ex. Modifier/
/// Sauvegarder du profil). Hauteur constante pour rester identique sur toutes les pages.
class _LocataireSectionBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  const _LocataireSectionBar({required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppTypography.titleLg)),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Tableau de bord du locataire — **lecture seule** : n'affiche que ce qui est
/// en attente (EDL à signer, messages non lus) et sert de raccourcis vers les
/// menus correspondants. L'utilisateur n'y modifie rien.
class _DashboardSection extends StatelessWidget {
  final _LocBundle bundle;
  final List<EtatDesLieuxModel> pendingEdls;
  final List<NotificationModel> unreadNotifs;
  final bool needsGarant;
  final bool hasSignature;
  final bool hasGarant;
  final VoidCallback onVoirChambres;
  final VoidCallback onVoirEdl;
  final VoidCallback onVoirMessages;
  final VoidCallback onVoirGarants;
  final VoidCallback onCompleterProfil;
  final VoidCallback onCreerSignature;

  const _DashboardSection({
    required this.bundle,
    required this.pendingEdls,
    required this.unreadNotifs,
    required this.needsGarant,
    required this.hasSignature,
    required this.hasGarant,
    required this.onVoirChambres,
    required this.onVoirEdl,
    required this.onVoirMessages,
    required this.onVoirGarants,
    required this.onCompleterProfil,
    required this.onCreerSignature,
  });

  /// Construit les conditions « prêt à louer » du locataire.
  List<ChecklistItem> _checklistItems() {
    final p = bundle.profile;
    final profilComplet = (p?.fullName?.trim().isNotEmpty ?? false) &&
        (p?.phone?.trim().isNotEmpty ?? false) &&
        p?.dateOfBirth != null;
    return [
      ChecklistItem(
        label: 'Compléter mon profil',
        hint: 'Nom, téléphone et date de naissance',
        done: profilComplet,
        actionLabel: 'Compléter',
        onAction: onCompleterProfil,
      ),
      ChecklistItem(
        label: 'Enregistrer ma signature électronique',
        hint: 'Nécessaire pour signer vos états des lieux et baux',
        done: hasSignature,
        actionLabel: 'Créer ma signature',
        onAction: onCreerSignature,
      ),
      // Enregistrer un garant est obligatoire pour louer.
      ChecklistItem(
        label: 'Enregistrer un garant (caution)',
        hint: 'Obligatoire pour louer',
        done: hasGarant,
        actionLabel: 'Ajouter un garant',
        onAction: onVoirGarants,
      ),
    ];
  }

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final profile = bundle.profile;
    final rawName = profile?.fullName?.trim() ?? '';
    final firstName = rawName.isNotEmpty ? rawName.split(' ').first : '';
    final greeting =
        firstName.isNotEmpty ? 'Bonjour, $firstName !' : 'Bienvenue !';
    final nbActions =
        pendingEdls.length + unreadNotifs.length + (needsGarant ? 1 : 0);
    final aJour = nbActions == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LocataireSectionBar(title: 'Tableau de bord'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Carte d'accueil ────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: AppRadius.borderLg,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  greeting,
                                  style: AppTypography.headlineMd.copyWith(
                                    color: AppColors.onPrimaryFixedVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  aJour
                                      ? "Vous êtes à jour, rien en attente."
                                      : '$nbActions élément${nbActions > 1 ? 's' : ''} '
                                          'en attente de votre part.',
                                  style: AppTypography.bodyMd.copyWith(
                                    color: AppColors.onPrimaryFixedVariant
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                FilledButton.icon(
                                  onPressed: onVoirChambres,
                                  icon: const Icon(Icons.search, size: 16),
                                  label: const Text('Rechercher une location'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Icon(
                            aJour
                                ? Icons.check_circle_outline
                                : Icons.notifications_active_outlined,
                            size: 72,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Conditions pour louer (checklist + liens) ─────────
                    ReadinessChecklist(items: _checklistItems()),
                    const SizedBox(height: AppSpacing.xl),

                    if (aJour)
                      _emptyState()
                    else ...[
                      // ── États des lieux à signer ──────────────────────────
                      if (pendingEdls.isNotEmpty) ...[
                        _sectionHeader(
                          icon: Icons.assignment_outlined,
                          title: 'États des lieux à signer',
                          actionLabel: 'Voir tout',
                          onAction: onVoirEdl,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...pendingEdls.map(
                          (e) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _DashboardEdlTile(
                              edl: e,
                              dateFmt: _dateFmt,
                              onTap: onVoirEdl,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],

                      // ── Messages non lus ──────────────────────────────────
                      if (unreadNotifs.isNotEmpty) ...[
                        _sectionHeader(
                          icon: Icons.mail_outline,
                          title: 'Messages non lus',
                          actionLabel: 'Voir tout',
                          onAction: onVoirMessages,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...unreadNotifs.map(
                          (n) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: NotificationCard(
                              notification: n,
                              onTap: onVoirMessages,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(title, style: AppTypography.titleLg)),
        TextButton.icon(
          onPressed: onAction,
          label: Text(actionLabel),
          icon: const Icon(Icons.arrow_forward, size: 16),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 56, color: AppColors.success),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Vous êtes à jour ✓',
                style: AppTypography.titleLg
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "Aucun état des lieux à signer, aucun message en attente.",
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

/// Tuile compacte (lecture seule) d'un EDL à signer affichée dans le tableau de
/// bord ; ouvre le menu « État des lieux ».
class _DashboardEdlTile extends StatelessWidget {
  final EtatDesLieuxModel edl;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  const _DashboardEdlTile({
    required this.edl,
    required this.dateFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lieu = [edl.immeubleNom, edl.chambreNom]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    final dateStr = edl.dateFinalisation != null
        ? 'Finalisé le ${dateFmt.format(edl.dateFinalisation!)}'
        : 'Finalisé';
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            const Icon(Icons.draw_outlined, size: 20, color: AppColors.error),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lieu.isEmpty ? 'État des lieux' : lieu,
                    style: AppTypography.bodyMd
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${edl.typeLabel} · $dateStr',
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Messages (notifications du locataire)

class _MessagesSection extends StatefulWidget {
  const _MessagesSection();

  @override
  State<_MessagesSection> createState() => _MessagesSectionState();
}

class _MessagesSectionState extends State<_MessagesSection>
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
      final data = await NotificationsDatasource.listByOwner(refresh: true);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LocataireSectionBar(title: 'Interactions'),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
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
              const Icon(Icons.mail_outline,
                  size: 48, color: AppColors.onSurfaceVariant),
              const SizedBox(height: AppSpacing.md),
              Text('Aucun message.',
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
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
                  child:
                      NotificationCard(notification: n, onTap: () => _markRead(n)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChambresSection extends StatefulWidget {
  final List<ChambreModel> chambres;
  final void Function(int id) onTap;

  const _ChambresSection({required this.chambres, required this.onTap});

  @override
  State<_ChambresSection> createState() => _ChambresSectionState();
}

class _ChambresSectionState extends State<_ChambresSection> {
  String _query = '';
  ChambreFilter _filter = ChambreFilter.empty;

  List<ChambreModel> get _filtered {
    return widget.chambres.where((c) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final inName = c.roomName.toLowerCase().contains(q);
        final inImm = c.immeubleName?.toLowerCase().contains(q) ?? false;
        final inAddr = c.immeubleAddress?.toLowerCase().contains(q) ?? false;
        final inCity = c.immeubleCity?.toLowerCase().contains(q) ?? false;
        if (!inName && !inImm && !inAddr && !inCity) return false;
      }
      final f = _filter;
      if (f.optionIds.isNotEmpty &&
          !f.optionIds.every((id) => c.selectedOptionIds.contains(id))) {
        return false;
      }
      if (f.city.isNotEmpty &&
          !(c.immeubleCity?.toLowerCase().contains(f.city.toLowerCase()) ??
              false)) {
        return false;
      }
      if (f.region.isNotEmpty &&
          !(c.immeubleRegion?.toLowerCase().contains(f.region.toLowerCase()) ??
              false)) {
        return false;
      }
      if (f.department.isNotEmpty &&
          !(c.immeubleDepartment
                  ?.toLowerCase()
                  .contains(f.department.toLowerCase()) ??
              false)) {
        return false;
      }
      if (f.bailType == BailTypeFilter.collectif && !c.immeubleBailLocation) {
        return false;
      }
      if (f.bailType == BailTypeFilter.individuel && !c.immeubleBailIndividuel) {
        return false;
      }
      if (f.m2Min != null && (c.m2 == null || c.m2! < f.m2Min!)) {
        return false;
      }
      if (f.m2Max != null && (c.m2 == null || c.m2! > f.m2Max!)) {
        return false;
      }
      if (f.prixMin != null &&
          (c.prixLoyer == null || c.prixLoyer! < f.prixMin!)) {
        return false;
      }
      if (f.prixMax != null &&
          (c.prixLoyer == null || c.prixLoyer! > f.prixMax!)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LocataireSectionBar(title: 'Chambres disponibles'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barre de recherche
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppRadius.borderFull,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une chambre, immeuble, ville…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: AppSpacing.md,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _query = ''),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              FilterPanel(
                filter: _filter,
                onChanged: (f) => setState(() => _filter = f),
                modules: const {
                  FilterModule.localisation,
                  FilterModule.bail,
                  FilterModule.meuble,
                  FilterModule.typeImmeuble,
                  FilterModule.surface,
                  FilterModule.prix,
                  FilterModule.equipements,
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                filtered.isEmpty
                    ? 'Aucune chambre ne correspond à la recherche.'
                    : '${filtered.length} chambre${filtered.length > 1 ? 's' : ''} '
                        'disponible${filtered.length > 1 ? 's' : ''}',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (widget.chambres.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      const Icon(
                        Icons.bed_outlined,
                        size: 64,
                        color: AppColors.outline,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Revenez bientôt — de nouvelles chambres\nseront disponibles prochainement.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: Text(
                      'Aucun résultat pour « $_query »',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth > 700 ? 3 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => ChambreCard(
                        chambre: filtered[i],
                        onTap: () => widget.onTap(filtered[i].id),
                      ),
                    );
                  },
                ),
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

class _ProfilSection extends StatefulWidget {
  final UsersClient? profile;

  const _ProfilSection({required this.profile});

  @override
  State<_ProfilSection> createState() => _ProfilSectionState();
}

class _ProfilSectionState extends State<_ProfilSection> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  late Future<bool> _hasContratsFuture;

  late final TextEditingController _nameCtrl;

  // Valores exibidos (confirmados após salvar)
  late String _displayName;
  late String _displayPhone;
  DateTime? _displayDob;

  GlobalKey<FormBuilderState> _phoneFormKey = GlobalKey<FormBuilderState>();

  // Valores temporários durante edição
  DateTime? _editDob;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  static int _computeAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  void initState() {
    super.initState();
    _displayName = widget.profile?.fullName ?? '';
    _displayPhone = widget.profile?.phone ?? '';
    _displayDob = widget.profile?.dateOfBirth;
    _nameCtrl = TextEditingController(text: _displayName);
    _hasContratsFuture = EtatDesLieuxDatasource.hasContratsLocataire(
      AuthService.currentUser?.id ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) {
      _nameCtrl.text = _displayName;
      setState(() {
        _editDob = _displayDob;
        _isEditing = false;
        _phoneFormKey = GlobalKey<FormBuilderState>();
      });
    } else {
      setState(() {
        _editDob = _displayDob;
        _isEditing = true;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _editDob ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 16, now.month, now.day),
      locale: const Locale('fr'),
    );
    if (picked != null && mounted) {
      setState(() => _editDob = picked);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: const Text(
          'Cette action est irréversible. Toutes vos données personnelles '
          'seront définitivement supprimées.\n\n'
          'Êtes-vous sûr de vouloir continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: AppTheme.deleteButtonStyle,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await AuthService.deleteAccount();
      if (!mounted) return;
      await AuthService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _save() async {
    final newName = _nameCtrl.text.trim();
    final newPhone =
        PhoneField.fullNumberFromState(_phoneFormKey.currentState, 'phone') ??
        '';
    final newDob = _editDob;
    setState(() => _isSaving = true);
    try {
      await AuthService.updateProfile(
        fullName: newName,
        phone: newPhone.isEmpty ? null : newPhone,
        age: newDob != null ? _computeAge(newDob) : null,
        dateOfBirth: newDob,
      );
      if (!mounted) return;
      setState(() {
        _displayName = newName;
        _displayPhone = newPhone;
        _displayDob = newDob;
        _isEditing = false;
        _isSaving = false;
        _phoneFormKey = GlobalKey<FormBuilderState>();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        widget.profile?.email ?? AuthService.currentUser?.email ?? '';
    final createdAt = widget.profile?.createdAt;
    final initial = (_displayName.isNotEmpty ? _displayName : email)
        .substring(0, 1)
        .toUpperCase();
    final currentDob = _isEditing ? _editDob : _displayDob;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Barre de titre ──────────────────────────────────────────────
        _LocataireSectionBar(
          title: 'Mon Profil',
          actions: [
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
              tooltip: _isEditing ? 'Annuler' : 'Modifier',
              color: _isEditing ? AppColors.error : null,
              onPressed: _toggleEdit,
            ),
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.save_outlined,
                      color: _isEditing
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
              tooltip: 'Sauvegarder',
              onPressed: _isEditing && !_isSaving ? _save : null,
            ),
          ],
        ),

        // ── Corps ────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.primaryFixed,
                            child: Text(
                              initial,
                              style: AppTypography.headlineMd.copyWith(
                                color: AppColors.onPrimaryFixedVariant,
                              ),
                            ),
                          ),
                          if (_isEditing)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surfaceContainerLowest,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Nom complet ──────────────────────────────────────
                    _fieldLabel('NOM COMPLET'),
                    TextField(
                      controller: _nameCtrl,
                      enabled: _isEditing,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(hintText: 'Jean Dupont'),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── E-mail ───────────────────────────────────────────
                    _fieldLabel('E-MAIL'),
                    _staticField(email),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Téléphone ────────────────────────────────────────
                    _fieldLabel('TÉLÉPHONE'),
                    if (_isEditing)
                      FormBuilder(
                        key: _phoneFormKey,
                        child: PhoneField(
                          name: 'phone',
                          initialValue: _displayPhone,
                        ),
                      )
                    else
                      _staticField(
                        _displayPhone.isEmpty ? '—' : _displayPhone,
                      ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Date de naissance ────────────────────────────────
                    _fieldLabel('DATE DE NAISSANCE'),
                    InkWell(
                      onTap: _isEditing ? _pickDate : null,
                      borderRadius: AppRadius.borderSm,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _isEditing
                              ? AppColors.surfaceContainerLowest
                              : AppColors.surfaceContainerLow,
                          borderRadius: AppRadius.borderSm,
                          border: Border.all(
                            color: _isEditing
                                ? AppColors.primary
                                : AppColors.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentDob != null
                                    ? _dateFmt.format(currentDob)
                                    : _isEditing
                                        ? 'Sélectionner une date'
                                        : 'Non renseignée',
                                style: AppTypography.bodyMd.copyWith(
                                  color: currentDob == null
                                      ? AppColors.onSurfaceVariant
                                          .withValues(alpha: 0.5)
                                      : null,
                                ),
                              ),
                            ),
                            if (_isEditing)
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (currentDob != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Âge : ${_computeAge(currentDob)} ans',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),

                    // ── Type de compte ───────────────────────────────────
                    _fieldLabel('TYPE DE COMPTE'),
                    _staticField('Locataire'),

                    // ── Membre depuis ────────────────────────────────────
                    if (createdAt != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _fieldLabel('MEMBRE DEPUIS'),
                      _staticField(_dateFmt.format(createdAt)),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Info ─────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              "Pour modifier votre adresse e-mail ou votre "
                              "mot de passe, contactez l'administrateur de "
                              "la plateforme.",
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Ma signature ──────────────────────────────────────
                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),
                    const _LocataireSignatureSection(),

                    // ── Zone dangereuse ───────────────────────────────────
                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),
                    _DangerZoneSection(
                      hasContratsFuture: _hasContratsFuture,
                      isDeleting: _isDeleting,
                      onDelete: _confirmDelete,
                    ),
                  ],
                ),
              ),
            ),
          ),
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

  Widget _staticField(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(value, style: AppTypography.bodyMd),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section État des lieux (onglet du locataire)

class _InteractionsSection extends StatefulWidget {
  const _InteractionsSection();

  @override
  State<_InteractionsSection> createState() => _InteractionsSectionState();
}

class _InteractionsSectionState extends State<_InteractionsSection>
    with SingleTickerProviderStateMixin, RealtimeRefreshMixin {
  late final TabController _tabCtrl;
  late Future<List<EtatDesLieuxModel>> _future;

  /// Fiche d'EDL affichée **dans le cadre** de la page (pas une nouvelle route).
  /// Null = on montre la liste/onglets.
  Widget? _detailView;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _future = _load();
  }

  /// Ouvre une fiche d'EDL en **plein cadre** (in-frame). [edl] détermine la page :
  /// collectif (parties communes) ou privatif individuel. La fermeture restaure la
  /// liste et recharge. Le mode locataire restreint déjà l'édition à ses propres
  /// observations (lecture seule une fois finalisé).
  Future<void> _openDetail(EtatDesLieuxModel edl) async {
    void close([bool _ = false]) {
      if (!mounted) return;
      setState(() {
        _detailView = null;
        _future = _load();
      });
    }

    if (edl.partie == PartieEdl.commune) {
      final imm = await ImmeublesDatasource.byId(edl.immeubleId);
      if (!mounted || imm == null) return;
      setState(() {
        _detailView = EdlCollectifNonMeubleePage(
          immeuble: imm,
          typeEdl: edl.typeEdl,
          existingEdl: edl,
          isLocataire: true,
          meublee: imm.locationMeuble == true,
          onClose: close,
        );
      });
      return;
    }
    if (edl.partie == PartieEdl.privative &&
        edl.typeBail == 'individuel' &&
        edl.chambreId != null) {
      final imm = await ImmeublesDatasource.byId(edl.immeubleId);
      ChambreModel? chambre;
      try {
        final chambres =
            await ChambresDatasource.listByImmeubles([edl.immeubleId]);
        chambre = chambres.where((c) => c.id == edl.chambreId).firstOrNull;
      } catch (_) {}
      if (!mounted || imm == null || chambre == null) return;
      setState(() {
        _detailView = EdlIndividuelMeubleePage(
          immeuble: imm,
          chambre: chambre!,
          typeEdl: edl.typeEdl,
          existingEdl: edl,
          isLocataire: true,
          meublee: imm.locationMeuble == true,
          onClose: close,
        );
      });
      return;
    }
    // EDL privatif (single-room / legado) → vue détaillée (route dédiée).
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _EdlDetailPage(
        edl: edl,
        onAccepter: () => _accepter(edl),
      ),
    ));
  }

  @override
  Set<String> get watchedEntities => {'edl'};

  @override
  void onRealtimeChange() {
    final f = _load();
    setState(() => _future = f);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<List<EtatDesLieuxModel>> _load() {
    final uid = AuthService.currentUser?.id ?? '';
    // Inclui EDLs privatifs (locataire_id) + collectifs onde é preneur.
    return EtatDesLieuxDatasource.listForLocataire(uid);
  }

  Future<void> _accepter(EtatDesLieuxModel edl) async {
    // Vérifie/crée la signature, montre l'aperçu PDF avec bouton « Signer »,
    // puis enregistre l'acceptation.
    final sigUrl = await runLocataireSignatureFlow(context, edl);
    if (sigUrl == null || !mounted) return;
    await EtatDesLieuxDatasource.locataireAccepter(
      edl.id,
      locataireSignatureUrl: sigUrl,
    );
    if (mounted) setState(() { _future = _load(); });
  }

  /// `true` se o EDL ainda está dentro da janela de **avenant** configurada na
  /// criação (snapshot `avenant_window_days`), e portanto comporta um avenant.
  static bool _isAvenantOpen(EtatDesLieuxModel edl) {
    if (edl.partie != PartieEdl.privative) return false;
    if (edl.chambreId == null) return false;
    if (edl.typeEdl != 'entree') return false;
    return edl.isAvenantWindowOpen;
  }

  /// Abre a `EdlIndividuelMeubleePage` diretamente na aba Additions (índice 4).
  Future<void> _openAddition(EtatDesLieuxModel edl) async {
    if (edl.chambreId == null) return;
    final imm = await ImmeublesDatasource.byId(edl.immeubleId);
    ChambreModel? chambre;
    try {
      final chambres =
          await ChambresDatasource.listByImmeubles([edl.immeubleId]);
      chambre = chambres.where((c) => c.id == edl.chambreId).firstOrNull;
    } catch (_) {}
    if (!mounted || imm == null || chambre == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: SafeArea(
          child: EdlIndividuelMeubleePage(
            immeuble: imm,
            chambre: chambre!,
            typeEdl: edl.typeEdl,
            existingEdl: edl,
            isLocataire: true,
            meublee: imm.locationMeuble == true,
            initialTabIndex: 4,
            onClose: (_) => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    ));
    if (mounted) setState(() { _future = _load(); });
  }

  @override
  Widget build(BuildContext context) {
    // Fiche ouverte in-frame → on l'affiche à la place de la liste/onglets.
    if (_detailView != null) return _detailView!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LocataireSectionBar(title: 'État des lieux'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Vision générale'),
              Tab(text: 'Entrée'),
              Tab(text: 'Sortie'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<EtatDesLieuxModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erreur : ${snapshot.error}'));
              }
              final all = snapshot.data ?? [];
              final pending = all
                  .where(
                    (e) =>
                        e.situation == SituationEdl.finalise &&
                        !e.locataireAccepte,
                  )
                  .toList();
              final entrees =
                  all.where((e) => e.typeEdl == 'entree').toList();
              final sorties =
                  all.where((e) => e.typeEdl == 'sortie').toList();

              // EDL ouverts à un avenant (fenêtre d'avenant encore ouverte).
              final avenantables = all.where(_isAvenantOpen).toList();

              return TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _EdlVisionGeneraleTab(
                    all: all,
                    pending: pending,
                    avenantables: avenantables,
                    onAccepter: _accepter,
                    onVoir: _openDetail,
                    onVisualiser: _openDetail,
                    onAvenant: _openAddition,
                    onSigner: _accepter,
                  ),
                  _EdlListTab(
                    edls: entrees,
                    emptyMessage: "Aucun état des lieux d'entrée.",
                    avenantables: avenantables,
                    onAvenant: _openAddition,
                    onVoir: _openDetail,
                    onVisualiser: _openDetail,
                    onSigner: _accepter,
                  ),
                  _EdlListTab(
                    edls: sorties,
                    emptyMessage: 'Aucun état des lieux de sortie.',
                    onVoir: _openDetail,
                    onVisualiser: _openDetail,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EdlVisionGeneraleTab extends StatelessWidget {
  final List<EtatDesLieuxModel> all;
  final List<EtatDesLieuxModel> pending;
  final List<EtatDesLieuxModel> avenantables;
  final Future<void> Function(EtatDesLieuxModel) onAccepter;
  final void Function(EtatDesLieuxModel) onVoir;
  final void Function(EtatDesLieuxModel) onVisualiser;
  final Future<void> Function(EtatDesLieuxModel) onAvenant;
  final Future<void> Function(EtatDesLieuxModel)? onSigner;

  const _EdlVisionGeneraleTab({
    required this.all,
    required this.pending,
    required this.avenantables,
    required this.onAccepter,
    required this.onVoir,
    required this.onVisualiser,
    required this.onAvenant,
    this.onSigner,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Important',
                  style: AppTypography.titleLg.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...pending.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _PendingEdlCard(
                  edl: e,
                  onAccepter: () => onAccepter(e),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
          ],
          // ── Titre + bouton « Avenant » (à droite, même ligne) ───────
          Row(
            children: [
              Expanded(
                child: Text('Tous les états des lieux',
                    style: AppTypography.titleLg),
              ),
              if (avenantables.isNotEmpty)
                _AvenantButton(
                  avenantables: avenantables,
                  onAvenant: onAvenant,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (all.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 56,
                      color: AppColors.outline,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Aucun état des lieux enregistré.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _EdlLocataireTable(
              edls: all,
              onVoir: onVoir,
              onVisualiser: onVisualiser,
              onSigner: onSigner,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton « Avenant » + dialog de sélection d'EDL (fenêtre d'avenant ouverte)

/// Bouton « Avenant » (locataire) : ouvre **toujours** la boîte de sélection des
/// EDL dont la fenêtre d'avenant est encore ouverte, puis déclenche [onAvenant].
class _AvenantButton extends StatelessWidget {
  final List<EtatDesLieuxModel> avenantables;
  final Future<void> Function(EtatDesLieuxModel) onAvenant;

  const _AvenantButton({required this.avenantables, required this.onAvenant});

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Perm.edlAddition,
      child: FilledButton.icon(
        onPressed: () async {
          final selected = await showDialog<EtatDesLieuxModel>(
            context: context,
            builder: (_) => _SelectAvenantDialog(edls: avenantables),
          );
          if (selected != null) onAvenant(selected);
        },
        icon: const Icon(Icons.note_add_outlined, size: 16),
        label: const Text('Avenant'),
      ),
    );
  }
}

class _SelectAvenantDialog extends StatelessWidget {
  final List<EtatDesLieuxModel> edls;
  const _SelectAvenantDialog({required this.edls});

  static final _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir un état des lieux'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sélectionnez le contrat pour lequel vous souhaitez faire un avenant :',
              style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            ...edls.map(
              (edl) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(
                  edl.immeubleNom ?? '—',
                  style: AppTypography.bodyMd
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${edl.chambreNom ?? '—'} · Finalisé le '
                  '${edl.dateFinalisation != null ? _fmt.format(edl.dateFinalisation!) : '—'}',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                onTap: () => Navigator.pop(context, edl),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EdlListTab extends StatelessWidget {
  final List<EtatDesLieuxModel> edls;
  final String emptyMessage;
  final void Function(EtatDesLieuxModel) onVoir;
  final void Function(EtatDesLieuxModel) onVisualiser;
  // EDL ouverts à un avenant + handler ; null = pas de bouton « Avenant »
  // (ex. onglet Sortie).
  final List<EtatDesLieuxModel>? avenantables;
  final Future<void> Function(EtatDesLieuxModel)? onAvenant;
  final Future<void> Function(EtatDesLieuxModel)? onSigner;

  const _EdlListTab({
    required this.edls,
    required this.emptyMessage,
    required this.onVoir,
    required this.onVisualiser,
    this.avenantables,
    this.onAvenant,
    this.onSigner,
  });

  @override
  Widget build(BuildContext context) {
    final showAvenant =
        avenantables != null && avenantables!.isNotEmpty && onAvenant != null;
    if (edls.isEmpty && !showAvenant) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 56,
              color: AppColors.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              emptyMessage,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showAvenant)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _AvenantButton(
                  avenantables: avenantables!,
                  onAvenant: onAvenant!,
                ),
              ),
            ),
          if (edls.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            )
          else
            _EdlLocataireTable(
              edls: edls,
              onVoir: onVoir,
              onVisualiser: onVisualiser,
              onSigner: onSigner,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Jours restants avant la fermeture de la fenêtre d'avenant/additions, ou null
/// s'il n'y a aucune fenêtre ouverte (EDL non finalisé, ou « Sans avenant »
/// configuré côté propriétaire), ou si la finalisation n'a pas encore de date.
int? _avenantJoursRestants(EtatDesLieuxModel e) {
  if (!e.isAvenantWindowOpen) return null;
  final ref = e.dateFinalisation;
  if (ref == null) return null; // finalisé non signé : pas encore de compteur
  final end = ref.add(Duration(days: e.avenantWindowDaysOrDefault));
  final days = end.difference(DateTime.now()).inDays;
  return days < 0 ? 0 : days;
}

/// Tableau des états des lieux du locataire — même présentation que côté
/// propriétaire : barre de filtres ([EdlFilterBar]) + lignes (large) ou cartes
/// (étroit). Le locataire ne voit que les EDL qui le concernent (filtrés en
/// amont par `listForLocataire`).
class _EdlLocataireTable extends StatefulWidget {
  final List<EtatDesLieuxModel> edls;
  final void Function(EtatDesLieuxModel) onVoir;
  final void Function(EtatDesLieuxModel) onVisualiser;
  final Future<void> Function(EtatDesLieuxModel)? onSigner;

  const _EdlLocataireTable({
    required this.edls,
    required this.onVoir,
    required this.onVisualiser,
    this.onSigner,
  });

  @override
  State<_EdlLocataireTable> createState() => _EdlLocataireTableState();
}

class _EdlLocataireTableState extends State<_EdlLocataireTable> {
  EdlTableFilter _filter = EdlTableFilter.empty;

  List<EtatDesLieuxModel> get _filtered =>
      widget.edls.where(_filter.matches).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: EdlFilterBar(
              filter: _filter,
              edls: widget.edls,
              onChanged: (f) => setState(() => _filter = f),
              modules: const {
                EdlFilterModule.recherche,
                EdlFilterModule.situation,
                EdlFilterModule.typeEdl,
                EdlFilterModule.dateCreation,
                EdlFilterModule.dateFinalisation,
              },
            ),
          ),
          const Divider(height: 1),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  widget.edls.isEmpty
                      ? 'Aucun état des lieux.'
                      : 'Aucun résultat pour ces filtres.',
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final e in filtered) ...[
                          _EdlLocataireCard(
                            edl: e,
                            onVoir: () => widget.onVoir(e),
                            onVisualiser: () => widget.onVisualiser(e),
                            onSigner: widget.onSigner != null
                                ? () => widget.onSigner!(e)
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    const _EdlLocataireHeaderRow(),
                    const Divider(height: 1),
                    for (int i = 0; i < filtered.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _EdlLocataireRow(
                        edl: filtered[i],
                        onVoir: () => widget.onVoir(filtered[i]),
                        onVisualiser: () => widget.onVisualiser(filtered[i]),
                        onSigner: widget.onSigner != null
                            ? () => widget.onSigner!(filtered[i])
                            : null,
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// Largeurs des colonnes fixes (header + lignes alignés).
const double _kColType = 90;
const double _kColSens = 70;
const double _kColSit = 96;
const double _kColDate = 92;
const double _kColAvenant = 124;
const double _kColAction = 96;

class _EdlLocataireHeaderRow extends StatelessWidget {
  const _EdlLocataireHeaderRow();

  Widget _h(String s,
      {double? width, int? flex, TextAlign align = TextAlign.start}) {
    final t = Text(
      s,
      textAlign: align,
      style: AppTypography.labelSm.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ),
    );
    if (flex != null) return Expanded(flex: flex, child: t);
    return SizedBox(width: width, child: t);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      child: Row(
        children: [
          _h('IMMEUBLE / CHAMBRE', flex: 3),
          const SizedBox(width: AppSpacing.sm),
          _h('PROPRIÉTAIRE', flex: 2),
          const SizedBox(width: AppSpacing.sm),
          _h('TYPE', width: _kColType, align: TextAlign.center),
          _h('SENS', width: _kColSens, align: TextAlign.center),
          _h('SITUATION', width: _kColSit, align: TextAlign.center),
          _h('DATE EDL', width: _kColDate, align: TextAlign.center),
          _h('AVENANT', width: _kColAvenant, align: TextAlign.center),
          const SizedBox(width: _kColAction),
        ],
      ),
    );
  }
}

class _EdlLocataireRow extends StatelessWidget {
  final EtatDesLieuxModel edl;
  final VoidCallback onVoir;
  final VoidCallback onVisualiser;
  final VoidCallback? onSigner;

  const _EdlLocataireRow({
    required this.edl,
    required this.onVoir,
    required this.onVisualiser,
    this.onSigner,
  });

  static final _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final jours = _avenantJoursRestants(edl);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edl.immeubleNom ?? edl.lieuLabel,
                  style:
                      AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (edl.chambreNom != null)
                  Text(
                    edl.chambreNom!,
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (edl.code != null) _EdlCodeChip(code: edl.code!),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: Text(
              edl.proprietaireNom ?? '—',
              style: AppTypography.bodyMd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: _kColType,
            child: Text(edl.typeLabel,
                textAlign: TextAlign.center, style: AppTypography.labelSm),
          ),
          SizedBox(
            width: _kColSens,
            child: Text(edl.sensLabel,
                textAlign: TextAlign.center, style: AppTypography.labelSm),
          ),
          SizedBox(
            width: _kColSit,
            child: Center(child: _EdlSituationBadge(situation: edl.situation)),
          ),
          SizedBox(
            width: _kColDate,
            child: Text(_fmt.format(edl.dateEtatLieux),
                textAlign: TextAlign.center, style: AppTypography.labelSm),
          ),
          SizedBox(
            width: _kColAvenant,
            child: Center(
              child: jours != null
                  ? _AvenantInfoChip(jours: jours)
                  : Text('—',
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ),
          SizedBox(
            width: _kColAction,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onVisualiser,
                  tooltip: 'Visualiser',
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                ),
                if (edl.situation != SituationEdl.finalise)
                  IconButton(
                    onPressed: onVoir,
                    tooltip: 'Éditer',
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    padding: EdgeInsets.zero,
                    color: AppColors.primary,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  )
                else if (!edl.locataireAccepte && onSigner != null)
                  IconButton(
                    onPressed: onSigner,
                    tooltip: 'Signer',
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    padding: EdgeInsets.zero,
                    color: AppColors.tertiary,
                    icon: const Icon(Icons.draw_outlined, size: 20),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge du code de référence de l'EDL (monospace, discret).
class _EdlCodeChip extends StatelessWidget {
  final String code;
  const _EdlCodeChip({required this.code});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        code,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Pastille « Avenant : N j » indiquant le nombre de jours restants pour faire
/// un avenant/une addition (rouge si urgent ≤ 3 jours).
class _AvenantInfoChip extends StatelessWidget {
  final int jours;
  const _AvenantInfoChip({required this.jours});

  @override
  Widget build(BuildContext context) {
    final urgent = jours <= 3;
    final color = urgent ? AppColors.error : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timelapse, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Avenant : $jours j',
              style: AppTypography.labelSm
                  .copyWith(color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EdlLocataireCard extends StatelessWidget {
  final EtatDesLieuxModel edl;
  final VoidCallback onVoir;
  final VoidCallback onVisualiser;
  final VoidCallback? onSigner;

  const _EdlLocataireCard({
    required this.edl,
    required this.onVoir,
    required this.onVisualiser,
    this.onSigner,
  });

  static final _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final nom = edl.proprietaireNom ?? '—';
    final initial = nom.isNotEmpty ? nom.substring(0, 1).toUpperCase() : '?';
    final typeBailLabel = edl.typeLabel;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onPrimaryFixedVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      edl.typeEdl == 'entree' ? 'Entrée' : 'Sortie',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            edl.immeubleNom ?? edl.lieuLabel,
            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (edl.chambreNom != null)
            Text(
              '${edl.chambreNom} · $typeBailLabel',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              typeBailLabel,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          if (edl.code != null) _EdlCodeChip(code: edl.code!),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ÉTAT',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fmt.format(edl.dateEtatLieux),
                      style: AppTypography.bodyMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINALISATION',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      edl.dateFinalisation != null
                          ? _fmt.format(edl.dateFinalisation!)
                          : '—',
                      style: AppTypography.bodyMd.copyWith(
                        color: edl.dateFinalisation == null
                            ? AppColors.onSurfaceVariant
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SITUATION',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _EdlSituationBadge(situation: edl.situation),
                ],
              ),
            ],
          ),
          if (_avenantJoursRestants(edl) case final j?) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: _AvenantInfoChip(jours: j),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onVisualiser,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Voir'),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (edl.situation != SituationEdl.finalise)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onVoir,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Continuer'),
                  ),
                )
              else if (!edl.locataireAccepte && onSigner != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSigner,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.tertiary),
                    icon: const Icon(Icons.draw_outlined, size: 16),
                    label: const Text('Signer'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PendingEdlCard extends StatefulWidget {
  final EtatDesLieuxModel edl;
  final Future<void> Function() onAccepter;

  const _PendingEdlCard({required this.edl, required this.onAccepter});

  @override
  State<_PendingEdlCard> createState() => _PendingEdlCardState();
}

class _PendingEdlCardState extends State<_PendingEdlCard> {
  bool _accepting = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await widget.onAccepter();
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  static final _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final edl = widget.edl;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.18),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'État des lieux finalisé par '
                  '${edl.proprietaireNom ?? 'votre propriétaire'}',
                  style: AppTypography.titleLg,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _row('Lieu', edl.lieuLabel),
          if (edl.immeubleAdresse != null)
            _row('Adresse', edl.immeubleAdresse!),
          _row('Date', _fmt.format(edl.dateEtatLieux)),
          if (edl.montant != null)
            _row('Montant', '€ ${edl.montant!.toStringAsFixed(2)}'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: AppRadius.borderSm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: AppColors.tertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    edl.proprietaireSignedAt != null
                        ? 'Le propriétaire a finalisé et signé le '
                              '${_fmt.format(edl.proprietaireSignedAt!)}. '
                              'Il ne reste que votre signature.'
                        : 'Le propriétaire a finalisé et signé ce document. '
                              'Il ne reste que votre signature.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _accepting ? null : _accept,
              child: _accepting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Accepter et signer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: AppTypography.bodyMd)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page de détail d'un état des lieux (lecture seule, toutes les étapes)

class _EdlDetailPage extends StatefulWidget {
  final EtatDesLieuxModel edl;
  final Future<void> Function() onAccepter;

  const _EdlDetailPage({
    required this.edl,
    required this.onAccepter,
  });

  @override
  State<_EdlDetailPage> createState() => _EdlDetailPageState();
}

class _EdlDetailPageState extends State<_EdlDetailPage> {
  bool _accepting = false;
  static final _fmt = DateFormat('dd/MM/yyyy');

  static const _wallLabels = {
    'fond': 'Mur du fond',
    'gauche': 'Mur gauche',
    'droit': 'Mur droit',
    'porte': "Mur d'entrée / Porte",
  };

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await widget.onAccepter();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _accepting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: AppTypography.labelSm.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _infoCard(List<Widget> rows) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: AppRadius.borderMd,
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(
            label,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: AppTypography.bodyMd)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final edl = widget.edl;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          edl.typeEdl == 'entree'
              ? "État des lieux d'entrée"
              : 'État des lieux de sortie',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Carte statut ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              edl.typeEdl == 'entree'
                                  ? "État des lieux d'entrée"
                                  : 'État des lieux de sortie',
                              style: AppTypography.titleLg,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              edl.lieuLabel,
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Le ${_fmt.format(edl.dateEtatLieux)}',
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _EdlSituationBadge(situation: edl.situation),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Propriétaire ──────────────────────────────────────────
                if (edl.proprietaireNom != null) ...[
                  _sectionTitle('PROPRIÉTAIRE'),
                  _infoCard([_infoRow('Nom', edl.proprietaireNom!)]),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ── Lieu ──────────────────────────────────────────────────
                _sectionTitle('LIEU'),
                _infoCard([
                  _infoRow('Immeuble', edl.immeubleNom ?? '—'),
                  if (edl.immeubleAdresse != null)
                    _infoRow('Adresse', edl.immeubleAdresse!),
                  if (edl.chambreNom != null)
                    _infoRow('Chambre', edl.chambreNom!),
                ]),
                const SizedBox(height: AppSpacing.lg),

                // ── Détails ───────────────────────────────────────────────
                _sectionTitle('DÉTAILS'),
                _infoCard([
                  _infoRow('Type de bail', edl.typeLabel),
                  _infoRow(
                    'Date état des lieux',
                    _fmt.format(edl.dateEtatLieux),
                  ),
                  if (edl.dateFinalisation != null)
                    _infoRow(
                      'Date de finalisation',
                      _fmt.format(edl.dateFinalisation!),
                    ),
                  if (edl.montant != null)
                    _infoRow(
                      'Montant',
                      '€ ${edl.montant!.toStringAsFixed(2)}',
                    ),
                ]),
                const SizedBox(height: AppSpacing.lg),

                // ── Notes ─────────────────────────────────────────────────
                if (edl.notes != null && edl.notes!.isNotEmpty) ...[
                  _sectionTitle('NOTES'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Text(edl.notes!, style: AppTypography.bodyMd),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ── Observations des murs ─────────────────────────────────
                if (edl.observations.isNotEmpty) ...[
                  _sectionTitle('ÉTAT DE LA CHAMBRE'),
                  ...edl.observations.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppRadius.borderMd,
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _wallLabels[entry.key] ?? entry.key,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (entry.value.description != null &&
                                entry.value.description!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                entry.value.description!,
                                style: AppTypography.bodyMd,
                              ),
                            ],
                            if (entry.value.photos.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              SizedBox(
                                height: 80,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: entry.value.photos.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (_, i) => ClipRRect(
                                    borderRadius: AppRadius.borderSm,
                                    child: PrivateImage(
                                      ref: entry.value.photos[i],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Signature ─────────────────────────────────────────────
                if (edl.situation == SituationEdl.finalise) ...[
                  _sectionTitle('SIGNATURE'),
                  edl.locataireAccepte
                      ? Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixed.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: AppRadius.borderMd,
                            border: Border.all(
                              color:
                                  AppColors.secondary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outlined,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Vous avez accepté et signé cet état des lieux.',
                                  style: AppTypography.bodyMd,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: AppRadius.borderMd,
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Cet état des lieux a été finalisé par votre '
                                'propriétaire et attend votre signature.',
                                style: AppTypography.bodyMd,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: _accepting ? null : _accept,
                                  child: _accepting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Accepter et signer'),
                                ),
                              ),
                            ],
                          ),
                        ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gestion de la signature du locataire (profil)

class _LocataireSignatureSection extends StatefulWidget {
  const _LocataireSignatureSection();

  @override
  State<_LocataireSignatureSection> createState() => _LocataireSignatureSectionState();
}

class _LocataireSignatureSectionState extends State<_LocataireSignatureSection> {
  late Future<String?> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = SignaturesDatasource.getSavedUrl();
  }

  Future<void> _update() async {
    final sig = await showSignatureDialog(context);
    if (sig == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await SignaturesDatasource.saveUrl(sig.url);
      if (mounted) setState(() { _future = SignaturesDatasource.getSavedUrl(); _saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la signature ?'),
        content: const Text('La signature sauvegardée sera supprimée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.deleteButtonStyle,
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await SignaturesDatasource.deleteSignature();
    } catch (_) {}
    if (mounted) setState(() { _future = SignaturesDatasource.getSavedUrl(); _saving = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ma signature', style: AppTypography.titleLg),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Signature utilisée lors de l\'acceptation des états des lieux.',
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<String?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final url = snap.data;
            if (url != null && url.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.outlineVariant),
                      borderRadius: AppRadius.borderMd,
                    ),
                    child: PrivateImage(ref: url, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _saving ? null : _update,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Modifier'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _delete,
                        style: AppTheme.deleteButtonStyle,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Supprimer'),
                      ),
                    ],
                  ),
                ],
              );
            }
            return FilledButton.icon(
              onPressed: _saving ? null : _update,
              icon: const Icon(Icons.draw_outlined, size: 16),
              label: const Text('Ajouter ma signature'),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DangerZoneSection extends StatelessWidget {
  final Future<bool> hasContratsFuture;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _DangerZoneSection({
    required this.hasContratsFuture,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zone dangereuse',
          style: AppTypography.titleLg.copyWith(color: AppColors.error),
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<bool>(
          future: hasContratsFuture,
          builder: (context, snapshot) {
            final hasContracts = snapshot.data ?? false;
            final loading = snapshot.connectionState != ConnectionState.done;

            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.15),
                borderRadius: AppRadius.borderMd,
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supprimer mon compte',
                    style: AppTypography.bodyMd
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    hasContracts
                        ? 'Impossible de supprimer votre compte : vous avez des contrats enregistrés à votre nom.'
                        : 'Cette action est irréversible. Toutes vos données seront définitivement supprimées.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      onPressed:
                          (hasContracts || loading || isDeleting) ? null : onDelete,
                      icon: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.error,
                              ),
                            )
                          : const Icon(Icons.delete_forever_outlined, size: 18),
                      label: Text(
                        isDeleting ? 'Suppression…' : 'Supprimer mon compte',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EdlSituationBadge extends StatelessWidget {
  final SituationEdl situation;
  const _EdlSituationBadge({required this.situation});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (situation) {
      SituationEdl.enCours => (
        AppColors.primaryFixed,
        AppColors.onPrimaryFixedVariant,
      ),
      SituationEdl.aVenir => (
        AppColors.tertiaryFixed,
        AppColors.onTertiaryFixedVariant,
      ),
      SituationEdl.finalise => (
        AppColors.secondaryFixed,
        AppColors.onSecondaryFixedVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        situation.label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Documents (Baux + Garants)

class _DocumentsSection extends StatefulWidget {
  /// Onglet ouvert à l'entrée : 0 = Mes baux, 1 = Garants.
  final int initialTab;
  const _DocumentsSection({this.initialTab = 0});

  @override
  State<_DocumentsSection> createState() => _DocumentsSectionState();
}

class _DocumentsSectionState extends State<_DocumentsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LocataireSectionBar(title: 'Documents'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Mes baux'),
              Tab(text: 'Garants'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              _BauxLocataireTab(),
              GarantsPage(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Onglet Baux ──────────────────────────────────────────────────────────────

class _BauxLocataireTab extends StatefulWidget {
  const _BauxLocataireTab();

  @override
  State<_BauxLocataireTab> createState() => _BauxLocataireTabState();
}

class _BauxLocataireTabState extends State<_BauxLocataireTab> {
  late Future<List<EtatDesLieuxModel>> _future;
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// Ouvre l'aperçu du bail après vérification de la signature du locataire :
  /// si le bail ne porte pas encore sa signature, propose de l'apposer
  /// (création si nécessaire) avant l'ouverture.
  Future<void> _openBail(EtatDesLieuxModel edl) async {
    final signed = await ensureBailSignature(context, edl, role: 'locataire');
    if (signed == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BailPdfPreviewPage(edl: signed),
    ));
    if (mounted) _reload();
  }

  void _reload() {
    final uid = AuthService.currentUser?.id ?? '';
    final f = EtatDesLieuxDatasource.listForLocataire(uid).then(
      (list) => list
          .where((e) => e.typeEdl == 'entree' && e.locataireAccepte)
          .toList()
        ..sort((a, b) => (b.dateDebutBail ?? b.dateEtatLieux)
            .compareTo(a.dateDebutBail ?? a.dateEtatLieux)),
    );
    setState(() { _future = f; });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EtatDesLieuxModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erreur : ${snap.error}'));
        }
        final list = snap.data ?? [];

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined,
                    size: 56, color: AppColors.outline),
                const SizedBox(height: AppSpacing.md),
                Text('Aucun bail signé', style: AppTypography.titleLg),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Vos baux apparaissent ici après avoir\naccepté et signé un état des lieux.',
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final edl = list[i];
            final debut = edl.dateDebutBail ?? edl.dateEtatLieux;
            final fin = edl.dateFinBail;
            final lieu = edl.chambreNom != null
                ? '${edl.immeubleNom ?? ''} · ${edl.chambreNom}'
                : (edl.immeubleNom ?? '—');
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryFixed,
                child: Icon(Icons.description_outlined,
                    color: AppColors.primary, size: 18),
              ),
              title: Text(lieu, style: AppTypography.bodyMd),
              subtitle: Text(
                '${_dateFmt.format(debut)}  →  ${fin != null ? _dateFmt.format(fin) : "En cours"}',
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              trailing: OutlinedButton.icon(
                onPressed: () => _openBail(edl),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Bail'),
              ),
            );
          },
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Section Finances (locataire) — loyers mensuels à payer (lecture seule)
// ═════════════════════════════════════════════════════════════════════════════

class _FinancesSection extends StatefulWidget {
  const _FinancesSection();

  @override
  State<_FinancesSection> createState() => _FinancesSectionState();
}

class _FinancesSectionState extends State<_FinancesSection> {
  late Future<List<RecetteModel>> _future;
  String? _filtreStatut;

  static final _currFmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final uid = AuthService.currentUser?.id;
    if (uid == null) {
      _future = Future.value([]);
    } else {
      final f = RecettesDatasource.listByLocataire(uid);
      setState(() {
        _future = f;
      });
    }
  }

  List<RecetteModel> _filter(List<RecetteModel> all) {
    if (_filtreStatut == null) return all;
    return all.where((r) => r.statut == _filtreStatut).toList();
  }

  double _total(List<RecetteModel> all, String statut) =>
      all.where((r) => r.statut == statut).fold(0.0, (s, r) => s + r.montant);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LocataireSectionBar(title: 'Mes Finances'),
        Expanded(
          child: FutureBuilder<List<RecetteModel>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erreur : ${snap.error}'));
              }
              final all = snap.data ?? [];
              final filtered = _filter(all);

              if (all.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_outlined,
                          size: 56, color: AppColors.outline),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucun loyer enregistré.',
                          style: AppTypography.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Résumé ────────────────────────────────────────────
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _LocFinanceChip(
                          label: 'À payer',
                          amount: _total(all, 'a_recevoir'),
                          color: AppColors.primary,
                          selected: _filtreStatut == 'a_recevoir',
                          onTap: () => setState(() => _filtreStatut =
                              _filtreStatut == 'a_recevoir'
                                  ? null
                                  : 'a_recevoir'),
                        ),
                        _LocFinanceChip(
                          label: 'Payé',
                          amount: _total(all, 'recu'),
                          color: AppColors.tertiary,
                          selected: _filtreStatut == 'recu',
                          onTap: () => setState(() => _filtreStatut =
                              _filtreStatut == 'recu' ? null : 'recu'),
                        ),
                        _LocFinanceChip(
                          label: 'En retard',
                          amount: _total(all, 'en_retard'),
                          color: AppColors.error,
                          selected: _filtreStatut == 'en_retard',
                          onTap: () => setState(() => _filtreStatut =
                              _filtreStatut == 'en_retard'
                                  ? null
                                  : 'en_retard'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Tableau ───────────────────────────────────────────
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Aucune échéance pour ce filtre.',
                                style: AppTypography.bodyMd.copyWith(
                                    color: AppColors.onSurfaceVariant),
                              ),
                            )
                          : LayoutBuilder(builder: (ctx, constraints) {
                              final narrow = constraints.maxWidth < 650;
                              return SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth),
                                    child: DataTable(
                                      columnSpacing: AppSpacing.lg,
                                      headingRowColor:
                                          WidgetStateProperty.all(
                                              AppColors.surfaceContainerLow),
                                      columns: [
                                        const DataColumn(label: Text('Mois')),
                                        if (!narrow)
                                          const DataColumn(
                                              label: Text('Bien')),
                                        DataColumn(
                                            label: const Text('Loyer (€)'),
                                            numeric: true),
                                        const DataColumn(
                                            label: Text('Statut')),
                                        if (!narrow)
                                          const DataColumn(
                                              label: Text('Payé le')),
                                      ],
                                      rows: filtered.map((r) {
                                        return DataRow(cells: [
                                          DataCell(Text(r.moisLabel,
                                              style: AppTypography.bodyMd)),
                                          if (!narrow)
                                            DataCell(Text(r.lieuLabel,
                                                style: AppTypography.bodyMd,
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                          DataCell(Text(
                                              _currFmt.format(r.montant),
                                              style: AppTypography.bodyMd)),
                                          DataCell(
                                              _LocStatutBadge(statut: r.statut)),
                                          if (!narrow)
                                            DataCell(Text(
                                                r.paiementLabel ?? '—',
                                                style: AppTypography.bodyMd)),
                                        ]);
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            }),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LocFinanceChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _LocFinanceChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  static final _fmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppColors.surfaceContainerLowest,
          border: Border.all(
              color: selected ? color : AppColors.outlineVariant,
              width: selected ? 2 : 1),
          borderRadius: AppRadius.borderMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
            Text(_fmt.format(amount),
                style: AppTypography.titleLs
                    .copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LocStatutBadge extends StatelessWidget {
  final String statut;
  const _LocStatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (statut) {
      'recu' => (
          'Payé',
          AppColors.tertiaryFixed,
          AppColors.onTertiaryFixedVariant
        ),
      'en_retard' => (
          'En retard',
          AppColors.errorContainer,
          AppColors.onErrorContainer
        ),
      _ => (
          'À payer',
          AppColors.secondaryFixed,
          AppColors.onSecondaryFixedVariant
        ),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: AppRadius.borderFull),
      child: Text(label, style: AppTypography.labelSm.copyWith(color: fg)),
    );
  }
}
