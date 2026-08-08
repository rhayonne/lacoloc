import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/chambres.dart';
import 'package:habitafrance/data/datasources/etat_de_lieux.dart';
import 'package:habitafrance/data/datasources/immeubles.dart';
import 'package:habitafrance/data/models/etat_de_lieux.dart';
import 'package:habitafrance/presentation/users/proprietaires/etat_de_lieux_page.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Menu super admin — **États des lieux (global)**.
/// Liste TOUS les EDL du système (actifs + inactifs), avec recherche (code,
/// locataire, propriétaire, immeuble). Contrôle total : éditer (même finalisé),
/// désactiver/réactiver (soft-delete en cascade) et supprimer définitivement.
class AdminEdlPage extends StatefulWidget {
  const AdminEdlPage({super.key});

  @override
  State<AdminEdlPage> createState() => _AdminEdlPageState();
}

class _AdminEdlPageState extends State<AdminEdlPage> {
  final _searchCtrl = TextEditingController();
  late Future<List<EtatDesLieuxModel>> _future;
  Widget? _detail; // fiche EDL ouverte en place (édition), sinon la liste.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = EtatDesLieuxDatasource.listAllForAdmin();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Recharge la liste depuis le serveur (après une action). La recherche
  /// filtre **en mémoire** (voir build) — pas de refetch à chaque frappe.
  void _reload() {
    final f = EtatDesLieuxDatasource.listAllForAdmin();
    setState(() {
      _future = f;
    });
  }

  Future<void> _openEditor(EtatDesLieuxModel e) async {
    setState(() => _busy = true);
    try {
      final imm = await ImmeublesDatasource.byId(e.immeubleId, refresh: true);
      if (imm == null) {
        _snack('Immeuble introuvable.');
        return;
      }
      final meublee = imm.locationMeuble == true;
      void close(bool _) {
        setState(() => _detail = null);
        _reload();
      }

      Widget page;
      if (e.partie == PartieEdl.privative) {
        final ch = e.chambreId != null
            ? await ChambresDatasource.byId(e.chambreId!, refresh: true)
            : null;
        if (ch == null) {
          _snack('Chambre introuvable.');
          return;
        }
        page = EdlIndividuelMeubleePage(
          immeuble: imm,
          chambre: ch,
          typeEdl: e.typeEdl,
          existingEdl: e,
          meublee: meublee,
          superAdmin: true,
          onClose: close,
        );
      } else {
        page = EdlCollectifNonMeubleePage(
          immeuble: imm,
          typeEdl: e.typeEdl,
          existingEdl: e,
          meublee: meublee,
          lockLocataires: e.typeBail == 'individuel',
          superAdmin: true,
          onClose: close,
        );
      }
      if (mounted) setState(() => _detail = page);
    } catch (err) {
      _snack('Erreur : $err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleActive(EtatDesLieuxModel e) async {
    final activer = !e.actif;
    if (!activer) {
      final ok = await _confirm(
        titre: 'Désactiver cet état des lieux ?',
        message: e.isCollectifInterne
            ? 'Le contrat collectif et TOUS ses EDL individuels (+ sorties) '
                'seront désactivés. Ils disparaîtront pour les parties mais '
                'resteront réactivables ici.'
            : e.partie == PartieEdl.privative
                ? 'Cet EDL individuel (+ sa sortie) sera désactivé. Le contrat '
                    'collectif reste lié aux autres locataires actifs.'
                : 'Cet EDL (+ sa sortie) sera désactivé en cascade. Il '
                    'disparaîtra pour les parties mais restera réactivable ici.',
        confirmLabel: 'Désactiver',
        danger: true,
      );
      if (ok != true) return;
    }
    await _run(() => EtatDesLieuxDatasource.setActive(e.id, activer));
  }

  Future<void> _deleteHard(EtatDesLieuxModel e) async {
    final ok = await _confirm(
      titre: 'Supprimer définitivement ?',
      message: 'Suppression IRRÉVERSIBLE de l\'EDL ${e.code ?? e.id} et de '
          'tous ses éléments (observations, preneurs, relevés, sections…). '
          'Un collectif supprime aussi ses EDL individuels. À utiliser en '
          'dernier recours — préférez « Désactiver ».',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (ok != true) return;
    await _run(() => EtatDesLieuxDatasource.deleteHardAdmin(e.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _reload();
    } catch (err) {
      _snack('Erreur : $err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<bool?> _confirm({
    required String titre,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_detail != null) return _detail!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppTopBar(title: 'États des lieux — administration'),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: TextField(
            controller: _searchCtrl,
            // Filtre en mémoire : un simple rebuild suffit (la liste complète
            // a déjà été téléchargée ; refetch seulement après une action).
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
                  'Rechercher (code, locataire, propriétaire, immeuble…)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    ),
              border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
              isDense: true,
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
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
              final edls = (snap.data ?? const <EtatDesLieuxModel>[])
                  .where((e) => EtatDesLieuxDatasource.adminQueryMatches(
                      e, _searchCtrl.text))
                  .toList();
              if (edls.isEmpty) {
                return const Center(child: Text('Aucun état des lieux.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.xl),
                itemCount: edls.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _EdlAdminRow(
                  edl: edls[i],
                  onEdit: () => _openEditor(edls[i]),
                  onToggle: () => _toggleActive(edls[i]),
                  onDelete: () => _deleteHard(edls[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EdlAdminRow extends StatelessWidget {
  final EtatDesLieuxModel edl;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _EdlAdminRow({
    required this.edl,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final inactif = !edl.actif;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: inactif
            ? AppColors.surfaceContainerLow
            : AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: inactif ? AppColors.outline : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        edl.code ?? 'EDL #${edl.id}',
                        style: AppTypography.titleLg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _Chip(
                      label: '${edl.typeLabel} · ${edl.sensLabel}',
                      color: AppColors.primaryFixed,
                      textColor: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    _Chip(
                      label: edl.situation.label,
                      color: AppColors.surfaceContainerHigh,
                      textColor: AppColors.onSurfaceVariant,
                    ),
                    if (inactif) ...[
                      const SizedBox(width: 6),
                      _Chip(
                        label: 'Inactif',
                        color: AppColors.errorContainer,
                        textColor: AppColors.onErrorContainer,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${edl.displayLocataire} · ${edl.proprietaireNom ?? '—'} · '
                  '${edl.lieuLabel} · ${edl.dateEdlFormatted}',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Éditer',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: inactif ? 'Réactiver' : 'Désactiver',
            icon: Icon(inactif ? Icons.restart_alt : Icons.visibility_off_outlined),
            color: inactif ? AppColors.success : AppColors.onSurfaceVariant,
            onPressed: onToggle,
          ),
          IconButton(
            tooltip: 'Supprimer définitivement',
            icon: const Icon(Icons.delete_forever_outlined),
            color: AppColors.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(label,
          style: AppTypography.labelSm.copyWith(color: textColor)),
    );
  }
}
