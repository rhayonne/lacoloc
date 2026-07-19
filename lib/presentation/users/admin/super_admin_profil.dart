import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/charges_reference.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/payment_types.dart';
import 'package:lacoloc_front/data/datasources/user_management.dart';
import 'package:lacoloc_front/presentation/admin/charges_reference_page.dart';
import 'package:lacoloc_front/presentation/admin/meuble_categories_page.dart';
import 'package:lacoloc_front/presentation/admin/meuble_types_page.dart';
import 'package:lacoloc_front/presentation/admin/payment_types_page.dart';
import 'package:lacoloc_front/presentation/nav/app_nav_sidebar.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/presentation/widgets/app_top_bar.dart';
import 'package:lacoloc_front/presentation/users/admin/communication_page.dart';
import 'package:lacoloc_front/presentation/users/admin/admin_edl_page.dart';
import 'package:lacoloc_front/presentation/users/admin/comptes_entreprises_page.dart';
import 'package:lacoloc_front/presentation/users/admin/maintenance_page.dart';
import 'package:lacoloc_front/presentation/users/admin/themes_admin_page.dart';
import 'package:lacoloc_front/presentation/users/admin/utilisateurs_admin_page.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/app_tab_bar.dart';

enum _Section { dashboard, utilisateurs, edls, communication, entreprises, paymentTypes, configImmeuble, configuration, maintenance }

// ─────────────────────────────────────────────────────────────────────────────

class SuperAdminProfilPage extends StatefulWidget {
  const SuperAdminProfilPage({super.key});

  @override
  State<SuperAdminProfilPage> createState() => _SuperAdminProfilPageState();
}

