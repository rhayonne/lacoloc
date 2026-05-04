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
import 'package:lacoloc_front/presentation/users/proprietaires/immeuble_detail_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/mes_chambres_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/mes_immeubles_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/nouveau_immeuble_page.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

// ─── Índices do sidebar ──────────────────────────────────────────────────────
// 0 = Accueil (navegar para /)
// 1 = Mes Propriétés
// 2 = Mes Chambres
// 3 = Créer une chambre
// 4 = Finances / Factures
// 5 = Fournisseurs
const _idxAccueil = 0;
const _idxProprietes = 1;
const _idxChambres = 2;
const _idxCreerChambre = 3;
const _idxFinances = 4;
const _idxFournisseurs = 5;

enum _Section { proprietes, chambres, creerChambre, finances, fournisseurs }

int _sectionToIndex(_Section s) => switch (s) {
  _Section.proprietes => _idxProprietes,
  _Section.chambres => _idxChambres,
  _Section.creerChambre => _idxCreerChambre,
  _Section.finances => _idxFinances,
  _Section.fournisseurs => _idxFournisseurs,
};

_Section _indexToSection(int i) => switch (i) {
  _idxChambres => _Section.chambres,
  _idxCreerChambre => _Section.creerChambre,
  _idxFinances => _Section.finances,
  _idxFournisseurs => _Section.fournisseurs,
  _ => _Section.proprietes,
};

// ─────────────────────────────────────────────────────────────────────────────

class ProprietaireProfilPage extends StatefulWidget {
  const ProprietaireProfilPage({super.key});

  @override
  State<ProprietaireProfilPage> createState() => _ProprietaireProfilPageState();
}

class _ProprietaireProfilPageState extends State<ProprietaireProfilPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SidebarXController _navCtrl;

  _Section _section = _Section.proprietes;

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
    _navCtrl = SidebarXController(
      selectedIndex: _idxProprietes,
      extended: true,
    );
    _navCtrl.addListener(_onNavChanged);
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.trim()),
    );
  }

  @override
  void dispose() {
    _navCtrl.removeListener(_onNavChanged);
    _navCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Navegação ──────────────────────────────────────────────────────────────

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
    _showImmeubleDetail = false;
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
    if (_showImmeubleDetail && _detailImmeuble != null) {
      return ImmeubleDetailPage(
        immeuble: _detailImmeuble!,
        chambres: _detailChambres,
        onModifierImmeuble: () => _openImmeubleEdition(_detailImmeuble!),
        onModifierChambre: _openChambreEdition,
        onAjouterFacture: () =>
            _openFactureCreation(immeubleId: _detailImmeuble!.id),
      );
    }
    if (_showImmeubleForm) {
      return NouveauImmeublePage(
        immeuble: _editingImmeuble,
        onSaved: _closeForm,
      );
    }
    if (_showChambreForm) {
      return CreerChambrePage(chambre: _editingChambre, onSaved: _closeForm);
    }
    // Secção Finances
    if (_section == _Section.finances) {
      return FacturesListPage(
        onAjouter: _openFactureCreation,
        onOuvrir: _openFacture,
      );
    }
    // Secção Fournisseurs
    if (_section == _Section.fournisseurs) {
      return const FournisseursPage();
    }
    return switch (_section) {
      _Section.proprietes => MesImmeublesPage(
        onAjouter: _openImmeubleCreation,
        onModifier: _openImmeubleEdition,
        onVoirDetail: _openImmeubleDetail,
      ),
      _Section.chambres => MesChambresPage(onModifier: _openChambreEdition),
      _Section.creerChambre => const CreerChambrePage(),
      _Section.finances => const SizedBox.shrink(),
      _Section.fournisseurs => const SizedBox.shrink(),
    };
  }

  // ── Sidebar ────────────────────────────────────────────────────────────────

  List<SidebarXItem> _buildNavItems() {
    final inChambreGroup =
        _section == _Section.chambres || _section == _Section.creerChambre;

    return [
      const SidebarXItem(icon: Icons.home_outlined, label: 'Accueil'),
      const SidebarXItem(
        icon: Icons.home_work_outlined,
        label: 'Mes Propriétés',
      ),
      SidebarXItem(
        icon: Icons.bed_outlined,
        label: 'Mes Chambres',
        iconBuilder: inChambreGroup
            ? (selected, _) =>
                  _GroupIcon(icon: Icons.bed_outlined, selected: selected)
            : null,
      ),
      SidebarXItem(
        icon: Icons.add_circle_outline,
        label: 'Créer une chambre',
        iconBuilder: inChambreGroup
            ? (selected, _) =>
                  _GroupIcon(icon: Icons.add_circle_outline, selected: selected)
            : null,
      ),
      const SidebarXItem(icon: Icons.receipt_long_outlined, label: 'Finances'),
      const SidebarXItem(icon: Icons.store_outlined, label: 'Fournisseurs'),
    ];
  }

  Widget _buildSidebar({required bool isNarrow}) {
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      searchController: _searchCtrl,
      items: _buildNavItems(),
      footerBuilder: (_, extended) => SidebarActionButton(
        extended: extended,
        icon: Icons.logout,
        label: 'Se déconnecter',
        onTap: _doLogout,
        color: AppColors.error,
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

class _GroupIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  const _GroupIcon({required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: selected
            ? Colors.transparent
            : AppColors.primaryFixed.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        size: 20,
        color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
      ),
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
