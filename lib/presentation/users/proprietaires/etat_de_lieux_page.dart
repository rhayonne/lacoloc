import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lacoloc_front/data/cache/realtime_refresh_mixin.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/edl_details.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
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
import 'package:lacoloc_front/presentation/users/proprietaires/edl_select_chambre_dialog.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_select_collectif_avenant_dialog.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_select_immeuble_dialog.dart';
import 'package:lacoloc_front/presentation/widgets/edl_filter_bar.dart';
import 'package:lacoloc_front/presentation/widgets/form_page_header.dart';
import 'package:lacoloc_front/presentation/widgets/locataire_search_field.dart';
import 'package:lacoloc_front/presentation/widgets/unsaved_changes_dialog.dart';
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
/// Choix proposé quand le collectif d'entrée est déjà finalisé : nouveau contrat
/// collectif (en crée un nouveau) ou avenant au contrat existant.
enum _ContratChoice { nouveau, avenant }

const double _colType = 124.0; // Type immeuble + meublé + Collectif/Individuel
const double _colSens = 84.0; // Entrée / Sortie
const double _colEtat = 92.0;
const double _colFin = 104.0;
const double _colSit = 140.0;
const double _colBtn = 92.0; // bouton « Continuer » (compact)
const double _colDel = 36.0;
const double _colEye = 36.0; // bouton « visualiser »
const double _colLink = 20.0; // icône de lien de contrat (collectif ↔ privatifs)

// Palette déterministe pour regrouper visuellement un contrat (EDL collectif +
// ses privatifs) : même couleur de barre/icône = même contrat. Indexée par
// `contratId % longueur`, donc stable entre Vision générale / Entrée / Sortie.
const List<Color> _kContratColors = [
  Color(0xFF2563EB), // bleu
  Color(0xFF059669), // vert
  Color(0xFFD97706), // ambre
  Color(0xFF7C3AED), // violet
  Color(0xFFDB2777), // rose
  Color(0xFF0891B2), // cyan
  Color(0xFFCA8A04), // or
  Color(0xFFDC2626), // rouge
];

Color _contratColor(int contratId) =>
    _kContratColors[contratId % _kContratColors.length];

