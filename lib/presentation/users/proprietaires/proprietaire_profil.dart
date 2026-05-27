import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/facture.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/presentation/finances/factures_list_page.dart';
import 'package:lacoloc_front/presentation/finances/fournisseurs_page.dart';
import 'package:lacoloc_front/presentation/finances/nouvelle_facture_page.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/creer_chambre_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/agenda_visites_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/documentation_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/etat_de_lieux_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/interactions_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/mon_profil_proprietaire_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/vue_generale_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/immeuble_detail_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/inventaire_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/mes_chambres_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/mes_immeubles_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/nouveau_immeuble_page.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

// ─── Índices do sidebar ──────────────────────────────────────────────────────
// 0 = Vue générale
// 1 = Gestion Immobilière (abas: Mes Propriétés / Mes Chambres)
// 2 = Finances / Factures
// 3 = Fournisseurs
// 4 = État des lieux
// 5 = Documentation
// 6 = Interactions
// 7 = Mon Profil
const _idxVueGenerale = 0;
const _idxGestion = 1;
const _idxFinances = 2;
const _idxFournisseurs = 3;
const _idxEtatDesLieux = 4;
const _idxDocumentation = 5;
const _idxInteractions = 6;
const _idxMonProfil = 7;

enum _Section {
  vueGenerale,
  gestion,
  finances,
  fournisseurs,
  etatDesLieux,
  documentation,
  interactions,
  monProfil,
}

int _sectionToIndex(_Section s) => switch (s) {
  _Section.vueGenerale => _idxVueGenerale,
  _Section.gestion => _idxGestion,
  _Section.finances => _idxFinances,
  _Section.fournisseurs => _idxFournisseurs,
  _Section.etatDesLieux => _idxEtatDesLieux,
  _Section.documentation => _idxDocumentation,
  _Section.interactions => _idxInteractions,
  _Section.monProfil => _idxMonProfil,
};

_Section _indexToSection(int i) => switch (i) {
  _idxVueGenerale => _Section.vueGenerale,
  _idxFinances => _Section.finances,
  _idxFournisseurs => _Section.fournisseurs,
  _idxEtatDesLieux => _Section.etatDesLieux,
  _idxDocumentation => _Section.documentation,
  _idxInteractions => _Section.interactions,
  _idxMonProfil => _Section.monProfil,
  _ => _Section.gestion,
};

// ─────────────────────────────────────────────────────────────────────────────

class ProprietaireProfilPage extends StatefulWidget {
  const ProprietaireProfilPage({super.key});

  @override
  State<ProprietaireProfilPage> createState() => _ProprietaireProfilPageState();
}

