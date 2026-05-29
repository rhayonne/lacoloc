import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/edl_details.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/observations_edl.dart';
import 'package:lacoloc_front/data/datasources/pieces.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/edl_details.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:lacoloc_front/data/models/observation_edl.dart';
import 'package:lacoloc_front/data/models/piece.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_document_editor.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_select_immeuble_dialog.dart';
import 'package:lacoloc_front/presentation/widgets/form_page_header.dart';
import 'package:lacoloc_front/presentation/widgets/photo_picker_field.dart';
import 'package:lacoloc_front/utils/phone_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/card_delete_button.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

// Larguras fixes des colonnes du tableau EDL (partagées entre header et lignes)
const double _colEtat = 100.0;
const double _colFin = 118.0;
const double _colSit = 158.0;
const double _colBtn = 112.0;
const double _colDel = 36.0;

// ─────────────────────────────────────────────────────────────────────────────

class EtatDesLieuxPage extends StatefulWidget {
  const EtatDesLieuxPage({super.key});

  @override
  State<EtatDesLieuxPage> createState() => _EtatDesLieuxPageState();
}

typedef _PageData = ({List<EtatDesLieuxModel> edls, List<UsersClient> invites});

class _EtatDesLieuxPageState extends State<EtatDesLieuxPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _showForm = false;
  EtatDesLieuxModel? _editingEdl;
  String _formTypeEdl = 'entree';
  bool _showDetail = false;
  EtatDesLieuxModel? _detailEdl;
  // Nouveau flux : page Collectif + non meublée
  bool _showCollectifForm = false;
  ImmeublesModel? _formImmeuble;
  EtatDesLieuxModel? _formEdl; // EDL existant à éditer dans le nouveau flux
  late Future<_PageData> _future;

  /// Démarre un nouvel EDL : popup de sélection d'immeuble puis routage.
  /// Cas géré : Collectif + non meublée → nouvelle page.
  /// Autres cas → SnackBar "en cours de développement".
  Future<void> _startNewEdl(String typeEdl) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final immeubles = await ImmeublesDatasource.listByOwner(uid);
    if (!mounted) return;
    final selected = await showSelectImmeubleDialog(context, immeubles);
    if (selected == null || !mounted) return;
    final isCollectifNonMeublee =
        selected.bailCollectif && selected.locationMeuble == false;
    if (isCollectifNonMeublee) {
      setState(() {
        _showCollectifForm = true;
        _formImmeuble = selected;
        _formEdl = null;
        _formTypeEdl = typeEdl;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce cas est en cours de développement.'),
        ),
      );
    }
  }

  /// Ouvre un EDL existant pour édition.
  /// Collectif + non meublée → nouvelle page. Autres → SnackBar.
  Future<void> _openExistingEdl(EtatDesLieuxModel edl) async {
    if (edl.typeBail != 'collectif') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("L'édition de ce type d'EDL est en cours de développement."),
        ),
      );
      return;
    }
    // Charger l'immeuble pour vérifier location_meuble
    ImmeublesModel? immeuble;
    try {
      final uid = AuthService.currentUser?.id ?? '';
      final list = await ImmeublesDatasource.listByOwner(uid);
      immeuble = list.where((i) => i.id == edl.immeubleId).firstOrNull;
    } catch (_) {}
    if (!mounted) return;
    if (immeuble == null || immeuble.locationMeuble != false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("L'édition de ce type d'EDL est en cours de développement."),
        ),
      );
      return;
    }
    setState(() {
      _showCollectifForm = true;
      _formImmeuble = immeuble;
      _formEdl = edl;
      _formTypeEdl = edl.typeEdl;
    });
  }

  Future<void> _confirmDelete(EtatDesLieuxModel edl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'état des lieux ?'),
        content: Text(
          'Cette action est irréversible. L\'état des lieux du '
          '${_dateFmt.format(edl.dateEtatLieux)} sera définitivement supprimé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: AppTheme.deleteButtonStyle,
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await EtatDesLieuxDatasource.delete(edl.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _future = _load();
  }

  Future<_PageData> _load() async {
    final uid = AuthService.currentUser?.id ?? '';
    final results = await Future.wait([
      EtatDesLieuxDatasource.listByProprietaire(uid),
      EtatDesLieuxDatasource.listInvitedLocataires(uid),
    ]);
    return (
      edls: results[0] as List<EtatDesLieuxModel>,
      invites: results[1] as List<UsersClient>,
    );
  }

  void _reload() {
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showDetail && _detailEdl != null) {
      final edl = _detailEdl!;
      return _EdlDetailProprietairePage(
        edl: edl,
        onClose: () => setState(() {
          _showDetail = false;
          _detailEdl = null;
        }),
        onEditer: () => setState(() {
          _showDetail = false;
          _detailEdl = null;
          _editingEdl = edl;
          _formTypeEdl = edl.typeEdl;
          _showForm = true;
        }),
      );
    }

    if (_showCollectifForm && _formImmeuble != null) {
      return EdlCollectifNonMeubleePage(
        immeuble: _formImmeuble!,
        typeEdl: _formTypeEdl,
        existingEdl: _formEdl,
        onClose: (refresh) {
          setState(() {
            _showCollectifForm = false;
            _formImmeuble = null;
            _formEdl = null;
          });
          if (refresh) _reload();
        },
      );
    }

    if (_showForm) {
      return _EdlFormOverlay(
        existingEdl: _editingEdl,
        typeEdl: _formTypeEdl,
        onClose: (refresh) {
          setState(() {
            _showForm = false;
            _editingEdl = null;
          });
          if (refresh) _reload();
        },
      );
    }

    return FutureBuilder<_PageData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final data = snapshot.data;
        final all = data?.edls ?? [];
        final invites = data?.invites ?? [];
        final entrees = all.where((e) => e.typeEdl == 'entree').toList();
        final sorties = all.where((e) => e.typeEdl == 'sortie').toList();

        void openForm(String type, [EtatDesLieuxModel? edl]) {
          if (edl == null) {
            _startNewEdl(type);
            return;
          }
          // Édition d'un EDL existant : nouveau flux ou SnackBar.
          _openExistingEdl(edl);
        }

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
                  Tab(text: 'Vision générale'),
                  Tab(text: 'Entrée'),
                  Tab(text: 'Sortie'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _VisionGeneraleTab(
                    all: all,
                    invitedLocataires: invites,
                    onNouveau: () => openForm('entree'),
                    onVoir: (e) {
                      if (e.situation == SituationEdl.enCours) {
                        openForm(e.typeEdl, e);
                      } else {
                        setState(() {
                          _detailEdl = e;
                          _showDetail = true;
                        });
                      }
                    },
                    onEditer: (e) => openForm(e.typeEdl, e),
                    onDelete: (e) => _confirmDelete(e),
                  ),
                  _EdlListTab(
                    edls: entrees,
                    title: "États des lieux d'entrée",
                    onNouveau: () => openForm('entree'),
                    onVoir: (e) {
                      if (e.situation == SituationEdl.enCours) {
                        openForm('entree', e);
                      } else {
                        setState(() {
                          _detailEdl = e;
                          _showDetail = true;
                        });
                      }
                    },
                    onEditer: (e) => openForm('entree', e),
                    onDelete: (e) => _confirmDelete(e),
                  ),
                  _EdlListTab(
                    edls: sorties,
                    title: 'États des lieux de sortie',
                    onNouveau: () => openForm('sortie'),
                    onVoir: (e) {
                      if (e.situation == SituationEdl.enCours) {
                        openForm('sortie', e);
                      } else {
                        setState(() {
                          _detailEdl = e;
                          _showDetail = true;
                        });
                      }
                    },
                    onEditer: (e) => openForm('sortie', e),
                    onDelete: (e) => _confirmDelete(e),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 : Vision générale

class _VisionGeneraleTab extends StatelessWidget {
  final List<EtatDesLieuxModel> all;
  final List<UsersClient> invitedLocataires;
  final VoidCallback onNouveau;
  final ValueChanged<EtatDesLieuxModel> onVoir;
  final ValueChanged<EtatDesLieuxModel>? onEditer;
  final ValueChanged<EtatDesLieuxModel>? onDelete;

  const _VisionGeneraleTab({
    required this.all,
    required this.invitedLocataires,
    required this.onNouveau,
    required this.onVoir,
    this.onEditer,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = today.add(const Duration(days: 3));
    final urgentsCount = all.where((e) {
      final d = DateTime(
        e.dateEtatLieux.year,
        e.dateEtatLieux.month,
        e.dateEtatLieux.day,
      );
      return !d.isBefore(today) && !d.isAfter(deadline);
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 720;
              final stat = _StatCard(
                label: 'Urgents',
                sublabel: 'dans les 3 prochains jours',
                value: urgentsCount,
                color: AppColors.error,
              );
              final invites =
                  _LocatairesInvitesCard(locataires: invitedLocataires);
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    stat,
                    const SizedBox(height: AppSpacing.md),
                    invites,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: stat),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: invites),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          _EdlTableCard(
            edls: all,
            title: 'Tous les états des lieux',
            onNouveau: onNouveau,
            onVoir: onVoir,
            onEditer: onEditer,
            onDelete: onDelete,
            shrinkWrap: true,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card locataires invités

class _LocatairesInvitesCard extends StatefulWidget {
  final List<UsersClient> locataires;

  const _LocatairesInvitesCard({required this.locataires});

  @override
  State<_LocatairesInvitesCard> createState() => _LocatairesInvitesCardState();
}

class _LocatairesInvitesCardState extends State<_LocatairesInvitesCard> {
  @override
  Widget build(BuildContext context) {
    final count = widget.locataires.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowTint.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Locataires invités',
                    style: AppTypography.titleLg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$count invitation${count > 1 ? 's' : ''}',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (widget.locataires.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Aucun locataire invité.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.locataires.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final loc = widget.locataires[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      _InitialsAvatar(name: loc.fullName ?? loc.email),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.fullName ?? '—',
                              style: AppTypography.bodyMd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              loc.email,
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar avec initiales

class _InitialsAvatar extends StatelessWidget {
  final String name;
  static const double size = 36;

  const _InitialsAvatar({required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primaryFixed,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onPrimaryFixedVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabs 2 & 3 : Entrée / Sortie

class _EdlListTab extends StatelessWidget {
  final List<EtatDesLieuxModel> edls;
  final String title;
  final VoidCallback onNouveau;
  final ValueChanged<EtatDesLieuxModel> onVoir;
  final ValueChanged<EtatDesLieuxModel>? onEditer;
  final ValueChanged<EtatDesLieuxModel>? onDelete;

  const _EdlListTab({
    required this.edls,
    required this.title,
    required this.onNouveau,
    required this.onVoir,
    this.onEditer,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: _EdlTableCard(
        edls: edls,
        title: title,
        onNouveau: onNouveau,
        onVoir: onVoir,
        onEditer: onEditer,
        onDelete: onDelete,
        shrinkWrap: false,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Container style Finances — réutilisé dans Vision générale et les tabs

class _EdlTableCard extends StatefulWidget {
  final List<EtatDesLieuxModel> edls;
  final String title;
  final VoidCallback onNouveau;
  final ValueChanged<EtatDesLieuxModel> onVoir;
  final ValueChanged<EtatDesLieuxModel>? onEditer;
  final ValueChanged<EtatDesLieuxModel>? onDelete;

  /// true → shrinkWrap (pour SingleChildScrollView parent),
  /// false → Expanded (pour tab plein écran)
  final bool shrinkWrap;

  const _EdlTableCard({
    required this.edls,
    required this.title,
    required this.onNouveau,
    required this.onVoir,
    required this.shrinkWrap,
    this.onEditer,
    this.onDelete,
  });

  @override
  State<_EdlTableCard> createState() => _EdlTableCardState();
}

class _EdlTableCardState extends State<_EdlTableCard> {
  String _query = '';
  SituationEdl? _filterSituation;

  List<EtatDesLieuxModel> get _filtered => widget.edls.where((e) {
    if (_filterSituation != null && e.situation != _filterSituation) {
      return false;
    }
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return (e.locataireNom?.toLowerCase().contains(q) ?? false) ||
        (e.locataireEmail?.toLowerCase().contains(q) ?? false) ||
        (e.immeubleNom?.toLowerCase().contains(q) ?? false) ||
        (e.chambreNom?.toLowerCase().contains(q) ?? false);
  }).toList();

  int _countSituation(SituationEdl s) =>
      widget.edls.where((e) => e.situation == s).length;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _buildCard(
        context,
        isNarrow: constraints.maxWidth < 900,
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required bool isNarrow}) {
    final filtered = _filtered;
    final totalCount = widget.edls.length;

    final chips = [
      _SituationFilterChip(
        label: 'Toutes',
        count: totalCount,
        selected: _filterSituation == null,
        onTap: () => setState(() => _filterSituation = null),
      ),
      ...SituationEdl.values.map(
        (s) => _SituationFilterChip(
          label: s.label,
          count: _countSituation(s),
          selected: _filterSituation == s,
          onTap: () => setState(
            () => _filterSituation = _filterSituation == s ? null : s,
          ),
        ),
      ),
    ];

    final searchField = TextField(
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Rechercher locataire, immeuble…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _query = ''),
              )
            : null,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: AppSpacing.md,
        ),
      ),
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.title,
                    style: AppTypography.titleLg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _CountBadge(count: totalCount),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.icon(
            onPressed: widget.onNouveau,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouveau'),
          ),
        ],
      ),
    );

    final searchAndFilters = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chipsRow = Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: chips,
          );
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: AppSpacing.sm),
                chipsRow,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: AppSpacing.md),
              Flexible(child: chipsRow),
            ],
          );
        },
      ),
    );

    final columnHeaders = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 6,
      ),
      child: Row(
        children: [
          // avatar placeholder
          const SizedBox(width: _InitialsAvatar.size + AppSpacing.md),
          Expanded(
            flex: 3,
            child: Text(
              'LOCATAIRE',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              'IMMEUBLE',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _colEtat,
            child: Text(
              'DATE EDL',
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _colFin,
            child: Text(
              'FINALISATION',
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _colSit,
            child: Text(
              'SITUATION',
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(width: _colBtn),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(width: _colDel),
        ],
      ),
    );

    final listWidget = filtered.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text(
                widget.edls.isEmpty
                    ? 'Aucun état des lieux.'
                    : 'Aucun résultat pour « $_query ».',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: widget.shrinkWrap,
            physics: widget.shrinkWrap
                ? const NeverScrollableScrollPhysics()
                : null,
            padding: EdgeInsets.zero,
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => _EdlRow(
              edl: filtered[i],
              compact: isNarrow,
              onVoir: () => widget.onVoir(filtered[i]),
              onEditer: widget.onEditer != null
                  ? () => widget.onEditer!(filtered[i])
                  : null,
              onDelete: widget.onDelete != null
                  ? () => widget.onDelete!(filtered[i])
                  : null,
            ),
          );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowTint.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
          header,
          const Divider(height: 1),
          searchAndFilters,
          const Divider(height: 1),
          if (!isNarrow) ...[
            columnHeaders,
            const Divider(height: 1),
          ],
          if (widget.shrinkWrap) listWidget else Expanded(child: listWidget),
        ],
      ),
    );
  }
}

class _EdlRow extends StatelessWidget {
  final EtatDesLieuxModel edl;
  final VoidCallback onVoir;
  final VoidCallback? onEditer;
  final VoidCallback? onDelete;
  final bool compact;

  const _EdlRow({
    required this.edl,
    required this.onVoir,
    this.onEditer,
    this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final typeBailLabel = edl.typeBail == 'collectif'
        ? 'Colocation'
        : 'Individuel';
    return compact ? _buildCompact(typeBailLabel) : _buildWide(typeBailLabel);
  }

  Widget _buildCompact(String typeBailLabel) {
    final locataireASigner =
        edl.situation == SituationEdl.finalise && !edl.locataireAccepte;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _InitialsAvatar(
                name: edl.locataireNom ?? edl.locataireEmail ?? '?',
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      edl.locataireNom ?? edl.locataireEmail ?? '—',
                      style: AppTypography.bodyMd
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (edl.locataireNom != null && edl.locataireEmail != null)
                      Text(
                        edl.locataireEmail!,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            edl.immeubleNom ?? '—',
            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            edl.chambreNom != null
                ? '${edl.chambreNom} · $typeBailLabel'
                : typeBailLabel,
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _kv('ÉTAT', edl.dateEdlFormatted),
              ),
              Expanded(
                child: _kv(
                  'FINALISATION',
                  edl.dateFinalisationFormatted ?? '—',
                  muted: edl.dateFinalisation == null,
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
                  locataireASigner
                      ? _LocataireASignerBadge()
                      : _SituationBadge(situation: edl.situation),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onVoir,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Continuer'),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: _colDel,
                  height: 36,
                  child: FilledButton(
                    onPressed: onDelete,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderMd,
                      ),
                    ),
                    child: const Icon(Icons.delete_outline, size: 18),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool muted = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
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
            value,
            style: AppTypography.bodyMd.copyWith(
              color: muted ? AppColors.onSurfaceVariant : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );

  Widget _buildWide(String typeBailLabel) {
    // Locataire à signer: finalisé par propriétaire mais pas encore accepté par locataire
    final locataireASigner =
        edl.situation == SituationEdl.finalise && !edl.locataireAccepte;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          _InitialsAvatar(name: edl.locataireNom ?? edl.locataireEmail ?? '?'),
          const SizedBox(width: AppSpacing.md),

          // LOCATAIRE (flex 3)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edl.locataireNom ?? edl.locataireEmail ?? '—',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (edl.locataireNom != null && edl.locataireEmail != null)
                  Text(
                    edl.locataireEmail!,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // IMMEUBLE (flex 2)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edl.immeubleNom ?? '—',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  edl.chambreNom != null
                      ? '${edl.chambreNom} · $typeBailLabel'
                      : typeBailLabel,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // DATE EDL
          SizedBox(
            width: _colEtat,
            child: Text(
              edl.dateEdlFormatted,
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // FINALISATION (date ou —)
          SizedBox(
            width: _colFin,
            child: Text(
              edl.dateFinalisationFormatted ?? '—',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: edl.dateFinalisation == null
                    ? AppColors.onSurfaceVariant
                    : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // SITUATION
          SizedBox(
            width: _colSit,
            child: Center(
              child: locataireASigner
                  ? _LocataireASignerBadge()
                  : _SituationBadge(situation: edl.situation),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Bouton Continuer
          SizedBox(
            width: _colBtn,
            child: FilledButton.icon(
              onPressed: onVoir,
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Continuer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: _colDel,
            height: 32,
            child: FilledButton(
              onPressed: onDelete,
              style: FilledButton.styleFrom(
                backgroundColor:
                    onDelete != null ? AppColors.error : AppColors.outlineVariant,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderMd,
                ),
              ),
              child: const Icon(Icons.delete_outline, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compteur en pill (à côté du titre)

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(
        '$count',
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip de filtre avec compteur intégré

class _SituationFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SituationFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : AppColors.surfaceContainerLowest;
    final fg = selected ? AppColors.onPrimary : AppColors.onSurface;
    final badgeBg = selected
        ? AppColors.onPrimary.withValues(alpha: 0.18)
        : AppColors.surfaceContainerHigh;
    final borderColor = selected ? AppColors.primary : AppColors.outlineVariant;

    return InkWell(
      borderRadius: AppRadius.borderFull,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: AppRadius.borderFull,
              ),
              child: Text(
                '$count',
                style: AppTypography.labelSm.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulaire

class _FormBundle {
  final List<ImmeublesModel> immeubles;
  final List<ChambreModel> allChambres;
  final String? bailleurNom;
  const _FormBundle({
    required this.immeubles,
    required this.allChambres,
    this.bailleurNom,
  });
}

class _EdlFormOverlay extends StatefulWidget {
  final EtatDesLieuxModel? existingEdl;
  final String typeEdl;
  final void Function(bool refresh) onClose;

  const _EdlFormOverlay({
    this.existingEdl,
    required this.typeEdl,
    required this.onClose,
  });

  bool get isEditing => existingEdl != null;

  @override
  State<_EdlFormOverlay> createState() => _EdlFormOverlayState();
}

class _EdlFormOverlayState extends State<_EdlFormOverlay> {
  // Sélections
  UsersClient? _locataire;
  ImmeublesModel? _immeuble;
  ChambreModel? _chambre;
  DateTime _dateEdl = DateTime.now();
  final _montantCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // ── Champs « BIEN » (en-tête du document) ──────────────────────────────────
  final _surfaceCtrl = TextEditingController();
  final _piecesCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _etageCtrl = TextEditingController();
  final _bailleurNomCtrl = TextEditingController();
  final _bailleurAdrCtrl = TextEditingController();
  final _nouvelleAdrCtrl = TextEditingController();
  final _lieuRedactionCtrl = TextEditingController();
  final _exemplairesCtrl = TextEditingController();

  // Recherche locataire
  final _locataireSearchCtrl = TextEditingController();
  List<UsersClient> _searchResults = [];
  bool _showLocataireResults = false;
  bool _searchingLocataires = false;
  Timer? _debounce;

  // Données du formulaire
  late Future<_FormBundle> _formBundleFuture;
  List<ChambreModel> _chambresForImmeuble = [];
  List<PieceModel> _piecesForImmeuble = []; // pièces du bien (EDL collectif)

  bool _isSaving = false;
  bool _isFinalising = false;
  bool _isDeleting = false;

  // Steps
  int _currentStep = 0;
  int _stepCount = 1; // mis à jour à chaque build (voir _buildSteps)
  Set<int> _headerStepIndices = {}; // indices dos steps que são separadores de seção
  List<ObservationEdl> _observations = [];
  bool _loadingObs = false;
  int? _newEdlId; // ID do EDL recém-criado (null quando editando existente)
  int? get _currentEdlId => _newEdlId ?? widget.existingEdl?.id;

  /// La 2e étape est utilisable quand l'immeuble est en bail individuel,
  /// une chambre est sélectionnée et l'EDL a déjà été enregistré au moins
  /// une fois (pour pouvoir attacher des observations).
  bool get _canUseStep2 =>
      _immeuble?.bailIndividuel == true &&
      _chambre != null &&
      _currentEdlId != null;

  @override
  void initState() {
    super.initState();
    _formBundleFuture = _loadBundle().then((bundle) {
      if (!mounted) return bundle;
      // Pre-fill bailleur name from proprietaire profile if not already set
      if (_bailleurNomCtrl.text.isEmpty && bundle.bailleurNom != null) {
        _bailleurNomCtrl.text = bundle.bailleurNom!;
      }
      if (widget.existingEdl != null) {
        final edl = widget.existingEdl!;
        final imm = bundle.immeubles
            .where((i) => i.id == edl.immeubleId)
            .firstOrNull;
        if (imm != null) {
          setState(() {
            _immeuble = imm;
            _chambresForImmeuble = bundle.allChambres
                .where((c) => c.immeubleId == imm.id)
                .toList();
            if (edl.chambreId != null) {
              _chambre = bundle.allChambres
                  .where((c) => c.id == edl.chambreId)
                  .firstOrNull;
            }
          });
          _loadPieces(imm.id);
        }
      }
      return bundle;
    });
    _initFromExisting();
    if (widget.existingEdl != null) _loadObservations();
  }

  Future<_FormBundle> _loadBundle() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) {
      return const _FormBundle(immeubles: [], allChambres: []);
    }
    final immeubles = await ImmeublesDatasource.listByOwner(uid);
    final ids = immeubles.map((i) => i.id).toList();
    final chambres = await ChambresDatasource.listByImmeubles(ids);
    String? bailleurNom;
    try {
      final profile = await AuthService.loadCurrentProfile();
      bailleurNom = profile?.fullName;
    } catch (_) {}
    return _FormBundle(
      immeubles: immeubles,
      allChambres: chambres,
      bailleurNom: bailleurNom,
    );
  }

  void _initFromExisting() {
    final edl = widget.existingEdl;
    if (edl == null) return;
    _dateEdl = edl.dateEtatLieux;
    _montantCtrl.text = edl.montant?.toStringAsFixed(2) ?? '';
    _notesCtrl.text = edl.notes ?? '';
    _surfaceCtrl.text = edl.surfaceM2?.toString() ?? '';
    _piecesCtrl.text = edl.nombrePiecesPrincipales?.toString() ?? '';
    _designationCtrl.text = edl.designation ?? '';
    _etageCtrl.text = edl.etage ?? '';
    _bailleurNomCtrl.text = edl.bailleurNom ?? '';
    _bailleurAdrCtrl.text = edl.bailleurAdresse ?? '';
    _nouvelleAdrCtrl.text = edl.nouvelleAdresse ?? '';
    _lieuRedactionCtrl.text = edl.lieuRedaction ?? '';
    _exemplairesCtrl.text = edl.nombreExemplaires ?? '';
    final loId = edl.locataireId;
    if (loId != null && loId.isNotEmpty) {
      _locataire = UsersClient(
        id: loId,
        createdAt: DateTime.now(),
        email: edl.locataireEmail ?? '',
        fullName: edl.locataireNom,
        phone: edl.locatairePhone,
      );
      _locataireSearchCtrl.text = _locataireLabel(_locataire!);
      // Se os dados do join estão vazios (RLS ou ausência de dados), busca separado
      if (_locataire!.email.isEmpty && _locataire!.fullName == null) {
        _fetchLocataireSiManquant(_locataire!.id);
      }
    }
  }

  Future<void> _fetchLocataireSiManquant(String id) async {
    try {
      final loc = await EtatDesLieuxDatasource.getLocataireById(id);
      if (mounted && loc != null) {
        setState(() {
          _locataire = loc;
          _locataireSearchCtrl.text = _locataireLabel(loc);
        });
      }
    } catch (_) {
      // Falha silenciosa — o chip ainda mostra o ID
    }
  }

  String _locataireLabel(UsersClient loc) {
    final name = loc.fullName?.trim() ?? '';
    return name.isNotEmpty ? '$name (${loc.email})' : loc.email;
  }

  void _onLocataireSearch(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _showLocataireResults = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _searchingLocataires = true);
      try {
        final results = await EtatDesLieuxDatasource.searchLocataires(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _showLocataireResults = true;
          });
        }
      } finally {
        if (mounted) setState(() => _searchingLocataires = false);
      }
    });
  }

  void _selectLocataire(UsersClient loc) {
    setState(() {
      _locataire = loc;
      _locataireSearchCtrl.text = _locataireLabel(loc);
      _showLocataireResults = false;
      _searchResults = [];
    });
  }

  void _clearLocataire() {
    setState(() {
      _locataire = null;
      _locataireSearchCtrl.clear();
      _showLocataireResults = false;
      _searchResults = [];
    });
  }

  void _selectImmeuble(ImmeublesModel? imm, List<ChambreModel> allChambres) {
    setState(() {
      _immeuble = imm;
      _chambre = null;
      _currentStep = 0;
      _chambresForImmeuble = imm != null
          ? allChambres.where((c) => c.immeubleId == imm.id).toList()
          : [];
      _piecesForImmeuble = [];
    });
    // Charger les pièces du bien (plan de murs par pièce — EDL collectif)
    if (imm != null) _loadPieces(imm.id);
    // Auto-fill surface m² depuis l'immeuble (bail collectif)
    if (imm?.bailCollectif == true && imm?.totalM2 != null) {
      _surfaceCtrl.text = imm!.totalM2!.toStringAsFixed(0);
    } else {
      _surfaceCtrl.clear(); // bail individuel → rempli à la sélection de chambre
    }
    // Auto-fill adresse bailleur depuis l'immeuble
    if (imm != null) {
      final parts = [imm.address, imm.city]
          .where((s) => s != null && s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) _bailleurAdrCtrl.text = parts.join(', ');
    }
    // Auto-fill loyer
    if (imm?.bailCollectif == true && imm?.prixLoyer != null) {
      _montantCtrl.text = imm!.prixLoyer!.toStringAsFixed(2);
    } else {
      _montantCtrl.clear();
    }
  }

  void _selectChambre(ChambreModel? ch) {
    setState(() {
      _chambre = ch;
      if (ch == null && _currentStep > 0) _currentStep = 0;
    });
    // Auto-fill surface m² depuis la chambre (bail individuel)
    if (_immeuble?.bailIndividuel == true && ch?.m2 != null) {
      _surfaceCtrl.text = ch!.m2!.toStringAsFixed(0);
    } else if (ch == null) {
      _surfaceCtrl.clear();
    }
    // Auto-fill loyer de la chambre
    if (_immeuble?.bailIndividuel == true && ch?.prixLoyer != null) {
      _montantCtrl.text = ch!.prixLoyer!.toStringAsFixed(2);
    }
  }

  SituationEdl get _computedSituation => SituationEdl.fromDate(_dateEdl);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateEdl,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('fr'),
    );
    if (picked != null && mounted) setState(() => _dateEdl = picked);
  }

  Future<bool> _saveInternal() async {
    if (_locataire == null) {
      _snack('Sélectionnez un locataire.');
      return false;
    }
    if (_immeuble == null) {
      _snack('Sélectionnez un immeuble.');
      return false;
    }
    if ((_immeuble?.bailIndividuel ?? false) &&
        _chambresForImmeuble.isNotEmpty &&
        _chambre == null) {
      _snack('Sélectionnez une chambre.');
      return false;
    }

    setState(() => _isSaving = true);
    try {
      final uid = AuthService.currentUser?.id ?? '';
      final montant = double.tryParse(
        _montantCtrl.text.trim().replaceAll(',', '.'),
      );
      final notes = _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim();

      String? t(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      final bien = <String, dynamic>{
        'surface_m2': double.tryParse(_surfaceCtrl.text.replaceAll(',', '.')),
        'nombre_pieces_principales': int.tryParse(_piecesCtrl.text),
        'designation': t(_designationCtrl),
        'etage': t(_etageCtrl),
        'bailleur_nom': t(_bailleurNomCtrl),
        'bailleur_adresse': t(_bailleurAdrCtrl),
        'nouvelle_adresse': t(_nouvelleAdrCtrl),
        'lieu_redaction': t(_lieuRedactionCtrl),
        'nombre_exemplaires': t(_exemplairesCtrl),
      };

      // Déjà enregistré (édition d'un EDL existant OU re-sauvegarde d'un EDL
      // créé à l'étape précédente) → update. Sinon → create.
      final existingId = _currentEdlId;
      if (existingId != null) {
        // Mise à jour : ne pas toucher la colonne observations (gérée par la nouvelle table)
        final updates = <String, dynamic>{
          'locataire_id': _locataire!.id,
          'immeuble_id': _immeuble!.id,
          if (_chambre != null) 'chambre_id': _chambre!.id,
          'type_bail': _immeuble!.bailCollectif ? 'collectif' : 'individuel',
          'type_edl': widget.typeEdl,
          'date_etat_lieux': _dateEdl.toIso8601String().substring(0, 10),
          'situation': _computedSituation.raw,
          'montant': ?montant,
          'notes': notes,
          ...bien,
        };
        await EtatDesLieuxDatasource.update(existingId, updates);
      } else {
        // Bail individuel + chambre sélectionnée → EDL « privative » lié au
        // EDL « commune » (collectif) partagé de l'immeuble. Sinon → « commune ».
        final typeBail = _immeuble!.bailCollectif ? 'collectif' : 'individuel';
        final isPrivative = _immeuble!.bailIndividuel && _chambre != null;

        int? collectifId;
        if (isPrivative) {
          collectifId = await EtatDesLieuxDatasource.ensureCollectif(
            EtatDesLieuxModel(
              id: 0,
              proprietaireId: uid,
              locataireId: _locataire!.id,
              immeubleId: _immeuble!.id,
              typeBail: typeBail,
              typeEdl: widget.typeEdl,
              dateEtatLieux: _dateEdl,
              situation: _computedSituation,
              createdAt: DateTime.now(),
              partie: PartieEdl.commune,
            ),
          );
        }

        final edl = EtatDesLieuxModel(
          id: 0,
          proprietaireId: uid,
          locataireId: _locataire!.id,
          immeubleId: _immeuble!.id,
          chambreId: _chambre?.id,
          typeBail: typeBail,
          typeEdl: widget.typeEdl,
          dateEtatLieux: _dateEdl,
          situation: _computedSituation,
          createdAt: DateTime.now(),
          montant: montant,
          notes: notes,
          observations: const {},
          partie: isPrivative ? PartieEdl.privative : PartieEdl.commune,
          edlCollectifId: collectifId,
          surfaceM2: double.tryParse(_surfaceCtrl.text.replaceAll(',', '.')),
          nombrePiecesPrincipales: int.tryParse(_piecesCtrl.text),
          designation: t(_designationCtrl),
          etage: t(_etageCtrl),
          bailleurNom: t(_bailleurNomCtrl),
          bailleurAdresse: t(_bailleurAdrCtrl),
          nouvelleAdresse: t(_nouvelleAdrCtrl),
          lieuRedaction: t(_lieuRedactionCtrl),
          nombreExemplaires: t(_exemplairesCtrl),
        );
        final created = await EtatDesLieuxDatasource.create(edl);
        if (mounted) setState(() => _newEdlId = created.id);

        // Auto-import depuis l'inventaire (immeuble → collectif, chambre → privatif)
        await _autoSeedFromInventaire(
          collectifId: isPrivative ? collectifId : created.id,
          privatifId: isPrivative ? created.id : null,
        );
      }
      return true;
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Importe automatiquement les équipements de l'inventaire :
  ///  • les pièces communes (Pieces) + leurs articles → EDL collectif
  ///  • les articles liés à la chambre → EDL privatif
  /// Idempotent : ne fait rien si l'EDL a déjà des sections.
  Future<void> _autoSeedFromInventaire({
    required int? collectifId,
    int? privatifId,
  }) async {
    final imm = _immeuble;
    if (imm == null) return;
    try {
      final pieces = await PiecesDatasource.listByImmeuble(imm.id);
      final items = await InventaireDatasource.listByImmeuble(imm.id);

      EdlLigne ligneFrom(InventaireModel it, int ordre) => EdlLigne(
        sectionId: 0,
        equipement: it.displayNom,
        natureNombre: it.quantite > 0 ? it.quantite.toString() : null,
        ordre: ordre,
      );

      // ── Collectif : une section par pièce commune ──────────────────────────
      if (collectifId != null) {
        final existing = await EdlDetailsDatasource.listSections(collectifId);
        if (existing.isEmpty) {
          for (var pi = 0; pi < pieces.length; pi++) {
            final p = pieces[pi];
            final lignes = items
                .where((it) => it.pieceId == p.id)
                .toList()
                .asMap()
                .entries
                .map((e) => ligneFrom(e.value, e.key))
                .toList();
            await EdlDetailsDatasource.createSectionWithLignes(
              EdlSection(
                etatDesLieuxId: collectifId,
                nom: p.nom.toUpperCase(),
                ordre: pi,
              ),
              lignes,
            );
          }
        }
      }

      // ── Privatif : une section pour la chambre ─────────────────────────────
      if (privatifId != null && _chambre != null) {
        final existing = await EdlDetailsDatasource.listSections(privatifId);
        if (existing.isEmpty) {
          final lignes = items
              .where((it) => it.chambreId == _chambre!.id)
              .toList()
              .asMap()
              .entries
              .map((e) => ligneFrom(e.value, e.key))
              .toList();
          await EdlDetailsDatasource.createSectionWithLignes(
            EdlSection(
              etatDesLieuxId: privatifId,
              nom: 'CHAMBRE — ${_chambre!.roomName}'.toUpperCase(),
            ),
            lignes,
          );
        }
      }
    } catch (_) {
      // Best-effort : l'import ne doit pas bloquer la création de l'EDL.
    }
  }

  Future<void> _save() async {
    final ok = await _saveInternal();
    if (ok && mounted) widget.onClose(true);
  }

  Future<void> _saveAndNextStep() async {
    final ok = await _saveInternal();
    if (!ok || !mounted) return;
    await _loadObservations();
    var next = _currentStep + 1;
    // Pular separadores de seção (não são steps reais)
    while (_headerStepIndices.contains(next) && next < _stepCount - 1) {
      next++;
    }
    if (mounted) setState(() => _currentStep = next);
  }

  /// Le formulaire représente un EDL « privatif » (bail individuel + chambre) ?
  /// Sinon c'est un EDL « commune » (collectif).
  bool get _isPrivativeForm {
    final e = widget.existingEdl;
    if (e != null) return e.partie == PartieEdl.privative;
    return _immeuble?.bailIndividuel == true;
  }

  /// Placeholder affiché dans les étapes « document » tant que l'EDL n'est pas
  /// encore enregistré (les tables filles ont besoin de l'id de l'EDL).
  Widget _docPlaceholder() => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: AppRadius.borderMd,
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            "Enregistrez d'abord les informations (« Suivant ») pour remplir cette section.",
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    ),
  );

  /// Contenu de l'étape « Le bien » (en-tête du document).
  Widget _buildStepBien() {
    Widget field(TextEditingController c, String label,
            {TextInputType? keyboard}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(label),
              TextField(
                controller: c,
                keyboardType: keyboard,
                decoration: const InputDecoration(isDense: true),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: field(_surfaceCtrl, 'SURFACE (m²)',
                    keyboard: TextInputType.number)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: field(_piecesCtrl, 'PIÈCES PRINCIPALES',
                    keyboard: TextInputType.number)),
          ],
        ),
        field(_designationCtrl, 'DÉSIGNATION DES LOCAUX'),
        field(_etageCtrl, 'ÉTAGE'),
        field(_bailleurNomCtrl, 'BAILLEUR — NOM'),
        field(_bailleurAdrCtrl, 'BAILLEUR — ADRESSE'),
        if (widget.typeEdl == 'sortie')
          field(_nouvelleAdrCtrl, 'NOUVELLE ADRESSE (sortie)'),
        Row(
          children: [
            Expanded(child: field(_lieuRedactionCtrl, 'FAIT À')),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: field(_exemplairesCtrl, "NOMBRE D'EXEMPLAIRES")),
          ],
        ),
      ],
    );
  }

  Future<void> _finaliser() async {
    // Pour un nouveau EDL pas encore enregistré, sauvegarder d'abord
    if (_currentEdlId == null) {
      final ok = await _saveInternal();
      if (!ok || !mounted) return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finaliser l\'état des lieux'),
        content: const Text(
          'Cette action finalisera l\'état des lieux. '
          'La date de finalisation sera enregistrée uniquement '
          'lorsque le locataire l\'aura accepté. '
          'Voulez-vous continuer ?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppTheme.cancelButtonStyle,
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finaliser'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isFinalising = true);
    try {
      await EtatDesLieuxDatasource.finaliser(_currentEdlId!);
      if (mounted) widget.onClose(true);
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isFinalising = false);
    }
  }

  Future<void> _openCreerLocataireDialog() async {
    final uid = AuthService.currentUser?.id ?? '';
    final result = await showDialog<UsersClient>(
      context: context,
      builder: (ctx) => _CreerLocataireDialog(proprietaireId: uid),
    );
    if (result != null && mounted) _selectLocataire(result);
  }

  Future<void> _deleteEdl() async {
    final id = _currentEdlId;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'état des lieux'),
        content: const Text(
          'Cette action est irréversible. '
          'L\'état des lieux et toutes ses données associées seront supprimés.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppTheme.cancelButtonStyle,
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
    if (confirm != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await EtatDesLieuxDatasource.delete(id);
      if (mounted) widget.onClose(true);
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _debounce?.cancel();
    _montantCtrl.dispose();
    _notesCtrl.dispose();
    _locataireSearchCtrl.dispose();
    _surfaceCtrl.dispose();
    _piecesCtrl.dispose();
    _designationCtrl.dispose();
    _etageCtrl.dispose();
    _bailleurNomCtrl.dispose();
    _bailleurAdrCtrl.dispose();
    _nouvelleAdrCtrl.dispose();
    _lieuRedactionCtrl.dispose();
    _exemplairesCtrl.dispose();
    super.dispose();
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

  Widget _buildStep0Content(_FormBundle bundle, bool isFinalized) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Locataire ─────────────────────────────────────────────────
        _fieldLabel('LOCATAIRE'),
        if (_locataire != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.15),
              borderRadius: AppRadius.borderSm,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryFixed,
                  child: Text(
                    ((_locataire!.fullName ?? _locataire!.email).isNotEmpty
                        ? (_locataire!.fullName ?? _locataire!.email)
                              .substring(0, 1)
                              .toUpperCase()
                        : '?'),
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onPrimaryFixedVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_locataire!.fullName != null)
                        Text(
                          _locataire!.fullName!,
                          style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(
                        _locataire!.email,
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _clearLocataire,
                  tooltip: 'Changer de locataire',
                ),
              ],
            ),
          )
        else ...[
          _LocataireSearchField(
            controller: _locataireSearchCtrl,
            selected: _locataire,
            results: _searchResults,
            showResults: _showLocataireResults,
            searching: _searchingLocataires,
            onSearch: _onLocataireSearch,
            onSelect: _selectLocataire,
            onClear: _clearLocataire,
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openCreerLocataireDialog,
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Créer un nouveau locataire'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),

        // ── Immeuble ──────────────────────────────────────────────────
        _fieldLabel('IMMEUBLE'),
        _ImmeubleDropdown(
          immeubles: bundle.immeubles,
          allChambres: bundle.allChambres,
          selected: _immeuble,
          onChanged: (imm) => _selectImmeuble(imm, bundle.allChambres),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Chambre (seulement pour bail individuel) ──────────────────
        if (_immeuble != null && _immeuble!.bailIndividuel) ...[
          _fieldLabel('CHAMBRE'),
          _ChambreDropdown(
            chambres: _chambresForImmeuble,
            selected: _chambre,
            onChanged: _selectChambre,
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Date ──────────────────────────────────────────────────────
        _fieldLabel('DATE ÉTAT DES LIEUX'),
        InkWell(
          onTap: _pickDate,
          borderRadius: AppRadius.borderSm,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderSm,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dateFmt.format(_dateEdl),
                    style: AppTypography.bodyMd,
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              'Situation : ',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            _SituationBadge(situation: _computedSituation),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Montant ───────────────────────────────────────────────────
        _fieldLabel('MONTANT (€)'),
        TextField(
          controller: _montantCtrl,
          readOnly: true,
          decoration: InputDecoration(
            prefixText: '€ ',
            hintText: 'Sélectionnez un immeuble',
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            helperText: _immeuble == null
                ? null
                : _immeuble!.bailCollectif
                ? 'Loyer global de l\'immeuble'
                : 'Loyer de la chambre sélectionnée',
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Notes ─────────────────────────────────────────────────────
        _fieldLabel('NOTES'),
        TextField(
          controller: _notesCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Observations, remarques…',
            alignLabelWithHint: true,
          ),
        ),

        // ── Statut finalisation ────────────────────────────────────────
        if (isFinalized) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.secondaryFixed.withValues(alpha: 0.3),
              borderRadius: AppRadius.borderMd,
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.4),
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
                    widget.existingEdl!.locataireAccepte
                        ? 'Finalisé et accepté par le locataire.'
                        : 'Finalisé — en attente d\'acceptation du locataire.',
                    style: AppTypography.bodyMd,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep1Placeholder() {
    String message;
    if (_immeuble == null) {
      message = 'Sélectionnez d\'abord un immeuble dans l\'étape précédente.';
    } else if (_immeuble!.bailIndividuel != true) {
      message = 'Cette étape n\'est disponible que pour les baux individuels.';
    } else if (_chambre == null) {
      message = 'Sélectionnez une chambre dans l\'étape précédente.';
    } else {
      message =
          'Enregistrez d\'abord les informations en cliquant sur « Suivant ».';
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoomDiagram(
          chambreName: _chambre?.roomName ?? '',
          chambrePhoto:
              _chambre?.mainPhoto ??
              (_chambre?.roomPhotos.isNotEmpty == true
                  ? _chambre!.roomPhotos.first
                  : null),
          observations: _observations,
          onEditWall: _openWallDialog,
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _currentEdlId != null
                ? () => _openGeneralObsDialog()
                : null,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter une observation générale'),
          ),
        ),
        if (_loadingObs) ...[
          const SizedBox(height: AppSpacing.md),
          const Center(child: CircularProgressIndicator()),
        ] else if (_observations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _ObservationsList(
            observations: _observations,
            onEdit: (obs) => obs.wallKey != null
                ? _openWallDialog(obs.wallKey!, existing: obs)
                : _openGeneralObsDialog(existing: obs),
            onDelete: (obs) {
              if (obs.id != null) _deleteObservation(obs.id!);
            },
          ),
        ],
      ],
    );
  }

  /// EDL collectif : plan de murs + observations pour CHAQUE pièce commune et
  /// CHAQUE chambre du bien (liste expansible). Les observations sont rattachées
  /// à la pièce/chambre via piece_id / chambre_id.
  Widget _buildEtatPiecesChambres() {
    if (_piecesForImmeuble.isEmpty && _chambresForImmeuble.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                "Ce bien n'a aucune pièce ni chambre enregistrée. "
                "Ajoutez-les dans la gestion de l'immeuble.",
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Établissez le plan de chaque pièce commune et de chaque chambre.',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ExpansionPanelList.radio(
          elevation: 0,
          expandedHeaderPadding: EdgeInsets.zero,
          children: [
            for (final p in _piecesForImmeuble)
              _roomObsPanel(
                value: 'piece-${p.id}',
                icon: Icons.meeting_room_outlined,
                name: p.nom,
                planLabel: 'Plan de la pièce — ${p.nom}',
                photo: p.photos.isNotEmpty ? p.photos.first.url : null,
                obs: _observations.where((o) => o.pieceId == p.id).toList(),
                onEditWall: (wallKey) =>
                    _openWallDialog(wallKey, pieceId: p.id),
                onAddGeneral: () => _openGeneralObsDialog(pieceId: p.id),
              ),
            for (final c in _chambresForImmeuble)
              _roomObsPanel(
                value: 'chambre-${c.id}',
                icon: Icons.bed_outlined,
                name: c.roomName,
                planLabel: 'Plan de la chambre — ${c.roomName}',
                photo:
                    c.mainPhoto ??
                    (c.roomPhotos.isNotEmpty ? c.roomPhotos.first : null),
                obs: _observations.where((o) => o.chambreId == c.id).toList(),
                onEditWall: (wallKey) =>
                    _openWallDialog(wallKey, chambreId: c.id),
                onAddGeneral: () => _openGeneralObsDialog(chambreId: c.id),
              ),
          ],
        ),
      ],
    );
  }

  /// Panneau (accordéon) d'une pièce/chambre : diagramme de murs + observations.
  ExpansionPanelRadio _roomObsPanel({
    required String value,
    required IconData icon,
    required String name,
    required String planLabel,
    String? photo,
    required List<ObservationEdl> obs,
    required void Function(String wallKey) onEditWall,
    required VoidCallback onAddGeneral,
  }) {
    return ExpansionPanelRadio(
      value: value,
      canTapOnHeader: true,
      headerBuilder: (context, isExpanded) => ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          name,
          style: AppTypography.titleLg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: obs.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(
                  '${obs.length} obs',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RoomDiagram(
              chambreName: name,
              planLabel: planLabel,
              chambrePhoto: photo,
              observations: obs,
              onEditWall: onEditWall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onAddGeneral,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter une observation générale'),
              ),
            ),
            if (obs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _ObservationsList(
                observations: obs,
                onEdit: (o) => o.wallKey != null
                    ? _openWallDialog(
                        o.wallKey!,
                        existing: o,
                        pieceId: o.pieceId,
                        chambreId: o.chambreId,
                      )
                    : _openGeneralObsDialog(
                        existing: o,
                        pieceId: o.pieceId,
                        chambreId: o.chambreId,
                      ),
                onDelete: (o) {
                  if (o.id != null) _deleteObservation(o.id!);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construit dynamiquement les étapes selon la partie (commune / privative).
  /// Met à jour [_stepCount] et [_headerStepIndices].
  ///
  /// Bail collectif  : Informations · Le bien · Preneurs · Relevés · Composition
  /// Bail individuel : Informations · Le bien · Relevés · Composition
  ///                   ── [PARTIES PRIVATIVES] ──
  ///                   Remise des clés · État de la chambre
  List<Step> _buildSteps(_FormBundle bundle, bool isFinalized) {
    _headerStepIndices = {};
    final saved = _currentEdlId != null;
    final priv = _isPrivativeForm;
    var idx = 0;

    Step mk(
      String title,
      String subtitle,
      Widget content, {
      bool enabled = true,
    }) {
      final i = idx++;
      return Step(
        title: Text(title),
        subtitle: Text(subtitle),
        isActive: _currentStep >= i,
        state: !enabled
            ? StepState.disabled
            : (_currentStep > i ? StepState.complete : StepState.indexed),
        content: content,
      );
    }

    // Separador visual entre seções (não é um step real — é ignorado na navegação)
    Step sectionDivider(String label) {
      final i = idx++;
      _headerStepIndices.add(i);
      return Step(
        title: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: AppRadius.borderFull,
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.secondary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        subtitle: const SizedBox.shrink(),
        isActive: false,
        state: StepState.disabled,
        content: const SizedBox.shrink(),
      );
    }

    Widget docOr(Widget Function() w) => saved ? w() : _docPlaceholder();

    final steps = <Step>[];

    if (priv) {
      // ── Bail individuel ─────────────────────────────────────────────────────
      steps.addAll([
        mk(
          'Informations',
          'Locataire, immeuble, chambre et notes',
          _buildStep0Content(bundle, isFinalized),
        ),
        mk('Le bien', 'Surface, bailleur, en-tête (parties communes)',
            _buildStepBien()),
        mk(
          'Relevés',
          'Compteurs, chauffage, eau chaude',
          docOr(() => EdlRelevesSection(edlId: _currentEdlId!)),
          enabled: saved,
        ),
        mk(
          'Composition',
          'Pièces communes et équipements',
          docOr(() => EdlCompositionSection(edlId: _currentEdlId!)),
          enabled: saved,
        ),
        sectionDivider('PARTIES PRIVATIVES'),
        mk(
          'Remise des clés',
          'Badge, clés, dates de remise',
          docOr(() => EdlClesSection(edlId: _currentEdlId!)),
          enabled: saved,
        ),
        mk(
          'État de la chambre',
          _canUseStep2 ? 'Plan, observations par mur' : "Enregistrez d'abord",
          _canUseStep2 ? _buildStep1Content() : _buildStep1Placeholder(),
          enabled: _canUseStep2,
        ),
      ]);
    } else {
      // ── Bail collectif ──────────────────────────────────────────────────────
      steps.addAll([
        mk(
          'Informations',
          'Locataire, immeuble et notes',
          _buildStep0Content(bundle, isFinalized),
        ),
        mk('Le bien', 'Surface, bailleur, en-tête du document',
            _buildStepBien()),
        mk(
          'Preneurs',
          'Les colocataires (signataires)',
          docOr(() => EdlPreneursSection(edlId: _currentEdlId!)),
          enabled: saved,
        ),
        mk(
          'Relevés',
          'Compteurs, chauffage, eau chaude',
          docOr(() => EdlRelevesSection(edlId: _currentEdlId!)),
          enabled: saved,
        ),
        mk(
          'Composition',
          'Pièces et équipements (état N/B/U/M)',
          docOr(() => EdlCompositionSection(edlId: _currentEdlId!)),
          enabled: saved,
        ),
        mk(
          'État des pièces et chambres',
          saved ? 'Plan, observations par mur' : "Enregistrez d'abord",
          docOr(_buildEtatPiecesChambres),
          enabled: saved,
        ),
      ]);
    }

    _stepCount = steps.length;
    return steps;
  }

  Widget _buildStepControls(bool isFinalized) {
    final isLastStep = _currentStep >= _stepCount - 1;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TOP — Suivant (seulement si étape suivante disponible et non finalisé)
          if (!isFinalized && !isLastStep) ...[
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveAndNextStep,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Suivant'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
          ],
          // BOTTOM — Annuler + Sauvegarder et sortir
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onClose(false),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Annuler'),
                style: AppTheme.cancelButtonStyle,
              ),
              if (!isFinalized) ...[
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onTertiaryFixed,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Sauvegarder et sortir'),
                  style: AppTheme.saveButtonStyle,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FormBundle>(
      future: _formBundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final bundle =
            snapshot.data ?? const _FormBundle(immeubles: [], allChambres: []);
        final isFinalized =
            widget.existingEdl?.situation == SituationEdl.finalise;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête ─────────────────────────────────────────────────
            FormPageHeader(
              title: widget.isEditing
                  ? 'Modifier l\'état des lieux'
                  : widget.typeEdl == 'sortie'
                      ? 'Nouvel état des lieux de sortie'
                      : 'Nouvel état des lieux d\'entrée',
              trailing: () {
                final actions = <Widget>[
                  if (widget.isEditing) ...[
                    IconButton(
                      onPressed: _isDeleting ? null : _deleteEdl,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      tooltip: 'Supprimer l\'état des lieux',
                      color: AppColors.error,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  if (!isFinalized)
                    OutlinedButton(
                      onPressed: _isFinalising ? null : _finaliser,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: _isFinalising
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Finaliser'),
                    ),
                ];
                return actions.isEmpty
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions,
                      );
              }(),
            ),

            // ── Stepper (conteúdo centrado e limitado em largura) ────────
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Stepper(
                    type: StepperType.vertical,
                    currentStep: _currentStep,
                    physics: const ClampingScrollPhysics(),
                    onStepTapped: (step) {
                      if (_headerStepIndices.contains(step)) return;
                      if (step > 0 && _currentEdlId == null) return;
                      setState(() => _currentStep = step);
                    },
                    onStepContinue: null,
                    onStepCancel: null,
                    controlsBuilder: (_, _) => _buildStepControls(isFinalized),
                    stepIconBuilder: (stepIndex, _) {
                      if (_headerStepIndices.contains(stepIndex)) {
                        return const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.secondary,
                        );
                      }
                      return null;
                    },
                    steps: _buildSteps(bundle, isFinalized),
                  ),
                ),         // ConstrainedBox
              ),           // Align
            ),             // Expanded
          ],               // Column children
        );                 // Column / return
      },
    );
  }

  Future<void> _loadPieces(int immeubleId) async {
    try {
      final pieces = await PiecesDatasource.listByImmeuble(immeubleId);
      if (mounted) setState(() => _piecesForImmeuble = pieces);
    } catch (_) {
      // Falha silenciosa — lista vazia
    }
  }

  Future<void> _loadObservations() async {
    final id = _currentEdlId;
    if (id == null) return;
    setState(() => _loadingObs = true);
    try {
      final obs = await ObservationsEdlDatasource.listByEdl(id);
      if (mounted) setState(() => _observations = obs);
    } catch (_) {
      // Falha silenciosa — lista vazia
    } finally {
      if (mounted) setState(() => _loadingObs = false);
    }
  }

  Future<void> _deleteObservation(int obsId) async {
    try {
      await ObservationsEdlDatasource.deleteById(obsId);
      await _loadObservations();
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _openWallDialog(
    String wallKey, {
    ObservationEdl? existing,
    int? pieceId,
    int? chambreId,
  }) async {
    final id = _currentEdlId;
    if (id == null) return;

    final saved =
        await showDialog<({String? description, List<String> photos})>(
          context: context,
          builder: (_) => _WallObsDialog(wallKey: wallKey, existing: existing),
        );

    if (saved == null || !mounted) return;

    try {
      final obs = ObservationEdl(
        etatDesLieuxId: id,
        wallKey: wallKey,
        pieceId: pieceId,
        chambreId: chambreId,
        description: saved.description,
        photos: saved.photos,
      );
      final existingId = existing?.id;
      if (existingId != null) {
        await ObservationsEdlDatasource.updateById(existingId, obs);
      } else {
        await ObservationsEdlDatasource.insertWall(obs);
      }
      await _loadObservations();
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _openGeneralObsDialog({
    ObservationEdl? existing,
    int? pieceId,
    int? chambreId,
  }) async {
    final id = _currentEdlId;
    if (id == null) return;

    final saved =
        await showDialog<({String? description, List<String> photos})>(
          context: context,
          builder: (_) => _GeneralObsDialog(existing: existing),
        );

    if (saved == null || !mounted) return;

    try {
      final obs = ObservationEdl(
        etatDesLieuxId: id,
        wallKey: null,
        pieceId: pieceId,
        chambreId: chambreId,
        description: saved.description,
        photos: saved.photos,
      );
      final existingId = existing?.id;
      if (existingId != null) {
        await ObservationsEdlDatasource.updateById(existingId, obs);
      } else {
        await ObservationsEdlDatasource.insertGeneral(obs);
      }
      await _loadObservations();
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recherche locataire

class _LocataireSearchField extends StatelessWidget {
  final TextEditingController controller;
  final UsersClient? selected;
  final List<UsersClient> results;
  final bool showResults;
  final bool searching;
  final void Function(String) onSearch;
  final void Function(UsersClient) onSelect;
  final VoidCallback onClear;

  const _LocataireSearchField({
    required this.controller,
    required this.selected,
    required this.results,
    required this.showResults,
    required this.searching,
    required this.onSearch,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: selected == null,
          onChanged: onSearch,
          decoration: InputDecoration(
            hintText: 'Rechercher un locataire (nom, email)…',
            prefixIcon: searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search, size: 20),
            suffixIcon: selected != null
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                    tooltip: 'Désélectionner',
                  )
                : null,
          ),
        ),
        if (showResults)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: AppColors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowTint.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: results.isEmpty && !searching
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Aucun locataire trouvé.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final loc = results[i];
                      final initial = (loc.fullName ?? loc.email)
                          .substring(0, 1)
                          .toUpperCase();
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryFixed,
                          child: Text(
                            initial,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onPrimaryFixedVariant,
                            ),
                          ),
                        ),
                        title: Text(loc.fullName ?? loc.email),
                        subtitle: loc.fullName != null ? Text(loc.email) : null,
                        onTap: () => onSelect(loc),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown immeuble avec compteurs

class _ImmeubleDropdown extends StatelessWidget {
  final List<ImmeublesModel> immeubles;
  final List<ChambreModel> allChambres;
  final ImmeublesModel? selected;
  final void Function(ImmeublesModel?) onChanged;

  const _ImmeubleDropdown({
    required this.immeubles,
    required this.allChambres,
    required this.selected,
    required this.onChanged,
  });

  String _label(ImmeublesModel imm) {
    if (imm.bailIndividuel) return '${imm.name} (bail individuel)';
    return '${imm.name} (bail collectif)';
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ImmeublesModel>(
      initialValue: selected,
      isExpanded: true,
      hint: const Text('Sélectionner un immeuble…'),
      items: immeubles
          .map(
            (imm) => DropdownMenuItem(
              value: imm,
              child: Text(_label(imm), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown chambre

class _ChambreDropdown extends StatelessWidget {
  final List<ChambreModel> chambres;
  final ChambreModel? selected;
  final void Function(ChambreModel?) onChanged;

  const _ChambreDropdown({
    required this.chambres,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ChambreModel>(
      initialValue: selected,
      isExpanded: true,
      hint: const Text('Sélectionner une chambre…'),
      items: chambres
          .map(
            (ch) => DropdownMenuItem(
              value: ch,
              child: Text(ch.roomName, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page de détail EDL (vue propriétaire, lecture seule + bouton Éditer)

class _EdlDetailProprietairePage extends StatefulWidget {
  final EtatDesLieuxModel edl;
  final VoidCallback onClose;
  final VoidCallback onEditer;

  const _EdlDetailProprietairePage({
    required this.edl,
    required this.onClose,
    required this.onEditer,
  });

  @override
  State<_EdlDetailProprietairePage> createState() =>
      _EdlDetailProprietairePageState();
}

class _EdlDetailProprietairePageState
    extends State<_EdlDetailProprietairePage> {
  static final _fmt = DateFormat('dd/MM/yyyy');
  late final Future<List<ObservationEdl>> _obsFuture;

  static const _wallOrder = <String?>['fond', 'gauche', 'droit', 'porte', null];
  static const _wallLabels = <String, String>{
    'fond': 'Mur du fond',
    'gauche': 'Mur gauche',
    'droit': 'Mur droit',
    'porte': "Mur d'entrée / Porte",
  };

  @override
  void initState() {
    super.initState();
    _obsFuture = ObservationsEdlDatasource.listByEdl(widget.edl.id);
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
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
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
        leading: BackButton(onPressed: widget.onClose),
        title: Text(
          edl.typeEdl == 'entree'
              ? "État des lieux d'entrée"
              : 'État des lieux de sortie',
        ),
        actions: [
          TextButton.icon(
            onPressed: widget.onEditer,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Éditer'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Carte statut ───────────────────────────────────────────
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
                      _SituationBadge(situation: edl.situation),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Locataire ──────────────────────────────────────────────
                _sectionTitle('LOCATAIRE'),
                _infoCard([
                  if (edl.locataireNom != null)
                    _infoRow('Nom', edl.locataireNom!),
                  if (edl.locataireEmail != null)
                    _infoRow('E-mail', edl.locataireEmail!),
                  if (edl.locatairePhone != null &&
                      edl.locatairePhone!.isNotEmpty)
                    _infoRow('Téléphone', edl.locatairePhone!),
                ]),
                const SizedBox(height: AppSpacing.lg),

                // ── Lieu ───────────────────────────────────────────────────
                _sectionTitle('LIEU'),
                _infoCard([
                  _infoRow('Immeuble', edl.immeubleNom ?? '—'),
                  if (edl.immeubleAdresse != null)
                    _infoRow('Adresse', edl.immeubleAdresse!),
                  if (edl.chambreNom != null)
                    _infoRow('Chambre', edl.chambreNom!),
                ]),
                const SizedBox(height: AppSpacing.lg),

                // ── Détails ────────────────────────────────────────────────
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
                    _infoRow('Montant', '€ ${edl.montant!.toStringAsFixed(2)}'),
                ]),
                const SizedBox(height: AppSpacing.lg),

                // ── Notes ──────────────────────────────────────────────────
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

                // ── Signature locataire ────────────────────────────────────
                if (edl.situation == SituationEdl.finalise) ...[
                  _sectionTitle('SIGNATURE LOCATAIRE'),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: edl.locataireAccepte
                          ? AppColors.secondaryFixed.withValues(alpha: 0.3)
                          : AppColors.errorContainer.withValues(alpha: 0.15),
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                        color: edl.locataireAccepte
                            ? AppColors.secondary.withValues(alpha: 0.4)
                            : AppColors.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          edl.locataireAccepte
                              ? Icons.check_circle_outlined
                              : Icons.pending_outlined,
                          color: edl.locataireAccepte
                              ? AppColors.secondary
                              : AppColors.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            edl.locataireAccepte
                                ? 'Le locataire a accepté et signé.'
                                : 'En attente de signature du locataire.',
                            style: AppTypography.bodyMd,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ── État de la chambre ─────────────────────────────────────
                _sectionTitle('ÉTAT DE LA CHAMBRE'),
                FutureBuilder<List<ObservationEdl>>(
                  future: _obsFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final obs = snap.data ?? [];
                    if (obs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppRadius.borderMd,
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Text(
                          'Aucune observation enregistrée.',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final grouped = <String?, List<ObservationEdl>>{};
                    for (final o in obs) {
                      (grouped[o.wallKey] ??= []).add(o);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final wallKey in _wallOrder)
                          if (grouped.containsKey(wallKey)) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                                bottom: AppSpacing.xs,
                              ),
                              child: Text(
                                (_wallLabels[wallKey] ?? 'Général')
                                    .toUpperCase(),
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            for (final o in grouped[wallKey]!)
                              _EdlObsTile(obs: o),
                          ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EdlObsTile extends StatelessWidget {
  final ObservationEdl obs;
  const _EdlObsTile({required this.obs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
            if (obs.description != null && obs.description!.isNotEmpty)
              Text(obs.description!, style: AppTypography.bodyMd),
            if (obs.photos.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: obs.photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: AppRadius.borderSm,
                    child: CachedNetworkImage(
                      imageUrl: obs.photos[i],
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
            if ((obs.description == null || obs.description!.isEmpty) &&
                obs.photos.isEmpty)
              Text(
                '(aucun contenu)',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge de situation

class _SituationBadge extends StatelessWidget {
  final SituationEdl situation;
  const _SituationBadge({required this.situation});

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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.borderFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            situation.label,
            style: AppTypography.labelSm.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocataireASignerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed.withValues(alpha: 0.5),
        borderRadius: AppRadius.borderFull,
        border: Border.all(
          color: AppColors.onTertiaryFixedVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.onTertiaryFixedVariant,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Loc. à signer',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onTertiaryFixedVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte statistique

class _StatCard extends StatelessWidget {
  final String label;
  final String? sublabel;
  final int value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowTint.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.borderMd,
            ),
            alignment: Alignment.center,
            child: Text(
              value.toString(),
              style: AppTypography.headlineMd.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppTypography.titleLg.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogue création locataire

class _CreerLocataireDialog extends StatefulWidget {
  final String proprietaireId;
  const _CreerLocataireDialog({required this.proprietaireId});

  @override
  State<_CreerLocataireDialog> createState() => _CreerLocataireDialogState();
}

class _CreerLocataireDialogState extends State<_CreerLocataireDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _isSaving = false;
  String? _emailError;
  String? _phoneError;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    _formKey.currentState?.save();
    final phone = (_formKey.currentState?.value['telephone'] as String? ?? '')
        .trim();

    if (name.isEmpty || email.isEmpty) {
      setState(() => _error = 'Le nom et l\'e-mail sont obligatoires.');
      return;
    }

    setState(() {
      _isSaving = true;
      _emailError = null;
      _phoneError = null;
      _error = null;
    });

    try {
      if (await EtatDesLieuxDatasource.emailExists(email)) {
        setState(() {
          _emailError = 'Cet e-mail est déjà enregistré dans le système.';
          _isSaving = false;
        });
        return;
      }

      if (phone.isNotEmpty && await EtatDesLieuxDatasource.phoneExists(phone)) {
        setState(() {
          _phoneError = 'Ce numéro de téléphone est déjà enregistré.';
          _isSaving = false;
        });
        return;
      }

      final userId = await EtatDesLieuxDatasource.inviteLocataire(
        fullName: name,
        email: email,
        proprietaireId: widget.proprietaireId,
        phone: phone.isEmpty ? null : phone,
      );

      if (mounted) {
        Navigator.of(context).pop(
          UsersClient(
            id: userId,
            createdAt: DateTime.now(),
            email: email,
            fullName: name,
            phone: phone.isEmpty ? null : phone,
          ),
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        if (msg.contains('déjà enregistré') ||
            msg.contains('already been registered') ||
            msg.contains('already registered')) {
          setState(() {
            _emailError = 'Un compte avec cet e-mail existe déjà.';
            _isSaving = false;
          });
        } else {
          setState(() {
            _error = 'Erreur lors de la création : $msg';
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un locataire'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: FormBuilder(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet *',
                    hintText: 'Jean Dupont',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-mail *',
                    hintText: 'jean@example.com',
                    errorText: _emailError,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PhoneField(name: 'telephone', labelText: 'Téléphone'),
                if (_phoneError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _phoneError!,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          style: AppTheme.cancelButtonStyle,
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Text('Créer et inviter'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diagramme 2D de la chambre

class _RoomDiagram extends StatelessWidget {
  final String chambreName;
  final String? planLabel; // titre personnalisé (pièce vs chambre)
  final String? chambrePhoto;
  final List<ObservationEdl> observations;
  final void Function(String wallKey) onEditWall;

  const _RoomDiagram({
    required this.chambreName,
    this.planLabel,
    this.chambrePhoto,
    required this.observations,
    required this.onEditWall,
  });

  int _obsCount(String key) =>
      observations.where((o) => o.wallKey == key).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.home_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              planLabel ??
                  (chambreName.isNotEmpty
                      ? 'Plan de la chambre — $chambreName'
                      : 'Plan de la chambre'),
              style: AppTypography.labelMd.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Appuyez sur chaque mur pour ajouter des observations et photos.',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: Stack(
              children: [
                // Mur du fond (top)
                Positioned(
                  top: 0,
                  left: 60,
                  right: 60,
                  height: 60,
                  child: _WallPanel(
                    label: 'Mur du fond',
                    icon: Icons.crop_square,
                    obsCount: _obsCount('fond'),
                    onTap: () => onEditWall('fond'),
                  ),
                ),
                // Mur gauche
                Positioned(
                  top: 60,
                  left: 0,
                  width: 60,
                  bottom: 60,
                  child: _WallPanel(
                    label: 'Mur gauche',
                    icon: Icons.crop_square,
                    obsCount: _obsCount('gauche'),
                    onTap: () => onEditWall('gauche'),
                    vertical: true,
                  ),
                ),
                // Intérieur : photo de fond + deux zones cliquables
                // (Plafond en haut, Sol en bas — séparées horizontalement)
                Positioned(
                  top: 60,
                  left: 60,
                  right: 60,
                  bottom: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: (chambrePhoto != null &&
                                  chambrePhoto!.trim().isNotEmpty &&
                                  Uri.tryParse(chambrePhoto!.trim())
                                          ?.hasScheme ==
                                      true)
                              ? CachedNetworkImage(
                                  imageUrl: chambrePhoto!.trim(),
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => const Center(
                                    child: Icon(
                                      Icons.home_outlined,
                                      size: 36,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.home_outlined,
                                    size: 36,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                        ),
                        Column(
                          children: [
                            Expanded(
                              child: _InnerZone(
                                label: 'Plafond',
                                icon: Icons.expand_less,
                                obsCount: _obsCount('plafond'),
                                onTap: () => onEditWall('plafond'),
                                alignTop: true,
                              ),
                            ),
                            Expanded(
                              child: _InnerZone(
                                label: 'Sol',
                                icon: Icons.expand_more,
                                obsCount: _obsCount('sol'),
                                onTap: () => onEditWall('sol'),
                                alignTop: false,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Mur droit
                Positioned(
                  top: 60,
                  right: 0,
                  width: 60,
                  bottom: 60,
                  child: _WallPanel(
                    label: 'Mur droit',
                    icon: Icons.crop_square,
                    obsCount: _obsCount('droit'),
                    onTap: () => onEditWall('droit'),
                    vertical: true,
                  ),
                ),
                // Mur d'entrée + porte (painel único cobrindo toda a largura)
                Positioned(
                  bottom: 0,
                  left: 60,
                  right: 60,
                  height: 60,
                  child: _WallPanel(
                    label: "Mur d'entrée\n+ Porte",
                    icon: Icons.door_front_door_outlined,
                    obsCount: _obsCount('porte'),
                    onTap: () => onEditWall('porte'),
                    isDoor: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WallPanel extends StatelessWidget {
  final String label;
  final IconData icon;
  final int obsCount;
  final VoidCallback onTap;
  final bool vertical;
  final bool isDoor;

  const _WallPanel({
    required this.label,
    required this.icon,
    required this.obsCount,
    required this.onTap,
    this.vertical = false,
    this.isDoor = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = obsCount > 0;
    final bg = hasContent
        ? AppColors.primaryFixed.withValues(alpha: 0.35)
        : AppColors.surfaceContainerLowest;
    final fgColor = hasContent ? AppColors.primary : AppColors.onSurfaceVariant;
    final borderColor = hasContent
        ? AppColors.primary.withValues(alpha: 0.5)
        : AppColors.outlineVariant;

    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_circle_outline, size: 14, color: fgColor),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: fgColor,
            fontWeight: hasContent ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (hasContent) ...[
          const SizedBox(height: 2),
          Text(
            '$obsCount obs.',
            style: TextStyle(
              fontSize: 9,
              color: fgColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );

    if (vertical) {
      content = RotatedBox(quarterTurns: 1, child: content);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.lightBlue.withValues(alpha: 0.18),
        splashColor: Colors.lightBlue.withValues(alpha: 0.25),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: borderColor),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Zone cliquable à l'intérieur du diagramme (Plafond en haut, Sol en bas).
/// Photo de fond visible derrière ; bandeau translucide en haut/bas avec le
/// libellé, l'icône et le compteur d'observations.
class _InnerZone extends StatelessWidget {
  final String label;
  final IconData icon;
  final int obsCount;
  final VoidCallback onTap;
  final bool alignTop;

  const _InnerZone({
    required this.label,
    required this.icon,
    required this.obsCount,
    required this.onTap,
    required this.alignTop,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = obsCount > 0;
    final overlay = hasContent
        ? AppColors.primary.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.6);
    final fgColor = Colors.white;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: overlay,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasContent) ...[
            const SizedBox(width: 6),
            Text(
              '$obsCount',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.lightBlue.withValues(alpha: 0.18),
        splashColor: Colors.lightBlue.withValues(alpha: 0.25),
        child: Align(
          alignment: alignTop ? Alignment.topCenter : Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: pill,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Liste des observations (murs + générales)

class _ObservationsList extends StatelessWidget {
  final List<ObservationEdl> observations;
  final void Function(ObservationEdl) onEdit;
  final void Function(ObservationEdl) onDelete;

  const _ObservationsList({
    required this.observations,
    required this.onEdit,
    required this.onDelete,
  });

  static const _wallOrder = <String?>[
    'plafond', 'fond', 'gauche', 'droit', 'porte', 'sol', null,
  ];

  static String _groupLabel(String? wallKey) => switch (wallKey) {
    'fond' => 'Mur du fond',
    'gauche' => 'Mur gauche',
    'droit' => 'Mur droit',
    'porte' => "Mur d'entrée / Porte",
    'sol' => 'Sol',
    'plafond' => 'Plafond',
    _ => 'Général',
  };

  @override
  Widget build(BuildContext context) {
    final grouped = <String?, List<ObservationEdl>>{};
    for (final obs in observations) {
      (grouped[obs.wallKey] ??= []).add(obs);
    }

    final sections = <Widget>[];
    for (final wallKey in _wallOrder) {
      final group = grouped[wallKey];
      if (group == null || group.isEmpty) continue;

      sections.add(
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                wallKey != null ? Icons.crop_square : Icons.notes_outlined,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _groupLabel(wallKey).toUpperCase(),
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      );

      for (final obs in group) {
        sections.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ObservationTile(
              obs: obs,
              onEdit: () => onEdit(obs),
              onDelete: () => onDelete(obs),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'OBSERVATIONS ENREGISTRÉES',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        ...sections,
      ],
    );
  }
}

class _ObservationTile extends StatelessWidget {
  final ObservationEdl obs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ObservationTile({
    required this.obs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasDesc = obs.description != null && obs.description!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDesc)
                  Text(obs.description!, style: AppTypography.bodyMd),
                if (obs.photos.isNotEmpty) ...[
                  if (hasDesc) const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.photo_outlined,
                        size: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${obs.photos.length} photo${obs.photos.length > 1 ? 's' : ''}',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                if (!hasDesc && obs.photos.isEmpty)
                  Text(
                    '(aucun contenu)',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: onEdit,
            tooltip: 'Modifier',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 16,
              color: AppColors.error,
            ),
            onPressed: onDelete,
            tooltip: 'Supprimer',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogue observation mur (StatefulWidget pour gérer le cycle du controller)

class _WallObsDialog extends StatefulWidget {
  final String wallKey;
  final ObservationEdl? existing;

  const _WallObsDialog({required this.wallKey, this.existing});

  @override
  State<_WallObsDialog> createState() => _WallObsDialogState();
}

class _WallObsDialogState extends State<_WallObsDialog> {
  late final TextEditingController _descCtrl;
  List<String> _photos = [];

  static const _labels = {
    'fond': 'Mur du fond',
    'gauche': 'Mur gauche',
    'droit': 'Mur droit',
    'porte': "Mur d'entrée / Porte",
  };

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _photos = List.from(widget.existing?.photos ?? []);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallLabel = _labels[widget.wallKey] ?? widget.wallKey;
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Modifier — $wallLabel' : 'Ajouter — $wallLabel'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observations',
                  hintText: 'État du mur, dommages, remarques…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'PHOTOS',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PhotoPickerField(
                folder: 'etat_de_lieux/murs',
                initialPhotos: _photos,
                onChanged: (urls) => setState(() => _photos = urls),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: AppTheme.cancelButtonStyle,
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            photos: _photos,
          )),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogue observation générale

class _GeneralObsDialog extends StatefulWidget {
  final ObservationEdl? existing;

  const _GeneralObsDialog({this.existing});

  @override
  State<_GeneralObsDialog> createState() => _GeneralObsDialogState();
}

class _GeneralObsDialogState extends State<_GeneralObsDialog> {
  late final TextEditingController _descCtrl;
  List<String> _photos = [];

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _photos = List.from(widget.existing?.photos ?? []);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(
        isEditing
            ? "Modifier l'observation"
            : 'Ajouter une observation générale',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observations',
                  hintText: 'Remarques générales sur la chambre…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'PHOTOS',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PhotoPickerField(
                folder: 'etat_de_lieux/general',
                initialPhotos: _photos,
                onChanged: (urls) => setState(() => _photos = urls),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: AppTheme.cancelButtonStyle,
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            photos: _photos,
          )),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EDL Collectif + non meublée — nouvelle page full-width
// ═════════════════════════════════════════════════════════════════════════════

/// Page de saisie d'un EDL pour un immeuble **Collectif + non meublée**.
/// Layout : 3 colonnes en haut (Bien · Locataires · Dates) + en bas la liste
/// expansible des pièces / chambres avec le diagramme à 6 zones.
class EdlCollectifNonMeubleePage extends StatefulWidget {
  final ImmeublesModel immeuble;
  final String typeEdl; // 'entree' | 'sortie'
  final EtatDesLieuxModel? existingEdl; // null = nouvel EDL
  final void Function(bool refresh) onClose;

  const EdlCollectifNonMeubleePage({
    super.key,
    required this.immeuble,
    required this.typeEdl,
    this.existingEdl,
    required this.onClose,
  });

  @override
  State<EdlCollectifNonMeubleePage> createState() =>
      _EdlCollectifNonMeubleePageState();
}

class _EdlCollectifNonMeubleePageState
    extends State<EdlCollectifNonMeubleePage> {
  int? _edlId;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  List<PieceModel> _pieces = [];
  List<ChambreModel> _chambres = [];
  List<EdlPreneur> _preneurs = [];
  List<ObservationEdl> _observations = [];

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Map<String, GlobalKey> _tileKeys = {};
  final LayerLink _searchLink = LayerLink();
  final GlobalKey _searchFieldKey = GlobalKey();
  final OverlayPortalController _resultsCtrl = OverlayPortalController();
  Timer? _debounce;
  List<UsersClient> _searchResults = [];
  bool _searching = false;
  bool _showResults = false;
  // Fallback local (locataireId → e-mail) caso le join Users_Client soit
  // bloqué par la RLS au moment du rechargement des preneurs.
  final Map<String, String> _emailByLocataire = {};

  void _syncResultsOverlay() {
    if (_showResults && _searchResults.isNotEmpty) {
      _resultsCtrl.show();
    } else {
      _resultsCtrl.hide();
    }
  }

  @override
  void initState() {
    super.initState();
    final edl = widget.existingEdl;
    if (edl != null) {
      _edlId = edl.id;
      _date = edl.dateEtatLieux;
    }
    _loadRooms();
    if (edl != null) {
      _loadPreneurs();
      _loadObservations();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool get _saved => _edlId != null;

  Future<void> _loadRooms() async {
    try {
      final pieces =
          await PiecesDatasource.listByImmeuble(widget.immeuble.id);
      final chambres =
          await ChambresDatasource.listByImmeubles([widget.immeuble.id]);
      if (!mounted) return;
      setState(() {
        _pieces = pieces;
        _chambres = chambres;
      });
    } catch (_) {}
  }

  Future<void> _loadPreneurs() async {
    if (_edlId == null) return;
    try {
      final list = await EdlDetailsDatasource.listPreneurs(_edlId!);
      final merged = list.map((p) {
        if ((p.email == null || p.email!.isEmpty) &&
            p.locataireId != null &&
            _emailByLocataire.containsKey(p.locataireId)) {
          return EdlPreneur(
            id: p.id,
            etatDesLieuxId: p.etatDesLieuxId,
            locataireId: p.locataireId,
            nom: p.nom,
            adresse: p.adresse,
            ordre: p.ordre,
            email: _emailByLocataire[p.locataireId],
          );
        }
        return p;
      }).toList();
      if (mounted) setState(() => _preneurs = merged);
    } catch (_) {}
  }

  Future<void> _loadObservations() async {
    if (_edlId == null) return;
    try {
      final obs = await ObservationsEdlDatasource.listByEdl(_edlId!);
      if (mounted) setState(() => _observations = obs);
    } catch (_) {}
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('fr'),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<bool> _saveEdl() async {
    setState(() => _isSaving = true);
    try {
      final uid = AuthService.currentUser?.id ?? '';
      final situation = SituationEdl.fromDate(_date);
      if (_edlId == null) {
        final model = EtatDesLieuxModel(
          id: 0,
          proprietaireId: uid,
          locataireId: null,
          immeubleId: widget.immeuble.id,
          typeBail: 'collectif',
          typeEdl: widget.typeEdl,
          dateEtatLieux: _date,
          situation: situation,
          createdAt: DateTime.now(),
          partie: PartieEdl.commune,
        );
        final created = await EtatDesLieuxDatasource.create(model);
        if (!mounted) return false;
        setState(() => _edlId = created.id);
      } else {
        await EtatDesLieuxDatasource.update(_edlId!, {
          'date_etat_lieux': _date.toIso8601String().substring(0, 10),
          'situation': situation.raw,
        });
      }
      return true;
    } catch (e) {
      _snack('Erreur : $e');
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onSavePressed() async {
    final ok = await _saveEdl();
    if (ok) _snack('Enregistré.');
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      _syncResultsOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final r = await EtatDesLieuxDatasource.searchLocataires(q);
        if (!mounted) return;
        setState(() {
          _searchResults = r;
          _showResults = true;
        });
        _syncResultsOverlay();
      } catch (_) {
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _addPreneur(UsersClient user) async {
    if (_preneurs.any((p) => p.locataireId == user.id)) {
      _snack('Ce locataire est déjà ajouté.');
      _clearSearch();
      return;
    }
    if (_edlId == null) {
      final ok = await _saveEdl();
      if (!ok) return;
    }
    if (user.email.isNotEmpty) _emailByLocataire[user.id] = user.email;
    try {
      await EdlDetailsDatasource.createPreneur(EdlPreneur(
        etatDesLieuxId: _edlId!,
        locataireId: user.id,
        nom: user.fullName ?? user.email,
        ordre: _preneurs.length,
      ));
      _clearSearch();
      await _loadPreneurs();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _deletePreneur(int id) async {
    try {
      await EdlDetailsDatasource.deletePreneur(id);
      await _loadPreneurs();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _searchResults = [];
      _showResults = false;
    });
    _syncResultsOverlay();
  }

  /// Liste flottante des résultats — affichée par-dessus le reste de l'UI
  /// (ne pousse pas les autres sections vers le bas).
  Widget _buildResultsOverlay(BuildContext context) {
    final box = _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 320.0;
    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _searchLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: AppRadius.borderSm,
              color: AppColors.surfaceContainerLowest,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowTint.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _searchResults
                  .take(5)
                  .map((u) => ListTile(
                        dense: true,
                        title: Text(u.fullName ?? u.email),
                        subtitle: Text(u.email,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _addPreneur(u),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openWall(
    String wallKey, {
    int? pieceId,
    int? chambreId,
    ObservationEdl? existing,
  }) async {
    if (_edlId == null) {
      final ok = await _saveEdl();
      if (!ok || !mounted) return;
    }
    final saved =
        await showDialog<({String? description, List<String> photos})>(
      context: context,
      builder: (_) => _WallObsDialog(wallKey: wallKey, existing: existing),
    );
    if (saved == null || !mounted) return;
    try {
      final obs = ObservationEdl(
        etatDesLieuxId: _edlId!,
        wallKey: wallKey,
        pieceId: pieceId,
        chambreId: chambreId,
        description: saved.description,
        photos: saved.photos,
      );
      if (existing?.id != null) {
        await ObservationsEdlDatasource.updateById(existing!.id!, obs);
      } else {
        await ObservationsEdlDatasource.insertWall(obs);
      }
      await _loadObservations();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _openGeneral({
    int? pieceId,
    int? chambreId,
    ObservationEdl? existing,
  }) async {
    if (_edlId == null) {
      final ok = await _saveEdl();
      if (!ok || !mounted) return;
    }
    final saved =
        await showDialog<({String? description, List<String> photos})>(
      context: context,
      builder: (_) => _GeneralObsDialog(existing: existing),
    );
    if (saved == null || !mounted) return;
    try {
      final obs = ObservationEdl(
        etatDesLieuxId: _edlId!,
        wallKey: null,
        pieceId: pieceId,
        chambreId: chambreId,
        description: saved.description,
        photos: saved.photos,
      );
      if (existing?.id != null) {
        await ObservationsEdlDatasource.updateById(existing!.id!, obs);
      } else {
        await ObservationsEdlDatasource.insertGeneral(obs);
      }
      await _loadObservations();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _deleteObservation(int id) async {
    try {
      await ObservationsEdlDatasource.deleteById(id);
      await _loadObservations();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormPageHeader(
          title: "Nouvel état des lieux — ${widget.immeuble.name}",
          leading: IconButton.outlined(
            icon: const Icon(Icons.close),
            tooltip: 'Annuler',
            onPressed: () => widget.onClose(_saved),
          ),
          trailing: FilledButton.icon(
            onPressed: _isSaving ? null : _onSavePressed,
            style: AppTheme.saveButtonStyle,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Enregistrer'),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopRow(),
                const SizedBox(height: AppSpacing.md),
                _buildLocatairesSection(),
                const SizedBox(height: AppSpacing.xl),
                _buildRoomsSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 640;
      if (wide) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _buildBienCard()),
              const SizedBox(width: AppSpacing.md),
              SizedBox(width: 220, child: _buildDatesCard()),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBienCard(),
          const SizedBox(height: AppSpacing.md),
          _buildDatesCard(),
        ],
      );
    });
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.labelMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _buildBienCard() {
    final imm = widget.immeuble;
    final lieu = [imm.address, imm.city]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    return _sectionCard(
      title: 'BIEN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(imm.name, style: AppTypography.titleLg),
          if (lieu.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              lieu,
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaChip(
                icon: Icons.square_foot,
                text: imm.totalM2 != null
                    ? '${imm.totalM2!.toStringAsFixed(0)} m²'
                    : '— m²',
              ),
              const _MetaChip(
                  icon: Icons.assignment_outlined, text: 'Collectif'),
              const _MetaChip(
                  icon: Icons.chair_outlined, text: 'Non meublée'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocatairesSection() {
    final searchField = CompositedTransformTarget(
      link: _searchLink,
      child: OverlayPortal(
        controller: _resultsCtrl,
        overlayChildBuilder: _buildResultsOverlay,
        child: TextField(
          key: _searchFieldKey,
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Rechercher un locataire (nom, e-mail)…',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearSearch,
                      )
                    : null),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );

    final searchColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        searchField,
        if (!_saved) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Enregistrez d'abord pour ajouter des locataires.",
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ] else if (_preneurs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${_preneurs.length} locataire${_preneurs.length > 1 ? 's' : ''} ajouté${_preneurs.length > 1 ? 's' : ''} à droite.',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );

    final tenantsArea = _preneurs.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _saved ? 'Aucun locataire ajouté.' : '',
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in _preneurs)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: IntrinsicWidth(
                    child: _TenantCard(
                      preneur: p,
                      onDelete: () => _deletePreneur(p.id!),
                    ),
                  ),
                ),
            ],
          );

    return _sectionCard(
      title: 'LOCATAIRES',
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 580) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 320, child: searchColumn),
              const SizedBox(width: 24),
              Expanded(child: tenantsArea),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            searchColumn,
            const SizedBox(height: AppSpacing.md),
            tenantsArea,
          ],
        );
      }),
    );
  }

  Widget _buildDatesCard() {
    return _sectionCard(
      title: 'DATES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Date de l'état des lieux",
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: _pickDate,
            borderRadius: AppRadius.borderSm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderSm,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Text(_dateFmt.format(_date), style: AppTypography.bodyMd),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.meeting_room_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('État des pièces et chambres',
                  style: AppTypography.titleLg),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _saved
                ? 'Cliquez sur un mur, le sol ou le plafond pour ajouter une observation.'
                : "Enregistrez d'abord pour activer les observations.",
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_pieces.isEmpty && _chambres.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  "Aucune pièce ni chambre enregistrée pour cet immeuble.",
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in _pieces)
                  _buildRoomTile(
                    key: ValueKey('piece-${p.id}'),
                    tileId: 'piece-${p.id}',
                    icon: Icons.meeting_room_outlined,
                    name: p.nom,
                    planLabel: 'Plan de la pièce — ${p.nom}',
                    photo: p.photos.isNotEmpty ? p.photos.first.url : null,
                    obs: _observations
                        .where((o) => o.pieceId == p.id)
                        .toList(),
                    onEditWall: (k) => _openWall(k, pieceId: p.id),
                    onAddGeneral: () => _openGeneral(pieceId: p.id),
                  ),
                for (final c in _chambres)
                  _buildRoomTile(
                    key: ValueKey('chambre-${c.id}'),
                    tileId: 'chambre-${c.id}',
                    icon: Icons.bed_outlined,
                    name: c.roomName,
                    planLabel: 'Plan de la chambre — ${c.roomName}',
                    photo: c.mainPhoto ??
                        (c.roomPhotos.isNotEmpty ? c.roomPhotos.first : null),
                    obs: _observations
                        .where((o) => o.chambreId == c.id)
                        .toList(),
                    onEditWall: (k) => _openWall(k, chambreId: c.id),
                    onAddGeneral: () => _openGeneral(chambreId: c.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static const _wallKeys = ['fond', 'gauche', 'droit', 'porte', 'sol', 'plafond'];

  Widget _wallProgressBadge(List<ObservationEdl> obs) {
    final done = _wallKeys.where((k) => obs.any((o) => o.wallKey == k)).length;
    final color = done == 6
        ? AppColors.primary
        : (done > 0 ? AppColors.secondary : AppColors.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$done/6',
        style: AppTypography.labelSm.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRoomTile({
    required Key key,
    required String tileId,
    required IconData icon,
    required String name,
    required String planLabel,
    String? photo,
    required List<ObservationEdl> obs,
    required void Function(String wallKey) onEditWall,
    required VoidCallback onAddGeneral,
  }) {
    final tileKey = _tileKeys.putIfAbsent(tileId, GlobalKey.new);
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderSm,
        child: ExpansionTile(
          key: tileKey,
          // Header ligeiramente colorido; body branco abaixo via Container filho.
          collapsedBackgroundColor: const Color(0xFFF0F6FA),
          backgroundColor: const Color(0xFFF0F6FA),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(icon, color: AppColors.primary),
          title: Text(name,
              style: AppTypography.titleLg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          trailing: _wallProgressBadge(obs),
          onExpansionChanged: (expanded) {
            if (!expanded) return;
            // Attendre la fin de l'animation d'expansion (≈200 ms) avant de
            // scroller, sinon la box n'a pas encore sa hauteur finale.
            Future.delayed(const Duration(milliseconds: 260), () {
              if (!mounted) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ctx = tileKey.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(
                    ctx,
                    alignment: 0.05,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                }
              });
            });
          },
          childrenPadding: EdgeInsets.zero,
          children: [
            Container(
              color: AppColors.surfaceContainerLowest,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AbsorbPointer(
                    absorbing: !_saved,
                    child: Opacity(
                      opacity: _saved ? 1 : 0.5,
                      child: RepaintBoundary(
                        child: _RoomDiagram(
                          chambreName: name,
                          planLabel: planLabel,
                          chambrePhoto: photo,
                          observations: obs,
                          onEditWall: onEditWall,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _saved ? onAddGeneral : null,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter une observation générale'),
                    ),
                  ),
                  if (obs.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ObservationsList(
                      observations: obs,
                      onEdit: (o) => o.wallKey != null
                          ? _openWall(o.wallKey!,
                              existing: o,
                              pieceId: o.pieceId,
                              chambreId: o.chambreId)
                          : _openGeneral(
                              existing: o,
                              pieceId: o.pieceId,
                              chambreId: o.chambreId),
                      onDelete: (o) {
                        if (o.id != null) _deleteObservation(o.id!);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text,
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  final EdlPreneur preneur;
  final VoidCallback onDelete;

  const _TenantCard({required this.preneur, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final initials = (preneur.nom ?? '?')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCFE0E7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preneur.nom ?? '—',
                  style: AppTypography.labelMd
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (preneur.email != null && preneur.email!.isNotEmpty)
                  Text(
                    preneur.email!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF5B6772),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          CardDeleteButton(onPressed: onDelete),
        ],
      ),
    );
  }
}
