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
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/presentation/users/admin/comptes_entreprises_page.dart';
import 'package:lacoloc_front/presentation/users/admin/maintenance_page.dart';
import 'package:lacoloc_front/presentation/users/admin/utilisateurs_admin_page.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

// ─── Índices do sidebar ───────────────────────────────────────────────────────
const _idxDashboard      = 0;
const _idxUtilisateurs   = 1;
const _idxEntreprises    = 2;
const _idxPaymentTypes   = 3;
const _idxConfigImmeuble = 4;
const _idxMaintenance    = 5;

enum _Section { dashboard, utilisateurs, entreprises, paymentTypes, configImmeuble, maintenance }

_Section _indexToSection(int i) => switch (i) {
      _idxUtilisateurs   => _Section.utilisateurs,
      _idxEntreprises    => _Section.entreprises,
      _idxPaymentTypes   => _Section.paymentTypes,
      _idxConfigImmeuble => _Section.configImmeuble,
      _idxMaintenance    => _Section.maintenance,
      _                  => _Section.dashboard,
    };

int _sectionToIndex(_Section s) => switch (s) {
      _Section.dashboard       => _idxDashboard,
      _Section.utilisateurs    => _idxUtilisateurs,
      _Section.entreprises     => _idxEntreprises,
      _Section.paymentTypes    => _idxPaymentTypes,
      _Section.configImmeuble  => _idxConfigImmeuble,
      _Section.maintenance     => _idxMaintenance,
    };

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
  bool _syncingNav   = false;

  @override
  void initState() {
    super.initState();
    _navCtrl = SidebarXController(
      selectedIndex: _idxDashboard,
      extended: true,
    );
    _navCtrl.addListener(_onNavChanged);
  }

  @override
  void dispose() {
    _navCtrl.removeListener(_onNavChanged);
    _navCtrl.dispose();
    super.dispose();
  }

  void _onNavChanged() {
    if (_syncingNav || !mounted) return;
    final newSection = _indexToSection(_navCtrl.selectedIndex);
    if (newSection == _section) return;
    _changeSection(newSection);
  }

  void _changeSection(_Section s) {
    setState(() => _section = s);
    final targetIdx = _sectionToIndex(s);
    if (_navCtrl.selectedIndex != targetIdx) {
      _syncingNav = true;
      _navCtrl.selectIndex(targetIdx);
      _syncingNav = false;
    }
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
      _Section.utilisateurs    => const UtilisateursAdminPage(),
      _Section.entreprises     => const ComptesEntreprisesPage(),
      _Section.paymentTypes    => const PaymentTypesPage(),
      _Section.configImmeuble  => const _ConfigImmeublePage(),
      _Section.maintenance     => const MaintenancePage(),
    };
  }

  Widget _buildSidebar({required bool isNarrow}) {
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      userTypeLabel: 'Super Admin',
      items: [
        badgedSidebarItem(
            icon: Icons.dashboard_outlined,
            label: 'Tableau de bord',
            extended: _navCtrl.extended),
        badgedSidebarItem(
            icon: Icons.people_outlined,
            label: 'Utilisateurs',
            extended: _navCtrl.extended),
        badgedSidebarItem(
            icon: Icons.business_outlined,
            label: 'Comptes Entreprises',
            extended: _navCtrl.extended),
        badgedSidebarItem(
            icon: Icons.payment_outlined,
            label: 'Types de paiement',
            extended: _navCtrl.extended),
        badgedSidebarItem(
            icon: Icons.apartment_outlined,
            label: 'Config Immeuble',
            extended: _navCtrl.extended),
        badgedSidebarItem(
            icon: Icons.build_outlined,
            label: 'Maintenance',
            extended: _navCtrl.extended),
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

    return Scaffold(
      key: _scaffoldKey,
      drawer: isNarrow ? _buildSidebar(isNarrow: true) : null,
      appBar: isNarrow
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  if (!_navCtrl.extended) _navCtrl.setExtended(true);
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              title: Row(
                children: [
                  const Text('Super Admin'),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ADMIN',
                      style: AppTypography.labelSm.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isNarrow) _buildSidebar(isNarrow: false),
          Expanded(
            child: KeyedSubtree(
              key: _contentKey,
              child: _buildContent(),
            ),
          ),
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
  const _ConfigImmeublePage();

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
    _tabCtrl = TabController(length: 3, vsync: this);
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
        // Les onglets disparaissent quand un formulaire est ouvert
        if (!_isFormOpen)
          TabBar(
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
            physics: _isFormOpen
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
