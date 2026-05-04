import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/filter_state.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_card.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
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
  late Future<_LocBundle> _bundleFuture;

  static const _idxAccueil = 0;
  static const _idxChambres = 1;
  static const _idxProfil = 2;

  @override
  void initState() {
    super.initState();
    _navCtrl = SidebarXController(selectedIndex: _idxChambres, extended: true);
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
    if (_navCtrl.selectedIndex == _idxAccueil) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
    setState(() {});
  }

  Future<void> _doLogout() async {
    await AuthService.signOut();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  Widget _buildSidebar({required bool isNarrow}) {
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: AuthService.currentUser?.email,
      items: const [
        SidebarXItem(icon: Icons.home_outlined, label: 'Accueil'),
        SidebarXItem(icon: Icons.search_outlined, label: 'Chambres disponibles'),
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

  Widget _buildBody() {
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
          _idxChambres => _ChambresSection(
              chambres: bundle.available,
              onTap: (id) => Navigator.of(context).pushNamed(
                '/chambre',
                arguments: id,
              ),
            ),
          _idxProfil => _ProfilSection(profile: bundle.profile),
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
  _LocBundle({required this.available, required this.total, required this.profile});
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
  BailTypeFilter? _bailType;

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
      if (_bailType == BailTypeFilter.collectif && !c.immeubleBailCollectif) {
        return false;
      }
      if (_bailType == BailTypeFilter.individuel && !c.immeubleBailIndividuel) {
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

              // Filtres bail
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  FilterChip(
                    label: Text('Bail collectif',
                        style: AppTypography.labelSm),
                    selected: _bailType == BailTypeFilter.collectif,
                    onSelected: (v) => setState(() =>
                        _bailType = v ? BailTypeFilter.collectif : null),
                    selectedColor: AppColors.primaryFixed,
                    checkmarkColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  FilterChip(
                    label: Text('Bail individuel',
                        style: AppTypography.labelSm),
                    selected: _bailType == BailTypeFilter.individuel,
                    onSelected: (v) => setState(() =>
                        _bailType = v ? BailTypeFilter.individuel : null),
                    selectedColor: AppColors.primaryFixed,
                    checkmarkColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                filtered.isEmpty
                    ? 'Aucune chambre ne correspond à la recherche.'
                    : '${filtered.length} chambre${filtered.length > 1 ? 's' : ''} disponible${filtered.length > 1 ? 's' : ''}',
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
                      const Icon(Icons.bed_outlined,
                          size: 64, color: AppColors.outline),
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
  late final TextEditingController _nameCtrl;
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.profile?.fullName ?? '';
    _nameCtrl = TextEditingController(text: _displayName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) _nameCtrl.text = _displayName; // revert on cancel
    setState(() => _isEditing = !_isEditing);
  }

  Future<void> _save() async {
    final newName = _nameCtrl.text.trim();
    setState(() => _isSaving = true);
    try {
      await AuthService.updateProfile(fullName: newName);
      if (!mounted) return;
      setState(() {
        _displayName = newName;
        _isEditing = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.profile?.email ?? AuthService.currentUser?.email ?? '';
    final createdAt = widget.profile?.createdAt;
    final initial = (_displayName.isNotEmpty ? _displayName : email)
        .substring(0, 1)
        .toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Barre de titre ──
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm,
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
                icon: Icon(
                  _isEditing ? Icons.close : Icons.edit_outlined,
                ),
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
                            : AppColors.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                tooltip: 'Sauvegarder',
                onPressed: _isEditing && !_isSaving ? _save : null,
              ),
            ],
          ),
        ),

        // ── Corps du formulaire ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primaryFixed,
                        child: Text(
                          initial,
                          style: AppTypography.headlineMd.copyWith(
                            color: AppColors.onPrimaryFixedVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _fieldLabel('NOM COMPLET'),
                    TextField(
                      controller: _nameCtrl,
                      enabled: _isEditing,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Jean Dupont',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    _fieldLabel('E-MAIL'),
                    _staticField(email),
                    const SizedBox(height: AppSpacing.lg),

                    _fieldLabel('TYPE DE COMPTE'),
                    _staticField('Locataire'),

                    if (createdAt != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _fieldLabel('MEMBRE DEPUIS'),
                      _staticField(
                        '${createdAt.day.toString().padLeft(2, '0')}/'
                        '${createdAt.month.toString().padLeft(2, '0')}/'
                        '${createdAt.year}',
                      ),
                    ],
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
