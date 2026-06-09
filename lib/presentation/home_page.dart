import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/presentation/app_search_bar.dart';
import 'package:lacoloc_front/presentation/chambres/chambres_list.dart';
import 'package:lacoloc_front/presentation/immeubles/immeubles_list_page.dart';
import 'package:lacoloc_front/presentation/login_dialog.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/presentation/widgets/filter_panel.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

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
                showConnexionDialog(ctx);
              },
              color: AppColors.primary,
            ),
          Padding(
            padding: EdgeInsetsGeometry.symmetric(vertical: 8.0),
            child: Divider(height: 1, thickness: 1, color: AppColors.outline),
          ),
          SizedBox(height: 4),
        ],
      ),
      userEmail: user?.email,
    );
  }

  Widget _buildBody() {
    if (_section == _idxImmeubles) {
      return const ImmeublesListPage();
    }
    // No telefone (estreito) o bandeau de texto some; o botão « Voir les
    // immeubles » fica ao lado do botão Filtres (via `trailing`).
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        if (!isPhone)
          _ColocationBanner(
            onVoirImmeubles: () => _navCtrl.selectIndex(_idxImmeubles),
          ),
        FilterPanel(
          filter: _chambreFilter,
          onChanged: (f) => setState(() => _chambreFilter = f),
          modules: const {
            FilterModule.localisation,
            FilterModule.bail,
            FilterModule.meuble,
            FilterModule.typeImmeuble,
            FilterModule.surface,
            FilterModule.prix,
            FilterModule.equipements,
          },
          trailing: isPhone
              ? OutlinedButton.icon(
                  onPressed: () => _navCtrl.selectIndex(_idxImmeubles),
                  icon: const Icon(Icons.apartment_outlined, size: 18),
                  label: const Text('Voir les immeubles'),
                )
              : null,
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

    // Desktop : la sidebar occupe toute la hauteur à gauche ; la barre du haut
    // (recherche + « Mon compte ») reste à droite, sous le haut de la sidebar.
    final topBar = AppSearchBar(
      listCache: _listCache,
      isExpanded: _isExpanded,
      onTap: () => setState(() => _isExpanded = true),
      onSearch: (value) => setState(() => _searchQuery = value),
    );

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          Expanded(
            child: Column(
              children: [
                SizedBox(height: topBar.preferredSize.height, child: topBar),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'information en haut de la liste des chambres : rappelle que les
/// annonces sont des chambres en colocation et propose d'aller voir les
/// immeubles (change la section active vers « Immeubles »).
class _ColocationBanner extends StatelessWidget {
  final VoidCallback onVoirImmeubles;

  const _ColocationBanner({required this.onVoirImmeubles});

  @override
  Widget build(BuildContext context) {
    // Em telas estreitas (telefone), texto curto + tipografia menor.
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    final text = isNarrow
        ? 'Voir les immeubles.'
        : 'Vous consultez des chambres à louer en colocation. '
              'Pour parcourir les immeubles, cliquez sur « Voir les immeubles ».';
    final textStyle = (isNarrow ? AppTypography.labelSm : AppTypography.bodyMd)
        .copyWith(color: AppColors.onPrimaryFixedVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryFixed,
          borderRadius: AppRadius.borderLg,
        ),
        child: Row(
          children: [
            Icon(
              Icons.groups_outlined,
              size: isNarrow ? 18 : 22,
              color: AppColors.onPrimaryFixedVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(text, style: textStyle)),
            const SizedBox(width: AppSpacing.sm),
            isNarrow
                ? IconButton(
                    onPressed: onVoirImmeubles,
                    tooltip: 'Voir les immeubles',
                    icon: const Icon(Icons.apartment_outlined),
                    color: AppColors.onPrimaryFixedVariant,
                  )
                : OutlinedButton.icon(
                    onPressed: onVoirImmeubles,
                    icon: const Icon(Icons.apartment_outlined, size: 18),
                    label: const Text('Voir les immeubles'),
                  ),
          ],
        ),
      ),
    );
  }
}
