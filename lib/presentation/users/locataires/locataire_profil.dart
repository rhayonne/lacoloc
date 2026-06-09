import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/cache/realtime_refresh_mixin.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_card.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/etat_de_lieux_page.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_detail_page.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/presentation/widgets/filter_panel.dart';
import 'package:lacoloc_front/utils/phone_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class LocataireProfilPage extends StatefulWidget {
  const LocataireProfilPage({super.key});

  @override
  State<LocataireProfilPage> createState() => _LocataireProfilPageState();
}

class _LocataireProfilPageState extends State<LocataireProfilPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SidebarXController _navCtrl;
  late Future<_LocBundle> _bundleFuture;
  int? _selectedChambreId;

  static const _idxDashboard = 0;
  static const _idxChambres = 1;
  static const _idxProfil = 2;
  static const _idxInteractions = 3;

  @override
  void initState() {
    super.initState();
    _navCtrl = SidebarXController(selectedIndex: _idxDashboard, extended: true);
    _navCtrl.addListener(_onNavChanged);
    _bundleFuture = _loadBundle();
  }

  @override
  void dispose() {
    _navCtrl.removeListener(_onNavChanged);
    _navCtrl.dispose();
    super.dispose();
  }

  Future<_LocBundle> _loadBundle() async {
    final results = await Future.wait([
      ChambresDatasource.listAll(),
      AuthService.loadCurrentProfile(),
    ]);
    final all = results[0] as List<ChambreModel>;
    final profile = results[1] as UsersClient?;
    final available = all.where((c) => !c.estLoue && c.isActive).toList();
    return _LocBundle(available: available, total: all.length, profile: profile);
  }

  void _onNavChanged() {
    if (!mounted) return;
    setState(() => _selectedChambreId = null);
  }

  Future<void> _doLogout() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  void _goToChambres() => _navCtrl.selectIndex(_idxChambres);

  Widget _buildSidebar({required bool isNarrow}) {
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      items: const [
        SidebarXItem(icon: Icons.dashboard_outlined, label: 'Tableau de bord'),
        SidebarXItem(icon: Icons.search_outlined, label: 'Chambres disponibles'),
        SidebarXItem(icon: Icons.person_outline, label: 'Mon Profil'),
        SidebarXItem(
          icon: Icons.assignment_outlined,
          label: 'État des lieux',
        ),
      ],
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

  void _openChambre(int id) => setState(() => _selectedChambreId = id);
  void _closeChambre() => setState(() => _selectedChambreId = null);

  Widget _buildBody() {
    if (_selectedChambreId != null) {
      return ChambreDetailView(
        chambreId: _selectedChambreId!,
        onBack: _closeChambre,
      );
    }

    return FutureBuilder<_LocBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final bundle = snapshot.data!;
        return switch (_navCtrl.selectedIndex) {
          _idxDashboard => _DashboardSection(
              bundle: bundle,
              onVoirChambres: _goToChambres,
              onTapChambre: _openChambre,
            ),
          _idxChambres => _ChambresSection(
              chambres: bundle.available,
              onTap: _openChambre,
            ),
          _idxProfil => _ProfilSection(profile: bundle.profile),
          _idxInteractions => const _InteractionsSection(),
          _ => const SizedBox.shrink(),
        };
      },
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
        body: body,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LocBundle {
  final List<ChambreModel> available;
  final int total;
  final UsersClient? profile;

  _LocBundle({
    required this.available,
    required this.total,
    required this.profile,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class _DashboardSection extends StatelessWidget {
  final _LocBundle bundle;
  final VoidCallback onVoirChambres;
  final void Function(int id) onTapChambre;

  const _DashboardSection({
    required this.bundle,
    required this.onVoirChambres,
    required this.onTapChambre,
  });

  @override
  Widget build(BuildContext context) {
    final profile = bundle.profile;
    final rawName = profile?.fullName?.trim() ?? '';
    final firstName = rawName.isNotEmpty ? rawName.split(' ').first : '';
    final greeting =
        firstName.isNotEmpty ? 'Bonjour, $firstName !' : 'Bienvenue !';
    final count = bundle.available.length;
    final featured = bundle.available.take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Carte de bienvenue ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: AppRadius.borderLg,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: AppTypography.headlineMd.copyWith(
                              color: AppColors.onPrimaryFixedVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            count == 0
                                ? 'Aucune chambre disponible pour le moment.'
                                : '$count chambre${count > 1 ? 's' : ''} '
                                    'disponible${count > 1 ? 's' : ''} en ce moment.',
                            style: AppTypography.bodyMd.copyWith(
                              color: AppColors.onPrimaryFixedVariant
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton.icon(
                            onPressed: onVoirChambres,
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('Rechercher une chambre'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    const Icon(
                      Icons.bed_outlined,
                      size: 72,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Chambres en vedette ─────────────────────────────────────
              if (featured.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.bed_outlined,
                          size: 56,
                          color: AppColors.outline,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Revenez bientôt —',
                          style: AppTypography.titleLg.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'de nouvelles chambres seront publiées prochainement.',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dernières chambres disponibles',
                        style: AppTypography.titleLg,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onVoirChambres,
                      label: const Text('Voir toutes'),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      iconAlignment: IconAlignment.end,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth > 700 ? 3 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: featured.length,
                      itemBuilder: (context, i) => ChambreCard(
                        chambre: featured[i],
                        onTap: () => onTapChambre(featured[i].id),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChambresSection extends StatefulWidget {
  final List<ChambreModel> chambres;
  final void Function(int id) onTap;

  const _ChambresSection({required this.chambres, required this.onTap});

  @override
  State<_ChambresSection> createState() => _ChambresSectionState();
}

class _ChambresSectionState extends State<_ChambresSection> {
  String _query = '';
  ChambreFilter _filter = ChambreFilter.empty;

  List<ChambreModel> get _filtered {
    return widget.chambres.where((c) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final inName = c.roomName.toLowerCase().contains(q);
        final inImm = c.immeubleName?.toLowerCase().contains(q) ?? false;
        final inAddr = c.immeubleAddress?.toLowerCase().contains(q) ?? false;
        final inCity = c.immeubleCity?.toLowerCase().contains(q) ?? false;
        if (!inName && !inImm && !inAddr && !inCity) return false;
      }
      final f = _filter;
      if (f.optionIds.isNotEmpty &&
          !f.optionIds.every((id) => c.selectedOptionIds.contains(id))) {
        return false;
      }
      if (f.city.isNotEmpty &&
          !(c.immeubleCity?.toLowerCase().contains(f.city.toLowerCase()) ??
              false)) {
        return false;
      }
      if (f.region.isNotEmpty &&
          !(c.immeubleRegion?.toLowerCase().contains(f.region.toLowerCase()) ??
              false)) {
        return false;
      }
      if (f.department.isNotEmpty &&
          !(c.immeubleDepartment
                  ?.toLowerCase()
                  .contains(f.department.toLowerCase()) ??
              false)) {
        return false;
      }
      if (f.bailType == BailTypeFilter.collectif && !c.immeubleBailCollectif) {
        return false;
      }
      if (f.bailType == BailTypeFilter.individuel && !c.immeubleBailIndividuel) {
        return false;
      }
      if (f.m2Min != null && (c.m2 == null || c.m2! < f.m2Min!)) {
        return false;
      }
      if (f.m2Max != null && (c.m2 == null || c.m2! > f.m2Max!)) {
        return false;
      }
      if (f.prixMin != null &&
          (c.prixLoyer == null || c.prixLoyer! < f.prixMin!)) {
        return false;
      }
      if (f.prixMax != null &&
          (c.prixLoyer == null || c.prixLoyer! > f.prixMax!)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chambres disponibles', style: AppTypography.headlineMd),
              const SizedBox(height: AppSpacing.md),

              // Barre de recherche
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppRadius.borderFull,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une chambre, immeuble, ville…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: AppSpacing.md,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _query = ''),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              FilterPanel(
                filter: _filter,
                onChanged: (f) => setState(() => _filter = f),
                modules: const {
                  FilterModule.localisation,
                  FilterModule.bail,
                  FilterModule.meuble,
                  FilterModule.typeImmeuble,
                  FilterModule.surface,
                  FilterModule.prix,
                  FilterModule.equipements,
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                filtered.isEmpty
                    ? 'Aucune chambre ne correspond à la recherche.'
                    : '${filtered.length} chambre${filtered.length > 1 ? 's' : ''} '
                        'disponible${filtered.length > 1 ? 's' : ''}',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (widget.chambres.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      const Icon(
                        Icons.bed_outlined,
                        size: 64,
                        color: AppColors.outline,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Revenez bientôt — de nouvelles chambres\nseront disponibles prochainement.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: Text(
                      'Aucun résultat pour « $_query »',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth > 700 ? 3 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => ChambreCard(
                        chambre: filtered[i],
                        onTap: () => widget.onTap(filtered[i].id),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProfilSection extends StatefulWidget {
  final UsersClient? profile;

  const _ProfilSection({required this.profile});

  @override
  State<_ProfilSection> createState() => _ProfilSectionState();
}

class _ProfilSectionState extends State<_ProfilSection> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  late Future<bool> _hasContratsFuture;

  late final TextEditingController _nameCtrl;

  // Valores exibidos (confirmados após salvar)
  late String _displayName;
  late String _displayPhone;
  DateTime? _displayDob;

  GlobalKey<FormBuilderState> _phoneFormKey = GlobalKey<FormBuilderState>();

  // Valores temporários durante edição
  DateTime? _editDob;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  static int _computeAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  void initState() {
    super.initState();
    _displayName = widget.profile?.fullName ?? '';
    _displayPhone = widget.profile?.phone ?? '';
    _displayDob = widget.profile?.dateOfBirth;
    _nameCtrl = TextEditingController(text: _displayName);
    _hasContratsFuture = EtatDesLieuxDatasource.hasContratsLocataire(
      AuthService.currentUser?.id ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) {
      _nameCtrl.text = _displayName;
      setState(() {
        _editDob = _displayDob;
        _isEditing = false;
        _phoneFormKey = GlobalKey<FormBuilderState>();
      });
    } else {
      setState(() {
        _editDob = _displayDob;
        _isEditing = true;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _editDob ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 16, now.month, now.day),
      locale: const Locale('fr'),
    );
    if (picked != null && mounted) {
      setState(() => _editDob = picked);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: const Text(
          'Cette action est irréversible. Toutes vos données personnelles '
          'seront définitivement supprimées.\n\n'
          'Êtes-vous sûr de vouloir continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: AppTheme.deleteButtonStyle,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await AuthService.deleteAccount();
      if (!mounted) return;
      await AuthService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _save() async {
    final newName = _nameCtrl.text.trim();
    final newPhone =
        PhoneField.fullNumberFromState(_phoneFormKey.currentState, 'phone') ??
        '';
    final newDob = _editDob;
    setState(() => _isSaving = true);
    try {
      await AuthService.updateProfile(
        fullName: newName,
        phone: newPhone.isEmpty ? null : newPhone,
        age: newDob != null ? _computeAge(newDob) : null,
        dateOfBirth: newDob,
      );
      if (!mounted) return;
      setState(() {
        _displayName = newName;
        _displayPhone = newPhone;
        _displayDob = newDob;
        _isEditing = false;
        _isSaving = false;
        _phoneFormKey = GlobalKey<FormBuilderState>();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        widget.profile?.email ?? AuthService.currentUser?.email ?? '';
    final createdAt = widget.profile?.createdAt;
    final initial = (_displayName.isNotEmpty ? _displayName : email)
        .substring(0, 1)
        .toUpperCase();
    final currentDob = _isEditing ? _editDob : _displayDob;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Barre de titre ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(color: AppColors.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Mon Profil', style: AppTypography.titleLg),
              ),
              IconButton(
                icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
                tooltip: _isEditing ? 'Annuler' : 'Modifier',
                color: _isEditing ? AppColors.error : null,
                onPressed: _toggleEdit,
              ),
              IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.save_outlined,
                        color: _isEditing
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant
                                .withValues(alpha: 0.35),
                      ),
                tooltip: 'Sauvegarder',
                onPressed: _isEditing && !_isSaving ? _save : null,
              ),
            ],
          ),
        ),

        // ── Corps ────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.primaryFixed,
                            child: Text(
                              initial,
                              style: AppTypography.headlineMd.copyWith(
                                color: AppColors.onPrimaryFixedVariant,
                              ),
                            ),
                          ),
                          if (_isEditing)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surfaceContainerLowest,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Nom complet ──────────────────────────────────────
                    _fieldLabel('NOM COMPLET'),
                    TextField(
                      controller: _nameCtrl,
                      enabled: _isEditing,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(hintText: 'Jean Dupont'),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── E-mail ───────────────────────────────────────────
                    _fieldLabel('E-MAIL'),
                    _staticField(email),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Téléphone ────────────────────────────────────────
                    _fieldLabel('TÉLÉPHONE'),
                    if (_isEditing)
                      FormBuilder(
                        key: _phoneFormKey,
                        child: PhoneField(
                          name: 'phone',
                          initialValue: _displayPhone,
                        ),
                      )
                    else
                      _staticField(
                        _displayPhone.isEmpty ? '—' : _displayPhone,
                      ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Date de naissance ────────────────────────────────
                    _fieldLabel('DATE DE NAISSANCE'),
                    InkWell(
                      onTap: _isEditing ? _pickDate : null,
                      borderRadius: AppRadius.borderSm,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _isEditing
                              ? AppColors.surfaceContainerLowest
                              : AppColors.surfaceContainerLow,
                          borderRadius: AppRadius.borderSm,
                          border: Border.all(
                            color: _isEditing
                                ? AppColors.primary
                                : AppColors.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentDob != null
                                    ? _dateFmt.format(currentDob)
                                    : _isEditing
                                        ? 'Sélectionner une date'
                                        : 'Non renseignée',
                                style: AppTypography.bodyMd.copyWith(
                                  color: currentDob == null
                                      ? AppColors.onSurfaceVariant
                                          .withValues(alpha: 0.5)
                                      : null,
                                ),
                              ),
                            ),
                            if (_isEditing)
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (currentDob != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Âge : ${_computeAge(currentDob)} ans',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),

                    // ── Type de compte ───────────────────────────────────
                    _fieldLabel('TYPE DE COMPTE'),
                    _staticField('Locataire'),

                    // ── Membre depuis ────────────────────────────────────
                    if (createdAt != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _fieldLabel('MEMBRE DEPUIS'),
                      _staticField(_dateFmt.format(createdAt)),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Info ─────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              "Pour modifier votre adresse e-mail ou votre "
                              "mot de passe, contactez l'administrateur de "
                              "la plateforme.",
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Zone dangereuse ───────────────────────────────────
                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),
                    _DangerZoneSection(
                      hasContratsFuture: _hasContratsFuture,
                      isDeleting: _isDeleting,
                      onDelete: _confirmDelete,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          text,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _staticField(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(value, style: AppTypography.bodyMd),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section État des lieux (onglet du locataire)

class _InteractionsSection extends StatefulWidget {
  const _InteractionsSection();

  @override
  State<_InteractionsSection> createState() => _InteractionsSectionState();
}

class _InteractionsSectionState extends State<_InteractionsSection>
    with SingleTickerProviderStateMixin, RealtimeRefreshMixin {
  late final TabController _tabCtrl;
  late Future<List<EtatDesLieuxModel>> _future;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _future = _load();
  }

  @override
  Set<String> get watchedEntities => {'edl'};

  @override
  void onRealtimeChange() {
    final f = _load();
    setState(() => _future = f);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<List<EtatDesLieuxModel>> _load() {
    final uid = AuthService.currentUser?.id ?? '';
    // Inclui EDLs privatifs (locataire_id) + collectifs onde é preneur.
    return EtatDesLieuxDatasource.listForLocataire(uid);
  }

  Future<void> _accepter(int edlId) async {
    await EtatDesLieuxDatasource.locataireAccepter(edlId);
    if (mounted) setState(() { _future = _load(); });
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('État des lieux', style: AppTypography.headlineMd),
              const SizedBox(height: AppSpacing.lg),
              TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'Vision générale'),
                  Tab(text: 'Entrée'),
                  Tab(text: 'Sortie'),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<EtatDesLieuxModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erreur : ${snapshot.error}'));
              }
              final all = snapshot.data ?? [];
              final pending = all
                  .where(
                    (e) =>
                        e.situation == SituationEdl.finalise &&
                        !e.locataireAccepte,
                  )
                  .toList();
              final entrees =
                  all.where((e) => e.typeEdl == 'entree').toList();
              final sorties =
                  all.where((e) => e.typeEdl == 'sortie').toList();

              Future<void> voirDetail(EtatDesLieuxModel edl) async {
                // EDL collectif (parties communes) → écran observations où le
                // locataire ajoute/édite SES propres observations.
                if (edl.partie == PartieEdl.commune) {
                  final imm =
                      await ImmeublesDatasource.byId(edl.immeubleId);
                  if (!context.mounted || imm == null) return;
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: SafeArea(
                        child: EdlCollectifNonMeubleePage(
                          immeuble: imm,
                          typeEdl: edl.typeEdl,
                          existingEdl: edl,
                          isLocataire: true,
                          meublee: imm.locationMeuble == true,
                          onClose: (_) => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ));
                  if (mounted) setState(() { _future = _load(); });
                  return;
                }
                // EDL privatif individuel + meublée → écran chambre (le
                // locataire ajoute/édite SES observations ; inventaire en lecture).
                if (edl.partie == PartieEdl.privative &&
                    edl.typeBail == 'individuel' &&
                    edl.chambreId != null) {
                  final imm = await ImmeublesDatasource.byId(edl.immeubleId);
                  ChambreModel? chambre;
                  try {
                    final chambres = await ChambresDatasource.listByImmeubles(
                        [edl.immeubleId]);
                    chambre = chambres
                        .where((c) => c.id == edl.chambreId)
                        .firstOrNull;
                  } catch (_) {}
                  if (!context.mounted || imm == null || chambre == null) {
                    return;
                  }
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: SafeArea(
                        child: EdlIndividuelMeubleePage(
                          immeuble: imm,
                          chambre: chambre!,
                          typeEdl: edl.typeEdl,
                          existingEdl: edl,
                          isLocataire: true,
                          meublee: imm.locationMeuble == true,
                          onClose: (_) => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ));
                  if (mounted) setState(() { _future = _load(); });
                  return;
                }
                // EDL privatif (single-room / legado) → vue détaillée existante.
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => _EdlDetailPage(
                    edl: edl,
                    onAccepter: () => _accepter(edl.id),
                  ),
                ));
              }

              return TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _EdlVisionGeneraleTab(
                    all: all,
                    pending: pending,
                    onAccepter: _accepter,
                    onVoir: voirDetail,
                  ),
                  _EdlListTab(
                    edls: entrees,
                    emptyMessage: "Aucun état des lieux d'entrée.",
                    onVoir: voirDetail,
                  ),
                  _EdlListTab(
                    edls: sorties,
                    emptyMessage: 'Aucun état des lieux de sortie.',
                    onVoir: voirDetail,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EdlVisionGeneraleTab extends StatelessWidget {
  final List<EtatDesLieuxModel> all;
  final List<EtatDesLieuxModel> pending;
  final Future<void> Function(int) onAccepter;
  final void Function(EtatDesLieuxModel) onVoir;

  const _EdlVisionGeneraleTab({
    required this.all,
    required this.pending,
    required this.onAccepter,
    required this.onVoir,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Important',
                  style: AppTypography.titleLg.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...pending.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _PendingEdlCard(
                  edl: e,
                  onAccepter: () => onAccepter(e.id),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
          ],
          Text('Tous les états des lieux', style: AppTypography.titleLg),
          const SizedBox(height: AppSpacing.md),
          if (all.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 56,
                      color: AppColors.outline,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Aucun état des lieux enregistré.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _EdlLocataireTable(edls: all, onVoir: onVoir),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EdlListTab extends StatelessWidget {
  final List<EtatDesLieuxModel> edls;
  final String emptyMessage;
  final void Function(EtatDesLieuxModel) onVoir;

  const _EdlListTab({
    required this.edls,
    required this.emptyMessage,
    required this.onVoir,
  });

  @override
  Widget build(BuildContext context) {
    if (edls.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 56,
              color: AppColors.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              emptyMessage,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: _EdlLocataireTable(edls: edls, onVoir: onVoir),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EdlLocataireTable extends StatelessWidget {
  final List<EtatDesLieuxModel> edls;
  final void Function(EtatDesLieuxModel) onVoir;

  const _EdlLocataireTable({required this.edls, required this.onVoir});

  static final _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in edls) ...[
                _EdlLocataireCard(edl: e, onVoir: () => onVoir(e)),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }
        return _buildTable();
      },
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(AppColors.surfaceContainerLow),
        columns: const [
          DataColumn(label: Text('Propriétaire')),
          DataColumn(label: Text('Immeuble / Chambre')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Situation')),
          DataColumn(label: Text('Date état')),
          DataColumn(label: Text('Finalisation')),
          DataColumn(label: Text('')),
        ],
        rows: edls
            .map(
              (e) => DataRow(
                cells: [
                  DataCell(Text(e.proprietaireNom ?? '—')),
                  DataCell(Text(e.lieuLabel)),
                  DataCell(
                    Text(e.typeEdl == 'entree' ? 'Entrée' : 'Sortie'),
                  ),
                  DataCell(_EdlSituationBadge(situation: e.situation)),
                  DataCell(Text(_fmt.format(e.dateEtatLieux))),
                  DataCell(
                    Text(
                      e.dateFinalisation != null
                          ? _fmt.format(e.dateFinalisation!)
                          : '—',
                    ),
                  ),
                  DataCell(
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Voir'),
                      onPressed: () => onVoir(e),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EdlLocataireCard extends StatelessWidget {
  final EtatDesLieuxModel edl;
  final VoidCallback onVoir;

  const _EdlLocataireCard({required this.edl, required this.onVoir});

  static final _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final nom = edl.proprietaireNom ?? '—';
    final initial = nom.isNotEmpty ? nom.substring(0, 1).toUpperCase() : '?';
    final typeBailLabel =
        edl.typeBail == 'collectif' ? 'Colocation' : 'Individuel';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onPrimaryFixedVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      edl.typeEdl == 'entree' ? 'Entrée' : 'Sortie',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            edl.immeubleNom ?? edl.lieuLabel,
            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (edl.chambreNom != null)
            Text(
              '${edl.chambreNom} · $typeBailLabel',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              typeBailLabel,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ÉTAT',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fmt.format(edl.dateEtatLieux),
                      style: AppTypography.bodyMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINALISATION',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      edl.dateFinalisation != null
                          ? _fmt.format(edl.dateFinalisation!)
                          : '—',
                      style: AppTypography.bodyMd.copyWith(
                        color: edl.dateFinalisation == null
                            ? AppColors.onSurfaceVariant
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SITUATION',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _EdlSituationBadge(situation: edl.situation),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onVoir,
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Continuer'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PendingEdlCard extends StatefulWidget {
  final EtatDesLieuxModel edl;
  final Future<void> Function() onAccepter;

  const _PendingEdlCard({required this.edl, required this.onAccepter});

  @override
  State<_PendingEdlCard> createState() => _PendingEdlCardState();
}

class _PendingEdlCardState extends State<_PendingEdlCard> {
  bool _accepting = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await widget.onAccepter();
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  static final _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final edl = widget.edl;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.18),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'État des lieux finalisé par '
                  '${edl.proprietaireNom ?? 'votre propriétaire'}',
                  style: AppTypography.titleLg,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _row('Lieu', edl.lieuLabel),
          if (edl.immeubleAdresse != null)
            _row('Adresse', edl.immeubleAdresse!),
          _row('Date', _fmt.format(edl.dateEtatLieux)),
          if (edl.montant != null)
            _row('Montant', '€ ${edl.montant!.toStringAsFixed(2)}'),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _accepting ? null : _accept,
              child: _accepting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Accepter et signer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: AppTypography.bodyMd)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page de détail d'un état des lieux (lecture seule, toutes les étapes)

class _EdlDetailPage extends StatefulWidget {
  final EtatDesLieuxModel edl;
  final Future<void> Function() onAccepter;

  const _EdlDetailPage({
    required this.edl,
    required this.onAccepter,
  });

  @override
  State<_EdlDetailPage> createState() => _EdlDetailPageState();
}

class _EdlDetailPageState extends State<_EdlDetailPage> {
  bool _accepting = false;
  static final _fmt = DateFormat('dd/MM/yyyy');

  static const _wallLabels = {
    'fond': 'Mur du fond',
    'gauche': 'Mur gauche',
    'droit': 'Mur droit',
    'porte': "Mur d'entrée / Porte",
  };

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await widget.onAccepter();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _accepting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: AppTypography.labelSm.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _infoCard(List<Widget> rows) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: AppRadius.borderMd,
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(
            label,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: AppTypography.bodyMd)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final edl = widget.edl;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          edl.typeEdl == 'entree'
              ? "État des lieux d'entrée"
              : 'État des lieux de sortie',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Carte statut ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              edl.typeEdl == 'entree'
                                  ? "État des lieux d'entrée"
                                  : 'État des lieux de sortie',
                              style: AppTypography.titleLg,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              edl.lieuLabel,
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Le ${_fmt.format(edl.dateEtatLieux)}',
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _EdlSituationBadge(situation: edl.situation),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Propriétaire ──────────────────────────────────────────
                if (edl.proprietaireNom != null) ...[
                  _sectionTitle('PROPRIÉTAIRE'),
                  _infoCard([_infoRow('Nom', edl.proprietaireNom!)]),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ── Lieu ──────────────────────────────────────────────────
                _sectionTitle('LIEU'),
                _infoCard([
                  _infoRow('Immeuble', edl.immeubleNom ?? '—'),
                  if (edl.immeubleAdresse != null)
                    _infoRow('Adresse', edl.immeubleAdresse!),
                  if (edl.chambreNom != null)
                    _infoRow('Chambre', edl.chambreNom!),
                ]),
                const SizedBox(height: AppSpacing.lg),

                // ── Détails ───────────────────────────────────────────────
                _sectionTitle('DÉTAILS'),
                _infoCard([
                  _infoRow(
                    'Type de bail',
                    edl.typeBail == 'collectif' ? 'Collectif' : 'Individuel',
                  ),
                  _infoRow(
                    'Date état des lieux',
                    _fmt.format(edl.dateEtatLieux),
                  ),
                  if (edl.dateFinalisation != null)
                    _infoRow(
                      'Date de finalisation',
                      _fmt.format(edl.dateFinalisation!),
                    ),
                  if (edl.montant != null)
                    _infoRow(
                      'Montant',
                      '€ ${edl.montant!.toStringAsFixed(2)}',
                    ),
                ]),
                const SizedBox(height: AppSpacing.lg),

                // ── Notes ─────────────────────────────────────────────────
                if (edl.notes != null && edl.notes!.isNotEmpty) ...[
                  _sectionTitle('NOTES'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Text(edl.notes!, style: AppTypography.bodyMd),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ── Observations des murs ─────────────────────────────────
                if (edl.observations.isNotEmpty) ...[
                  _sectionTitle('ÉTAT DE LA CHAMBRE'),
                  ...edl.observations.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppRadius.borderMd,
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _wallLabels[entry.key] ?? entry.key,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (entry.value.description != null &&
                                entry.value.description!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                entry.value.description!,
                                style: AppTypography.bodyMd,
                              ),
                            ],
                            if (entry.value.photos.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              SizedBox(
                                height: 80,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: entry.value.photos.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (_, i) => ClipRRect(
                                    borderRadius: AppRadius.borderSm,
                                    child: CachedNetworkImage(
                                      imageUrl: entry.value.photos[i],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => const SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: Icon(Icons.broken_image_outlined,
                                            color: AppColors.onSurfaceVariant),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Signature ─────────────────────────────────────────────
                if (edl.situation == SituationEdl.finalise) ...[
                  _sectionTitle('SIGNATURE'),
                  edl.locataireAccepte
                      ? Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixed.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: AppRadius.borderMd,
                            border: Border.all(
                              color:
                                  AppColors.secondary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outlined,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Vous avez accepté et signé cet état des lieux.',
                                  style: AppTypography.bodyMd,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: AppRadius.borderMd,
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Cet état des lieux a été finalisé par votre '
                                'propriétaire et attend votre signature.',
                                style: AppTypography.bodyMd,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: _accepting ? null : _accept,
                                  child: _accepting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Accepter et signer'),
                                ),
                              ),
                            ],
                          ),
                        ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DangerZoneSection extends StatelessWidget {
  final Future<bool> hasContratsFuture;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _DangerZoneSection({
    required this.hasContratsFuture,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zone dangereuse',
          style: AppTypography.titleLg.copyWith(color: AppColors.error),
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<bool>(
          future: hasContratsFuture,
          builder: (context, snapshot) {
            final hasContracts = snapshot.data ?? false;
            final loading = snapshot.connectionState != ConnectionState.done;

            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.15),
                borderRadius: AppRadius.borderMd,
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supprimer mon compte',
                    style: AppTypography.bodyMd
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    hasContracts
                        ? 'Impossible de supprimer votre compte : vous avez des contrats enregistrés à votre nom.'
                        : 'Cette action est irréversible. Toutes vos données seront définitivement supprimées.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      onPressed:
                          (hasContracts || loading || isDeleting) ? null : onDelete,
                      icon: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.error,
                              ),
                            )
                          : const Icon(Icons.delete_forever_outlined, size: 18),
                      label: Text(
                        isDeleting ? 'Suppression…' : 'Supprimer mon compte',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EdlSituationBadge extends StatelessWidget {
  final SituationEdl situation;
  const _EdlSituationBadge({required this.situation});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (situation) {
      SituationEdl.enCours => (
        AppColors.primaryFixed,
        AppColors.onPrimaryFixedVariant,
      ),
      SituationEdl.aVenir => (
        AppColors.tertiaryFixed,
        AppColors.onTertiaryFixedVariant,
      ),
      SituationEdl.finalise => (
        AppColors.secondaryFixed,
        AppColors.onSecondaryFixedVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        situation.label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}
