import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/models/chambre.dart';
import 'package:habitafrance/presentation/app_search_bar.dart';
import 'package:habitafrance/presentation/chambres/chambre_detail_page.dart';
import 'package:habitafrance/presentation/home/home_listings_grid.dart';
import 'package:habitafrance/presentation/immeubles/immeuble_public_detail_page.dart';
import 'package:habitafrance/presentation/login_dialog.dart';
import 'package:habitafrance/presentation/nav/app_sidebar.dart';
import 'package:habitafrance/presentation/widgets/filter_panel.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';

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
  int? _detailChambreId;
  int? _detailImmeubleId;

  // La home affiche Location et Colocations en même temps (chacun togglable
  // indépendamment). Au moins un des deux doit rester actif (voir
  // [_toggleSection]) ; les filtres et ces deux toggles sont conservés tels
  // quels quand on ouvre une fiche détail puis qu'on revient à l'accueil.
  bool _showLocation = true;
  bool _showColocation = true;

  @override
  void initState() {
    super.initState();
    _navCtrl = SidebarXController(selectedIndex: 0, extended: true);
    // Seul item du menu = « Accueil » : un clic dessus notifie toujours
    // (même index), qu'on soit déjà sur la liste ou pas — on s'en sert pour
    // fermer une éventuelle fiche détail ouverte SANS toucher aux filtres/
    // toggles, qui restent tels que l'utilisateur les avait laissés.
    _navCtrl.addListener(_onAccueilTapped);
  }

  @override
  void dispose() {
    _navCtrl.removeListener(_onAccueilTapped);
    _navCtrl.dispose();
    super.dispose();
  }

  void _onAccueilTapped() {
    if (!mounted) return;
    if (_detailChambreId == null && _detailImmeubleId == null) return;
    setState(() {
      _detailChambreId = null;
      _detailImmeubleId = null;
    });
  }

  void _toggleSection({bool? location, bool? colocation}) {
    final newLocation = location ?? _showLocation;
    final newColocation = colocation ?? _showColocation;
    // Garde : au moins une des deux catégories doit rester visible.
    if (!newLocation && !newColocation) return;
    setState(() {
      _showLocation = newLocation;
      _showColocation = newColocation;
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
    // Fiche immeuble/chambre rendue dans le cadre principal (menu conservé à
    // gauche). Prioritaire : « Retour » efface l'immeuble et, si on venait
    // d'une chambre (_detailChambreId encore défini), on retombe dessus.
    if (_detailImmeubleId != null) {
      return ImmeublePublicDetailView(
        immeubleId: _detailImmeubleId!,
        onBack: () => setState(() => _detailImmeubleId = null),
      );
    }
    if (_detailChambreId != null) {
      return ChambreDetailView(
        chambreId: _detailChambreId!,
        onBack: () => setState(() => _detailChambreId = null),
        onVoirImmeuble: (id) => setState(() => _detailImmeubleId = id),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        FilterPanel(
          filter: _chambreFilter,
          onChanged: (f) => setState(() => _chambreFilter = f),
          modules: const {
            FilterModule.localisation,
            FilterModule.meuble,
            FilterModule.typeImmeuble,
            FilterModule.surface,
            FilterModule.prix,
            FilterModule.equipements,
            FilterModule.charges,
            FilterModule.disponibilite,
          },
          trailingAtStart: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _FilterBarSeparator(),
              const SizedBox(width: AppSpacing.sm),
              _BienTypeToggleButton(
                icon: Icons.apartment_outlined,
                label: 'Voir Location',
                selected: _showLocation,
                onTap: () => _toggleSection(location: !_showLocation),
              ),
              const SizedBox(width: AppSpacing.sm),
              _BienTypeToggleButton(
                icon: Icons.groups_outlined,
                label: 'Voir Colocations',
                selected: _showColocation,
                onTap: () => _toggleSection(colocation: !_showColocation),
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_isExpanded) {
                setState(() => _isExpanded = false);
                FocusScope.of(context).unfocus();
              }
            },
            child: HomeListingsGrid(
              filter: _chambreFilter,
              searchQuery: _searchQuery,
              showLocation: _showLocation,
              showColocation: _showColocation,
              onChambresLoaded: (data) => _listCache = data,
              onTapChambre: (id) => setState(() => _detailChambreId = id),
              onTapImmeuble: (id) => setState(() => _detailImmeubleId = id),
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
            tooltip: 'Ouvrir le menu',
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

/// Petit séparateur vertical entre le bouton « Filtres » et les puces
/// Location/Colocations — signale que ces deux groupes de contrôles sont
/// distincts (Filtres = affine la liste ; Location/Colocations = catégories
/// affichées).
class _FilterBarSeparator extends StatelessWidget {
  const _FilterBarSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.outlineVariant,
    );
  }
}

/// Bouton toggle « Voir Location » / « Voir Colocations » — même gabarit que
/// [FilterButton] (dimensions, pilule, élévation) pour rester bien visible et
/// tactile en responsive ; coché (icône ✓) quand actif. Indépendants l'un de
/// l'autre (pas un choix exclusif) — au moins un reste actif, voir
/// [_HomePageState._toggleSection].
class _BienTypeToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BienTypeToggleButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primary : AppColors.onSurfaceVariant;
    return Material(
      color:
          selected ? AppColors.primaryFixed : AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderFull,
        side: BorderSide(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.55)
              : AppColors.outlineVariant,
        ),
      ),
      elevation: AppTheme.raisedButtonElevation,
      shadowColor: AppTheme.raisedButtonShadowColor,
      child: InkWell(
        borderRadius: AppRadius.borderFull,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.labelMd
                    .copyWith(fontWeight: FontWeight.w600, color: fg),
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.check, size: 18, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
