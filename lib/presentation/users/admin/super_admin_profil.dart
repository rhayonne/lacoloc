import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
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
const _idxAccueil       = 0;
const _idxUtilisateurs  = 1;
const _idxEntreprises   = 2;
const _idxPaymentTypes  = 3;
const _idxMeubleTypes   = 4;
const _idxMaintenance   = 5;

enum _Section { utilisateurs, entreprises, paymentTypes, meubleTypes, maintenance }

_Section _indexToSection(int i) => switch (i) {
      _idxEntreprises  => _Section.entreprises,
      _idxPaymentTypes => _Section.paymentTypes,
      _idxMeubleTypes  => _Section.meubleTypes,
      _idxMaintenance  => _Section.maintenance,
      _                => _Section.utilisateurs,
    };

int _sectionToIndex(_Section s) => switch (s) {
      _Section.utilisateurs  => _idxUtilisateurs,
      _Section.entreprises   => _idxEntreprises,
      _Section.paymentTypes  => _idxPaymentTypes,
      _Section.meubleTypes   => _idxMeubleTypes,
      _Section.maintenance   => _idxMaintenance,
    };

// ─────────────────────────────────────────────────────────────────────────────

class SuperAdminProfilPage extends StatefulWidget {
  const SuperAdminProfilPage({super.key});

  @override
  State<SuperAdminProfilPage> createState() => _SuperAdminProfilPageState();
}

class _SuperAdminProfilPageState extends State<SuperAdminProfilPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // GlobalKey estável: preserva o estado do conteúdo quando o layout muda
  // entre drawer (estreito) e sidebar fixa (largo) ao redimensionar a janela.
  final _contentKey = GlobalKey();
  late final SidebarXController _navCtrl;

  _Section _section = _Section.utilisateurs;
  bool _syncingNav = false;

  @override
  void initState() {
    super.initState();
    _navCtrl = SidebarXController(
      selectedIndex: _idxUtilisateurs,
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
      _Section.utilisateurs  => const UtilisateursAdminPage(),
      _Section.entreprises   => const ComptesEntreprisesPage(),
      _Section.paymentTypes  => const PaymentTypesPage(),
      _Section.meubleTypes   => const MeubleTypesPage(),
      _Section.maintenance   => const MaintenancePage(),
    };
  }

  Widget _buildSidebar({required bool isNarrow}) {
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      items: const [
        SidebarXItem(icon: Icons.home_outlined,    label: 'Accueil'),
        SidebarXItem(icon: Icons.people_outlined,  label: 'Utilisateurs'),
        SidebarXItem(icon: Icons.business_outlined,label: 'Comptes Entreprises'),
        SidebarXItem(icon: Icons.payment_outlined, label: 'Types de paiement'),
        SidebarXItem(icon: Icons.chair_outlined,   label: 'Types de meuble'),
        SidebarXItem(icon: Icons.build_outlined,   label: 'Maintenance'),
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

    // Estrutura única de Scaffold independente do tamanho da janela.
    // O KeyedSubtree com GlobalKey preserva o estado do conteúdo quando o
    // layout alterna entre drawer (estreito) e sidebar fixa (largo).
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