/// Bloc « libellé + champ de date » compact, partagé par les cartes DATES des
/// écrans d'EDL. [onTap] null = lecture seule (fond grisé, ex. date de
/// finalisation définie à l'acceptation du locataire).
Widget _edlDateBlock({
  required String label,
  required String value,
  required IconData icon,
  VoidCallback? onTap,
  bool muted = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
      ),
      const SizedBox(height: AppSpacing.xs),
      InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderSm,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderSm,
            border: Border.all(color: AppColors.outlineVariant),
            color: onTap == null ? AppColors.surfaceContainerLow : null,
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 14,
                  color: muted ? AppColors.onSurfaceVariant : null),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  value,
                  style: AppTypography.labelMd.copyWith(
                    color: muted ? AppColors.onSurfaceVariant : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class EtatDesLieuxPage extends StatefulWidget {
  const EtatDesLieuxPage({super.key});

  @override
  State<EtatDesLieuxPage> createState() => _EtatDesLieuxPageState();
}

typedef _PageData = ({List<EtatDesLieuxModel> edls, List<UsersClient> invites});

class _EtatDesLieuxPageState extends State<EtatDesLieuxPage>
    with SingleTickerProviderStateMixin, RealtimeRefreshMixin {
  late final TabController _tabCtrl;
  bool _showForm = false;
  EtatDesLieuxModel? _editingEdl;
  String _formTypeEdl = 'entree';
  bool _showDetail = false;
  EtatDesLieuxModel? _detailEdl;
  // Nouveau flux : page Collectif + non meublée
  bool _showCollectifForm = false;
  // Collectif d'un bail individuel : locataires en lecture seule.
  bool _showCollectifLockLocataires = false;
  // Nouveau flux : page Individuel + meublée (unité = chambre)
  bool _showIndividuelForm = false;
  ChambreModel? _formChambre;
  bool _formMeublee = false; // location meublée (affiche l'inventaire)
  ImmeublesModel? _formImmeuble;
  EtatDesLieuxModel? _formEdl; // EDL existant à éditer dans le nouveau flux
  // Mode avenant : privatif rattaché à un collectif finalisé existant.
  bool _formIsAvenant = false;
  int? _formAvenantCollectifId;
  late Future<_PageData> _future;

  /// Démarre un nouvel EDL : popup de sélection d'immeuble puis routage.
  /// Cas géré : Collectif + non meublée → nouvelle page.
  /// Autres cas → SnackBar "en cours de développement".
  Future<void> _startNewEdl(String typeEdl) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final immeubles = await ImmeublesDatasource.listByOwner(uid);
    if (!mounted) return;

    // Disponibilité des chambres (bail individuel) pour les cards d'immeuble :
    // chambres sans EDL de ce type / total. Une seule passe pour tous.
    final individualIds =
        immeubles.where((i) => i.bailIndividuel).map((i) => i.id).toList();
    final allChambres =
        await ChambresDatasource.listByImmeubles(individualIds);
    final occupied =
        await EtatDesLieuxDatasource.chambreIdsWithEdlForImmeubles(
      immeubleIds: individualIds,
      typeEdl: typeEdl,
    );
    if (!mounted) return;
    final stats = <int, ({int total, int available})>{};
    for (final id in individualIds) {
      final chs = allChambres.where((c) => c.immeubleId == id).toList();
      final avail = chs.where((c) => !occupied.contains(c.id)).length;
      stats[id] = (total: chs.length, available: avail);
    }

    // Boucle : le bouton « Retour » de la sélection de chambre revient ici.
    while (true) {
      final selected = await showSelectImmeubleDialog(
        context,
        immeubles,
        chambreStats: stats,
      );
      if (selected == null || !mounted) return;
      // location_meuble peut être null (non répondu) → traité comme non meublée.
      final meublee = selected.locationMeuble == true;

      if (!selected.bailIndividuel) {
        // Bail collectif (parties communes).
        setState(() {
          _showCollectifForm = true;
          _formImmeuble = selected;
          _formMeublee = meublee;
          _formEdl = null;
          _formTypeEdl = typeEdl;
        });
        return;
      }

      // Bail individuel → sélection de la chambre.
      final chambres =
          allChambres.where((c) => c.immeubleId == selected.id).toList();
      if (chambres.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cet immeuble n\'a aucune chambre.')),
        );
        continue; // revient au choix d'immeuble
      }
      final res = await showSelectChambreDialog(
        context,
        chambres,
        chambresAvecEdl: occupied,
      );
      if (res == null || !mounted) return; // annulé
      if (res.back) continue; // « Retour » → ré-affiche les immeubles
      final chambre = res.chambre!;

      // Décide du rattachement collectif : ouvert → normal ; finalisé → demande
      // « nouveau contrat » ou « avenant au contrat existant ».
      bool isAvenant = false;
      int? avenantCollectifId;
      final open = await EtatDesLieuxDatasource.findOpenCollectif(
        immeubleId: selected.id,
        typeEdl: typeEdl,
      );
      if (!mounted) return;
      if (open == null) {
        final finalised = await EtatDesLieuxDatasource.findCollectif(
          immeubleId: selected.id,
          typeEdl: typeEdl,
        );
        if (!mounted) return;
        if (finalised != null && finalised.situation == SituationEdl.finalise) {
          final choice = await _askNouveauOuAvenant();
          if (choice == null || !mounted) return; // annulé
          if (choice == _ContratChoice.avenant) {
            isAvenant = true;
            avenantCollectifId = finalised.id;
          }
        }
      }

      setState(() {
        _showIndividuelForm = true;
        _formImmeuble = selected;
        _formChambre = chambre;
        _formMeublee = meublee;
        _formEdl = null;
        _formTypeEdl = typeEdl;
        _formIsAvenant = isAvenant;
        _formAvenantCollectifId = avenantCollectifId;
      });
      return;
    }
  }

  /// Demande, quand le collectif d'entrée est déjà finalisé, si le nouvel EDL
  /// individuel fait partie d'un nouveau contrat collectif ou d'un avenant au
  /// contrat existant. Retourne null si annulé.
  Future<_ContratChoice?> _askNouveauOuAvenant() {
    return showDialog<_ContratChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contrat collectif déjà finalisé'),
        content: const Text(
          "L'état des lieux collectif d'entrée de cet immeuble est déjà "
          "finalisé.\n\nCe nouveau locataire fait-il partie d'un nouveau "
          'contrat collectif, ou doit-il être ajouté (avenant) au contrat '
          'existant ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, _ContratChoice.nouveau),
            child: const Text('Nouveau contrat'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _ContratChoice.avenant),
            child: const Text('Avenant au contrat existant'),
          ),
        ],
      ),
    );
  }

  /// Flux Avenant (bouton « Avenant ») : choisir un collectif finalisé avec des
  /// chambres libres, puis une chambre libre → page individuel en mode avenant.
  Future<void> _startAvenant(String typeEdl) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final amendables = await EtatDesLieuxDatasource.listAmendableCollectifs(
      uid,
      typeEdl: typeEdl,
    );
    if (!mounted) return;
    if (amendables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Aucun contrat collectif finalisé avec des chambres libres.'),
        ),
      );
      return;
    }
    final picked = await showSelectCollectifAvenantDialog(context, amendables);
    if (picked == null || !mounted) return;
    final res =
        await showSelectChambreDialog(context, picked.freeChambres);
    if (res == null || res.back || !mounted) return;
    final chambre = res.chambre!;
    final immeubles = await ImmeublesDatasource.listByOwner(uid);
    if (!mounted) return;
    final immeuble = immeubles
        .where((i) => i.id == picked.collectif.immeubleId)
        .firstOrNull;
    if (immeuble == null) return;
    setState(() {
      _showIndividuelForm = true;
      _formImmeuble = immeuble;
      _formChambre = chambre;
      _formMeublee = immeuble.locationMeuble == true;
      _formEdl = null;
      _formTypeEdl = typeEdl;
      _formIsAvenant = true;
      _formAvenantCollectifId = picked.collectif.id;
    });
  }

  /// Ouvre un EDL existant pour édition, en routant vers la bonne page selon
  /// bail (collectif/individuel) — meublée ou non.
  Future<void> _openExistingEdl(EtatDesLieuxModel edl) async {
    void notDev() {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "L'édition de ce type d'EDL est en cours de développement."),
        ),
      );
    }

    // Charger l'immeuble pour connaître bail / location_meuble.
    ImmeublesModel? immeuble;
    try {
      final uid = AuthService.currentUser?.id ?? '';
      final list = await ImmeublesDatasource.listByOwner(uid);
      immeuble = list.where((i) => i.id == edl.immeubleId).firstOrNull;
    } catch (_) {}
    if (!mounted) return;
    if (immeuble == null) {
      notDev();
      return;
    }
    final meublee = immeuble.locationMeuble == true;

    // Individuel + privatif (chambre) → page individuel.
    if (edl.typeBail == 'individuel' &&
        edl.partie == PartieEdl.privative &&
        edl.chambreId != null) {
      ChambreModel? chambre;
      try {
        final chambres =
            await ChambresDatasource.listByImmeubles([immeuble.id]);
        chambre = chambres.where((c) => c.id == edl.chambreId).firstOrNull;
      } catch (_) {}
      if (!mounted) return;
      if (chambre == null) {
        notDev();
        return;
      }
      setState(() {
        _showIndividuelForm = true;
        _formImmeuble = immeuble;
        _formChambre = chambre;
        _formMeublee = meublee;
        _formEdl = edl;
        _formTypeEdl = edl.typeEdl;
      });
      return;
    }

    // Collectif (parties communes) — bail collectif OU bail individuel.
    // Pour un bail individuel, les locataires y sont en lecture seule
    // (gérés via les EDL individuels) → lockLocataires.
    if (edl.partie == PartieEdl.commune) {
      setState(() {
        _showCollectifForm = true;
        _showCollectifLockLocataires = edl.typeBail == 'individuel';
        _formImmeuble = immeuble;
        _formMeublee = meublee;
        _formEdl = edl;
        _formTypeEdl = edl.typeEdl;
      });
      return;
    }

    notDev();
  }

  /// Message bloquant la suppression (EDL finalisé ou collectif avec privatifs).
  void _showDeleteBlocked(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.block, color: AppColors.error),
        title: const Text('Suppression impossible'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(EtatDesLieuxModel edl) async {
    // Règle 1 : un EDL finalisé ne peut pas être supprimé.
    if (edl.situation == SituationEdl.finalise) {
      _showDeleteBlocked(
        'Cet état des lieux est finalisé et ne peut pas être supprimé.',
      );
      return;
    }
    // Règle 2 : un collectif lié à des EDL individuels doit d'abord voir
    // ses privatifs supprimés.
    if (edl.partie == PartieEdl.commune) {
      final privatifs =
          await EtatDesLieuxDatasource.listPrivativesByCollectif(edl.id);
      if (!mounted) return;
      if (privatifs.isNotEmpty) {
        _showDeleteBlocked(
          'Ce contrat collectif est lié à ${privatifs.length} '
          'état(s) des lieux individuel(s). Supprimez-les d\'abord.',
        );
        return;
      }
    }
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
  Set<String> get watchedEntities => {'edl'};

  @override
  void onRealtimeChange() {
    // Ne pas recharger (ni reconstruire la liste) tant qu'un formulaire plein
    // écran est ouvert : les insertions faites pendant l'enregistrement
    // déclencheraient sinon des rebuilds inutiles sous l'utilisateur.
    if (_showForm ||
        _showCollectifForm ||
        _showIndividuelForm ||
        _showDetail) {
      return;
    }
    _reload();
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
        meublee: _formMeublee,
        lockLocataires: _showCollectifLockLocataires,
        onClose: (refresh) {
          setState(() {
            _showCollectifForm = false;
            _showCollectifLockLocataires = false;
            _formImmeuble = null;
            _formEdl = null;
          });
          if (refresh) _reload();
        },
      );
    }

    if (_showIndividuelForm && _formImmeuble != null && _formChambre != null) {
      return EdlIndividuelMeubleePage(
        immeuble: _formImmeuble!,
        chambre: _formChambre!,
        typeEdl: _formTypeEdl,
        existingEdl: _formEdl,
        meublee: _formMeublee,
        isAvenant: _formIsAvenant,
        avenantCollectifId: _formAvenantCollectifId,
        onClose: (refresh) {
          setState(() {
            _showIndividuelForm = false;
            _formImmeuble = null;
            _formChambre = null;
            _formEdl = null;
            _formIsAvenant = false;
            _formAvenantCollectifId = null;
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
                    onAvenant: () => _startAvenant('entree'),
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
                    // Visualiser : ouvre la fiche en lecture seule (sans éditer).
                    onVisualiser: (e) => setState(() {
                      _detailEdl = e;
                      _showDetail = true;
                    }),
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
  final VoidCallback? onAvenant;
  final ValueChanged<EtatDesLieuxModel> onVoir;
  final ValueChanged<EtatDesLieuxModel>? onEditer;
  final ValueChanged<EtatDesLieuxModel>? onDelete;
  final ValueChanged<EtatDesLieuxModel>? onVisualiser;

  const _VisionGeneraleTab({
    required this.all,
    required this.invitedLocataires,
    required this.onNouveau,
    this.onAvenant,
    required this.onVoir,
    this.onEditer,
    this.onDelete,
    this.onVisualiser,
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
              // Largeur du card invités = nb de colonnes (3 par colonne) × 300,
              // pour qu'il occupe juste le nécessaire et ne s'étire pas.
              final invCols = invitedLocataires.isEmpty
                  ? 1
                  : ((invitedLocataires.length + 2) ~/ 3);
              // 360 par colonne : titre complet + séparateurs bord à bord.
              final invitesWidth = invCols * 360.0;
              // IntrinsicHeight + stretch : les deux cartes ont la même hauteur.
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 280, child: stat),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: invitesWidth),
                        child: invites,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          _EdlTableCard(
            edls: all,
            title: 'Tous les états des lieux',
            onNouveau: onNouveau,
            onAvenant: onAvenant,
            onVoir: onVoir,
            onEditer: onEditer,
            onDelete: onDelete,
            onVisualiser: onVisualiser,
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
  // Max de lignes par colonne ; au-delà, une nouvelle colonne est créée.
  static const int _rowsPerColumn = 3;
  static const double _rowHeight = 64;
  // Largeur d'une colonne = largeur de la carte (le séparateur entre lignes
  // s'étend ainsi d'un bord à l'autre). Doit correspondre à `invitesWidth`.
  static const double _columnWidth = 360;

  // Ids en cours de renvoi d'invitation (spinner sur la ligne).
  final Set<String> _sending = {};

  Future<void> _resend(UsersClient loc) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    setState(() => _sending.add(loc.id));
    try {
      await EtatDesLieuxDatasource.resendInvitation(
        userId: loc.id,
        email: loc.email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation renvoyée à ${loc.email}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _sending.remove(loc.id));
    }
  }

  /// Découpe la liste en colonnes de [_rowsPerColumn] lignes.
  List<List<UsersClient>> get _columns {
    final out = <List<UsersClient>>[];
    for (var i = 0; i < widget.locataires.length; i += _rowsPerColumn) {
      final end = (i + _rowsPerColumn < widget.locataires.length)
          ? i + _rowsPerColumn
          : widget.locataires.length;
      out.add(widget.locataires.sublist(i, end));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.locataires.length;
    final columns = _columns;
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
            // Colonnes de 3 lignes côte à côte (scroll horizontal si nécessaire).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c = 0; c < columns.length; c++) ...[
                      if (c > 0) const VerticalDivider(width: 1),
                      SizedBox(
                        width: _columnWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var r = 0; r < columns[c].length; r++) ...[
                              if (r > 0) const Divider(height: 1),
                              _invitedRow(columns[c][r]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _invitedRow(UsersClient loc) {
    final sending = _sending.contains(loc.id);
    return SizedBox(
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            _InitialsAvatar.name(loc.fullName ?? loc.email),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(width: AppSpacing.xs),
            TextButton.icon(
              onPressed: sending ? null : () => _resend(loc),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                visualDensity: VisualDensity.compact,
              ),
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 16),
              label: const Text('Renvoyer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar avec initiales

class _InitialsAvatar extends StatelessWidget {
  /// Un nom par locataire/preneur. Plusieurs noms → le cercle est partagé en
  /// parts (une par locataire), chacune avec son initiale.
  final List<String> names;
  static const double size = 36;
  static const int _maxSlices = 4; // au-delà, la dernière part affiche « +N »

  const _InitialsAvatar({required this.names});

  /// Raccourci pour un seul locataire.
  _InitialsAvatar.name(String name) : names = [name];

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final valid = names.where((n) => n.trim().isNotEmpty).toList();

    // Un seul locataire (ou aucun) → cercle plein avec les initiales.
    if (valid.length <= 1) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.primaryFixed,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          valid.isEmpty ? '?' : _initialsOf(valid.first),
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onPrimaryFixedVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Plusieurs locataires → parts de camembert, une par preneur (max 4).
    final slices = <_AvatarSlice>[];
    if (valid.length <= _maxSlices) {
      for (var i = 0; i < valid.length; i++) {
        slices.add(_AvatarSlice(
          label: valid[i].trim().substring(0, 1).toUpperCase(),
          color: _kContratColors[i % _kContratColors.length],
        ));
      }
    } else {
      for (var i = 0; i < _maxSlices - 1; i++) {
        slices.add(_AvatarSlice(
          label: valid[i].trim().substring(0, 1).toUpperCase(),
          color: _kContratColors[i % _kContratColors.length],
        ));
      }
      slices.add(_AvatarSlice(
        label: '+${valid.length - (_maxSlices - 1)}',
        color: AppColors.onSurfaceVariant,
      ));
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SegmentedAvatarPainter(slices),
        // Tooltip avec la liste complète des locataires.
        child: Tooltip(message: valid.join('\n'), child: const SizedBox.expand()),
      ),
    );
  }
}

class _AvatarSlice {
  final String label;
  final Color color;
  const _AvatarSlice({required this.label, required this.color});
}

/// Dessine un avatar circulaire divisé en parts égales (une par locataire),
/// avec un séparateur blanc et l'initiale au centre de chaque part.
class _SegmentedAvatarPainter extends CustomPainter {
  final List<_AvatarSlice> slices;
  const _SegmentedAvatarPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final n = slices.length;
    final sweep = 2 * math.pi / n;
    const start = -math.pi / 2; // première part en haut

    // Parts colorées.
    for (var i = 0; i < n; i++) {
      final paint = Paint()
        ..color = slices[i].color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawArc(rect, start + i * sweep, sweep, true, paint);
    }

    // Séparateurs radiaux blancs.
    final divider = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < n; i++) {
      final a = start + i * sweep;
      canvas.drawLine(
        center,
        center + Offset(math.cos(a), math.sin(a)) * radius,
        divider,
      );
    }

    // Initiales au centre de chaque part.
    final fontSize = n >= 4 ? 8.0 : 9.0;
    for (var i = 0; i < n; i++) {
      final mid = start + (i + 0.5) * sweep;
      final pos = center + Offset(math.cos(mid), math.sin(mid)) * (radius * 0.58);
      final tp = TextPainter(
        text: TextSpan(
          text: slices[i].label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedAvatarPainter old) =>
      old.slices != slices;
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
  final VoidCallback? onAvenant;
  final ValueChanged<EtatDesLieuxModel> onVoir;
  final ValueChanged<EtatDesLieuxModel>? onEditer;
  final ValueChanged<EtatDesLieuxModel>? onDelete;
  final ValueChanged<EtatDesLieuxModel>? onVisualiser;

  /// true → shrinkWrap (pour SingleChildScrollView parent),
  /// false → Expanded (pour tab plein écran)
  final bool shrinkWrap;

  const _EdlTableCard({
    required this.edls,
    required this.title,
    required this.onNouveau,
    required this.onVoir,
    required this.shrinkWrap,
    this.onAvenant,
    this.onEditer,
    this.onDelete,
    this.onVisualiser,
  });

  @override
  State<_EdlTableCard> createState() => _EdlTableCardState();
}

class _EdlTableCardState extends State<_EdlTableCard> {
  EdlTableFilter _filter = EdlTableFilter.empty;

  List<EtatDesLieuxModel> get _filtered =>
      widget.edls.where(_filter.matches).toList();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _buildCard(
        context,
        isNarrow: constraints.maxWidth < 900,
      ),
    );
  }

  /// En-tête de colonne (texte centré, largeur fixe).
  Widget _colHeader(String label, double width) => SizedBox(
        width: width,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      );

  Widget _buildCard(BuildContext context, {required bool isNarrow}) {
    final filtered = _filtered;
    final totalCount = widget.edls.length;

    // Contrats regroupés (collectif ↔ privatifs) visibles dans la liste :
    // ids de collectifs référencés par au moins un privatif affiché. Un EDL
    // n'affiche la barre/icône que s'il appartient à un tel groupe.
    final linkedCollectifIds = <int>{
      for (final e in filtered)
        if (e.partie == PartieEdl.privative && e.edlCollectifId != null)
          e.edlCollectifId!,
    };
    Color? contratColorFor(EtatDesLieuxModel e) {
      final cid = e.contratId;
      if (cid == null) return null;
      final grouped = e.partie == PartieEdl.privative
          ? true // un privatif est toujours lié à son collectif
          : linkedCollectifIds.contains(e.id); // collectif avec ≥1 privatif visible
      return grouped ? _contratColor(cid) : null;
    }

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
          if (widget.onAvenant != null) ...[
            OutlinedButton.icon(
              onPressed: widget.onAvenant,
              icon: const Icon(Icons.note_add_outlined, size: 18),
              label: const Text('Avenant'),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
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
      child: EdlFilterBar(
        filter: _filter,
        edls: widget.edls,
        onChanged: (f) => setState(() => _filter = f),
        modules: const {
          EdlFilterModule.recherche,
          EdlFilterModule.situation,
          EdlFilterModule.bail,
          EdlFilterModule.typeEdl,
          EdlFilterModule.dateCreation,
          EdlFilterModule.dateFinalisation,
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
          // slot icône de lien + avatar placeholder
          const SizedBox(width: _colLink),
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
          _colHeader('TYPE', _colType),
          const SizedBox(width: AppSpacing.md),
          _colHeader('SITUATION', _colSit),
          const SizedBox(width: AppSpacing.md),
          _colHeader('SENS', _colSens),
          const SizedBox(width: AppSpacing.md),
          _colHeader('DATE EDL', _colEtat),
          const SizedBox(width: AppSpacing.md),
          _colHeader('FINALISATION', _colFin),
          const SizedBox(width: AppSpacing.md),
          SizedBox(width: _colEye),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(width: _colBtn),
          const SizedBox(width: AppSpacing.sm),
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
                    : 'Aucun résultat pour ces filtres.',
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
              contratColor: contratColorFor(filtered[i]),
              onVoir: () => widget.onVoir(filtered[i]),
              onEditer: widget.onEditer != null
                  ? () => widget.onEditer!(filtered[i])
                  : null,
              onDelete: widget.onDelete != null
                  ? () => widget.onDelete!(filtered[i])
                  : null,
              onVisualiser: widget.onVisualiser != null
                  ? () => widget.onVisualiser!(filtered[i])
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
  // Visualiser (lecture seule) — bouton œil. Null = pas affiché.
  final VoidCallback? onVisualiser;
  final bool compact;
  // Couleur du contrat (collectif ↔ privatifs). Non null = barre + icône lien.
  final Color? contratColor;

  const _EdlRow({
    required this.edl,
    required this.onVoir,
    this.onEditer,
    this.onDelete,
    this.onVisualiser,
    this.compact = false,
    this.contratColor,
  });

  /// Noms des locataires pour l'avatar : la liste des preneurs (collectif) ou le
  /// locataire principal (privatif). Plusieurs → avatar divisé en parts.
  List<String> get _avatarNames {
    if (edl.preneursNoms.length > 1) return edl.preneursNoms;
    final single = edl.locataireNom ?? edl.locataireEmail;
    if (single != null && single.trim().isNotEmpty) return [single];
    if (edl.preneursNoms.isNotEmpty) return edl.preneursNoms;
    return const ['?'];
  }

  /// Texte du tooltip du lien de contrat (selon collectif/privatif).
  String get _contratTooltip {
    final imm = edl.immeubleNom ?? 'Immeuble';
    final ref = edl.contratId != null ? ' #${edl.contratId}' : '';
    return edl.partie == PartieEdl.commune
        ? 'Contrat collectif$ref — $imm\n(regroupe les états des lieux individuels)'
        : 'Lié au contrat collectif$ref — $imm';
  }

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
    return Container(
      decoration: contratColor != null
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: contratColor!, width: 4),
              ),
            )
          : null,
      padding: EdgeInsets.only(
        left: AppSpacing.md - (contratColor != null ? 4 : 0),
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _InitialsAvatar(names: _avatarNames),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      edl.displayLocataire,
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
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _TypePill(label: edl.immeubleTypeLabel, muted: true),
              _TypePill(label: edl.meubleLabel, muted: !edl.immeubleMeuble),
              _TypePill(label: edl.typeLabel),
              _TypePill(label: edl.sensLabel, muted: true),
              if (contratColor != null)
                _ContratLink(
                  color: contratColor!,
                  tooltip: _contratTooltip,
                  label: edl.contratId != null
                      ? 'Contrat #${edl.contratId}'
                      : 'Contrat',
                ),
            ],
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
              if (onVisualiser != null) ...[
                OutlinedButton.icon(
                  onPressed: onVisualiser,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Voir'),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: onVoir,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Continuer'),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: AppSpacing.sm),
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

    // Barre colorée à gauche (bord) pour regrouper le contrat ; la marge gauche
    // est compensée de 4 px pour ne pas décaler le contenu vs les autres lignes.
    return Container(
      decoration: contratColor != null
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: contratColor!, width: 4),
              ),
            )
          : null,
      padding: EdgeInsets.only(
        left: AppSpacing.lg - (contratColor != null ? 4 : 0),
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icône de lien de contrat (slot toujours réservé pour l'alignement)
          SizedBox(
            width: _colLink,
            child: contratColor != null
                ? _ContratLink(color: contratColor!, tooltip: _contratTooltip)
                : null,
          ),
          // Avatar
          _InitialsAvatar(names: _avatarNames),
          const SizedBox(width: AppSpacing.md),

          // LOCATAIRE (flex 3)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edl.displayLocataire,
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

          // TYPE : type d'immeuble + meublé/non + Collectif/Individuel
          SizedBox(
            width: _colType,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  edl.immeubleTypeLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                _TypePill(label: edl.meubleLabel, muted: !edl.immeubleMeuble),
                const SizedBox(height: 3),
                _TypePill(label: edl.typeLabel, muted: true),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // SITUATION (4ᵉ colonne)
          SizedBox(
            width: _colSit,
            child: Center(
              child: locataireASigner
                  ? _LocataireASignerBadge()
                  : _SituationBadge(situation: edl.situation),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // SENS (Entrée / Sortie)
          SizedBox(
            width: _colSens,
            child: Text(
              edl.sensLabel,
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
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

          // Visualiser (œil) — colonne toujours réservée pour l'alignement.
          SizedBox(
            width: _colEye,
            height: 32,
            child: onVisualiser == null
                ? null
                : OutlinedButton(
                    onPressed: onVisualiser,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderMd,
                      ),
                    ),
                    child: const Icon(Icons.visibility_outlined, size: 16),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Bouton Continuer (compact, icône crayon)
          SizedBox(
            width: _colBtn,
            child: FilledButton.icon(
              onPressed: onVoir,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Continuer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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

/// Pastille pour le type (Collectif/Individuel) ou le sens (Entrée/Sortie).
/// Indicateur de lien de contrat (EDL collectif ↔ privatifs) : icône chaîne
/// colorée par contrat, avec tooltip. En mode carte, peut afficher un libellé
/// « Contrat #id » sous forme de pastille.
class _ContratLink extends StatelessWidget {
  final Color color;
  final String tooltip;
  final String? label;
  const _ContratLink({required this.color, required this.tooltip, this.label});

  @override
  Widget build(BuildContext context) {
    final Widget content = label == null
        ? Icon(Icons.link, size: 16, color: color)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.borderFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  label!,
                  style: AppTypography.labelSm.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
    return Tooltip(message: tooltip, child: content);
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final bool muted;
  const _TypePill({required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final bg =
        muted ? AppColors.surfaceContainerHigh : AppColors.primaryFixed;
    final fg = muted
        ? AppColors.onSurfaceVariant
        : AppColors.onPrimaryFixedVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.labelSm.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

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
  // Lecture seule (locataire ou EDL finalisé) : les murs ne sont plus éditables.
  final bool readOnly;

  const _RoomDiagram({
    required this.chambreName,
    this.planLabel,
    this.chambrePhoto,
    required this.observations,
    required this.onEditWall,
    this.readOnly = false,
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
          readOnly
              ? 'Appuyez sur chaque mur pour consulter les observations.'
              : 'Appuyez sur chaque mur pour ajouter des observations et photos.',
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
                    onTap: () => readOnly ? null : onEditWall('fond'),
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
                    onTap: () => readOnly ? null : onEditWall('gauche'),
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
                                onTap: () => readOnly ? null : onEditWall('plafond'),
                                alignTop: true,
                              ),
                            ),
                            Expanded(
                              child: _InnerZone(
                                label: 'Sol',
                                icon: Icons.expand_more,
                                obsCount: _obsCount('sol'),
                                onTap: () => readOnly ? null : onEditWall('sol'),
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
                    onTap: () => readOnly ? null : onEditWall('droit'),
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
                    onTap: () => readOnly ? null : onEditWall('porte'),
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
          padding: const EdgeInsets.all(2),
          alignment: Alignment.center,
          // scaleDown : si le contenu (icône + libellé 2 lignes + « N obs. »)
          // dépasse la hauteur fixe du panneau, on le réduit au lieu de déborder.
          child: FittedBox(fit: BoxFit.scaleDown, child: content),
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
  // Quais observações o usuário atual pode editar/excluir (null = todas).
  final bool Function(ObservationEdl)? canModify;

  const _ObservationsList({
    required this.observations,
    required this.onEdit,
    required this.onDelete,
    this.canModify,
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

    // Um "bloco" por mur (cabeçalho + suas observações), mantido inteiro para
    // poder dispor os blocos em 2 colunas sem separar header das obs.
    final blocks = <Widget>[];
    for (final wallKey in _wallOrder) {
      final group = grouped[wallKey];
      if (group == null || group.isEmpty) continue;

      blocks.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            for (final obs in group)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ObservationTile(
                  obs: obs,
                  canModify: canModify?.call(obs) ?? true,
                  onEdit: () => onEdit(obs),
                  onDelete: () => onDelete(obs),
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
          'OBSERVATIONS ENREGISTRÉES',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        // 2 colunas (cada bloco = metade da largura) em telas não-mobile;
        // empilhado no mobile (< 600px).
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: blocks,
              );
            }
            const gap = AppSpacing.lg;
            final colWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: 0,
              children: [
                for (final b in blocks) SizedBox(width: colWidth, child: b),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ObservationTile extends StatelessWidget {
  final ObservationEdl obs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canModify;

  const _ObservationTile({
    required this.obs,
    required this.onEdit,
    required this.onDelete,
    this.canModify = true,
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
                if (obs.isLocataire) ...[
                  _LocataireBadge(),
                  const SizedBox(height: AppSpacing.xs),
                ],
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
          if (canModify) ...[
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
        ],
      ),
    );
  }
}

/// Selo "Ajouté par le locataire" para observações criadas pelo locataire.
class _LocataireBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 12,
              color: AppColors.onTertiaryFixed),
          const SizedBox(width: 4),
          Text(
            'Ajouté par le locataire',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onTertiaryFixed,
              fontWeight: FontWeight.w600,
            ),
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

/// Dialog d'ajout d'une **addition** (post-finalisation) : choix du comodo
/// (la chambre ou une pièce commune) + observation + photo. La date/heure est
/// enregistrée automatiquement (created_at).
class _AdditionDialog extends StatefulWidget {
  final List<({String label, int? pieceId, int? chambreId})> comodos;
  const _AdditionDialog({required this.comodos});

  @override
  State<_AdditionDialog> createState() => _AdditionDialogState();
}

class _AdditionDialogState extends State<_AdditionDialog> {
  late final TextEditingController _descCtrl;
  List<String> _photos = [];
  int _comodoIndex = 0;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une addition'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('OÙ (comodo)',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  )),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<int>(
                initialValue: _comodoIndex,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (var i = 0; i < widget.comodos.length; i++)
                    DropdownMenuItem(
                        value: i, child: Text(widget.comodos[i].label)),
                ],
                onChanged: (v) => setState(() => _comodoIndex = v ?? 0),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observation',
                  hintText: 'Décrivez l\'élément non vérifié…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('PHOTO',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  )),
              const SizedBox(height: AppSpacing.sm),
              PhotoPickerField(
                folder: 'etat_de_lieux/additions',
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
          onPressed: () {
            final c = widget.comodos[_comodoIndex];
            Navigator.pop(context, (
              description:
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              photos: _photos,
              pieceId: c.pieceId,
              chambreId: c.chambreId,
            ));
          },
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
  // Mode locataire (preneur) : Bien/Locataires/Dates en lecture seule ; le
  // locataire n'ajoute/édite que SES propres observations (author_role).
  final bool isLocataire;
  // Location meublée → affiche l'inventaire (composition) des pièces.
  final bool meublee;
  // Collectif d'un bail **individuel** (parties communes) : les locataires ne
  // s'éditent pas ici (ils viennent des EDL individuels) → section read-only +
  // section « Avenants ».
  final bool lockLocataires;

  const EdlCollectifNonMeubleePage({
    super.key,
    required this.immeuble,
    required this.typeEdl,
    this.existingEdl,
    required this.onClose,
    this.isLocataire = false,
    this.meublee = false,
    this.lockLocataires = false,
  });

  @override
  State<EdlCollectifNonMeubleePage> createState() =>
      _EdlCollectifNonMeubleePageState();
}

class _EdlCollectifNonMeubleePageState
    extends State<EdlCollectifNonMeubleePage> {
  int? _edlId;
  DateTime _date = DateTime.now();
  DateTime? _dateFinalisation;
  bool _isSaving = false;
  bool _isFinalising = false;
  SituationEdl _situation = SituationEdl.enCours;
  bool _locataireAccepte = false;

  List<PieceModel> _pieces = [];
  List<ChambreModel> _chambres = [];
  List<EdlPreneur> _preneurs = [];
  List<ObservationEdl> _observations = [];
  // Inventaire (sections + lignes) chargé une seule fois ; affiché DANS chaque
  // accordéon de pièce/chambre (pas dans une section séparée).
  List<EdlSection> _sections = [];

  final _scrollCtrl = ScrollController();
  final Map<String, GlobalKey> _tileKeys = {};
  // Fallback local (locataireId → e-mail) caso le join Users_Client soit
  // bloqué par la RLS au moment du rechargement des preneurs.
  final Map<String, String> _emailByLocataire = {};

  @override
  void initState() {
    super.initState();
    final edl = widget.existingEdl;
    if (edl != null) {
      _edlId = edl.id;
      _date = edl.dateEtatLieux;
      _dateFinalisation = edl.dateFinalisation;
      _situation = edl.situation;
      _locataireAccepte = edl.locataireAccepte;
    }
    _loadRooms();
    if (edl != null) {
      _loadPreneurs();
      _loadObservations();
      if (widget.meublee) _loadSections();
      if (widget.lockLocataires) _loadAvenants();
    }
  }

  Future<void> _loadSections() async {
    if (_edlId == null) return;
    try {
      final s = await EdlDetailsDatasource.listSections(_edlId!);
      if (mounted) setState(() => _sections = s);
    } catch (_) {}
  }

  /// Section d'inventaire correspondant à une pièce/chambre (par nom, en MAJ).
  EdlSection? _sectionFor(String name) {
    final key = name.trim().toUpperCase();
    for (final s in _sections) {
      if (s.nom.trim().toUpperCase() == key) return s;
    }
    return null;
  }

  Future<void> _addLigneTo(EdlSection section) async {
    await EdlDetailsDatasource.createLigne(EdlLigne(
      sectionId: section.id!,
      equipement: 'Nouvel élément',
      ordre: section.lignes.length,
    ));
    await _loadSections();
  }

  Future<void> _saveLigne(EdlLigne ligne) async {
    if (ligne.id == null) return;
    await EdlDetailsDatasource.updateLigne(ligne.id!, ligne);
  }

  Future<void> _deleteLigne(int id) async {
    await EdlDetailsDatasource.deleteLigne(id);
    await _loadSections();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _saved => _edlId != null;
  bool get _isLocataire => widget.isLocataire;
  // Locataires non éditables ici (collectif d'un bail individuel).
  bool get _lockLocataires => widget.lockLocataires;

  // Privatifs « avenant » rattachés à ce collectif (entrés après coup).
  List<EtatDesLieuxModel> _avenants = [];

  Future<void> _loadAvenants() async {
    if (_edlId == null) return;
    try {
      final privatifs =
          await EtatDesLieuxDatasource.listPrivativesByCollectif(_edlId!);
      if (!mounted) return;
      setState(() =>
          _avenants = privatifs.where((p) => p.isAvenant).toList());
    } catch (_) {}
  }

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
        // Meublée : importe l'inventaire des pièces communes (sections/lignes).
        if (widget.meublee) await _autoSeedInventaire();
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

  /// Importe l'inventaire de l'immeuble (articles liés aux pièces) en sections
  /// du collectif. Idempotent. Best-effort.
  Future<void> _autoSeedInventaire() async {
    final id = _edlId;
    if (id == null) return;
    try {
      final existing = await EdlDetailsDatasource.listSections(id);
      if (existing.isNotEmpty) return;
      final items = await InventaireDatasource.listByImmeuble(widget.immeuble.id);
      for (var pi = 0; pi < _pieces.length; pi++) {
        final p = _pieces[pi];
        final lignes = items
            .where((it) => it.pieceId == p.id)
            .toList()
            .asMap()
            .entries
            .map((e) => EdlLigne(
                  sectionId: 0,
                  equipement: e.value.displayNom,
                  natureNombre:
                      e.value.quantite > 0 ? e.value.quantite.toString() : null,
                  ordre: e.key,
                ))
            .toList();
        await EdlDetailsDatasource.createSectionWithLignes(
          EdlSection(etatDesLieuxId: id, nom: p.nom.toUpperCase(), ordre: pi),
          lignes,
        );
      }
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _onSavePressed() async {
    final ok = await _saveEdl();
    if (ok) {
      if (widget.meublee) await _loadSections();
      _snack('Enregistré.');
    }
  }

  /// Fermeture avec confirmation (Continuer / Quitter / Sauvegarder et quitter).
  Future<void> _handleClose() async {
    if (_isLocataire) {
      widget.onClose(_saved);
      return;
    }
    final choice = await showUnsavedChangesDialog(
      context,
      message: 'Voulez-vous enregistrer les modifications avant de quitter ?',
    );
    if (!mounted) return;
    switch (choice) {
      case UnsavedChoice.cancel:
        return;
      case UnsavedChoice.discard:
        widget.onClose(_saved);
      case UnsavedChoice.save:
        final ok = await _saveEdl();
        if (ok && mounted) widget.onClose(true);
    }
  }

  Future<void> _addPreneur(UsersClient user) async {
    if (_preneurs.any((p) => p.locataireId == user.id)) {
      _snack('Ce locataire est déjà ajouté.');
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

  /// Ouvre le pop-up de création d'un nouveau locataire. À la confirmation,
  /// la fonction edge `invite-locataire` crée le compte et envoie l'e-mail
  /// d'activation ; le locataire est ensuite ajouté comme preneur de l'EDL.
  Future<void> _openCreerLocataireDialog() async {
    final uid = AuthService.currentUser?.id ?? '';
    final created = await showDialog<UsersClient>(
      context: context,
      builder: (_) => _CreerLocataireDialog(proprietaireId: uid),
    );
    if (created == null || !mounted) return;
    await _addPreneur(created);
    _snack('Locataire enregistré — un e-mail d\'activation a été envoyé.');
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
        authorRole: _isLocataire ? 'locataire' : 'proprietaire',
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
        authorRole: _isLocataire ? 'locataire' : 'proprietaire',
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

  /// Finaliser (proprietaire) : change la situation à `finalise`. La date de
  /// finalisation n'est gravée qu'à l'acceptation du locataire.
  Future<void> _finaliser() async {
    if (_edlId == null) {
      final ok = await _saveEdl();
      if (!ok || !mounted) return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Finaliser l'état des lieux"),
        content: const Text(
          "Cette action finalisera l'état des lieux. La date de finalisation "
          "sera enregistrée uniquement lorsque le locataire l'aura accepté. "
          "Voulez-vous continuer ?",
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
      await EtatDesLieuxDatasource.finaliser(_edlId!);
      if (mounted) setState(() => _situation = SituationEdl.finalise);
      _snack('État des lieux finalisé.');
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isFinalising = false);
    }
  }

  /// Accepter et signer (locataire) : grave `locataire_accepte` + date.
  Future<void> _accepter() async {
    if (_edlId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Accepter l'état des lieux"),
        content: const Text(
          "En acceptant, vous confirmez être d'accord avec le contenu de cet "
          "état des lieux. La date de signature sera enregistrée. Continuer ?",
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppTheme.cancelButtonStyle,
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.saveButtonStyle,
            child: const Text('Accepter et signer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isFinalising = true);
    try {
      await EtatDesLieuxDatasource.locataireAccepter(_edlId!);
      // Notifie le propriétaire (in-app + e-mail). Best-effort.
      final nom = AuthService.currentUser?.userMetadata?['full_name'] as String?;
      await NotificationsDatasource.notifyEdlProprietaire(
        edlId: _edlId!,
        type: 'edl_accepte',
        title: 'État des lieux accepté',
        body: '${nom ?? 'Le locataire'} a accepté et signé '
            "l'état des lieux de ${widget.immeuble.name}.",
      );
      await EtatDesLieuxDatasource.notifyAccepte(
          edlId: _edlId!, locataireNom: nom);
      if (mounted) setState(() => _locataireAccepte = true);
      _snack('État des lieux accepté.');
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isFinalising = false);
    }
  }

  /// Bandeau d'état (situation + acceptation) affiché en haut du corps.
  Widget _statusBanner() {
    final accepte = _locataireAccepte;
    final finalise = _situation == SituationEdl.finalise;
    final (color, icon, label) = accepte
        ? (AppColors.primary, Icons.verified_outlined,
            'Accepté et signé par le locataire')
        : finalise
            ? (AppColors.secondary, Icons.lock_outline,
                'Finalisé — en attente de la signature du locataire')
            : (AppColors.onSurfaceVariant, Icons.edit_outlined, 'En cours');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label,
                style: AppTypography.labelMd.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  /// Bouton d'action contextuel du header (Finaliser / Accepter / null).
  Widget _fermerButton() => OutlinedButton.icon(
        onPressed: _isSaving ? null : _handleClose,
        style: AppTheme.cancelButtonStyle,
        icon: const Icon(Icons.close, size: 18),
        label: const Text('Fermer'),
      );

  Widget? _headerAction() {
    if (_isLocataire) {
      // Le locataire peut accepter quand c'est finalisé et pas encore accepté.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_saved &&
              _situation == SituationEdl.finalise &&
              !_locataireAccepte) ...[
            FilledButton.icon(
              onPressed: _isFinalising ? null : _accepter,
              style: AppTheme.saveButtonStyle,
              icon: _isFinalising
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Accepter et signer'),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          _fermerButton(),
        ],
      );
    }
    // Proprietaire : ordre standard Enregistrer · Fermer · | · Finaliser.
    final finalise = _situation == SituationEdl.finalise;
    return FormHeaderActions(
      onSave: _onSavePressed,
      onClose: _handleClose,
      isSaving: _isSaving,
      extraActions: [
        if (!finalise)
          OutlinedButton.icon(
            onPressed: _isFinalising ? null : _finaliser,
            icon: _isFinalising
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_outline),
            label: const Text('Finaliser'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormPageHeader(
          title: _isLocataire
              ? "État des lieux — ${widget.immeuble.name}"
              : "Nouvel état des lieux — ${widget.immeuble.name}",
          // Plus de bouton X : la fermeture se fait via le bouton « Fermer »
          // dans les actions (à côté de « Finaliser »).
          trailing: _headerAction(),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_saved) _statusBanner(),
                _buildTopRow(),
                const SizedBox(height: AppSpacing.md),
                _buildLocatairesSection(),
                if (_lockLocataires && _avenants.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildAvenantsSection(),
                ],
                const SizedBox(height: AppSpacing.xl),
                // L'inventaire est désormais intégré DANS chaque accordéon de
                // pièce/chambre (voir _buildRoomTile), plus de section séparée.
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
        // Pas d'IntrinsicHeight : _buildBienCard contient un Wrap (chips), et
        // Wrap ne supporte pas les dimensions intrinsèques → crash de layout.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildBienCard()),
            const SizedBox(width: AppSpacing.md),
            SizedBox(width: 220, child: _buildDatesCard()),
          ],
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
              _MetaChip(
                  icon: Icons.chair_outlined,
                  text: widget.meublee ? 'Meublée' : 'Non meublée'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocatairesSection() {
    // Recherche réutilisable — collectif = PLUSIEURS locataires (multiSelect:true).
    final searchColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LocataireSearchField(
          multiSelect: true,
          selectedIds: _preneurs
              .map((p) => p.locataireId)
              .whereType<String>()
              .toSet(),
          onSelect: _addPreneur,
          onCreateNew: _openCreerLocataireDialog,
        ),
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
                      readOnly: _isLocataire || _lockLocataires,
                      onDelete: () => _deletePreneur(p.id!),
                    ),
                  ),
                ),
            ],
          );

    // Locataire OU collectif d'un bail individuel : pas de recherche/ajout,
    // juste la liste en lecture seule (les locataires viennent des EDL
    // individuels — on les gère en supprimant l'EDL individuel concerné).
    if (_isLocataire || _lockLocataires) {
      return _sectionCard(
        title: 'LOCATAIRES',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_lockLocataires && !_isLocataire)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Les locataires de ce contrat collectif proviennent des états '
                  'des lieux individuels des chambres. Pour en retirer un, '
                  'supprimez l\'EDL individuel correspondant.',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            tenantsArea,
          ],
        ),
      );
    }

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

  /// Section « Avenants » : locataires entrés après l'établissement du collectif.
  Widget _buildAvenantsSection() {
    return _sectionCard(
      title: 'AVENANTS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in _avenants)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_outlined,
                      size: 18, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${a.displayLocataire} — ${a.chambreNom ?? 'Chambre'}'
                      '${a.avenantDateFormatted != null ? ' · entré le ${a.avenantDateFormatted}' : ''}',
                      style: AppTypography.bodyMd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ces locataires sont entrés après l\'établissement de l\'état des '
            'lieux collectif (avenant).',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesCard() {
    return _sectionCard(
      title: 'DATES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _edlDateBlock(
            label: "Date de l'état des lieux",
            value: _dateFmt.format(_date),
            icon: Icons.calendar_today_outlined,
            onTap: _isLocataire ? null : _pickDate,
          ),
          const SizedBox(height: AppSpacing.md),
          _edlDateBlock(
            label: 'Date de finalisation',
            value: _dateFinalisation != null
                ? _dateFmt.format(_dateFinalisation!)
                : 'En attente',
            icon: Icons.event_available_outlined,
            muted: _dateFinalisation == null,
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
                    inventorySection: _sectionFor(p.nom),
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
                    inventorySection: _sectionFor(c.roomName),
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
    EdlSection? inventorySection,
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
                      canModify: (o) => !_isLocataire || o.isLocataire,
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
                  // Inventaire de cette pièce/chambre (si meublée).
                  if (widget.meublee && _saved && inventorySection != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 16, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Inventaire',
                            style: AppTypography.labelMd.copyWith(
                                color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    EdlLignesTable(
                      section: inventorySection,
                      readOnly: _isLocataire,
                      onAddLigne: () => _addLigneTo(inventorySection),
                      onSaveLigne: _saveLigne,
                      onDeleteLigne: _deleteLigne,
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
  final bool readOnly;

  const _TenantCard({
    required this.preneur,
    required this.onDelete,
    this.readOnly = false,
  });

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
          if (!readOnly) ...[
            const SizedBox(width: 6),
            CardDeleteButton(onPressed: onDelete),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EDL Individuel + meublée — l'unité louée est la chambre
// ═════════════════════════════════════════════════════════════════════════════

/// Page de saisie d'un EDL « individuel + meublée ».
///
/// Modèle : 1 EDL collectif (parties communes, partagé par l'immeuble) +
/// 1 EDL privatif par chambre (`partie=privative`, `edl_collectif_id`,
/// `locataire_id`) avec l'inventaire des meubles de la chambre.
///
/// À l'enregistrement : `ensureCollectif` + création du privatif lié + import
/// auto de l'inventaire (pièces communes → collectif, meubles chambre →
/// privatif) + ajout du locataire comme preneur du collectif (voit les communes).
///
/// En mode locataire (`isLocataire`) : tout est en lecture seule sauf l'ajout
/// d'observations propres (selo) ; l'inventaire/état d'usure reste en lecture.
class EdlIndividuelMeubleePage extends StatefulWidget {
  final ImmeublesModel immeuble;
  final ChambreModel chambre;
  final String typeEdl; // 'entree' | 'sortie'
  final EtatDesLieuxModel? existingEdl; // privatif existant à éditer
  final void Function(bool refresh) onClose;
  final bool isLocataire;
  // Location meublée → affiche l'inventaire des meubles (composition).
  final bool meublee;

  /// Mode **avenant** : le privatif est rattaché à un collectif déjà finalisé
  /// (locataire entré après coup). [avenantCollectifId] = collectif cible.
  final bool isAvenant;
  final int? avenantCollectifId;

  const EdlIndividuelMeubleePage({
    super.key,
    required this.immeuble,
    required this.chambre,
    required this.typeEdl,
    this.existingEdl,
    required this.onClose,
    this.isLocataire = false,
    this.meublee = true,
    this.isAvenant = false,
    this.avenantCollectifId,
  });

  @override
  State<EdlIndividuelMeubleePage> createState() =>
      _EdlIndividuelMeubleePageState();
}

class _EdlIndividuelMeubleePageState extends State<EdlIndividuelMeubleePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  int? _privatifId; // EDL privatif (cette chambre)
  int? _collectifId; // EDL collectif (parties communes de l'immeuble)
  DateTime _date = DateTime.now();
  DateTime? _dateFinalisation;
  bool _isSaving = false;
  bool _isFinalising = false;
  // Création automatique en cours (nouvel EDL) : on enregistre dès l'ouverture
  // pour que le propriétaire puisse éditer sans cliquer « Enregistrer ».
  bool _autoCreating = false;
  SituationEdl _situation = SituationEdl.enCours;
  bool _locataireAccepte = false;

  List<PieceModel> _pieces = [];
  List<EdlPreneur> _preneurs = [];
  // Locataire de CETTE chambre (= locataire_id du privatif). Sert à n'afficher
  // que SON preneur, pas tous ceux du collectif (qui regroupe toutes les chambres).
  String? _privatifLocataireId;
  List<ObservationEdl> _obsPrivatif = [];
  List<ObservationEdl> _obsCollectif = [];
  // Ajouts (« additions ») faits après finalisation, dans la fenêtre d'1 mois.
  List<ObservationEdl> _additions = [];

  final _scrollCtrl = ScrollController();
  final Map<String, String> _emailByLocataire = {};

  bool get _saved => _privatifId != null;
  bool get _isLocataire => widget.isLocataire;

  /// Une fois finalisé, l'EDL ne peut plus être modifié (seuls les ajouts via
  /// l'onglet Additions restent possibles, dans la fenêtre).
  bool get _finalise => _situation == SituationEdl.finalise;
  bool get _readOnly => _isLocataire || _finalise;

  /// Fenêtre d'ajout ouverte : EDL finalisé et < 1 mois après la finalisation
  /// (date_finalisation, fixée à l'acceptation du locataire ; null = juste
  /// finalisé, pas encore accepté → fenêtre ouverte).
  bool get _additionsOpen {
    if (!_finalise) return false;
    final ref = _dateFinalisation;
    if (ref == null) return true;
    return DateTime.now()
        .isBefore(DateTime(ref.year, ref.month + 1, ref.day));
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    final edl = widget.existingEdl;
    if (edl != null) {
      _privatifId = edl.id;
      _collectifId = edl.edlCollectifId;
      _privatifLocataireId = edl.locataireId;
      _date = edl.dateEtatLieux;
      _dateFinalisation = edl.dateFinalisation;
      _situation = edl.situation;
      _locataireAccepte = edl.locataireAccepte;
      _loadRooms();
      _loadAll();
    } else if (!widget.isLocataire) {
      // Nouvel EDL : on crée tout de suite (collectif + privatif + inventaire)
      // pour permettre l'édition immédiate, sans étape « Enregistrer ».
      _autoCreating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _initNew());
    } else {
      _loadRooms();
    }
  }

  /// Crée automatiquement l'EDL à l'ouverture (nouveau, côté propriétaire).
  Future<void> _initNew() async {
    await _loadRooms(); // pièces requises pour l'auto-seed du collectif
    final ok = await _saveEdl(); // collectif + privatif + auto-seed
    if (mounted) setState(() => _autoCreating = false);
    if (ok && mounted) await _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final pieces = await PiecesDatasource.listByImmeuble(widget.immeuble.id);
      if (mounted) setState(() => _pieces = pieces);
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadObservations(), _loadPreneurs(), _loadSections()]);
  }

  // Inventaire (sections + lignes), chargé une fois, intégré DANS les accordéons.
  List<EdlSection> _privatifSections = [];
  List<EdlSection> _collectifSections = [];

  Future<void> _loadSections() async {
    if (!widget.meublee) return;
    try {
      if (_privatifId != null) {
        final s = await EdlDetailsDatasource.listSections(_privatifId!);
        if (mounted) setState(() => _privatifSections = s);
      }
      if (_collectifId != null) {
        final s = await EdlDetailsDatasource.listSections(_collectifId!);
        if (mounted) setState(() => _collectifSections = s);
      }
    } catch (_) {}
  }

  EdlSection? _sectionFor(List<EdlSection> sections, String name) {
    final key = name.trim().toUpperCase();
    for (final s in sections) {
      // La section privative de la chambre est nommée « CHAMBRE — <nom> ».
      final sn = s.nom.trim().toUpperCase();
      if (sn == key || sn.endsWith(key)) return s;
    }
    return null;
  }

  Future<void> _addLigneTo(EdlSection section) async {
    await EdlDetailsDatasource.createLigne(EdlLigne(
      sectionId: section.id!,
      equipement: 'Nouvel élément',
      ordre: section.lignes.length,
    ));
    await _loadSections();
  }

  Future<void> _saveLigne(EdlLigne ligne) async {
    if (ligne.id == null) return;
    await EdlDetailsDatasource.updateLigne(ligne.id!, ligne);
  }

  Future<void> _deleteLigne(int id) async {
    await EdlDetailsDatasource.deleteLigne(id);
    await _loadSections();
  }

  Future<void> _loadObservations() async {
    try {
      if (_privatifId != null) {
        final o = await ObservationsEdlDatasource.listByEdl(_privatifId!);
        if (mounted) {
          setState(() {
            // Les additions (post-finalisation) sont stockées sous le privatif ;
            // on les sépare des observations normales de la chambre.
            _obsPrivatif = o.where((x) => !x.isAddition).toList();
            _additions = o.where((x) => x.isAddition).toList();
          });
        }
      }
      if (_collectifId != null) {
        final o = await ObservationsEdlDatasource.listByEdl(_collectifId!);
        if (mounted) setState(() => _obsCollectif = o);
      }
    } catch (_) {}
  }

  Future<void> _loadPreneurs() async {
    if (_collectifId == null) return;
    try {
      final all = await EdlDetailsDatasource.listPreneurs(_collectifId!);
      // N'afficher que le locataire de CETTE chambre (privatif), pas tous les
      // preneurs du collectif (autres chambres). Vide si la chambre est libre.
      final list = _privatifLocataireId == null
          ? const <EdlPreneur>[]
          : all.where((p) => p.locataireId == _privatifLocataireId).toList();
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

  /// Crée (si besoin) le collectif + le privatif de la chambre, puis importe
  /// l'inventaire. Idempotent (ensureCollectif / ensurePrivatif) + garde anti
  /// double-clic (`_isSaving`) → pas de doublon.
  Future<bool> _saveEdl() async {
    if (_isSaving) return _privatifId != null; // évite la réentrance
    setState(() => _isSaving = true);
    try {
      final uid = AuthService.currentUser?.id ?? '';
      final situation = SituationEdl.fromDate(_date);

      // 1) Collectif (parties communes) partagé de l'immeuble.
      // En mode avenant : on rattache au collectif finalisé fourni (pas de
      // nouveau collectif). Sinon : collectif ouvert (ou nouveau).
      _collectifId ??= widget.isAvenant
          ? widget.avenantCollectifId
          : await EtatDesLieuxDatasource.ensureCollectif(
              EtatDesLieuxModel(
                id: 0,
                proprietaireId: uid,
                immeubleId: widget.immeuble.id,
                typeBail: 'individuel',
                typeEdl: widget.typeEdl,
                dateEtatLieux: _date,
                situation: situation,
                createdAt: DateTime.now(),
                partie: PartieEdl.commune,
              ),
            );

      // 2) Privatif de la chambre (idempotent : pas de doublon).
      if (_privatifId == null) {
        final edl = await EtatDesLieuxDatasource.ensurePrivatif(
          EtatDesLieuxModel(
            id: 0,
            proprietaireId: uid,
            immeubleId: widget.immeuble.id,
            chambreId: widget.chambre.id,
            typeBail: 'individuel',
            typeEdl: widget.typeEdl,
            dateEtatLieux: _date,
            situation: situation,
            createdAt: DateTime.now(),
            partie: PartieEdl.privative,
            edlCollectifId: _collectifId,
            isAvenant: widget.isAvenant,
            avenantDate: widget.isAvenant ? DateTime.now() : null,
          ),
        );
        if (!mounted) return false;
        setState(() => _privatifId = edl.id);
        // Lien collectif manquant (privatif réutilisé créé avant le collectif) :
        // on le rattache pour éviter un privatif orphelin.
        if (edl.edlCollectifId == null && _collectifId != null) {
          await EtatDesLieuxDatasource.update(
            edl.id,
            {'edl_collectif_id': _collectifId},
          );
        }
        // Garantit le marquage avenant même si le privatif existait déjà.
        if (widget.isAvenant && !edl.isAvenant) {
          await EtatDesLieuxDatasource.markAvenant(edl.id, DateTime.now());
        }
        await _autoSeed();
      } else {
        await EtatDesLieuxDatasource.update(_privatifId!, {
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

  /// Importe l'inventaire : pièces communes → sections du collectif ;
  /// meubles de la chambre → section du privatif. Idempotent.
  Future<void> _autoSeed() async {
    try {
      final items = await InventaireDatasource.listByImmeuble(widget.immeuble.id);
      EdlLigne ligneFrom(InventaireModel it, int ordre) => EdlLigne(
            sectionId: 0,
            equipement: it.displayNom,
            natureNombre: it.quantite > 0 ? it.quantite.toString() : null,
            ordre: ordre,
          );

      if (_collectifId != null) {
        final existing =
            await EdlDetailsDatasource.listSections(_collectifId!);
        if (existing.isEmpty) {
          for (var pi = 0; pi < _pieces.length; pi++) {
            final p = _pieces[pi];
            final lignes = items
                .where((it) => it.pieceId == p.id)
                .toList()
                .asMap()
                .entries
                .map((e) => ligneFrom(e.value, e.key))
                .toList();
            await EdlDetailsDatasource.createSectionWithLignes(
              EdlSection(
                etatDesLieuxId: _collectifId!,
                nom: p.nom.toUpperCase(),
                ordre: pi,
              ),
              lignes,
            );
          }
        }
      }

      if (_privatifId != null) {
        final existing =
            await EdlDetailsDatasource.listSections(_privatifId!);
        if (existing.isEmpty) {
          final lignes = items
              .where((it) => it.chambreId == widget.chambre.id)
              .toList()
              .asMap()
              .entries
              .map((e) => ligneFrom(e.value, e.key))
              .toList();
          await EdlDetailsDatasource.createSectionWithLignes(
            EdlSection(
              etatDesLieuxId: _privatifId!,
              nom: 'CHAMBRE — ${widget.chambre.roomName}'.toUpperCase(),
            ),
            lignes,
          );
        }
      }
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _onSavePressed() async {
    final ok = await _saveEdl();
    if (ok) {
      await _loadAll();
      _snack('Enregistré.');
    }
  }

  /// Fermeture / annulation. On ne **bloque jamais** la sortie : l'utilisateur
  /// peut toujours annuler. Un locataire reste obligatoire pour **sauvegarder**,
  /// mais « Quitter sans sauvegarder » est toujours possible — et si l'EDL avait
  /// été créé automatiquement sans locataire, on le supprime (nettoyage).
  Future<void> _handleClose() async {
    if (_isLocataire) {
      widget.onClose(_saved);
      return;
    }
    final noLocataire = _preneurs.isEmpty;
    final choice = await showUnsavedChangesDialog(
      context,
      message: noLocataire
          ? "Aucun locataire n'a été sélectionné. Si vous quittez sans "
              'sauvegarder, ce nouvel état des lieux sera annulé.'
          : 'Voulez-vous enregistrer les modifications avant de quitter ?',
      discardLabel: noLocataire ? 'Annuler la création' : 'Quitter sans sauvegarder',
    );
    if (!mounted) return;
    switch (choice) {
      case UnsavedChoice.cancel:
        return;
      case UnsavedChoice.discard:
        await _discardIfEmpty();
        widget.onClose(true);
      case UnsavedChoice.save:
        if (noLocataire) {
          _snack("Sélectionnez un locataire avant d'enregistrer.");
          return;
        }
        final ok = await _saveEdl();
        if (ok && mounted) widget.onClose(true);
    }
  }

  /// Supprime l'EDL privatif auto-créé s'il est resté sans locataire (création
  /// annulée) — évite de laisser un EDL vide dans la liste.
  Future<void> _discardIfEmpty() async {
    if (widget.existingEdl == null &&
        _preneurs.isEmpty &&
        _privatifId != null) {
      try {
        await EtatDesLieuxDatasource.delete(_privatifId!);
      } catch (_) {}
    }
  }

  // ── Recherche / preneur (1 locataire) ──────────────────────────────────────
  // La recherche est gérée par le widget réutilisable `LocataireSearchField`
  // (résultats en ligne). Ici on ne garde que l'ajout/suppression du preneur.

  Future<void> _addPreneur(UsersClient user) async {
    if (_preneurs.any((p) => p.locataireId == user.id)) {
      _snack('Ce locataire est déjà ajouté.');
      return;
    }
    final ok = await _saveEdl(); // garantit collectif + privatif
    if (!ok) return;
    if (user.email.isNotEmpty) _emailByLocataire[user.id] = user.email;
    try {
      // Lie le locataire au privatif (locataire_id) + l'ajoute comme preneur
      // du collectif (pour voir les parties communes).
      await EtatDesLieuxDatasource.update(_privatifId!, {
        'locataire_id': user.id,
      });
      _privatifLocataireId = user.id;
      await EdlDetailsDatasource.createPreneur(EdlPreneur(
        etatDesLieuxId: _collectifId!,
        locataireId: user.id,
        nom: user.fullName ?? user.email,
        ordre: _preneurs.length,
      ));
      await _loadPreneurs();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _deletePreneur(int id) async {
    try {
      await EdlDetailsDatasource.deletePreneur(id);
      if (_privatifId != null) {
        await EtatDesLieuxDatasource.update(_privatifId!, {'locataire_id': null});
      }
      _privatifLocataireId = null;
      await _loadPreneurs();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _openCreerLocataireDialog() async {
    final uid = AuthService.currentUser?.id ?? '';
    final created = await showDialog<UsersClient>(
      context: context,
      builder: (_) => _CreerLocataireDialog(proprietaireId: uid),
    );
    if (created == null || !mounted) return;
    await _addPreneur(created);
    _snack('Locataire enregistré — un e-mail d\'activation a été envoyé.');
  }

  // ── Observations (wall + générale) ─────────────────────────────────────────

  Future<void> _openWall(
    String wallKey, {
    int? pieceId,
    int? chambreId,
    required int edlId,
    ObservationEdl? existing,
  }) async {
    final saved =
        await showDialog<({String? description, List<String> photos})>(
      context: context,
      builder: (_) => _WallObsDialog(wallKey: wallKey, existing: existing),
    );
    if (saved == null || !mounted) return;
    try {
      final obs = ObservationEdl(
        etatDesLieuxId: edlId,
        wallKey: wallKey,
        pieceId: pieceId,
        chambreId: chambreId,
        description: saved.description,
        photos: saved.photos,
        authorRole: _isLocataire ? 'locataire' : 'proprietaire',
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
    required int edlId,
    ObservationEdl? existing,
  }) async {
    final saved =
        await showDialog<({String? description, List<String> photos})>(
      context: context,
      builder: (_) => _GeneralObsDialog(existing: existing),
    );
    if (saved == null || !mounted) return;
    try {
      final obs = ObservationEdl(
        etatDesLieuxId: edlId,
        wallKey: null,
        pieceId: pieceId,
        chambreId: chambreId,
        description: saved.description,
        photos: saved.photos,
        authorRole: _isLocataire ? 'locataire' : 'proprietaire',
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

  /// Finaliser (proprietaire) sur le privatif de la chambre.
  /// Ouvre le dialogue de bail pour saisir début, durée et date de fin.
  Future<void> _finaliser() async {
    final ok = await _saveEdl();
    if (!ok || !mounted || _privatifId == null) return;

    final result = await showDialog<_BailDialogResult>(
      context: context,
      builder: (_) => const _FinaliserBailDialog(),
    );
    if (result == null || !mounted) return;

    setState(() => _isFinalising = true);
    try {
      await EtatDesLieuxDatasource.finaliser(
        _privatifId!,
        dateDebutBail: result.dateDebut,
        dateFinBail: result.dateFin,
        dureeBailMois: result.dureeMois,
        chambreId: widget.chambre.id,
      );
      if (mounted) setState(() => _situation = SituationEdl.finalise);
      _snack('État des lieux finalisé.');
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isFinalising = false);
    }
  }

  /// Accepter et signer (locataire) sur le privatif.
  Future<void> _accepter() async {
    if (_privatifId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Accepter l'état des lieux"),
        content: const Text(
          "En acceptant, vous confirmez être d'accord avec le contenu de cet "
          "état des lieux. La date de signature sera enregistrée. Continuer ?",
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppTheme.cancelButtonStyle,
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.saveButtonStyle,
            child: const Text('Accepter et signer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isFinalising = true);
    try {
      await EtatDesLieuxDatasource.locataireAccepter(_privatifId!);
      final nom = AuthService.currentUser?.userMetadata?['full_name'] as String?;
      await NotificationsDatasource.notifyEdlProprietaire(
        edlId: _privatifId!,
        type: 'edl_accepte',
        title: 'État des lieux accepté',
        body: '${nom ?? 'Le locataire'} a accepté et signé '
            "l'état des lieux de ${widget.chambre.roomName}.",
      );
      await EtatDesLieuxDatasource.notifyAccepte(
          edlId: _privatifId!, locataireNom: nom);
      if (mounted) setState(() => _locataireAccepte = true);
      _snack('État des lieux accepté.');
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isFinalising = false);
    }
  }

  /// Bandeau « Avenant » : explique que ce locataire entre après l'EDL collectif.
  Widget _avenantBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: AppRadius.borderMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.note_add_outlined,
              size: 20, color: AppColors.onTertiaryFixed),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Avenant : ce locataire entre après l\'établissement de l\'état '
              'des lieux collectif. Il sera rattaché au contrat collectif existant.',
              style: AppTypography.labelMd
                  .copyWith(color: AppColors.onTertiaryFixed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final accepte = _locataireAccepte;
    final finalise = _situation == SituationEdl.finalise;
    final (color, icon, label) = accepte
        ? (AppColors.primary, Icons.verified_outlined,
            'Accepté et signé par le locataire')
        : finalise
            ? (AppColors.secondary, Icons.lock_outline,
                'Finalisé — en attente de la signature du locataire')
            : (AppColors.onSurfaceVariant, Icons.edit_outlined, 'En cours');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label,
                style: AppTypography.labelMd.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  Widget? _headerAction() {
    if (_isLocataire) {
      if (_saved && _situation == SituationEdl.finalise && !_locataireAccepte) {
        return FilledButton.icon(
          onPressed: _isFinalising ? null : _accepter,
          style: AppTheme.saveButtonStyle,
          icon: _isFinalising
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_circle_outline),
          label: const Text('Accepter et signer'),
        );
      }
      return null;
    }
    // Proprietaire : ordre standard Enregistrer · Fermer · | · Finaliser.
    final finalise = _situation == SituationEdl.finalise;
    return FormHeaderActions(
      onSave: _onSavePressed,
      onClose: _handleClose,
      isSaving: _isSaving,
      extraActions: [
        if (!finalise)
          OutlinedButton.icon(
            onPressed: _isFinalising ? null : _finaliser,
            icon: _isFinalising
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_outline),
            label: const Text('Finaliser'),
          ),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormPageHeader(
          title: _isLocataire
              ? 'État des lieux — ${widget.chambre.roomName}'
              : 'Nouvel état des lieux — ${widget.immeuble.name} · ${widget.chambre.roomName}',
          // Plus de bouton X : la fermeture se fait via le bouton « Fermer »
          // dans les actions (à côté de « Finaliser »).
          trailing: _headerAction(),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isAvenant) _avenantBanner(),
                if (_saved) _statusBanner(),
                _buildTopRow(),
                const SizedBox(height: AppSpacing.md),
                if (!_saved)
                  (_autoCreating
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _docHint())
                else ...[
                  TabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'La chambre'),
                      Tab(text: 'Parties communes'),
                      Tab(text: 'Relevés'),
                      Tab(text: 'Clés'),
                      Tab(text: 'Additions'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // On rend UNIQUEMENT l'onglet actif. (Un IndexedStack
                  // disposerait aussi les onglets cachés — Relevés/Clés
                  // contiennent des widgets à hauteur bornée qui plantent sous
                  // la hauteur illimitée du SingleChildScrollView.)
                  switch (_tabCtrl.index) {
                    0 => _buildChambreTab(),
                    1 => _buildCommunesTab(),
                    2 => _buildRelevesTab(),
                    3 => _buildClesTab(),
                    _ => _buildAdditionsTab(),
                  },
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _docHint() => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                "Enregistrez d'abord pour saisir le locataire, l'inventaire et les observations.",
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );

  Widget _buildTopRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final bien = _buildBienCard();
      final loc = _buildLocataireCard();
      final dates = _buildDatesCard();
      if (wide) {
        // Pas d'IntrinsicHeight : les cartes contiennent un Wrap (chips) et la
        // recherche (ListTiles), qui ne supportent pas les dimensions
        // intrinsèques → crash de layout.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: bien),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 3, child: loc),
            const SizedBox(width: AppSpacing.md),
            SizedBox(width: 200, child: dates),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bien,
          const SizedBox(height: AppSpacing.md),
          loc,
          const SizedBox(height: AppSpacing.md),
          dates,
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
          Text(title,
              style: AppTypography.labelMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
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
          Text('${imm.name} · ${widget.chambre.roomName}',
              style: AppTypography.titleLg),
          if (lieu.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(lieu,
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaChip(
                icon: Icons.square_foot,
                text: widget.chambre.m2 != null
                    ? '${widget.chambre.m2!.toStringAsFixed(0)} m²'
                    : '— m²',
              ),
              const _MetaChip(
                  icon: Icons.assignment_outlined, text: 'Individuel'),
              _MetaChip(
                  icon: Icons.chair_outlined,
                  text: widget.meublee ? 'Meublée' : 'Non meublée'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocataireCard() {
    final tenant = _preneurs.isNotEmpty
        ? Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in _preneurs)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: IntrinsicWidth(
                    child: _TenantCard(
                      preneur: p,
                      readOnly: _readOnly,
                      onDelete: () => _deletePreneur(p.id!),
                    ),
                  ),
                ),
            ],
          )
        : Text(
            _saved ? 'Aucun locataire.' : '',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          );

    if (_isLocataire || _preneurs.isNotEmpty) {
      return _sectionCard(title: 'LOCATAIRE', child: tenant);
    }

    // Recherche réutilisable — individuel = UN SEUL locataire (multiSelect:false).
    return _sectionCard(
      title: 'LOCATAIRE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocataireSearchField(
            multiSelect: false,
            selectedIds: _preneurs
                .map((p) => p.locataireId)
                .whereType<String>()
                .toSet(),
            onSelect: _addPreneur,
            onCreateNew: _openCreerLocataireDialog,
          ),
          if (!_saved) ...[
            const SizedBox(height: AppSpacing.xs),
            Text("Le locataire sera enregistré à la sauvegarde.",
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  Widget _buildDatesCard() {
    return _sectionCard(
      title: 'DATES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _edlDateBlock(
            label: "Date de l'état des lieux",
            value: _dateFmt.format(_date),
            icon: Icons.calendar_today_outlined,
            onTap: _isLocataire ? null : _pickDate,
          ),
          const SizedBox(height: AppSpacing.md),
          _edlDateBlock(
            label: 'Date de finalisation',
            value: _dateFinalisation != null
                ? _dateFmt.format(_dateFinalisation!)
                : 'En attente',
            icon: Icons.event_available_outlined,
            muted: _dateFinalisation == null,
          ),
        ],
      ),
    );
  }

  // ── Onglets ───────────────────────────────────────────────────────────────

  Widget _buildChambreTab() {
    final c = widget.chambre;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRoomBlock(
          tileId: 'chambre-${c.id}',
          name: c.roomName,
          planLabel: 'Plan de la chambre — ${c.roomName}',
          photo: c.mainPhoto ??
              (c.roomPhotos.isNotEmpty ? c.roomPhotos.first : null),
          obs: _obsPrivatif,
          edlId: _privatifId!,
          chambreId: c.id,
          // L'inventaire des meubles est intégré DANS l'accordéon de la chambre.
          inventorySection: _sectionFor(_privatifSections, c.roomName),
        ),
      ],
    );
  }

  Widget _buildCommunesTab() {
    if (_collectifId == null) {
      return _emptyTab('Aucune partie commune.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pieces.isEmpty)
          _emptyTab('Aucune pièce commune enregistrée pour cet immeuble.')
        else
          for (final p in _pieces)
            _buildRoomBlock(
              tileId: 'piece-${p.id}',
              name: p.nom,
              planLabel: 'Plan de la pièce — ${p.nom}',
              photo: p.photos.isNotEmpty ? p.photos.first.url : null,
              obs: _obsCollectif.where((o) => o.pieceId == p.id).toList(),
              edlId: _collectifId!,
              pieceId: p.id,
              // Inventaire de la pièce intégré DANS son accordéon.
              inventorySection: _sectionFor(_collectifSections, p.nom),
            ),
      ],
    );
  }

  Widget _buildRelevesTab() {
    // Relevés (compteurs/chauffage) au niveau de l'immeuble → collectif.
    if (_collectifId == null) return _emptyTab('—');
    if (_isLocataire) {
      return _emptyTab('Les relevés sont gérés par le propriétaire.');
    }
    if (_finalise) {
      return _emptyTab('État des lieux finalisé — les relevés sont verrouillés.');
    }
    return EdlRelevesSection(edlId: _collectifId!);
  }

  Widget _buildClesTab() {
    // Remise des clés → privatif (la chambre louée).
    if (_privatifId == null) return _emptyTab('—');
    if (_isLocataire) {
      return _emptyTab('La remise des clés est gérée par le propriétaire.');
    }
    if (_finalise) {
      return _emptyTab('État des lieux finalisé — la remise des clés est verrouillée.');
    }
    return EdlClesSection(edlId: _privatifId!);
  }

  // ── Onglet Additions (ajouts post-finalisation, fenêtre d'1 mois) ───────────

  /// Comodos sélectionnables pour une addition : la chambre + les pièces communes.
  List<({String label, int? pieceId, int? chambreId})> get _comodos => [
        (label: widget.chambre.roomName, pieceId: null, chambreId: widget.chambre.id),
        for (final p in _pieces) (label: p.nom, pieceId: p.id, chambreId: null),
      ];

  String _comodoLabel(ObservationEdl a) {
    if (a.chambreId != null) return widget.chambre.roomName;
    return _pieces.where((p) => p.id == a.pieceId).firstOrNull?.nom ?? 'Comodo';
  }

  Widget _buildAdditionsTab() {
    if (_privatifId == null) return _emptyTab('—');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _additionsBanner(),
        if (_additionsOpen) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _addAddition,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter une addition'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (_additions.isEmpty)
          _emptyTab('Aucune addition pour le moment.')
        else
          for (final a in _additions) _additionCard(a),
      ],
    );
  }

  Widget _additionsBanner() {
    final (icon, color, text) = switch (true) {
      _ when !_finalise => (
          Icons.info_outline,
          AppColors.onSurfaceVariant,
          "Les additions seront possibles une fois l'état des lieux finalisé "
              '(pendant 1 mois), pour signaler un élément non vérifié.'
        ),
      _ when _additionsOpen => (
          Icons.edit_calendar_outlined,
          AppColors.primary,
          _dateFinalisation != null
              ? 'Vous pouvez ajouter des éléments jusqu\'au '
                  '${_dateFmt.format(DateTime(_dateFinalisation!.year, _dateFinalisation!.month + 1, _dateFinalisation!.day))}.'
              : 'Vous pouvez ajouter des éléments non vérifiés (fenêtre d\'1 mois).'
        ),
      _ => (
          Icons.lock_clock_outlined,
          AppColors.error,
          'La période d\'ajout (1 mois après la finalisation) est terminée.'
        ),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: AppTypography.bodyMd.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  Widget _additionCard(ObservationEdl a) {
    final stamp = a.createdAtLabel;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_location_alt_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(_comodoLabel(a),
                    style: AppTypography.titleLg.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (a.isLocataire ? AppColors.secondary : AppColors.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(
                  a.isLocataire ? 'Locataire' : 'Propriétaire',
                  style: AppTypography.labelSm.copyWith(
                    color: a.isLocataire ? AppColors.secondary : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (stamp != null) ...[
            const SizedBox(height: 2),
            Text('Ajouté le $stamp',
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
          if (a.description != null && a.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(a.description!, style: AppTypography.bodyMd),
          ],
          if (a.photos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final url in a.photos)
                  ClipRRect(
                    borderRadius: AppRadius.borderSm,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        width: 72,
                        height: 72,
                        color: AppColors.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined, size: 18),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addAddition() async {
    final res = await showDialog<
        ({String? description, List<String> photos, int? pieceId, int? chambreId})>(
      context: context,
      builder: (_) => _AdditionDialog(comodos: _comodos),
    );
    if (res == null || !mounted) return;
    if ((res.description == null || res.description!.isEmpty) &&
        res.photos.isEmpty) {
      _snack('Ajoutez au moins une observation ou une photo.');
      return;
    }
    try {
      await ObservationsEdlDatasource.insertAddition(ObservationEdl(
        etatDesLieuxId: _privatifId!,
        pieceId: res.pieceId,
        chambreId: res.chambreId,
        description: res.description,
        photos: res.photos,
        authorRole: _isLocataire ? 'locataire' : 'proprietaire',
        isAddition: true,
      ));
      // Locataire → prévenir le propriétaire (notification in-app + e-mail).
      if (_isLocataire) {
        final comodo = res.chambreId != null
            ? widget.chambre.roomName
            : (_pieces.where((p) => p.id == res.pieceId).firstOrNull?.nom ??
                'comodo');
        final nom =
            AuthService.currentUser?.userMetadata?['full_name'] as String?;
        await NotificationsDatasource.notifyEdlProprietaire(
          edlId: _privatifId!,
          type: 'edl_addition',
          title: 'Nouvelle addition',
          body: '${nom ?? 'Le locataire'} a ajouté un élément ($comodo) à '
              "l'état des lieux de ${widget.chambre.roomName}.",
        );
        await EtatDesLieuxDatasource.notifyAddition(
          edlId: _privatifId!,
          locataireNom: nom,
          comodo: comodo,
          texte: res.description,
        );
      }
      await _loadObservations();
      if (mounted) _snack('Addition enregistrée.');
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Widget _emptyTab(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(t,
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
        ),
      );

  static const _wallKeys = ['fond', 'gauche', 'droit', 'porte', 'sol', 'plafond'];

  Widget _obsBadge(List<ObservationEdl> obs) {
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
      child: Text('$done/6',
          style: AppTypography.labelSm
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }

  /// Bloc accordéon (comme le collectif) : en-tête cliquable + plan de murs
  /// (6 zones) + observations dans le corps dépliable.
  Widget _buildRoomBlock({
    required String tileId,
    required String name,
    required String planLabel,
    String? photo,
    required List<ObservationEdl> obs,
    required int edlId,
    int? pieceId,
    int? chambreId,
    EdlSection? inventorySection,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderSm,
        child: ExpansionTile(
          // ValueKey (pas PageStorageKey) : un PageStorageKey ferait que le
          // SingleChildScrollView interne (inventaire) lise l'état booléen de
          // l'ExpansionTile comme un offset (double) → crash restoreScrollOffset.
          key: ValueKey(tileId),
          collapsedBackgroundColor: const Color(0xFFF0F6FA),
          backgroundColor: const Color(0xFFF0F6FA),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(
            chambreId != null
                ? Icons.bed_outlined
                : Icons.meeting_room_outlined,
            color: AppColors.primary,
          ),
          title: Text(name,
              style: AppTypography.titleLg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          trailing: _obsBadge(obs),
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
                  RepaintBoundary(
                    child: _RoomDiagram(
                      chambreName: name,
                      planLabel: planLabel,
                      chambrePhoto: photo,
                      observations: obs,
                      readOnly: _readOnly,
                      onEditWall: (k) => _openWall(k,
                          edlId: edlId, pieceId: pieceId, chambreId: chambreId),
                    ),
                  ),
                  if (!_readOnly) ...[
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _openGeneral(
                            edlId: edlId,
                            pieceId: pieceId,
                            chambreId: chambreId),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ajouter une observation générale'),
                      ),
                    ),
                  ],
                  if (obs.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ObservationsList(
                      observations: obs,
                      // Une fois finalisé, plus rien n'est modifiable/supprimable.
                      canModify: (o) =>
                          !_finalise && (!_isLocataire || o.isLocataire),
                      onEdit: (o) => o.wallKey != null
                          ? _openWall(o.wallKey!,
                              existing: o,
                              edlId: edlId,
                              pieceId: o.pieceId,
                              chambreId: o.chambreId)
                          : _openGeneral(
                              existing: o,
                              edlId: edlId,
                              pieceId: o.pieceId,
                              chambreId: o.chambreId),
                      onDelete: (o) {
                        if (o.id != null) _deleteObservation(o.id!);
                      },
                    ),
                  ],
                  // Inventaire de cette pièce/chambre (si meublée).
                  if (widget.meublee && inventorySection != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 16, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Inventaire',
                            style: AppTypography.labelMd.copyWith(
                                color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    EdlLignesTable(
                      section: inventorySection,
                      readOnly: _readOnly,
                      onAddLigne: () => _addLigneTo(inventorySection),
                      onSaveLigne: _saveLigne,
                      onDeleteLigne: _deleteLigne,
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

// ─────────────────────────────────────────────────────────────────────────────
// Dialogue de finalisation du bail individuel

class _BailDialogResult {
  final DateTime dateDebut;
  final DateTime dateFin;
  final int dureeMois;

  const _BailDialogResult({
    required this.dateDebut,
    required this.dateFin,
    required this.dureeMois,
  });
}

class _FinaliserBailDialog extends StatefulWidget {
  const _FinaliserBailDialog();

  @override
  State<_FinaliserBailDialog> createState() => _FinaliserBailDialogState();
}

class _FinaliserBailDialogState extends State<_FinaliserBailDialog> {
  static const _durees = [12, 24, 36, 48, 60];
  static final _fmt = DateFormat('dd/MM/yyyy');

  final DateTime _dateFinalisation = DateTime.now();
  late DateTime _dateDebut = DateTime.now();
  int _dureeMois = 12;
  // _dateFin est recalculé quand l'utilisateur change le début ou la durée,
  // mais il peut aussi être modifié manuellement via le date picker.
  late DateTime _dateFin = _calcDateFin(DateTime.now(), 12);

  static DateTime _calcDateFin(DateTime debut, int mois) {
    final m = debut.month - 1 + mois;
    final year = debut.year + m ~/ 12;
    final month = m % 12 + 1;
    final maxDay = DateUtils.getDaysInMonth(year, month);
    return DateTime(year, month, math.min(debut.day, maxDay));
  }

  Future<void> _pickDateDebut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateDebut,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      locale: const Locale('fr'),
    );
    if (picked != null) {
      setState(() {
        _dateDebut = picked;
        _dateFin = _calcDateFin(picked, _dureeMois);
      });
    }
  }

  Future<void> _pickDateFin() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFin,
      firstDate: _dateDebut,
      lastDate: DateTime(2060),
      locale: const Locale('fr'),
    );
    if (picked != null) setState(() => _dateFin = picked);
  }

  void _onDureeChanged(int d) {
    setState(() {
      _dureeMois = d;
      _dateFin = _calcDateFin(_dateDebut, d);
    });
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _readonlyField(String value) => Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(value, style: AppTypography.bodyMd),
      );

  Widget _dateField(DateTime date, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderSm,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderSm,
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(_fmt.format(date), style: AppTypography.bodyMd),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Finaliser l'état des lieux"),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 340, maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('DATE DE FINALISATION'),
              _readonlyField(_fmt.format(_dateFinalisation)),
              const SizedBox(height: AppSpacing.md),

              _label('DATE DE DÉBUT DU BAIL'),
              _dateField(_dateDebut, _pickDateDebut),
              const SizedBox(height: AppSpacing.md),

              _label('DURÉE DU BAIL'),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _durees
                    .map((d) => ChoiceChip(
                          label: Text('$d mois'),
                          selected: d == _dureeMois,
                          onSelected: (_) => _onDureeChanged(d),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              _label('DATE DE FIN DU BAIL'),
              _dateField(_dateFin, _pickDateFin),
              const SizedBox(height: 4),
              Text(
                'Calculée automatiquement, modifiable si besoin.',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant, fontSize: 12),
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
          onPressed: () => Navigator.pop(
            context,
            _BailDialogResult(
              dateDebut: _dateDebut,
              dateFin: _dateFin,
              dureeMois: _dureeMois,
            ),
          ),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}
