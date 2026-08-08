import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/datasources/chambres.dart';
import 'package:habitafrance/data/datasources/demandes_contact.dart';
import 'package:habitafrance/data/datasources/inventaire.dart';
import 'package:habitafrance/data/datasources/immeubles.dart';
import 'package:habitafrance/data/models/chambre.dart';
import 'package:habitafrance/data/models/chambre_disponibilite.dart';
import 'package:habitafrance/data/models/immeubles.dart';
import 'package:habitafrance/data/models/users_client.dart';
import 'package:habitafrance/presentation/chambres/chambre_card.dart';
import 'package:habitafrance/presentation/widgets/contact_dialog.dart';
import 'package:habitafrance/presentation/widgets/photo_carousel.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Fiche publique d'un immeuble : informations + chambres disponibles.
/// **Vue intégrable** (pas de Scaffold) : s'affiche dans le cadre principal, à
/// droite du menu (voir [onBack]). Le clic sur une chambre ouvre `/chambre`.
class ImmeublePublicDetailView extends StatefulWidget {
  final int immeubleId;

  /// Retour à la liste (rendu dans le même cadre). Si null → Navigator.pop().
  final VoidCallback? onBack;

  const ImmeublePublicDetailView({
    super.key,
    required this.immeubleId,
    this.onBack,
  });

  @override
  State<ImmeublePublicDetailView> createState() =>
      _ImmeublePublicDetailViewState();
}

class _ImmeublePublicDetailViewState extends State<ImmeublePublicDetailView> {
  late Future<_Bundle> _future;

  /// Profil courant (pour le bouton « Entrer en contact » — visible au
  /// locataire ; le visiteur non connecté est redirigé vers la connexion).
  UsersClient? _profile;

