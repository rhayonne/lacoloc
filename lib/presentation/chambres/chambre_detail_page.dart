import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/demandes_contact.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/presentation/login_dialog.dart';
import 'package:lacoloc_front/presentation/nav/app_sidebar.dart';
import 'package:lacoloc_front/presentation/widgets/photo_carousel.dart';
import 'package:lacoloc_front/presentation/widgets/contact_dialog.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Widget public : contenu seul, sans Scaffold ni sidebar.
// Utilisé inline dans les profils (locataire, proprietaire)
// et depuis la page publique ChambreDetailPage.

class ChambreDetailView extends StatefulWidget {
  final int chambreId;
  /// Callback du bouton "Retour". Si null, utilise Navigator.pop().
  final VoidCallback? onBack;
  /// « Voir l'immeuble » : si fourni, navigue vers la fiche de l'immeuble
  /// (in-frame) au lieu d'ouvrir un pop-up. Reçoit l'id de l'immeuble.
  final ValueChanged<int>? onVoirImmeuble;

  const ChambreDetailView({
    super.key,
    required this.chambreId,
    this.onBack,
    this.onVoirImmeuble,
  });

  @override
  State<ChambreDetailView> createState() => _ChambreDetailViewState();
}

class _ChambreDetailViewState extends State<ChambreDetailView> {
  late Future<_DetailBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(ChambreDetailView old) {
    super.didUpdateWidget(old);
    if (old.chambreId != widget.chambreId) {
      _future = _load();
    }
  }

