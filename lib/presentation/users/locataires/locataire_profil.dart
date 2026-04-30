import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class LocataireProfilPage extends StatefulWidget {
  const LocataireProfilPage({super.key});

  @override
  State<LocataireProfilPage> createState() => _LocataireProfilPageState();
}

class _LocataireProfilPageState extends State<LocataireProfilPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SidebarXController _navCtrl;

  // Indices: 0 = Accueil (navegar para /), 1 = Mon Profil
  static const _idxProfil = 1;

  @override
  void initState() {
    super.initState();
    _navCtrl =
        SidebarXController(selectedIndex: _idxProfil, extended: true);
    _navCtrl.addListener(_onNavChanged);
  }

  @override
  void dispose() {
    _navCtrl.removeListener(_onNavChanged);
    _navCtrl.dispose();
    super.dispose();
  }

  void _onNavChanged() {
    if (!mounted) return;
    if (_navCtrl.selectedIndex == 0) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  Future<void> _doLogout() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  Widget _buildSidebar({required bool isNarrow}) {
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      items: const [
        SidebarXItem(icon: Icons.home_outlined, label: 'Accueil'),
        SidebarXItem(icon: Icons.person_outline, label: 'Mon Profil'),
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

  Widget _buildContent() {
    final email = AuthService.currentUser?.email ?? '';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bienvenue', style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.sm),
          Text(email, style: AppTypography.bodyMd),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "Parcourez les chambres disponibles depuis l'accueil.",
            style: AppTypography.bodyMd,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (_) => false),
            icon: const Icon(Icons.search),
            label: const Text('Voir les chambres'),
          ),
        ],
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
          title: const Text('Mon Espace'),
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
