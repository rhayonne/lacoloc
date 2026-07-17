import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/cache/realtime_refresh_mixin.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/demandes_contact.dart';
import 'package:lacoloc_front/data/datasources/messages.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/facture.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/entreprise_config_page.dart';
import 'package:lacoloc_front/presentation/finances/factures_list_page.dart';
import 'package:lacoloc_front/presentation/finances/fournisseurs_page.dart';
import 'package:lacoloc_front/presentation/finances/nouvelle_facture_page.dart';
import 'package:lacoloc_front/presentation/nav/app_nav_sidebar.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/creer_chambre_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/agenda_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/documentation_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/etat_de_lieux_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/interactions_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/mon_profil_proprietaire_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/vue_generale_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/immeuble_detail_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/inventaire_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/lots_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/mes_chambres_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/mes_immeubles_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/nouveau_immeuble_page.dart';
import 'package:lacoloc_front/presentation/tour/guided_tours.dart';
import 'package:lacoloc_front/presentation/widgets/unsaved_changes_dialog.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

enum _Section {
  vueGenerale,
  gestion,
  agenda,
  finances,
  fournisseurs,
  etatDesLieux,
  documentation,
  interactions,
  monProfil,
}

// ─────────────────────────────────────────────────────────────────────────────

class ProprietaireProfilPage extends StatefulWidget {
  const ProprietaireProfilPage({super.key});

  @override
  State<ProprietaireProfilPage> createState() => _ProprietaireProfilPageState();
}

