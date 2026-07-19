import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/bail_pdf_preview_page.dart';
import 'package:lacoloc_front/presentation/widgets/app_list_search_field.dart';
import 'package:lacoloc_front/presentation/widgets/app_top_bar.dart';
import 'package:lacoloc_front/presentation/widgets/bail_signature_flow.dart';
import 'package:lacoloc_front/presentation/widgets/signature_manager.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/app_tab_bar.dart';

class DocumentationPage extends StatefulWidget {
  /// Onglet initial (piloté par le sous-menu de la sidebar).
  final int initialTab;
  /// Masque la barre d'onglets interne quand la navigation se fait par sous-menu.
  final bool showTabBar;
  const DocumentationPage({super.key, this.initialTab = 0, this.showTabBar = true});

  @override
  State<DocumentationPage> createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTabBar) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: AppTabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(text: 'Vue générale'),
                Tab(text: 'Baux'),
                Tab(text: 'Ma signature'),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            // Pas de balayage du contenu (changement d'onglet au tap seul).
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              _VisionGeneralePage(),
              _BauxPage(),
              _SignaturePage(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab : Vue générale

class _VisionGeneralePage extends StatelessWidget {
  const _VisionGeneralePage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTopBar(title: 'Vue générale'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withValues(alpha: 0.35),
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Gestion documentaire',
                    style: AppTypography.titleLg.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Gérez vos contrats de location (baux) et votre signature électronique. '
                "Un bail est généré automatiquement après signature de l'état des lieux par le locataire.",
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Raccourcis', style: AppTypography.titleLg),
        const SizedBox(height: AppSpacing.md),
        _QuickTile(
          icon: Icons.description_outlined,
          title: 'Baux',
          subtitle: 'Consulter et télécharger vos contrats de location.',
          onTap: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        _QuickTile(
          icon: Icons.draw_outlined,
          title: 'Ma signature',
          subtitle: 'Configurer la signature utilisée dans les documents.',
          onTap: () {},
        ),
        const SizedBox(height: AppSpacing.xl),
        const ESignatureNoticeCard(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Avis légal sur la signature électronique et sa validation dans l'application.
/// Affiché au propriétaire (Documentation) et au locataire (espace signature).
class ESignatureNoticeCard extends StatelessWidget {
  const ESignatureNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Signature électronique — valeur juridique',
                    style: AppTypography.titleLg),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "En France, la signature électronique a la même valeur juridique "
            "qu'une signature manuscrite dès lors que l'identité du signataire "
            "peut être établie et l'intégrité du document garantie (règlement "
            "européen eIDAS n° 910/2014 et articles 1366 et 1367 du Code civil).",
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Comment nous validons vos signatures',
              style: AppTypography.labelMd),
          const SizedBox(height: AppSpacing.xs),
          ...const [
            "Compte authentifié — chaque signataire est connecté à son compte personnel.",
            "Horodatage — la date et l'heure de la signature sont enregistrées.",
            "Empreinte d'intégrité (SHA-256) — une empreinte des données du document est calculée et apposée sur le PDF pour détecter toute modification ultérieure.",
            "Traçabilité — un faisceau d'indices (compte, horodatage, empreinte) est conservé pour prouver, en cas de litige, l'identité, le consentement et l'intégrité.",
          ].map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 5, right: 6),
                      child: Icon(Icons.check_circle_outline,
                          size: 14, color: AppColors.success),
                    ),
                    Expanded(
                      child: Text(t,
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.onSurface)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Ce niveau correspond à une « signature électronique simple » "
            "renforcée par un faisceau d'indices. Pour les baux et états des "
            "lieux d'habitation, ce niveau est adapté ; une signature avancée "
            "ou qualifiée (avec un prestataire certifié) reste possible pour "
            "une sécurité juridique maximale.",
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryFixed,
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: AppTypography.bodyMd),
      subtitle: Text(subtitle,
          style:
              AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab : Baux

class _BauxPage extends StatefulWidget {
  const _BauxPage();

  @override
  State<_BauxPage> createState() => _BauxPageState();
}

class _BauxPageState extends State<_BauxPage> {
  late Future<List<EtatDesLieuxModel>> _future;
  String _search = '';

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    setState(() {
      _future = EtatDesLieuxDatasource.listByProprietaire(uid).then(
        // Garder uniquement les EDL d'entrée acceptés par le locataire
        (list) => list
            .where((e) =>
                e.typeEdl == 'entree' &&
                e.locataireAccepte &&
                // Un bail porte sur un EDL privatif (individuel) ou commune (location)
                (e.partie == PartieEdl.privative ||
                    (e.partie == PartieEdl.commune &&
                        e.typeBail == 'location')))
            .toList()
          ..sort((a, b) =>
              (b.dateDebutBail ?? b.dateEtatLieux)
                  .compareTo(a.dateDebutBail ?? a.dateEtatLieux)),
      );
    });
  }

  /// Ouvre l'aperçu du bail après avoir vérifié la signature du bailleur :
  /// si le bail n'est pas encore signé, propose d'y apposer la signature
  /// (création si nécessaire) avant l'ouverture.
  Future<void> _openBail(EtatDesLieuxModel edl) async {
    // 1) Garant : choix (Oui/Non) + vérification ; peut bloquer l'impression
    //    et notifier le locataire s'il manque un garant requis.
    final garantRes = await ensureBailGarant(context, edl);
    if (garantRes == null || !mounted) return;
    // 2) Signature du bailleur.
    final signed = await ensureBailSignature(
      context,
      garantRes.edl,
      role: 'proprietaire',
    );
    if (signed == null || !mounted) return;
    // 3) Aperçu (l'impression est auto-bloquée si un garant requis manque).
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BailPdfPreviewPage(edl: signed),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── En-tête ─────────────────────────────────────────────────────────
        const AppTopBar(title: 'Contrats de location'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
          child: Text(
            "Un bail est généré après l'acceptation de l'état des lieux "
            "par le locataire. Le bail est valable tant que l'état des "
            "lieux de sortie n'est pas finalisé.",
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Recherche ────────────────────────────────────────────────────────
        AppListSearchField(
          hint: 'Rechercher par locataire, immeuble ou chambre…',
          onChanged: (q) => setState(() => _search = q),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Liste ────────────────────────────────────────────────────────────
        Expanded(
          child: FutureBuilder<List<EtatDesLieuxModel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erreur : ${snap.error}'));
              }
              final all = snap.data ?? [];
              final items = _search.isEmpty
                  ? all
                  : all.where((e) {
                      final q = _search;
                      return (e.locataireNom?.toLowerCase().contains(q) ??
                              false) ||
                          (e.immeubleNom?.toLowerCase().contains(q) ?? false) ||
                          (e.chambreNom?.toLowerCase().contains(q) ?? false);
                    }).toList();

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 56, color: AppColors.outline),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucun bail enregistré',
                          style: AppTypography.titleLg),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Les baux apparaissent ici après que le locataire\n'
                        "a accepté et signé l'état des lieux d'entrée.",
                        style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 700;
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    // Chaque bail dans une carte (bord arrondi + bordure),
                    // homogène avec la liste des utilisateurs.
                    itemBuilder: (_, i) => Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: AppRadius.borderLg,
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      child: _BailRow(
                        edl: items[i],
                        wide: wide,
                        dateFmt: _dateFmt,
                        onViewPdf: () => _openBail(items[i]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BailRow extends StatelessWidget {
  final EtatDesLieuxModel edl;
  final bool wide;
  final DateFormat dateFmt;
  final VoidCallback onViewPdf;

  const _BailRow({
    required this.edl,
    required this.wide,
    required this.dateFmt,
    required this.onViewPdf,
  });

  /// Statut du bail : En cours / Résilié
  String get _statut {
    // Un bail de sortie finalisé = résilié
    return 'En cours';
  }

  Color get _statutColor => AppColors.success;

  String _fmtDate(DateTime? d) => d != null ? dateFmt.format(d) : '—';

  @override
  Widget build(BuildContext context) {
    final debut = edl.dateDebutBail ?? edl.dateEtatLieux;
    final fin = edl.dateFinBail;
    final locataire = edl.locataireNom ??
        edl.preneursNoms.firstOrNull ??
        '—';
    final lieu = edl.chambreNom != null
        ? '${edl.immeubleNom ?? ''} · ${edl.chambreNom}'
        : (edl.immeubleNom ?? '—');

    if (!wide) {
      // Mode compact (carte)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryFixed,
              child: Icon(Icons.description_outlined,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(locataire, style: AppTypography.labelMd),
                  Text(lieu,
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_fmtDate(debut)}  →  ${_fmtDate(fin)}',
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onViewPdf,
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Bail'),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryFixed,
            child: Icon(Icons.description_outlined,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          // Locataire
          Expanded(
            flex: 2,
            child: Text(locataire,
                style: AppTypography.bodyMd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          // Lieu
          Expanded(
            flex: 2,
            child: Text(lieu,
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          // Début
          SizedBox(
            width: 100,
            child: Text(_fmtDate(debut),
                style: AppTypography.bodyMd,
                textAlign: TextAlign.center),
          ),
          // Fin
          SizedBox(
            width: 100,
            child: Text(_fmtDate(fin),
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
          ),
          // Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statutColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_statut,
                style: AppTypography.labelSm.copyWith(color: _statutColor)),
          ),
          const SizedBox(width: AppSpacing.md),
          // Bouton Bail
          OutlinedButton.icon(
            onPressed: onViewPdf,
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('Bail'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab : Ma signature

class _SignaturePage extends StatelessWidget {
  const _SignaturePage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTopBar(title: 'Ma signature'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              SignatureManagerSection(),
            ],
          ),
        ),
      ],
    );
  }
}
