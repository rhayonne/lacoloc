import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/datasources/garants.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/presentation/users/locataires/garants_page.dart';
import 'package:lacoloc_front/presentation/widgets/edl_signature_flow.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Pop-up des **documents requis pour générer le bail** d'un EDL.
/// - Côté **propriétaire** : affiche les coordonnées du locataire + le code de
///   l'EDL, la liste des éléments (barrés quand faits) et un bouton
///   « Demander le remplissage » (notifie le locataire).
/// - Côté **locataire** : affiche les coordonnées du propriétaire + le code de
///   l'EDL, la liste des éléments, avec un bouton « Résoudre » devant chaque
///   élément manquant (enregistrer un garant / signer l'EDL).
Future<void> showBailRequirementsDialog(
  BuildContext context, {
  required int edlId,
  required bool asProprietaire,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _BailRequirementsBody(edlId: edlId, asProprietaire: asProprietaire),
      ),
    ),
  );
}

class _Req {
  final String label;
  final bool done;
  final String? resolveKind; // 'garant' | 'signature_locataire' | null
  const _Req(this.label, this.done, [this.resolveKind]);
}

class _BailRequirementsBody extends StatefulWidget {
  final int edlId;
  final bool asProprietaire;
  const _BailRequirementsBody(
      {required this.edlId, required this.asProprietaire});

  @override
  State<_BailRequirementsBody> createState() => _BailRequirementsBodyState();
}

class _BailRequirementsBodyState extends State<_BailRequirementsBody> {
  late Future<_Data> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final edl = await EtatDesLieuxDatasource.findById(widget.edlId);
    if (edl == null) throw Exception('EDL introuvable');
    int garants = 0;
    if (edl.locataireId != null) {
      try {
        garants =
            (await GarantsDatasource.activeByLocataire(edl.locataireId!)).length;
      } catch (_) {}
    }
    return _Data(edl: edl, garantsCount: garants);
  }

  void _reload() => setState(() => _future = _load());

  List<_Req> _requirements(_Data d) {
    final edl = d.edl;
    return [
      if (edl.bailAvecGarant == true)
        _Req('Garant (caution) enregistré', d.garantsCount > 0, 'garant'),
      _Req(
        'Signature du locataire',
        edl.locataireAccepte || edl.locataireSignatureUrl != null,
        'signature_locataire',
      ),
      _Req('Signature du bailleur', edl.proprietaireSignatureUrl != null),
    ];
  }

  Future<void> _resolveGarant() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Mes garants')),
        body: const GarantsPage(),
      ),
    ));
    if (mounted) _reload();
  }

  Future<void> _resolveSignature(EtatDesLieuxModel edl) async {
    final url = await runLocataireSignatureFlow(context, edl);
    if (url == null || !mounted) return;
    await EtatDesLieuxDatasource.locataireAccepter(edl.id,
        locataireSignatureUrl: url);
    if (mounted) _reload();
  }

  Future<void> _demanderRemplissage() async {
    setState(() => _busy = true);
    try {
      await EtatDesLieuxDatasource.requestBailCompletion(widget.edlId);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Demande envoyée au locataire.'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'.replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Data>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Erreur : ${snap.error}'),
          );
        }
        final d = snap.data!;
        final edl = d.edl;
        final reqs = _requirements(d);
        final asProp = widget.asProprietaire;
        final code = edl.code ?? 'EDL #${edl.id}';
        final contactNom =
            asProp ? (edl.locataireNom ?? '—') : (edl.proprietaireNom ?? '—');
        final contactTel =
            asProp ? edl.locatairePhone : edl.proprietairePhone;
        final contactRole = asProp ? 'Locataire' : 'Bailleur';

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Documents requis pour le bail',
                        style: AppTypography.titleLg),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Bloc contact + code EDL
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppRadius.borderMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$contactRole : $contactNom',
                        style: AppTypography.bodyMd
                            .copyWith(fontWeight: FontWeight.w600)),
                    if (contactTel != null && contactTel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(children: [
                          const Icon(Icons.phone_outlined,
                              size: 14, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          SelectableText(contactTel,
                              style: AppTypography.labelMd.copyWith(
                                  color: AppColors.onSurfaceVariant)),
                        ]),
                      ),
                    const SizedBox(height: 2),
                    SelectableText('Code EDL : $code',
                        style: AppTypography.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text('Éléments nécessaires', style: AppTypography.labelMd),
              const SizedBox(height: AppSpacing.xs),
              ...reqs.map((r) => _reqRow(edl, r)),

              const SizedBox(height: AppSpacing.md),
              if (asProp)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _demanderRemplissage,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.mark_email_unread_outlined, size: 18),
                    label: const Text('Demander le remplissage'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _reqRow(EtatDesLieuxModel edl, _Req r) {
    final canResolve = !widget.asProprietaire &&
        !r.done &&
        r.resolveKind != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            r.done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: r.done ? AppColors.success : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              r.label,
              style: AppTypography.bodyMd.copyWith(
                color: r.done ? AppColors.onSurfaceVariant : null,
                decoration: r.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (canResolve)
            TextButton(
              onPressed: () {
                if (r.resolveKind == 'garant') {
                  _resolveGarant();
                } else if (r.resolveKind == 'signature_locataire') {
                  _resolveSignature(edl);
                }
              },
              child: const Text('Résoudre'),
            ),
        ],
      ),
    );
  }
}

class _Data {
  final EtatDesLieuxModel edl;
  final int garantsCount;
  const _Data({required this.edl, required this.garantsCount});
}