class _ProprietaireProfilPageState extends State<ProprietaireProfilPage>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SidebarXController _navCtrl;
  late final TabController _gestionTabCtrl;

  _Section _section = _Section.vueGenerale;

  // Formulário immeuble
  bool _showImmeubleForm = false;
  ImmeublesModel? _editingImmeuble;

  // Detalhe immeuble
  bool _showImmeubleDetail = false;
  ImmeublesModel? _detailImmeuble;
  List<ChambreModel> _detailChambres = [];

  // Formulário chambre
  bool _showChambreForm = false;
  ChambreModel? _editingChambre;

  // Formulário / detalhe facture
  bool _showFactureForm = false;
  FactureModel? _factureTarget;
  bool _factureReadOnly = false;
  int? _facturePrefilledImmeubleId;

  // Pesquisa
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Evita loop ao sincronizar secção ↔ controlador
  bool _syncingNav = false;

  @override
  void initState() {
    super.initState();
    _gestionTabCtrl = TabController(length: 4, vsync: this);
    _navCtrl = SidebarXController(
      selectedIndex: _idxVueGenerale,
      extended: true,
    );
    _navCtrl.addListener(_onNavChanged);
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.trim()),
    );
  }

  @override
  void dispose() {
    _gestionTabCtrl.dispose();
    _navCtrl.removeListener(_onNavChanged);
    _navCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Navegação ──────────────────────────────────────────────────────────────

  void _onNavChanged() {
    if (_syncingNav || !mounted) return;
    _changeSection(_indexToSection(_navCtrl.selectedIndex));
  }

  void _changeSection(_Section s) {
    setState(() {
      _section = s;
      _showImmeubleForm = false;
      _showImmeubleDetail = false;
      _showChambreForm = false;
      _showFactureForm = false;
      _editingImmeuble = null;
      _detailImmeuble = null;
      _detailChambres = [];
      _editingChambre = null;
      _factureTarget = null;
      _facturePrefilledImmeubleId = null;
      _searchCtrl.clear();
    });
    final targetIdx = _sectionToIndex(s);
    if (_navCtrl.selectedIndex != targetIdx) {
      _syncingNav = true;
      _navCtrl.selectIndex(targetIdx);
      _syncingNav = false;
    }
  }

  void _openImmeubleCreation() => setState(() {
    _editingImmeuble = null;
    _showImmeubleForm = true;
    _showImmeubleDetail = false;
    _showChambreForm = false;
    _showFactureForm = false;
  });

  void _openImmeubleEdition(ImmeublesModel imm) => setState(() {
    _editingImmeuble = imm;
    _showImmeubleForm = true;
    _showChambreForm = false;
    _showFactureForm = false;
  });

  void _openImmeubleDetail(ImmeublesModel imm, List<ChambreModel> chambres) =>
      setState(() {
        _detailImmeuble = imm;
        _detailChambres = chambres;
        _showImmeubleDetail = true;
        _showImmeubleForm = false;
        _showChambreForm = false;
        _showFactureForm = false;
      });

  void _openChambreCreation() => setState(() {
    _editingChambre = null;
    _showChambreForm = true;
    _showImmeubleForm = false;
    _showFactureForm = false;
  });

  void _openChambreEdition(ChambreModel ch) => setState(() {
    _editingChambre = ch;
    _showChambreForm = true;
    _showImmeubleForm = false;
    _showFactureForm = false;
  });

  void _openFactureCreation({int? immeubleId}) => setState(() {
    _factureTarget = null;
    _factureReadOnly = false;
    _facturePrefilledImmeubleId = immeubleId;
    _showFactureForm = true;
    _showImmeubleForm = false;
    _showChambreForm = false;
  });

  void _openFacture(FactureModel f, {required bool readOnly}) => setState(() {
    _factureTarget = f;
    _factureReadOnly = readOnly;
    _showFactureForm = true;
    _showImmeubleForm = false;
    _showChambreForm = false;
  });

  void _openRecetteCreation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité Recettes à venir.')),
    );
  }

  void _closeForm() => setState(() {
    _showImmeubleForm = false;
    _showImmeubleDetail = false;
    _showChambreForm = false;
    _showFactureForm = false;
    _editingImmeuble = null;
    _detailImmeuble = null;
    _detailChambres = [];
    _editingChambre = null;
    _factureTarget = null;
    _facturePrefilledImmeubleId = null;
  });

  void _closeImmeubleDetail() => setState(() {
    _showImmeubleDetail = false;
    _detailImmeuble = null;
    _detailChambres = [];
  });

  void _closeImmeubleForm() => setState(() {
    _showImmeubleForm = false;
    _editingImmeuble = null;
  });

  void _closeChambreForm() => setState(() {
    _showChambreForm = false;
    _editingChambre = null;
  });

  Future<void> _doLogout() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  // ── Conteúdo central ───────────────────────────────────────────────────────

  // Fecha o formulário de factura e volta ao detalhe do immeuble se era de lá.
  void _closeFactureForm() => setState(() {
    _showFactureForm = false;
    _factureTarget = null;
    _facturePrefilledImmeubleId = null;
    // _showImmeubleDetail / _detailImmeuble são mantidos para voltar ao detalhe.
  });

  Widget _buildContent() {
    if (_searchQuery.isNotEmpty) {
      return _SearchResultsPage(
        query: _searchQuery,
        onVoirDetailImmeuble: (imm, chbrs) {
          _searchCtrl.clear();
          _openImmeubleDetail(imm, chbrs);
        },
        onModifierChambre: (c) {
          _searchCtrl.clear();
          _openChambreEdition(c);
        },
      );
    }
    // Formulário de factura tem prioridade sobre qualquer outra vista.
    if (_showFactureForm) {
      if (_factureTarget != null) {
        return FactureDetailOverlay(
          facture: _factureTarget!,
          readOnly: _factureReadOnly,
          onClose: _closeFactureForm,
          onSaved: _closeFactureForm,
        );
      }
      // Decide o callback de "voltar" consoante a origem.
      final onBack = _showImmeubleDetail ? _closeFactureForm : _closeForm;
      return _FactureFormWithBack(
        prefilledImmeubleId: _facturePrefilledImmeubleId,
        prefilledImmeubleName: _detailImmeuble?.name,
        onBack: onBack,
        onSaved: onBack,
      );
    }
    if (_showImmeubleForm) {
      return NouveauImmeublePage(
        immeuble: _editingImmeuble,
        onSaved: _closeForm,
        onBack: _closeImmeubleForm,
      );
    }
    if (_showChambreForm) {
      return CreerChambrePage(
        chambre: _editingChambre,
        onSaved: _closeForm,
        onBack: _closeChambreForm,
      );
    }
    if (_showImmeubleDetail && _detailImmeuble != null) {
      return ImmeubleDetailPage(
        immeuble: _detailImmeuble!,
        chambres: _detailChambres,
        onModifierImmeuble: () => _openImmeubleEdition(_detailImmeuble!),
        onModifierChambre: _openChambreEdition,
        onAjouterFacture: () =>
            _openFactureCreation(immeubleId: _detailImmeuble!.id),
        onBack: _closeImmeubleDetail,
      );
    }
    if (_section == _Section.vueGenerale) return const VueGeneralePage();
    if (_section == _Section.monProfil) return const MonProfilProprietairePage();
    if (_section == _Section.finances) {
      return FacturesListPage(
        onAjouter: _openFactureCreation,
        onOuvrir: _openFacture,
        onAjouterRecette: _openRecetteCreation,
      );
    }
    if (_section == _Section.fournisseurs) return const FournisseursPage();
    if (_section == _Section.etatDesLieux) return const EtatDesLieuxPage();
    if (_section == _Section.documentation) return const DocumentationPage();
    if (_section == _Section.interactions) return const InteractionsPage();

    // Secção Gestion Immobilière — abas Mes Propriétés / Mes Chambres
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: TabBar(
            controller: _gestionTabCtrl,
            tabs: const [
              Tab(text: 'Mes Propriétés'),
              Tab(text: 'Mes Chambres'),
              Tab(text: 'Agenda — Visites'),
              Tab(text: 'Inventaire'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _gestionTabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _GestionCard(
                child: MesImmeublesPage(
                  onAjouter: _openImmeubleCreation,
                  onModifier: _openImmeubleEdition,
                  onVoirDetail: _openImmeubleDetail,
                ),
              ),
              _GestionCard(
                child: MesChambresPage(
                  onModifier: _openChambreEdition,
                  onCreerChambre: _openChambreCreation,
                ),
              ),
              const _GestionCard(child: AgendaVisitesPage()),
              const _GestionCard(child: InventairePage()),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sidebar ────────────────────────────────────────────────────────────────

  List<SidebarXItem> _buildNavItems() {
    return const [
      SidebarXItem(icon: Icons.dashboard_outlined, label: 'Vue générale'),
      SidebarXItem(
        icon: Icons.home_work_outlined,
        label: 'Gestion Immobilière',
      ),
      SidebarXItem(icon: Icons.receipt_long_outlined, label: 'Finances'),
      SidebarXItem(icon: Icons.store_outlined, label: 'Fournisseurs'),
      SidebarXItem(
        icon: Icons.assignment_outlined,
        label: 'État des lieux',
      ),
      SidebarXItem(icon: Icons.menu_book_outlined, label: 'Documentation'),
      SidebarXItem(icon: Icons.people_alt_outlined, label: 'Interactions'),
      SidebarXItem(icon: Icons.person_outline, label: 'Mon Profil'),
    ];
  }

  Widget _buildSidebar({required bool isNarrow}) {
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      searchController: _searchCtrl,
      items: _buildNavItems(),
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

  // ── Build ──────────────────────────────────────────────────────────────────

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
          title: const Text('Super Coloc'),
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

// ─────────────────────────────────────────────────────────────────────────────

class _GestionCard extends StatelessWidget {
  final Widget child;
  const _GestionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowTint.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.borderLg,
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Wrapper para nova factura com botão "voltar" no topo.
class _FactureFormWithBack extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSaved;
  final int? prefilledImmeubleId;
  final String? prefilledImmeubleName;

  const _FactureFormWithBack({
    required this.onBack,
    required this.onSaved,
    this.prefilledImmeubleId,
    this.prefilledImmeubleName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
                tooltip: 'Retour à la liste',
              ),
              const SizedBox(width: 16),
              Text('Nouvelle facture', style: AppTypography.titleLg),
            ],
          ),
        ),
        Expanded(
          child: NouvelleFacturePage(
            prefilledImmeubleId: prefilledImmeubleId,
            prefilledImmeubleName: prefilledImmeubleName,
            onSaved: onSaved,
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultsPage extends StatefulWidget {
  final String query;
  final void Function(ImmeublesModel, List<ChambreModel>) onVoirDetailImmeuble;
  final ValueChanged<ChambreModel> onModifierChambre;

  const _SearchResultsPage({
    required this.query,
    required this.onVoirDetailImmeuble,
    required this.onModifierChambre,
  });

  @override
  State<_SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<_SearchResultsPage> {
  late Future<_SearchData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SearchData> _load() async {
    final ownerId = AuthService.currentUser?.id;
    if (ownerId == null) return const _SearchData(immeubles: [], chambres: []);
    final immeubles = await ImmeublesDatasource.listByOwner(ownerId);
    final ids = immeubles.map((i) => i.id).toList();
    final chambres = await ChambresDatasource.listByImmeubles(ids);
    return _SearchData(immeubles: immeubles, chambres: chambres);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SearchData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data =
            snapshot.data ?? const _SearchData(immeubles: [], chambres: []);
        final q = widget.query.toLowerCase();

        final immeubles = data.immeubles
            .where(
              (i) =>
                  i.name.toLowerCase().contains(q) ||
                  (i.address?.toLowerCase().contains(q) ?? false),
            )
            .toList();
        final chambres = data.chambres
            .where(
              (c) =>
                  c.roomName.toLowerCase().contains(q) ||
                  (c.description?.toLowerCase().contains(q) ?? false) ||
                  (c.immeubleName?.toLowerCase().contains(q) ?? false),
            )
            .toList();

        if (immeubles.isEmpty && chambres.isEmpty) {
          return Center(
            child: Text(
              'Aucun résultat pour « ${widget.query} »',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (immeubles.isNotEmpty) ...[
              Text(
                'Immeubles (${immeubles.length})',
                style: AppTypography.titleLg,
              ),
              const SizedBox(height: 8),
              ...immeubles.map(
                (i) => ListTile(
                  leading: const Icon(Icons.apartment),
                  title: Text(i.name),
                  subtitle: Text(i.address ?? i.type?.typeName ?? ''),
                  trailing: !i.isActive
                      ? const Chip(label: Text('Inactif'))
                      : null,
                  onTap: () => widget.onVoirDetailImmeuble(
                    i,
                    data.chambres.where((c) => c.immeubleId == i.id).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (chambres.isNotEmpty) ...[
              Text(
                'Chambres (${chambres.length})',
                style: AppTypography.titleLg,
              ),
              const SizedBox(height: 8),
              ...chambres.map(
                (c) => ListTile(
                  leading: const Icon(Icons.bed_outlined),
                  title: Text(c.roomName),
                  subtitle: Text(c.immeubleName ?? ''),
                  trailing: !c.isActive
                      ? const Chip(label: Text('Inactif'))
                      : null,
                  onTap: () => widget.onModifierChambre(c),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SearchData {
  final List<ImmeublesModel> immeubles;
  final List<ChambreModel> chambres;
  const _SearchData({required this.immeubles, required this.chambres});
}