  /// Le locataire a-t-il déjà une demande active (non ignorée) **au niveau de
  /// l'immeuble** ? → on désactive le bouton pour éviter les doublons (mêmes
  /// garde-fous que la fiche chambre).
  bool _hasPendingDemande = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final p = await AuthService.loadCurrentProfile();
      if (!mounted) return;
      setState(() => _profile = p);
      await _refreshPending();
    } catch (_) {/* best-effort */}
  }

  Future<void> _refreshPending() async {
    final p = _profile;
    if (p == null || p.resolvedType != UserType.locataire) return;
    try {
      final pending = await DemandesContactDatasource.hasDemandeEnAttente(
        locataireId: p.id,
        immeubleId: widget.immeubleId,
      );
      if (mounted) setState(() => _hasPendingDemande = pending);
    } catch (_) {/* best-effort */}
  }

  void _contact(ImmeublesModel imm) {
    // Doit être connecté : sinon, direction la page de connexion.
    if (_profile?.resolvedType != UserType.locataire) {
      Navigator.of(context).pushNamed('/login');
      return;
    }
    showContactDialog(
      context,
      profile: _profile!,
      immeubleId: imm.id,
      immeubleName: imm.name,
      onSent: () {
        if (mounted) setState(() => _hasPendingDemande = true);
      },
    );
  }

  @override
  void didUpdateWidget(ImmeublePublicDetailView old) {
    super.didUpdateWidget(old);
    if (old.immeubleId != widget.immeubleId) _future = _load();
  }

  Future<_Bundle> _load() async {
    final immeuble = await ImmeublesDatasource.byId(widget.immeubleId);
    if (immeuble == null) throw Exception('Immeuble introuvable');
    final chambres = (await ChambresDatasource.listByImmeuble(widget.immeubleId))
        .where((c) => c.isActive)
        .toList();
    final ids = chambres.map((c) => c.id).toList();
    final equipMap = await InventaireDatasource.annonceLabelsByChambre(ids);
    final dispoMap = await ChambresDatasource.disponibiliteByIds(ids);
    return _Bundle(
      immeuble: immeuble,
      chambres: chambres,
      equipMap: equipMap,
      dispoMap: dispoMap,
    );
  }

  List<String> _photos(ImmeublesModel imm) {
    final out = <String>[];
    if (imm.mainPhoto != null && imm.mainPhoto!.isNotEmpty) {
      out.add(imm.mainPhoto!);
    }
    for (final p in imm.commonPhotos) {
      if (p.isNotEmpty && !out.contains(p)) out.add(p);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Bundle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child:
                  Text('Erreur : ${snap.error}', style: AppTypography.bodyMd),
            ),
          );
        }
        return _content(snap.data!);
      },
    );
  }

  Widget _content(_Bundle b) {
    final imm = b.immeuble;
    final photos = _photos(imm);

    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, cns) {
          // ~10% de marge gauche/droite ; la photo prend la majeure partie de
          // la largeur (responsive).
          final hpad = (cns.maxWidth * 0.10).clamp(AppSpacing.lg, 220.0);
          final carouselH = (cns.maxWidth * 0.8 * 9 / 16).clamp(260.0, 520.0);
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: hpad, vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Retour'),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Photo carousel (défilement auto 5 s + zoom plein écran).
                PhotoCarousel(
                  photos: photos,
                  height: carouselH,
                  placeholderIcon: Icons.apartment_outlined,
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(imm.name, style: AppTypography.headlineMd),
                const SizedBox(height: AppSpacing.xs),
                if (imm.city != null || imm.address != null)
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 16, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          [imm.address, imm.city, imm.region]
                              .where((s) => s != null && s.isNotEmpty)
                              .join(', '),
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (imm.type != null) _Pill(label: imm.type!.typeName),
                    if (imm.totalM2 != null)
                      _Pill(label: '${imm.totalM2!.toStringAsFixed(0)} m²'),
                    if (imm.bailLocation) const _Pill(label: 'Location'),
                    if (imm.bailIndividuel) const _Pill(label: 'Colocation'),
                    if (imm.locationMeuble == true)
                      const _Pill(label: 'Meublé')
                    else if (imm.locationMeuble == false)
                      const _Pill(label: 'Non meublé'),
                  ],
                ),
                if (imm.description != null &&
                    imm.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(imm.description!, style: AppTypography.bodyMd),
                ],

                // Entrer en contact — locataire connecté, ou visiteur (→ login).
                if (_profile?.resolvedType == UserType.locataire ||
                    !AuthService.isLoggedIn) ...[
                  const SizedBox(height: AppSpacing.lg),
                  if (_hasPendingDemande)
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.forum_outlined),
                      label:
                          const Text('Vous avez déjà contacté le propriétaire'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => _contact(imm),
                      icon: const Icon(Icons.contact_mail_outlined),
                      label: const Text('Entrer en contact'),
                    ),
                ],

                const SizedBox(height: AppSpacing.xl),
                Text('Chambres disponibles (${b.chambres.length})',
                    style: AppTypography.titleLg),
                const SizedBox(height: AppSpacing.md),
                if (b.chambres.isEmpty)
                  Text('Aucune chambre disponible pour le moment.',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant))
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 380,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      mainAxisExtent: 430,
                    ),
                    itemCount: b.chambres.length,
                    itemBuilder: (context, i) {
                      final c = b.chambres[i];
                      return ChambreCard(
                        chambre: c,
                        equipementLabels: b.equipMap[c.id] ?? const [],
                        disponibilite: b.dispoMap[c.id],
                        onTap: () => Navigator.of(context)
                            .pushNamed('/chambre', arguments: c.id),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Bundle {
  final ImmeublesModel immeuble;
  final List<ChambreModel> chambres;
  final Map<int, List<String>> equipMap;
  final Map<int, ChambreDisponibiliteModel> dispoMap;
  const _Bundle({
    required this.immeuble,
    required this.chambres,
    required this.equipMap,
    required this.dispoMap,
  });
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(label,
          style: AppTypography.labelSm
              .copyWith(color: AppColors.onPrimaryFixedVariant)),
    );
  }
}