class _ProprietaireProfilPageState extends State<ProprietaireProfilPage>
    with SingleTickerProviderStateMixin, RealtimeRefreshMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // Clé stable du contenu : préserve l'état des pages de section (ex. un EDL
  // ouvert) quand la mise en page change (drawer ↔ sidebar) au redimensionnement.
  final _contentKey = GlobalKey();
  late final SidebarXController _navCtrl;
  late final TabController _gestionTabCtrl;

  _Section _section = _Section.vueGenerale;

  // Formulário immeuble
  bool _showImmeubleForm = false;
  ImmeublesModel? _editingImmeuble;
  bool _tourImmeuble = false; // démarrer le tour guidé à l'ouverture du form

  // Detalhe immeuble
  bool _showImmeubleDetail = false;
  ImmeublesModel? _detailImmeuble;
  List<ChambreModel> _detailChambres = [];

  // Formulário chambre
  bool _showChambreForm = false;
  ChambreModel? _editingChambre;
  // Immeuble pré-rempli quand on crée une chambre depuis le détail d'immeuble.
  int? _chambrePrefilledImmeubleId;
  // Vrai si le formulaire chambre a été ouvert depuis le détail d'immeuble
  // (→ on y revient après enregistrement/annulation).
  bool _chambreFromDetail = false;

  // Formulário / detalhe facture
  bool _showFactureForm = false;
  FactureModel? _factureTarget;
  bool _factureReadOnly = false;
  int? _facturePrefilledImmeubleId;

  // Pesquisa
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Sous-onglet courant des sections à sous-menus (piloté par la sidebar).
  int _finSub = 0;
  int _docSub = 0;
  int _interSub = 0;
  int _edlSub = 0;

  // Perfil do usuário atual (para detectar admin de groupe → config entreprise).
  UsersClient? _profile;

  // Configuration entreprise (admin de groupe) — renderiza no frame principal.
  bool _showEntrepriseConfig = false;

  // Pastille du menu « Interactions » : notifications non lues + demandes de
  // contact non établies. Recalculé sur changement Realtime.
  int _interactionsBadge = 0;

  @override
  Set<String> get watchedEntities => {'notifications', 'demandes', 'messages'};

  @override
  void onRealtimeChange() => _refreshBadges();

  Future<void> _refreshBadges() async {
    try {
      final results = await Future.wait([
        NotificationsDatasource.unreadCount(),
        DemandesContactDatasource.listByOwner(),
        MessagesDatasource.unreadCount(refresh: true),
      ]);
      if (!mounted) return;
      final unread = results[0] as int;
      final demandes = results[1] as List;
      final msgNonLus = results[2] as int;
      final pendingDemandes =
          demandes.where((d) => d.contactEtabli == false).length;
      // Pastille = notifications non lues + demandes à traiter + messages reçus.
      setState(
        () => _interactionsBadge = unread + pendingDemandes + msgNonLus,
      );
    } catch (_) {
      // best-effort : pastille non bloquante
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _refreshBadges();
    _gestionTabCtrl = TabController(length: 4, vsync: this);
    // Rebuild la sidebar quand le sous-onglet de Gestion change (état sélectionné).
    _gestionTabCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _navCtrl = SidebarXController(
      selectedIndex: 0,
      extended: true,
    );
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.trim()),
    );
    // Deep-link depuis le manuel (« Tour guidé ») : `?tour=immeuble` ouvre le
    // formulaire de création d'immeuble avec le tour guidé automatiquement. Le
    // paramètre a été mémorisé dans PendingTour (l'URL l'a perdu au redirect).
    if (PendingTour.consume() == 'immeuble') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openImmeubleCreation(tour: true);
      });
    }
  }

  @override
  void dispose() {
    _gestionTabCtrl.dispose();
    _navCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await AuthService.loadCurrentProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  // ── Navegação ──────────────────────────────────────────────────────────────

  /// Navigation demandée depuis la sidebar (feuille ou en-tête de groupe).
  /// Si un formulaire est ouvert, demande confirmation avant de quitter.
  void _requestSection(_Section s) {
    if (_showImmeubleForm || _showChambreForm) {
      _askLeaveFormRun(() => _changeSection(s));
      return;
    }
    _changeSection(s);
  }

  /// Ouvre la section Gestion sur le sous-onglet [i] (Mes Propriétés / Mes
  /// Chambres / Inventaire) — pilotée par le sous-menu de la sidebar.
  void _openGestionTab(int i) {
    void go() {
      _changeSection(_Section.gestion);
      _gestionTabCtrl.index = i;
      if (mounted) setState(() {});
    }

    if (_showImmeubleForm || _showChambreForm) {
      _askLeaveFormRun(go);
    } else {
      go();
    }
  }

  /// Ouvre une section à sous-menus sur le sous-onglet demandé (Finances,
  /// Documentation, Interactions), en appliquant [apply] (maj du sous-index).
  void _openSub(_Section s, VoidCallback apply) {
    void go() {
      _changeSection(s);
      apply();
      if (mounted) setState(() {});
    }

    if (_showImmeubleForm || _showChambreForm) {
      _askLeaveFormRun(go);
    } else {
      go();
    }
  }

  Future<void> _askLeaveFormRun(VoidCallback run) async {
    final choice = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    if (choice != UnsavedChoice.cancel) run();
  }

  void _changeSection(_Section s) {
    setState(() {
      _section = s;
      _showEntrepriseConfig = false;
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
  }

  void _openImmeubleCreation({bool tour = false}) => setState(() {
    _editingImmeuble = null;
    _tourImmeuble = tour;
    _showImmeubleForm = true;
    _showImmeubleDetail = false;
    _showChambreForm = false;
    _showFactureForm = false;
  });

  /// Demande à l'utilisateur s'il veut le tour guidé pour créer un immeuble,
  /// puis ouvre le formulaire en conséquence (déclenché par le bouton « ? »).
  Future<void> _askImmeubleTour() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.school_outlined, color: AppColors.primary, size: 34),
        title: const Text('Tour guidé'),
        content: const Text(
          "Souhaitez-vous être guidé pas à pas pour créer un immeuble ?\n\n"
          "À la fin, vous pourrez conserver l'immeuble créé ou le supprimer.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non merci')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, me guider')),
        ],
      ),
    );
    _openImmeubleCreation(tour: ok == true);
  }

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

  // Crée une chambre depuis le détail d'un immeuble : l'immeuble est
  // pré-rempli et on revient au détail après enregistrement/annulation.
  void _openChambreCreationFromDetail(int immeubleId) => setState(() {
    _editingChambre = null;
    _chambrePrefilledImmeubleId = immeubleId;
    _chambreFromDetail = true;
    _showChambreForm = true;
    _showImmeubleForm = false;
    _showFactureForm = false;
  });

  // Supprime une chambre depuis la fiche immeuble (après confirmation) puis
  // recharge la liste. Comme `immeuble_id` est NOT NULL, retirer la chambre de
  // l'immeuble revient à la supprimer du système.
  Future<void> _deleteChambreFromDetail(ChambreModel c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la chambre'),
        content: Text(
          'La chambre « ${c.roomName} » sera supprimée définitivement '
          '(avec son inventaire). Cette action est irréversible.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.deleteButtonStyle,
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ChambresDatasource.delete(c.id);
      final imm = _detailImmeuble;
      final chambres = imm == null
          ? <ChambreModel>[]
          : await ChambresDatasource.listByImmeubles([imm.id]);
      if (!mounted) return;
      setState(() => _detailChambres = chambres);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  // Recharge les chambres du détail puis revient à la fiche immeuble.
  Future<void> _returnToDetailReloadChambres() async {
    final imm = _detailImmeuble;
    if (imm == null) {
      _closeForm();
      return;
    }
    List<ChambreModel> chambres = _detailChambres;
    try {
      chambres = await ChambresDatasource.listByImmeubles([imm.id]);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _detailChambres = chambres;
      _showChambreForm = false;
      _editingChambre = null;
      _chambrePrefilledImmeubleId = null;
      _chambreFromDetail = false;
    });
  }

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
    _tourImmeuble = false;
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
    _tourImmeuble = false;
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
        startTour: _tourImmeuble,
        onSaved: _closeForm,
        onBack: _closeImmeubleForm,
      );
    }
    if (_showChambreForm) {
      // Si la chambre est créée depuis le détail d'immeuble, on y revient
      // (en rechargeant les chambres) au lieu de fermer toute la vue.
      return CreerChambrePage(
        chambre: _editingChambre,
        prefilledImmeubleId: _chambreFromDetail
            ? _chambrePrefilledImmeubleId
            : null,
        onSaved:
            _chambreFromDetail ? _returnToDetailReloadChambres : _closeForm,
        onBack:
            _chambreFromDetail ? _returnToDetailReloadChambres : _closeChambreForm,
      );
    }
    if (_showEntrepriseConfig && _profile?.entrepriseId != null) {
      return EntrepriseConfigPage(entrepriseId: _profile!.entrepriseId!);
    }
    if (_showImmeubleDetail && _detailImmeuble != null) {
      return ImmeubleDetailPage(
        immeuble: _detailImmeuble!,
        chambres: _detailChambres,
        onModifierImmeuble: () => _openImmeubleEdition(_detailImmeuble!),
        onModifierChambre: _openChambreEdition,
        onAjouterChambre: () =>
            _openChambreCreationFromDetail(_detailImmeuble!.id),
        onSupprimerChambre: _deleteChambreFromDetail,
        onAjouterFacture: () =>
            _openFactureCreation(immeubleId: _detailImmeuble!.id),
        onBack: _closeImmeubleDetail,
      );
    }
    if (_section == _Section.vueGenerale) {
      return VueGeneralePage(
        onCompleterProfil: () => _changeSection(_Section.monProfil),
        onCreerImmeuble: () => _openImmeubleCreation(),
        onGererChambres: () => _changeSection(_Section.gestion),
        onAllerEtatsDesLieux: () => _changeSection(_Section.etatDesLieux),
      );
    }
    if (_section == _Section.monProfil) return const MonProfilProprietairePage();
    if (_section == _Section.finances) {
      return FacturesListPage(
        key: ValueKey('fin$_finSub'),
        initialTab: _finSub,
        showTabBar: false,
        onAjouter: _openFactureCreation,
        onOuvrir: _openFacture,
        onAjouterRecette: _openRecetteCreation,
      );
    }
    if (_section == _Section.agenda) return const AgendaPage();
    if (_section == _Section.fournisseurs) return const FournisseursPage();
    if (_section == _Section.etatDesLieux) {
      return EtatDesLieuxPage(
        key: ValueKey('edl$_edlSub'),
        initialTab: _edlSub,
        showTabBar: false,
      );
    }
    if (_section == _Section.documentation) {
      return DocumentationPage(
        key: ValueKey('doc$_docSub'),
        initialTab: _docSub,
        showTabBar: false,
      );
    }
    if (_section == _Section.interactions) {
      return InteractionsPage(
        key: ValueKey('inter$_interSub'),
        initialTab: _interSub,
        showTabBar: false,
      );
    }

    // Section Gestion Immobilière — les onglets sont devenus des sous-menus de
    // la sidebar (Mes Propriétés / Mes Chambres / Inventaire). On garde le
    // TabController pour l'affichage (TabBarView sans TabBar).
    return TabBarView(
      controller: _gestionTabCtrl,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        MesImmeublesPage(
          onAjouter: _openImmeubleCreation,
          onModifier: _openImmeubleEdition,
          onVoirDetail: _openImmeubleDetail,
          onTourGuide: _askImmeubleTour,
        ),
        MesChambresPage(
          onModifier: _openChambreEdition,
          onCreerChambre: _openChambreCreation,
        ),
        const InventairePage(),
        const LotsPage(),
      ],
    );
  }

  // ── Sidebar ────────────────────────────────────────────────────────────────

  List<NavEntry> _buildNavEntries(bool isNarrow) {
    void go(_Section s) {
      if (isNarrow) Navigator.of(context).pop();
      _requestSection(s);
    }

    void goGestionTab(int i) {
      if (isNarrow) Navigator.of(context).pop();
      _openGestionTab(i);
    }

    final inGestion = _section == _Section.gestion &&
        !_showImmeubleDetail &&
        !_showImmeubleForm &&
        !_showChambreForm;

    void goSub(_Section s, void Function() apply) {
      if (isNarrow) Navigator.of(context).pop();
      _openSub(s, apply);
    }

    return [
      NavEntry(
        icon: Icons.dashboard_outlined,
        label: 'Vue générale',
        selected: _section == _Section.vueGenerale,
        onTap: () => go(_Section.vueGenerale),
      ),
      NavEntry(
        icon: Icons.home_work_outlined,
        label: 'Gestion Immobilière',
        selected: _section == _Section.gestion,
        onTap: () => go(_Section.gestion),
        children: [
          NavChild(
            label: 'Mes Propriétés',
            selected: inGestion && _gestionTabCtrl.index == 0,
            onTap: () => goGestionTab(0),
          ),
          NavChild(
            label: 'Mes Chambres',
            selected: inGestion && _gestionTabCtrl.index == 1,
            onTap: () => goGestionTab(1),
          ),
          NavChild(
            label: 'Inventaire',
            selected: inGestion && _gestionTabCtrl.index == 2,
            onTap: () => goGestionTab(2),
          ),
          NavChild(
            label: 'Lots',
            selected: inGestion && _gestionTabCtrl.index == 3,
            onTap: () => goGestionTab(3),
          ),
        ],
      ),
      NavEntry(
        icon: Icons.calendar_month_outlined,
        label: 'Agenda',
        selected: _section == _Section.agenda,
        onTap: () => go(_Section.agenda),
      ),
      NavEntry(
        icon: Icons.store_outlined,
        label: 'Fournisseurs',
        selected: _section == _Section.fournisseurs,
        onTap: () => go(_Section.fournisseurs),
      ),
      NavEntry(
        icon: Icons.assignment_outlined,
        label: 'État des lieux',
        selected: _section == _Section.etatDesLieux,
        onTap: () => go(_Section.etatDesLieux),
        children: [
          NavChild(
            label: 'Vision générale',
            selected: _section == _Section.etatDesLieux && _edlSub == 0,
            onTap: () => goSub(_Section.etatDesLieux, () => _edlSub = 0),
          ),
          NavChild(
            label: 'Entrée',
            selected: _section == _Section.etatDesLieux && _edlSub == 1,
            onTap: () => goSub(_Section.etatDesLieux, () => _edlSub = 1),
          ),
          NavChild(
            label: 'Sortie',
            selected: _section == _Section.etatDesLieux && _edlSub == 2,
            onTap: () => goSub(_Section.etatDesLieux, () => _edlSub = 2),
          ),
          NavChild(
            label: 'Vétusté',
            selected: _section == _Section.etatDesLieux && _edlSub == 3,
            onTap: () => goSub(_Section.etatDesLieux, () => _edlSub = 3),
          ),
        ],
      ),
      NavEntry(
        icon: Icons.receipt_long_outlined,
        label: 'Finances',
        selected: _section == _Section.finances,
        onTap: () => go(_Section.finances),
        children: [
          NavChild(
            label: 'Vue générale',
            selected: _section == _Section.finances && _finSub == 0,
            onTap: () => goSub(_Section.finances, () => _finSub = 0),
          ),
          NavChild(
            label: 'Recettes',
            selected: _section == _Section.finances && _finSub == 1,
            onTap: () => goSub(_Section.finances, () => _finSub = 1),
          ),
          NavChild(
            label: 'Dépenses / Factures',
            selected: _section == _Section.finances && _finSub == 2,
            onTap: () => goSub(_Section.finances, () => _finSub = 2),
          ),
        ],
      ),
      NavEntry(
        icon: Icons.menu_book_outlined,
        label: 'Documentation',
        selected: _section == _Section.documentation,
        onTap: () => go(_Section.documentation),
        children: [
          NavChild(
            label: 'Vue générale',
            selected: _section == _Section.documentation && _docSub == 0,
            onTap: () => goSub(_Section.documentation, () => _docSub = 0),
          ),
          NavChild(
            label: 'Baux',
            selected: _section == _Section.documentation && _docSub == 1,
            onTap: () => goSub(_Section.documentation, () => _docSub = 1),
          ),
          NavChild(
            label: 'Ma signature',
            selected: _section == _Section.documentation && _docSub == 2,
            onTap: () => goSub(_Section.documentation, () => _docSub = 2),
          ),
        ],
      ),
      NavEntry(
        icon: Icons.people_alt_outlined,
        label: 'Interactions',
        count: _interactionsBadge,
        selected: _section == _Section.interactions,
        onTap: () => go(_Section.interactions),
        children: [
          NavChild(
            label: 'Demandes de contact',
            selected: _section == _Section.interactions && _interSub == 0,
            onTap: () => goSub(_Section.interactions, () => _interSub = 0),
          ),
          NavChild(
            label: 'Notifications',
            selected: _section == _Section.interactions && _interSub == 1,
            count: _interactionsBadge,
            onTap: () => goSub(_Section.interactions, () => _interSub = 1),
          ),
        ],
      ),
      NavEntry(
        icon: Icons.person_outline,
        label: 'Mon Profil',
        selected: _section == _Section.monProfil,
        onTap: () => go(_Section.monProfil),
      ),
    ];
  }

  Widget _buildSidebar({required bool isNarrow}) {
    return AppNavSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      userTypeLabel: _profile?.typeDisplayLabel,
      searchController: _searchCtrl,
      entries: _buildNavEntries(isNarrow),
      footerBuilder: (ctx, extended) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Admin de groupe : accès à la configuration de son entreprise.
          if (_profile?.resolvedType == UserType.adminGroupe &&
              _profile?.entrepriseId != null)
            SidebarActionButton(
              extended: extended,
              icon: Icons.business_outlined,
              label: 'Configuration entreprise',
              onTap: () {
                if (isNarrow) Navigator.of(ctx).pop();
                setState(() {
                  _showEntrepriseConfig = true;
                  _showImmeubleForm = false;
                  _showImmeubleDetail = false;
                  _showChambreForm = false;
                  _showFactureForm = false;
                });
              },
            ),
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
    // KeyedSubtree + GlobalKey stable : quand on passe drawer ↔ sidebar (resize),
    // le contenu (et son State, ex. un EDL en cours d'édition) est déplacé sans
    // être détruit → l'EDL ouvert n'est plus fermé sans prévenir.
    final content = KeyedSubtree(key: _contentKey, child: _buildContent());

    if (isNarrow) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: sidebar,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Ouvrir le menu',
            onPressed: () {
              if (!_navCtrl.extended) _navCtrl.setExtended(true);
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          title: const Text('Super Loc'),
        ),
        body: content,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          Expanded(child: content),
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
        // Header (titre + Enregistrer/Fermer) rendu par NouvelleFacturePage.
        Expanded(
          child: NouvelleFacturePage(
            prefilledImmeubleId: prefilledImmeubleId,
            prefilledImmeubleName: prefilledImmeubleName,
            onSaved: onSaved,
            onClose: onBack,
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
