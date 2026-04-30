import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/presentation/app_search_bar.dart';
import 'package:lacoloc_front/presentation/chambres/chambres_list.dart';
import 'package:lacoloc_front/presentation/immeubles/immeubles_list_page.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/presentation/widgets/filter_panel.dart';
import 'package:lacoloc_front/theme/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.title = 'Home'});

  final String? title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SidebarXController _navCtrl;

  List<ChambreModel> _listCache = [];
  bool _isExpanded = false;
  String _searchQuery = '';
  ChambreFilter _chambreFilter = ChambreFilter.empty;

  static const _idxChambres = 0;
  static const _idxImmeubles = 1;

  int _section = _idxChambres;

  @override
  void initState() {
    super.initState();
    _navCtrl = SidebarXController(selectedIndex: _idxChambres, extended: true);
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
    final idx = _navCtrl.selectedIndex;
    if (idx == _section) return;
    setState(() {
      _section = idx;
      if (idx != _idxChambres) {
        _searchQuery = '';
        _chambreFilter = ChambreFilter.empty;
      }
    });
  }

  Future<void> _doLogout() async {
    await AuthService.signOut();
    if (mounted) setState(() {});
  }

  Widget _buildSidebar({required bool isNarrow}) {
    final user = AuthService.currentUser;
    final isLoggedIn = AuthService.isLoggedIn;

    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      items: const [
        SidebarXItem(icon: Icons.home_outlined, label: 'Accueil'),
        SidebarXItem(icon: Icons.apartment_outlined, label: 'Immeubles'),
      ],
      footerBuilder: (ctx, extended) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoggedIn) ...[
            SidebarActionButton(
              extended: extended,
              icon: Icons.manage_accounts_outlined,
              label: 'Mon espace',
              onTap: () {
                if (isNarrow) Navigator.of(ctx).pop();
                Navigator.of(ctx).pushNamed('/profile');
              },
            ),
            SidebarActionButton(
              extended: extended,
              icon: Icons.logout,
              label: 'Se déconnecter',
              onTap: _doLogout,
              color: AppColors.error,
            ),
          ] else
            SidebarActionButton(
              extended: extended,
              icon: Icons.login,
              label: 'Se connecter',
              onTap: () {
                if (isNarrow) Navigator.of(ctx).pop();
                Navigator.of(ctx).pushNamed('/login');
              },
              color: AppColors.primary,
            ),
        ],
      ),
      userEmail: user?.email,
    );
  }

  Widget _buildBody() {
    if (_section == _idxImmeubles) {
      return const ImmeublesListPage();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterPanel(
          filter: _chambreFilter,
          onChanged: (f) => setState(() => _chambreFilter = f),
          showEquipments: true,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_isExpanded) {
                setState(() => _isExpanded = false);
                FocusScope.of(context).unfocus();
              }
            },
            child: ChambresList(
              filter: _searchQuery,
              chambreFilter: _chambreFilter,
              onDataLoaded: (data) => _listCache = data,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 800;
    final sidebar = _buildSidebar(isNarrow: isNarrow);
    final body = _buildBody();

    if (isNarrow) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: sidebar,
        appBar: AppSearchBar(
          listCache: _listCache,
          isExpanded: _isExpanded,
          onTap: () => setState(() => _isExpanded = true),
          onSearch: (value) => setState(() => _searchQuery = value),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              if (!_navCtrl.extended) _navCtrl.setExtended(true);
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ),
        body: body,
      );
    }

    return Scaffold(
      appBar: AppSearchBar(
        listCache: _listCache,
        isExpanded: _isExpanded,
        onTap: () => setState(() => _isExpanded = true),
        onSearch: (value) => setState(() => _searchQuery = value),
      ),
      body: Row(
        children: [
          sidebar,
          Expanded(child: body),
        ],
      ),
    );
  }
}