class _SuperAdminProfilPageState extends State<SuperAdminProfilPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _contentKey  = GlobalKey();
  late final SidebarXController _navCtrl;

  _Section _section  = _Section.dashboard;
  // Sous-onglet courant des sections à sous-menus.
  int _usersSub  = 0; // 0 = Utilisateurs, 1 = Groupes
  int _commSub   = 0; // 0 = Composer, 1 = Historique
  int _configSub = 0;
  int _maintSub  = 0;

  /// Nombre de sous-menus de la section courante (pour le swipe sur la barre).
  int get _subCount => switch (_section) {
    _Section.utilisateurs => 2,
    _Section.communication => 2,
    _Section.configImmeuble => 3,
    _Section.maintenance => 2,
    _ => 1,
  };

  int get _currentSub => switch (_section) {
    _Section.utilisateurs => _usersSub,
    _Section.communication => _commSub,
    _Section.configImmeuble => _configSub,
    _Section.maintenance => _maintSub,
    _ => 0,
  };

  void _setSub(int v) => setState(() {
    switch (_section) {
      case _Section.utilisateurs:
        _usersSub = v;
      case _Section.communication:
        _commSub = v;
      case _Section.configImmeuble:
        _configSub = v;
      case _Section.maintenance:
        _maintSub = v;
      default:
        break;
    }
  });

  /// Swipe horizontal SUR LA BARRE DE TITRE uniquement : change de sous-menu
  /// dans la section courante (aucun défilement de contenu ne navigue).
  void _swipeSub(int delta) {
    final next = _currentSub + delta;
    if (next >= 0 && next < _subCount) _setSub(next);
  }

  @override
  void initState() {
    super.initState();
    _navCtrl = SidebarXController(selectedIndex: 0, extended: true);
  }

  @override
  void dispose() {
    _navCtrl.dispose();
    super.dispose();
  }

  void _changeSection(_Section s) {
    setState(() => _section = s);
  }

  /// Ouvre une section à sous-menus sur le sous-onglet demandé.
  void _openSub(_Section s, VoidCallback apply) {
    setState(() {
      _section = s;
      apply();
    });
  }

  Future<void> _doLogout() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  Widget _buildContent() {
    return switch (_section) {
      _Section.dashboard       => const _SuperAdminDashboard(),
      _Section.utilisateurs    => UtilisateursAdminPage(
          key: ValueKey('usr$_usersSub'),
          initialTab: _usersSub,
          showTabBar: false,
        ),
      _Section.edls            => const AdminEdlPage(),
      _Section.communication   => CommunicationPage(
          key: ValueKey('comm$_commSub'),
          initialTab: _commSub,
          showTabBar: false,
        ),
      _Section.entreprises     => const ComptesEntreprisesPage(),
      _Section.paymentTypes    => const PaymentTypesPage(),
      _Section.configImmeuble  => _ConfigImmeublePage(
          key: ValueKey('cfg$_configSub'),
          initialTab: _configSub,
          showTabBar: false,
        ),
      // Configuration → un seul sous-menu pour l'instant (Thèmes).
      _Section.configuration   => const ThemesAdminPage(),
      _Section.maintenance     => MaintenancePage(
          key: ValueKey('mnt$_maintSub'),
          initialTab: _maintSub,
          showTabBar: false,
        ),
    };
  }

  Widget _buildSidebar({required bool isNarrow}) {
    void go(_Section s) {
      if (isNarrow) Navigator.of(context).pop();
      _changeSection(s);
    }

    void goSub(_Section s, void Function() apply) {
      if (isNarrow) Navigator.of(context).pop();
      _openSub(s, apply);
    }

    return AppNavSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      userTypeLabel: 'Super Admin',
      entries: [
        NavEntry(
          icon: Icons.dashboard_outlined,
          label: 'Tableau de bord',
          selected: _section == _Section.dashboard,
          onTap: () => go(_Section.dashboard),
        ),
        NavEntry(
          icon: Icons.people_outlined,
          label: 'Utilisateurs',
          selected: _section == _Section.utilisateurs,
          onTap: () => goSub(_Section.utilisateurs, () => _usersSub = 0),
          children: [
            NavChild(
              label: 'Utilisateurs',
              selected: _section == _Section.utilisateurs && _usersSub == 0,
              onTap: () => goSub(_Section.utilisateurs, () => _usersSub = 0),
            ),
            NavChild(
              label: 'Groupes',
              selected: _section == _Section.utilisateurs && _usersSub == 1,
              onTap: () => goSub(_Section.utilisateurs, () => _usersSub = 1),
            ),
          ],
        ),
        NavEntry(
          icon: Icons.assignment_outlined,
          label: 'États des lieux',
          selected: _section == _Section.edls,
          onTap: () => go(_Section.edls),
        ),
        NavEntry(
          icon: Icons.campaign_outlined,
          label: 'Communication',
          selected: _section == _Section.communication,
          onTap: () => goSub(_Section.communication, () => _commSub = 0),
          children: [
            NavChild(
              label: 'Nouveau message',
              selected: _section == _Section.communication && _commSub == 0,
              onTap: () => goSub(_Section.communication, () => _commSub = 0),
            ),
            NavChild(
              label: 'Historique',
              selected: _section == _Section.communication && _commSub == 1,
              onTap: () => goSub(_Section.communication, () => _commSub = 1),
            ),
          ],
        ),
        NavEntry(
          icon: Icons.business_outlined,
          label: 'Comptes Entreprises',
          selected: _section == _Section.entreprises,
          onTap: () => go(_Section.entreprises),
        ),
        NavEntry(
          icon: Icons.payment_outlined,
          label: 'Types de paiement',
          selected: _section == _Section.paymentTypes,
          onTap: () => go(_Section.paymentTypes),
        ),
        NavEntry(
          icon: Icons.apartment_outlined,
          label: 'Config Immeuble',
          selected: _section == _Section.configImmeuble,
          onTap: () => go(_Section.configImmeuble),
          children: [
            NavChild(
              label: 'Types de meuble',
              selected: _section == _Section.configImmeuble && _configSub == 0,
              onTap: () => goSub(_Section.configImmeuble, () => _configSub = 0),
            ),
            NavChild(
              label: 'Catégories',
              selected: _section == _Section.configImmeuble && _configSub == 1,
              onTap: () => goSub(_Section.configImmeuble, () => _configSub = 1),
            ),
            NavChild(
              label: 'Charges locatives',
              selected: _section == _Section.configImmeuble && _configSub == 2,
              onTap: () => goSub(_Section.configImmeuble, () => _configSub = 2),
            ),
          ],
        ),
        NavEntry(
          icon: Icons.tune,
          label: 'Configuration',
          selected: _section == _Section.configuration,
          onTap: () => go(_Section.configuration),
          children: [
            NavChild(
              label: 'Thèmes',
              selected: _section == _Section.configuration,
              onTap: () => go(_Section.configuration),
            ),
          ],
        ),
        NavEntry(
          icon: Icons.build_outlined,
          label: 'Maintenance',
          selected: _section == _Section.maintenance,
          onTap: () => go(_Section.maintenance),
          children: [
            NavChild(
              label: 'Connexions',
              selected: _section == _Section.maintenance && _maintSub == 0,
              onTap: () => goSub(_Section.maintenance, () => _maintSub = 0),
            ),
            NavChild(
              label: 'Services',
              selected: _section == _Section.maintenance && _maintSub == 1,
              onTap: () => goSub(_Section.maintenance, () => _maintSub = 1),
            ),
          ],
        ),
      ],
      footerBuilder: (_, extended) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SidebarActionButton(
            extended: extended,
            icon: Icons.home_outlined,
            label: 'Accueil',
            onTap: () => Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (r) => false),
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

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 800;

    // Sur mobile, le bouton « menu » (hamburger) est injecté dans la barre de
    // titre de la page courante via [TopBarMenuScope] — plus de barre « Super
    // Admin » séparée : chaque page montre son propre titre (nom du menu/
    // sous-menu) + son action. Le swipe horizontal n'est actif QUE sur cette
    // barre de titre (voir AppTopBar), et change de sous-menu.
    final menuButton = isNarrow
        ? IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Ouvrir le menu',
            onPressed: () {
              if (!_navCtrl.extended) _navCtrl.setExtended(true);
              _scaffoldKey.currentState?.openDrawer();
            },
          )
        : null;

    final content = TopBarMenuScope(
      menuButton: menuButton,
      onSwipeLeft: isNarrow && _subCount > 1 ? () => _swipeSub(1) : null,
      onSwipeRight: isNarrow && _subCount > 1 ? () => _swipeSub(-1) : null,
      child: KeyedSubtree(
        key: _contentKey,
        child: _buildContent(),
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: isNarrow ? _buildSidebar(isNarrow: true) : null,
      body: Row(
        children: [
          if (!isNarrow) _buildSidebar(isNarrow: false),
          Expanded(child: content),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard

class _SuperAdminDashboard extends StatefulWidget {
  const _SuperAdminDashboard();

  @override
  State<_SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<_SuperAdminDashboard> {
  late Future<_DashStats> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashStats> _load() async {
    final results = await Future.wait([
      UserManagementDatasource.listAll().then((l) => l.length),
      InventaireDatasource.listMeubleReferences().then((l) => l.length),
      ChargesReferenceDatasource.listAll().then((l) => l.length),
      PaymentTypesDatasource.listAll().then((l) => l.length),
    ]);
    return _DashStats(
      users:        results[0],
      meubleTypes:  results[1],
      chargeTypes:  results[2],
      paymentTypes: results[3],
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.currentUser?.email ?? '';

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 900 ? 4 : w >= 600 ? 2 : 1;
        const gap = AppSpacing.md;
        final cardW = (w - AppSpacing.xl * 2 - gap * (cols - 1)) / cols;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête
              Row(
                children: [
                  // Bouton menu (mobile) injecté par la coquille.
                  if (TopBarMenuScope.of(context)?.menuButton != null) ...[
                    TopBarMenuScope.of(context)!.menuButton!,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tableau de bord',
                            style: AppTypography.headlineLg),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          email,
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SUPER ADMIN',
                      style: AppTypography.labelSm.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.xl),

              // Grille de statistiques
              FutureBuilder<_DashStats>(
                future: _future,
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()));
                  }
                  if (snap.hasError || snap.data == null) {
                    return const SizedBox.shrink();
                  }
                  final s = snap.data!;
                  final cards = [
                    _StatCardData(Icons.people_outlined, 'Utilisateurs',
                        s.users, AppColors.primary),
                    _StatCardData(Icons.chair_outlined, 'Types de meuble',
                        s.meubleTypes, AppColors.tertiary),
                    _StatCardData(Icons.receipt_long_outlined,
                        'Charges locatives', s.chargeTypes, AppColors.secondary),
                    _StatCardData(Icons.payment_outlined, 'Types de paiement',
                        s.paymentTypes, AppColors.error),
                  ];
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: cards
                        .map((d) => SizedBox(
                              width: cardW,
                              child: _StatCard(d),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashStats {
  final int users;
  final int meubleTypes;
  final int chargeTypes;
  final int paymentTypes;

  const _DashStats({
    required this.users,
    required this.meubleTypes,
    required this.chargeTypes,
    required this.paymentTypes,
  });
}

class _StatCardData {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _StatCardData(this.icon, this.label, this.count, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard(this.data);

  @override
  Widget build(BuildContext context) {
    final color = data.color;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: color, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(data.count.toString(),
              style: AppTypography.headlineLg
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(data.label,
              style: AppTypography.labelMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Config Immeuble — Onglets Types de meuble + Catégories + Charges

class _ConfigImmeublePage extends StatefulWidget {
  final int initialTab;
  final bool showTabBar;
  const _ConfigImmeublePage({super.key, this.initialTab = 0, this.showTabBar = true});

  @override
  State<_ConfigImmeublePage> createState() => _ConfigImmeublePageState();
}

class _ConfigImmeublePageState extends State<_ConfigImmeublePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _isFormOpen = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onFormOpenChanged(bool open) {
    if (mounted) setState(() => _isFormOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Les onglets disparaissent quand un formulaire est ouvert OU quand la
        // navigation se fait par sous-menus (showTabBar=false).
        if (widget.showTabBar && !_isFormOpen)
          AppTabBar(
            controller: _tabCtrl,
            isScrollable: false,
            tabs: const [
              Tab(text: 'Types de meuble'),
              Tab(text: 'Catégories'),
              Tab(text: 'Charges locatives'),
            ],
          ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            // Balayage du contenu désactivé en mode sous-menus (ou formulaire
            // ouvert) : la navigation se fait par la sidebar, pas au swipe.
            physics: (_isFormOpen || !widget.showTabBar)
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            children: [
              MeubleTypesPage(onFormOpenChanged: _onFormOpenChanged),
              MeubleCategoriesPage(onFormOpenChanged: _onFormOpenChanged),
              ChargesReferencePage(onFormOpenChanged: _onFormOpenChanged),
            ],
          ),
        ),
      ],
    );
  }
}
