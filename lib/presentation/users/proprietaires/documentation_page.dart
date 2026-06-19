import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/datasources/signatures.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/bail_pdf_preview_page.dart';
import 'package:lacoloc_front/presentation/widgets/app_list_search_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/signature_pad.dart';

class DocumentationPage extends StatefulWidget {
  const DocumentationPage({super.key});

  @override
  State<DocumentationPage> createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
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
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Vue générale'),
              Tab(text: 'Baux'),
              Tab(text: 'Ma signature'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
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
    return ListView(
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
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
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
      ],
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── En-tête ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contrats de location', style: AppTypography.headlineLg),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      "Un bail est généré après l'acceptation de l'état des lieux "
                      "par le locataire. Le bail est valable tant que l'état des "
                      "lieux de sortie n'est pas finalisé.",
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

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
                      const Icon(Icons.description_outlined,
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
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _BailRow(
                      edl: items[i],
                      wide: wide,
                      dateFmt: _dateFmt,
                      onViewPdf: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BailPdfPreviewPage(edl: items[i]),
                        ),
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
            const CircleAvatar(
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
          const CircleAvatar(
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

class _SignaturePage extends StatefulWidget {
  const _SignaturePage();

  @override
  State<_SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<_SignaturePage> {
  late Future<String?> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = SignaturesDatasource.getSavedUrl();
  }

  Future<void> _update() async {
    final sig = await showSignatureDialog(context);
    if (sig == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await SignaturesDatasource.saveUrl(sig.url);
      if (mounted) {
        setState(() {
          _future = SignaturesDatasource.getSavedUrl();
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _delete(String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la signature ?'),
        content: const Text('La signature sauvegardée sera supprimée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.deleteButtonStyle,
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await SignaturesDatasource.deleteSignature();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
    if (mounted) {
      setState(() {
        _future = SignaturesDatasource.getSavedUrl();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snap) {
        final url = snap.data;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Ma signature par défaut', style: AppTypography.titleLg),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cette signature sera proposée automatiquement lors de la '
              "finalisation ou de l'acceptation d'un état des lieux.",
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (snap.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (url != null && url.isNotEmpty) ...[
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.outlineVariant),
                  borderRadius: AppRadius.borderMd,
                ),
                child: Image.network(url, fit: BoxFit.contain),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : _update,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _delete(url),
                    style: AppTheme.deleteButtonStyle,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                  ),
                ],
              ),
            ] else ...[
              Container(
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  border: Border.all(color: AppColors.outlineVariant),
                  borderRadius: AppRadius.borderMd,
                ),
                child: Text(
                  'Aucune signature sauvegardée',
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _saving ? null : _update,
                icon: const Icon(Icons.draw_outlined, size: 18),
                label: const Text('Ajouter ma signature'),
              ),
            ],
          ],
        );
      },
    );
  }
}
