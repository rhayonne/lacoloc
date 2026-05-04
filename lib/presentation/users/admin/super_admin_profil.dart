import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/presentation/admin/payment_types_page.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

// ─── Índices do sidebar ───────────────────────────────────────────────────────
const _idxAccueil = 0;
const _idxPaymentTypes = 1;

enum _Section { paymentTypes }

_Section _indexToSection(int i) => switch (i) {
      _ => _Section.paymentTypes,
    };

int _sectionToIndex(_Section s) => switch (s) {
      _Section.paymentTypes => _idxPaymentTypes,
    };

// ─────────────────────────────────────────────────────────────────────────────

class SuperAdminProfilPage extends StatefulWidget {
  const SuperAdminProfilPage({super.key});

  @override
  State<SuperAdminProfilPage> createState() => _SuperAdminProfilPageState();
}

class _SuperAdminProfilPageState extends State<SuperAdminProfilPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SidebarXController _navCtrl;

  _Section _section = _Section.paymentTypes;
  bool _syncingNav = false;

  @override
  void initState() {
    super.initState();
    _navCtrl = SidebarXController(
      selectedIndex: _idxPaymentTypes,
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
    final idx = _navCtrl.selectedIndex;
    if (idx == _idxAccueil) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
      return;
    }
    _changeSection(_indexToSection(idx));
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
      _Section.paymentTypes => const PaymentTypesPage(),
    };
  }

  Widget _buildSidebar({required bool isNarrow}) {
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      items: const [
        SidebarXItem(icon: Icons.home_outlined, label: 'Accueil'),
        SidebarXItem(
            icon: Icons.payment_outlined, label: 'Types de paiement'),
      ],
      footerBuilder: (_, extended) => SidebarActionButton(
        extended: extended,
        icon: Icons.logout,
        label: 'Se déconnecter',
        onTap: _doLogout,
        color: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 800;
    final sidebar = _buildSidebar(isNarrow: isNarrow);

    if (isNarrow) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: sidebar,
        appBar: AppBar(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ADMIN',
                  style: AppTypography.labelSm.copyWith(
                      color: AppColors.error, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        body: _buildContent(),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}