  /// Recarrega a fiche. O `_load()` roda FORA do `setState` — passá-lo dentro
  /// faria o closure devolver um Future (erro "setState callback returned a Future").
  void _reload() {
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  Future<_DetailBundle> _load() async {
    final chambre = await ChambresDatasource.byId(widget.chambreId);
    if (chambre == null) throw Exception('Chambre introuvable');
    final results = await Future.wait([
      ImmeublesDatasource.byId(chambre.immeubleId),
      InventaireDatasource.annonceLabelsByChambre([chambre.id]),
      AuthService.loadCurrentProfile(),
    ]);
    final profile = results[2] as UsersClient?;
    final equipMap = results[1] as Map<int, List<String>>;
    bool hasPendingDemande = false;
    if (profile?.resolvedType == UserType.locataire) {
      hasPendingDemande = await DemandesContactDatasource.hasDemandeEnAttente(
        locataireId: profile!.id,
        chambreId: widget.chambreId,
      );
    }
    return _DetailBundle(
      chambre: chambre,
      immeuble: results[0] as ImmeublesModel?,
      equipements: equipMap[chambre.id] ?? const [],
      currentProfile: profile,
      hasPendingDemande: hasPendingDemande,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DetailBundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Erreur : ${snapshot.error}'),
            ),
          );
        }
        return _DetailContent(
          onVoirImmeuble: widget.onVoirImmeuble,
          bundle: snapshot.data!,
          onBack: widget.onBack,
          onContactSent: _reload,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page publique (route /chambre) : sidebar + ChambreDetailView

class ChambreDetailPage extends StatefulWidget {
  final int chambreId;
  const ChambreDetailPage({super.key, required this.chambreId});

  @override
  State<ChambreDetailPage> createState() => _ChambreDetailPageState();
}

class _ChambreDetailPageState extends State<ChambreDetailPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SidebarXController _navCtrl;

  @override
  void initState() {
    super.initState();
    _navCtrl = SidebarXController(selectedIndex: 0, extended: true);
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
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<void> _doLogout() async {
    await AuthService.signOut();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Widget _buildSidebar({required bool isNarrow}) {
    final user = AuthService.currentUser;
    final isLoggedIn = AuthService.isLoggedIn;
    return AppSidebar(
      controller: _navCtrl,
      showToggleButton: !isNarrow,
      userEmail: user?.email,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 800;
    final sidebar = _buildSidebar(isNarrow: isNarrow);
    final body = ChambreDetailView(chambreId: widget.chambreId);

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
          title: const Text('Détails de la chambre'),
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

class _DetailBundle {
  final ChambreModel chambre;
  final ImmeublesModel? immeuble;
  final List<String> equipements;
  final UsersClient? currentProfile;
  final bool hasPendingDemande;
  _DetailBundle({
    required this.chambre,
    required this.immeuble,
    required this.equipements,
    this.currentProfile,
    this.hasPendingDemande = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class _DetailContent extends StatelessWidget {
  final _DetailBundle bundle;
  final VoidCallback? onBack;
  final VoidCallback? onContactSent;
  final ValueChanged<int>? onVoirImmeuble;
  const _DetailContent({
    required this.bundle,
    this.onBack,
    this.onContactSent,
    this.onVoirImmeuble,
  });

  List<String> _orderedPhotos(ChambreModel c) {
    if (c.mainPhoto == null || !c.roomPhotos.contains(c.mainPhoto)) {
      return c.roomPhotos;
    }
    return [c.mainPhoto!, ...c.roomPhotos.where((p) => p != c.mainPhoto)];
  }

  @override
  Widget build(BuildContext context) {
    final chambre = bundle.chambre;
    final selected = bundle.equipements;
    final photos = _orderedPhotos(chambre);

    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, cns) {
          // ~10% de marge à gauche/droite ; la photo occupe la majeure
          // partie de la largeur (responsive).
          final hpad = (cns.maxWidth * 0.10).clamp(AppSpacing.lg, 220.0);
          final carouselH = (cns.maxWidth * 0.8 * 9 / 16).clamp(260.0, 520.0);
          return Padding(
            padding:
                EdgeInsets.symmetric(horizontal: hpad, vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: onBack ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Retour'),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Photo carousel (défilement auto 5 s + zoom plein écran)
                PhotoCarousel(
                  photos: photos,
                  height: carouselH,
                  placeholderIcon: Icons.bed_outlined,
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(chambre.roomName, style: AppTypography.headlineMd),
                if (bundle.immeuble != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    bundle.immeuble!.address ?? bundle.immeuble!.name,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),

                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (chambre.m2 != null)
                      _Stat(
                        icon: Icons.square_foot,
                        label: '${chambre.m2!.toStringAsFixed(0)} m²',
                      ),
                    if (bundle.immeuble?.type != null)
                      _Stat(
                        icon: Icons.apartment,
                        label: bundle.immeuble!.type!.typeName,
                      ),
                    if (bundle.immeuble?.bailLabel != null)
                      _Stat(
                        icon: Icons.description_outlined,
                        label: bundle.immeuble!.bailLabel!,
                      ),
                  ],
                ),

                if (chambre.description != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Description', style: AppTypography.titleLg),
                  const SizedBox(height: AppSpacing.sm),
                  Text(chambre.description!, style: AppTypography.bodyMd),
                ],

                const SizedBox(height: AppSpacing.lg),
                Text('Équipements', style: AppTypography.titleLg),
                const SizedBox(height: AppSpacing.sm),
                if (selected.isEmpty)
                  Text(
                    'Aucun équipement renseigné.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  )
                else
                  Column(
                    children:
                        selected.map((name) => _OptionRow(label: name)).toList(),
                  ),

                if (bundle.immeuble != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton.icon(
                    // En contexte intégré (accueil), navigue vers la fiche de
                    // l'immeuble (Retour ramène à la chambre) ; sinon pop-up.
                    onPressed: () => onVoirImmeuble != null
                        ? onVoirImmeuble!(bundle.immeuble!.id)
                        : _showImmeuble(context, bundle.immeuble!),
                    icon: const Icon(Icons.location_city),
                    label: const Text("Voir l'immeuble"),
                  ),
                ],
                if (bundle.currentProfile?.resolvedType ==
                    UserType.locataire) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (bundle.hasPendingDemande)
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('Vous avez déjà contacté le propriétaire'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => _showContactDialog(context),
                      icon: const Icon(Icons.contact_mail_outlined),
                      label: const Text('Entrer en contact'),
                    ),
                ]
                // Visiteur non connecté : le contact exige d'être connecté.
                else if (!AuthService.isLoggedIn) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/login'),
                    icon: const Icon(Icons.contact_mail_outlined),
                    label: const Text('Entrer en contact'),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    final chambre = bundle.chambre;
    final immeuble = bundle.immeuble;
    showContactDialog(
      context,
      profile: bundle.currentProfile!,
      immeubleId: chambre.immeubleId,
      immeubleName: immeuble?.name ?? '—',
      chambreId: chambre.id,
      chambreName: chambre.roomName,
      onSent: () => onContactSent?.call(),
    );
  }

  void _showImmeuble(BuildContext context, ImmeublesModel imm) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  0,
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_city,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(imm.name, style: AppTypography.titleLg),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imm.commonPhotos.isNotEmpty)
                        ClipRRect(
                          borderRadius: AppRadius.borderMd,
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: CachedNetworkImage(
                              imageUrl:
                                  imm.mainPhoto ?? imm.commonPhotos.first,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                  color: AppColors.surfaceContainerLow),
                            ),
                          ),
                        ),
                      if (imm.commonPhotos.isNotEmpty)
                        const SizedBox(height: AppSpacing.md),
                      if (imm.address != null) ...[
                        Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 16,
                                color: AppColors.onSurfaceVariant),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(imm.address!,
                                  style: AppTypography.bodyMd),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          if (imm.type != null)
                            _Stat(
                              icon: Icons.home_work_outlined,
                              label: imm.type!.typeName,
                            ),
                          if (imm.totalM2 != null)
                            _Stat(
                              icon: Icons.square_foot,
                              label:
                                  '${imm.totalM2!.toStringAsFixed(0)} m²',
                            ),
                          if (imm.bailLabel != null)
                            _Stat(
                              icon: Icons.description_outlined,
                              label: imm.bailLabel!,
                            ),
                        ],
                      ),
                      if (imm.description != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text('Description', style: AppTypography.titleLg),
                        const SizedBox(height: AppSpacing.sm),
                        Text(imm.description!,
                            style: AppTypography.bodyMd),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTypography.labelMd),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  const _OptionRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.check_circle,
              size: 18, color: AppColors.tertiaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTypography.bodyMd),
        ],
      ),
    );
  }
}

