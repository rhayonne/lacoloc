import 'dart:async';
import 'package:lacoloc_front/presentation/widgets/app_date_picker.dart';
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
import 'package:lacoloc_front/data/datasources/garants.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/inventaire.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/data/datasources/observations_edl.dart';
import 'package:lacoloc_front/data/datasources/pieces.dart';
import 'package:lacoloc_front/data/datasources/recettes.dart';
import 'package:lacoloc_front/data/datasources/signatures.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/edl_details.dart';
import 'package:lacoloc_front/data/models/edl_readiness.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/garant.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';
import 'package:lacoloc_front/data/models/observation_edl.dart';
import 'package:lacoloc_front/data/models/piece.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/data/permissions/permissions_service.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_document_editor.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/vetuste_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_select_annee_dialog.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_select_chambre_dialog.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_select_collectif_avenant_dialog.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_select_entree_sortie_dialog.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_select_immeuble_dialog.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/bail_pdf_preview_page.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/resiliation_pdf_builder.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/resiliation_pdf_data.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_pdf_preview_page.dart';
import 'package:lacoloc_front/presentation/widgets/bail_signature_flow.dart';
import 'package:lacoloc_front/presentation/widgets/document_pdf_button.dart';
import 'package:lacoloc_front/presentation/widgets/edl_parcours_badge.dart';
import 'package:lacoloc_front/presentation/widgets/edl_filter_bar.dart';
import 'package:lacoloc_front/presentation/widgets/app_top_bar.dart';
import 'package:lacoloc_front/presentation/widgets/form_page_header.dart';
import 'package:lacoloc_front/presentation/widgets/permission_gate.dart';
import 'package:lacoloc_front/presentation/widgets/locataire_search_field.dart';
import 'package:lacoloc_front/presentation/widgets/unsaved_changes_dialog.dart';
import 'package:lacoloc_front/presentation/widgets/photo_picker_field.dart';
import 'package:lacoloc_front/presentation/widgets/private_image.dart';
import 'package:lacoloc_front/utils/phone_field.dart';
import 'package:lacoloc_front/utils/signature_pad.dart';
import 'package:lacoloc_front/presentation/widgets/edl_signature_flow.dart';
import 'package:lacoloc_front/theme/app_breakpoints.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/card_delete_button.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_table_theme.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/app_tab_bar.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

// Larguras fixes des colonnes du tableau EDL (partagées entre header et lignes)

// Largeurs de colonnes compactées pour que la table tienne sans débordement
// dès que le menu latéral est déployé (≈ 940 px utiles). En dessous de 950 px
// la table bascule en cartes (voir `isNarrow`).
const double _colType = 100.0; // Type immeuble + meublé + Collectif/Individuel
const double _colSens = 74.0; // Entrée / Sortie
const double _colEtat = 82.0;
const double _colFin = 84.0;
const double _colSit = 100.0;
const double _colBtn = 130.0; // bouton d'action (Continuer / Signature / Bail)
const double _colDel = 32.0;
const double _colEye = 44.0; // bouton « visualiser » (œil + libellé « EDL »)
const double _colLink =
    20.0; // icône de lien de contrat (collectif ↔ privatifs)

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
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderSm,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderSm,
            border: Border.all(color: AppColors.outlineVariant),
            color: onTap == null ? AppColors.surfaceContainerLow : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: muted ? AppColors.onSurfaceVariant : null,
              ),
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

/// En-tête « champ obligatoire » des cartes de la Configuration du bail
/// (titre + astérisque rouge + pastille « Obligatoire » ou coche verte).
/// **Partagé** par les deux pages d'EDL — ne pas dupliquer dans les States.
Widget _edlReqHeader(BuildContext context, String title, bool done) => Row(
  children: [
    Expanded(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextSpan(
              text: '  *',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
    if (done)
      Icon(Icons.check_circle, color: AppColors.success, size: 20)
    else
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Obligatoire',
          style: TextStyle(
            color: AppColors.onErrorContainer,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
  ],
);

/// Carte « Fenêtre d'avenant » (ChoiceChips 0/7/15/30/60/90 j) de la
/// Configuration du bail — **partagée** par les deux pages d'EDL.
Widget _edlAvenantWindowCard(
  BuildContext context, {
  required int? selected,
  required bool canEdit,
  required ValueChanged<int> onSelect,
}) {
  const options = [0, 7, 15, 30, 60, 90];
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _edlReqHeader(context, "Fenêtre d'avenant", selected != null),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Délai après finalisation pendant lequel des avenants/additions '
            'restent possibles. À choisir avant de finaliser.',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in options)
                ChoiceChip(
                  label: Text(d == 0 ? 'Sans avenant' : '$d jours'),
                  selected: selected == d,
                  onSelected: canEdit ? (_) => onSelect(d) : null,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Carte « Règlement de la caution » (en-tête obligatoire + `_CautionEditor`)
/// — **partagée** par les deux pages d'EDL.
Widget _edlCautionCard(
  BuildContext context, {
  required CautionMode? mode,
  required Map<String, dynamic>? details,
  required bool readOnly,
  required void Function(CautionMode, Map<String, dynamic>?) onChanged,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _edlReqHeader(context, 'Règlement de la caution', mode != null),
          const SizedBox(height: AppSpacing.sm),
          _CautionEditor(
            initialMode: mode,
            initialDetails: details,
            readOnly: readOnly,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

/// Paire de ChoiceChips « Avec garant / Sans garant » — **partagée** par les
/// deux pages d'EDL (le choix appartient au propriétaire).
Widget _edlAvecSansGarantChips({
  required bool? value,
  required bool canChoose,
  required ValueChanged<bool> onSelect,
}) {
  return Wrap(
    spacing: 8,
    children: [
      ChoiceChip(
        label: const Text('Avec garant'),
        selected: value == true,
        onSelected: canChoose ? (_) => onSelect(true) : null,
      ),
      ChoiceChip(
        label: const Text('Sans garant'),
        selected: value == false,
        onSelected: canChoose ? (_) => onSelect(false) : null,
      ),
    ],
  );
}

/// Cartes des garants rattachés + boutons « Ajouter `<garant>` » pour les
/// garants actifs restants — **partagé** par les deux pages d'EDL.
List<Widget> _edlGarantCards({
  required List<GarantModel> linked,
  required List<GarantModel> unlinked,
  required bool canManage,
  required void Function(int garantId) onLink,
  required void Function(int garantId) onUnlink,
}) {
  return [
    if (linked.isNotEmpty)
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final g in linked)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: IntrinsicWidth(
                child: _GarantCard(
                  garant: g,
                  name: g.displayName,
                  onDelete: canManage ? () => onUnlink(g.id) : null,
                ),
              ),
            ),
        ],
      ),
    // Garants actifs pas encore rattachés (ex. après suppression) →
    // possibilité de les (re)rattacher.
    if (canManage)
      for (final g in unlinked)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text('Ajouter ${g.displayName}'),
            onPressed: () => onLink(g.id),
          ),
        ),
  ];
}

/// Bandeau d'alerte « aucun garant actif » — **partagé** par les deux pages
/// d'EDL ([message] varie selon le rôle/le contexte).
Widget _edlGarantRequisBanner(String message) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(AppSpacing.sm),
  decoration: BoxDecoration(
    color: AppColors.errorContainer,
    borderRadius: AppRadius.borderMd,
    border: Border.all(color: AppColors.error),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          message,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onErrorContainer,
          ),
        ),
      ),
    ],
  ),
);

/// Texte du bandeau « garant requis » selon le rôle (le locataire est invité à
/// agir ; le propriétaire est informé que le locataire a été relancé).
String _edlGarantRequisMessage({required bool isLocataire}) => isLocataire
    ? 'Aucun garant actif. Ajoutez un garant ou activez-en un dans '
          '« Documents › Garants » : il sera inséré automatiquement dans ce bail.'
    : 'Aucun garant actif enregistré. Le locataire a été invité à en ajouter '
          'dans « Documents › Garants ».';

/// Carte de section (BIEN / DATES / LOCATAIRE…) des fiches d'EDL — cadre
/// discret + titre en petites capitales. **Partagée** par les deux pages.
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
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    ),
  );
}

/// Carte DATES des fiches d'EDL — **partagée** par les deux pages :
/// date de l'EDL (éditable côté proprietaire) + date de signature de l'EDL
/// (lecture seule, « En attente » tant que le locataire n'a pas accepté) +
/// (entrée) date de signature du bail. [extra] : blocs additionnels en bas
/// (ex. « Date limite d'avenant » de la page individuelle).
Widget _edlDatesCard({
  required bool isEntree,
  required DateTime date,
  required DateTime? dateFinalisation,
  required DateTime? bailSignedAt,
  required VoidCallback? onPickDate,
  List<Widget> extra = const [],
}) {
  final sensLabel = isEntree ? 'entrée' : 'sortie';
  return _sectionCard(
    title: 'DATES',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ligne 1 — dates de l'EDL (établissement + signature de l'EDL).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _edlDateBlock(
                label: "Date de l'état des lieux",
                value: _dateFmt.format(date),
                icon: Icons.calendar_today_outlined,
                onTap: onPickDate,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _edlDateBlock(
                // Ex-« Date de finalisation » : date de signature de l'EDL.
                label: "Date signature de l'EDL $sensLabel",
                value: dateFinalisation != null
                    ? _dateFmt.format(dateFinalisation)
                    : 'En attente',
                icon: Icons.event_available_outlined,
                muted: dateFinalisation == null,
              ),
            ),
          ],
        ),
        // Ligne 2 — date de signature du BAIL (document distinct de l'EDL).
        if (isEntree) ...[
          const SizedBox(height: AppSpacing.md),
          _edlDateBlock(
            label: 'Date de signature du bail',
            value: bailSignedAt != null
                ? _dateFmt.format(bailSignedAt)
                : 'En attente',
            icon: Icons.assignment_turned_in_outlined,
            muted: bailSignedAt == null,
          ),
        ],
        ...extra,
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class EtatDesLieuxPage extends StatefulWidget {
  /// Onglet initial (piloté par le sous-menu de la sidebar) : 0=Vision générale,
  /// 1=Entrée, 2=Sortie, 3=Vétusté.
  final int initialTab;

  /// Masque la barre d'onglets interne quand la navigation se fait par sous-menu.
  final bool showTabBar;
  const EtatDesLieuxPage({
    super.key,
    this.initialTab = 0,
    this.showTabBar = true,
  });

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
  // Vue du visualiser : false = résumée (_EdlDetailProprietairePage),
  // true = détaillée (la fiche complète embarquée, comme la voit le locataire).
  bool _detailVueDetaillee = true;
  Widget?
  _detailFullView; // page détaillée construite (immeuble/chambre chargés)
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
  // Forçar criação de novo collectif (novo ano letivo) mesmo existindo um aberto.
  bool _formForceNewCollectif = false;
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
    final individualIds = immeubles
        .where((i) => i.bailIndividuel)
        .map((i) => i.id)
        .toList();
    final allChambres = await ChambresDatasource.listByImmeubles(individualIds);
    final occupied = await EtatDesLieuxDatasource.chambreIdsWithEdlForImmeubles(
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
      final chambres = allChambres
          .where((c) => c.immeubleId == selected.id)
          .toList();
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

      // Sélection de l'année scolaire / contrat de base.
      bool isAvenant = false;
      int? avenantCollectifId;
      bool forceNewCollectif = false;

      final allCollectifs = await EtatDesLieuxDatasource.listAllCollectifs(
        immeubleId: selected.id,
        typeEdl: typeEdl,
      );
      if (!mounted) return;

      if (allCollectifs.isNotEmpty) {
        // Cas trivial : un seul collectif ouvert de la même année scolaire
        // → on le réutilise sans dialogue.
        final singleOpen =
            allCollectifs.length == 1 &&
            allCollectifs.first.situation != SituationEdl.finalise &&
            memeAnneeLetive(allCollectifs.first.dateEtatLieux, DateTime.now());

        if (!singleOpen) {
          final choice = await showSelectAnneeDialog(
            context,
            immeubleNom: selected.name,
            collectifs: allCollectifs,
          );
          if (choice == null || !mounted) return; // annulé
          if (choice.forceNew) {
            forceNewCollectif = true;
          } else if (choice.isAvenant) {
            isAvenant = true;
            avenantCollectifId = choice.collectif!.id;
          }
          // else: réutiliser le collectif ouvert choisi (ensureCollectif le trouve)
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
        _formForceNewCollectif = forceNewCollectif;
      });
      return;
    }
  }

  /// Demande, quand le collectif d'entrée est déjà finalisé, si le nouvel EDL
  /// individuel fait partie d'un nouveau contrat collectif ou d'un avenant au
  /// contrat existant. Retourne null si annulé.
  /// Diálogo explicativo quando não há contratos elegíveis para avenant.
  Future<void> _showAvenantBlockedDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avenant impossible'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Flux Avenant (bouton « Avenant ») : choisir un contrat finalisé avec des
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
      // Détecter la raison pour afficher un message spécifique.
      final all = await EtatDesLieuxDatasource.listByProprietaire(
        uid,
        refresh: false,
      );
      if (!mounted) return;

      // Cherche tout EDL finalisé susceptible d'avenant (privatif individuel
      // ou commune location).
      final hasFinalised = all.any(
        (e) =>
            e.typeEdl == typeEdl &&
            e.situation == SituationEdl.finalise &&
            ((e.partie == PartieEdl.privative && e.typeBail == 'individuel') ||
                (e.partie == PartieEdl.commune && e.typeBail == 'location')),
      );

      if (!hasFinalised) {
        await _showAvenantBlockedDialog(
          'Aucun contrat finalisé. Finalisez d\'abord un EDL individuel '
          'ou location pour pouvoir créer un avenant.',
        );
      } else {
        await _showAvenantBlockedDialog(
          'Toutes les chambres sont occupées dans vos contrats finalisés.',
        );
      }
      return;
    }

    final picked = await showSelectCollectifAvenantDialog(context, amendables);
    if (picked == null || !mounted) return;

    final immeubles = await ImmeublesDatasource.listByOwner(uid);
    if (!mounted) return;
    final immeuble = immeubles
        .where((i) => i.id == picked.collectif.immeubleId)
        .firstOrNull;
    if (immeuble == null) return;

    if (picked.collectif.typeBail == 'location') {
      // Bail location : ouvre l'EDL commune existant pour ajouter un preneur.
      setState(() {
        _showCollectifForm = true;
        _showCollectifLockLocataires = false;
        _formImmeuble = immeuble;
        _formMeublee = immeuble.locationMeuble == true;
        _formEdl = picked.collectif;
        _formTypeEdl = typeEdl;
      });
      return;
    }

    // Bail individuel : sélectionner la chambre → nouveau privatif avenant.
    final res = await showSelectChambreDialog(context, picked.freeChambres);
    if (res == null || res.back || !mounted) return;
    final chambre = res.chambre!;
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

  /// Avenant direct depuis la fiche de détail d'un EDL **individuel privatif**
  /// finalisé (ou, au besoin, d'un collectif) : on connaît déjà le collectif,
  /// on passe directement au choix de la chambre libre, puis à la page
  /// individuel en mode avenant.
  Future<void> _startAvenantDirect(EtatDesLieuxModel edl) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;

    // Le collectif qui regroupe l'avenant : l'EDL lui-même si c'est un
    // collectif, sinon le collectif référencé par le privatif.
    final collectifId = edl.partie == PartieEdl.commune
        ? edl.id
        : edl.edlCollectifId;
    if (collectifId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contrat collectif introuvable.')),
      );
      return;
    }

    // Charger l'immeuble et les chambres libres. Une erreur de chargement est
    // signalée telle quelle (sinon elle se déguise en « Aucune chambre libre »).
    ImmeublesModel? immeuble;
    List<ChambreModel> freeCh = [];
    try {
      final list = await ImmeublesDatasource.listByOwner(uid);
      immeuble = list.where((i) => i.id == edl.immeubleId).firstOrNull;
      if (immeuble != null) {
        final usedIds =
            await EtatDesLieuxDatasource.chambreIdsWithEdlForImmeubles(
              immeubleIds: [immeuble.id],
              typeEdl: edl.typeEdl,
            );
        final all = await ChambresDatasource.listByImmeubles([immeuble.id]);
        freeCh = all.where((c) => !usedIds.contains(c.id)).toList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
      }
      return;
    }
    if (!mounted) return;
    if (immeuble == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Immeuble introuvable.')));
      return;
    }

    if (freeCh.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune chambre libre pour cet immeuble.'),
        ),
      );
      return;
    }

    final res = await showSelectChambreDialog(context, freeCh);
    if (res == null || res.back || res.chambre == null || !mounted) return;

    setState(() {
      _showIndividuelForm = true;
      _formImmeuble = immeuble;
      _formChambre = res.chambre!;
      _formMeublee = immeuble!.locationMeuble == true;
      _formEdl = null;
      _formTypeEdl = edl.typeEdl;
      _formIsAvenant = true;
      _formAvenantCollectifId = collectifId;
    });
  }

  /// Flux « Nouveau » de l'onglet Sortie : un EDL de sortie ne se crée qu'à
  /// partir d'une **entrée finalisée**. On liste les entrées éligibles, on crée
  /// le sortie couplé (copie de structure depuis l'entrée) puis on l'ouvre.
  Future<void> _startSortie() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final entrees = await EtatDesLieuxDatasource.listFinalizedEntreesForSortie(
      uid,
    );
    if (!mounted) return;
    if (entrees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucune entrée finalisée disponible pour créer une sortie.',
          ),
        ),
      );
      return;
    }
    final entree = await showSelectEntreeForSortieDialog(context, entrees);
    if (entree == null || !mounted) return;
    try {
      final sortie = await EtatDesLieuxDatasource.createSortieFromEntree(
        entree,
      );
      if (!mounted) return;
      await _openExistingEdl(sortie);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  /// Ouvre un EDL existant pour édition, en routant vers la bonne page selon
  /// bail (collectif/individuel) — meublée ou non.
  Future<void> _openExistingEdl(EtatDesLieuxModel edl) async {
    void notDev() {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "L'édition de ce type d'EDL est en cours de développement.",
          ),
        ),
      );
    }

    // Signale une erreur de chargement telle quelle (sinon elle se déguise en
    // « en cours de développement » et le clic semble ne rien faire).
    void fail(Object e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
    }

    // Charger l'immeuble pour connaître bail / location_meuble.
    ImmeublesModel? immeuble;
    try {
      final uid = AuthService.currentUser?.id ?? '';
      final list = await ImmeublesDatasource.listByOwner(uid);
      immeuble = list.where((i) => i.id == edl.immeubleId).firstOrNull;
    } catch (e) {
      fail(e);
      return;
    }
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
        final chambres = await ChambresDatasource.listByImmeubles([
          immeuble.id,
        ]);
        chambre = chambres.where((c) => c.id == edl.chambreId).firstOrNull;
      } catch (e) {
        fail(e);
        return;
      }
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
        icon: Icon(Icons.block, color: AppColors.error),
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
      final privatifs = await EtatDesLieuxDatasource.listPrivativesByCollectif(
        edl.id,
      );
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
          '${_dateFmt.format(edl.dateEtatLieux)} sera définitivement supprimé.'
          // Dernier privatif d'un contrat → les parties communes internes
          // (collectif) partent avec (voir EtatDesLieuxDatasource.delete).
          '${edl.partie == PartieEdl.privative && edl.edlCollectifId != null ? '\n\nS\'il s\'agit du dernier état des lieux du contrat, l\'état des parties communes associé sera également supprimé.' : ''}',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabCtrl.addListener(() => setState(() {}));
    _future = _load();
  }

  Future<_PageData> _load() async {
    final uid = AuthService.currentUser?.id ?? '';
    final results = await Future.wait([
      EtatDesLieuxDatasource.listByProprietaire(uid),
      EtatDesLieuxDatasource.listInvitedLocataires(uid),
    ]);
    // Cache le collectif d'un bail individuel (partie=commune) : c'est un
    // détail d'implémentation (miroir des parties communes) édité DANS la
    // fiche de chaque EDL individuel — il n'apparaît plus comme ligne propre.
    // Même règle que `listForLocataire`. Le commune d'un bail *location*
    // reste visible (c'est le seul EDL du contrat dans ce cas).
    final edls = (results[0] as List<EtatDesLieuxModel>)
        .where((e) => !e.isCollectifInterne)
        .toList();
    return (edls: edls, invites: results[1] as List<UsersClient>);
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
    if (_showForm || _showCollectifForm || _showIndividuelForm || _showDetail) {
      return;
    }
    _reload();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  /// Sélecteur « Vue résumée / Vue détaillée » du visualiser (barre du haut).
  Widget _vueSelector() => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(
        value: false,
        label: Text('Vue résumée'),
        icon: Icon(Icons.subject, size: 16),
      ),
      ButtonSegment(
        value: true,
        label: Text('Vue détaillée'),
        icon: Icon(Icons.grid_view_outlined, size: 16),
      ),
    ],
    selected: {_detailVueDetaillee},
    showSelectedIcon: false,
    style: const ButtonStyle(
      visualDensity: VisualDensity.compact,
      textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
    ),
    onSelectionChanged: (s) => _setDetailVue(s.first),
  );

  void _fermerDetail() => setState(() {
    _showDetail = false;
    _detailEdl = null;
    _detailVueDetaillee = false;
    _detailFullView = null;
  });

  /// Bascule résumée ↔ détaillée. La vue détaillée est la fiche complète
  /// (celle du « Continuer », qui se verrouille d'elle-même si finalisé),
  /// embarquée sous la barre du sélecteur.
  Future<void> _setDetailVue(bool detaillee) async {
    final edl = _detailEdl;
    if (edl == null || detaillee == _detailVueDetaillee) return;
    if (!detaillee) {
      // Retour au résumé : recharge l'EDL (la fiche a pu le modifier).
      final fresh = await EtatDesLieuxDatasource.findById(edl.id);
      if (!mounted) return;
      setState(() {
        _detailEdl = fresh ?? edl;
        _detailVueDetaillee = false;
        _detailFullView = null;
      });
      return;
    }
    setState(() {
      _detailVueDetaillee = true;
      _detailFullView = null; // spinner pendant le chargement
    });
    try {
      final view = await _buildDetailFullView(edl);
      if (!mounted) return;
      if (view == null) {
        setState(() => _detailVueDetaillee = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vue détaillée indisponible pour cet état des lieux.',
            ),
          ),
        );
        return;
      }
      setState(() => _detailFullView = view);
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailVueDetaillee = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
    }
  }

  /// Construit la fiche complète pour la vue détaillée (même routage
  /// bail × partie que [_openExistingEdl], mais en widget embarqué : son
  /// « Fermer » revient à la vue résumée).
  Future<Widget?> _buildDetailFullView(EtatDesLieuxModel edl) async {
    final uid = AuthService.currentUser?.id ?? '';
    final list = await ImmeublesDatasource.listByOwner(uid);
    final immeuble = list.where((i) => i.id == edl.immeubleId).firstOrNull;
    if (immeuble == null) return null;
    final meublee = immeuble.locationMeuble == true;

    void backToResume(bool _) => _setDetailVue(false);

    if (edl.typeBail == 'individuel' &&
        edl.partie == PartieEdl.privative &&
        edl.chambreId != null) {
      final chambres = await ChambresDatasource.listByImmeubles([immeuble.id]);
      final chambre = chambres.where((c) => c.id == edl.chambreId).firstOrNull;
      if (chambre == null) return null;
      return EdlIndividuelMeubleePage(
        immeuble: immeuble,
        chambre: chambre,
        typeEdl: edl.typeEdl,
        existingEdl: edl,
        meublee: meublee,
        onClose: backToResume,
        viewSelector: _vueSelector(),
      );
    }
    if (edl.partie == PartieEdl.commune) {
      return EdlCollectifNonMeubleePage(
        immeuble: immeuble,
        typeEdl: edl.typeEdl,
        existingEdl: edl,
        meublee: meublee,
        lockLocataires: edl.typeBail == 'individuel',
        onClose: backToResume,
        viewSelector: _vueSelector(),
      );
    }
    return null; // EDL legado sans page détaillée
  }

  @override
  Widget build(BuildContext context) {
    if (_showDetail && _detailEdl != null) {
      final edl = _detailEdl!;
      // Vue détaillée : la fiche complète embarque déjà le sélecteur dans SA
      // propre barre d'en-tête (Enregistrer/Fermer/Document/…) — pas de barre
      // séparée. « Fermer » y ramène à la vue résumée (même barre pour les
      // deux vues, cf. `viewSelector` passé dans `_buildDetailFullView`).
      if (_detailVueDetaillee) {
        return _detailFullView ??
            const Center(child: CircularProgressIndicator());
      }
      final isFinalise = edl.situation == SituationEdl.finalise;
      // Avenant : uniquement depuis un EDL **individuel privatif** finalisé,
      // tant que la fenêtre (jours après finalisation) est ouverte. Le collectif
      // regroupe ensuite tout ce qui vient des individuels — pas de bouton là.
      final canAvenant =
          isFinalise &&
          edl.typeBail == 'individuel' &&
          edl.partie == PartieEdl.privative &&
          edl.edlCollectifId != null &&
          edl.isAvenantWindowOpen;
      return _EdlDetailProprietairePage(
        edl: edl,
        vueSelector: _vueSelector(),
        onClose: _fermerDetail,
        // EDL finalizado → não é editável; mostra Avenant se aplicável.
        onEditer: isFinalise
            ? null
            : () {
                _fermerDetail();
                _openExistingEdl(edl);
              },
        onAvenant: canAvenant
            ? () {
                _fermerDetail();
                _startAvenantDirect(edl);
              }
            : null,
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
        forceNewCollectif: _formForceNewCollectif,
        onClose: (refresh) {
          setState(() {
            _showIndividuelForm = false;
            _formImmeuble = null;
            _formChambre = null;
            _formEdl = null;
            _formIsAvenant = false;
            _formAvenantCollectifId = null;
            _formForceNewCollectif = false;
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

        const subLabels = ['Vision générale', 'Entrée', 'Sortie', 'Vétusté'];
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
                    Tab(text: 'Vision générale'),
                    Tab(text: 'Entrée'),
                    Tab(text: 'Sortie'),
                    Tab(text: 'Vétusté'),
                  ],
                ),
              ),
              const Divider(height: 1),
            ] else
              // Navigation par sous-menus : barre de titre standard du sous-item.
              AppTopBar(title: subLabels[widget.initialTab.clamp(0, 3)]),
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
                    onInviteChanged: _reload,
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
                    onNouveau: _startSortie,
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
                  const VetustePage(),
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
  // Rechargement après suppression d'une invitation.
  final VoidCallback? onInviteChanged;

  const _VisionGeneraleTab({
    required this.all,
    required this.invitedLocataires,
    required this.onNouveau,
    this.onAvenant,
    required this.onVoir,
    this.onEditer,
    this.onDelete,
    this.onVisualiser,
    this.onInviteChanged,
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
              final invites = _LocatairesInvitesCard(
                locataires: invitedLocataires,
                onChanged: onInviteChanged,
              );
              // La fenêtre d'avenant est désormais choisie **dans chaque EDL**
              // (onglet Bail), plus globalement ici.
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
              // Largeur du card invités = nb de colonnes (3 par colonne).
              final invCols = invitedLocataires.isEmpty
                  ? 1
                  : ((invitedLocataires.length + 2) ~/ 3);
              final invitesWidth = invCols * 360.0;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(width: 280, child: stat),
                  SizedBox(width: invitesWidth, child: invites),
                ],
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
  // Appelé après suppression d'une invitation (pour recharger la liste).
  final VoidCallback? onChanged;

  const _LocatairesInvitesCard({required this.locataires, this.onChanged});

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
  // Ids en cours de suppression d'invitation.
  final Set<String> _deleting = {};

  Future<void> _resend(UsersClient loc) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    setState(() => _sending.add(loc.id));
    try {
      await EtatDesLieuxDatasource.resendInvitation(
        userId: loc.id,
        email: loc.email,
        fullName: loc.fullName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation renvoyée à ${loc.email}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _sending.remove(loc.id));
    }
  }

  /// Supprime (annule) l'invitation après confirmation. Le compte invité
  /// (pas encore activé) est supprimé côté serveur ; la liste est rechargée.
  Future<void> _delete(UsersClient loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer l'invitation ?"),
        content: Text(
          "L'invitation de « ${loc.fullName ?? loc.email} » sera supprimée "
          'définitivement. Le compte (pas encore activé) sera effacé.',
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
    setState(() => _deleting.add(loc.id));
    try {
      await EtatDesLieuxDatasource.cancelInvitation(userId: loc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation de ${loc.email} supprimée.')),
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _deleting.remove(loc.id));
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
    final deleting = _deleting.contains(loc.id);
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
            // Annuler / supprimer l'invitation.
            IconButton(
              onPressed: deleting ? null : () => _delete(loc),
              tooltip: "Supprimer l'invitation",
              visualDensity: VisualDensity.compact,
              icon: deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
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
        decoration: BoxDecoration(
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
        slices.add(
          _AvatarSlice(
            label: valid[i].trim().substring(0, 1).toUpperCase(),
            color: _kContratColors[i % _kContratColors.length],
          ),
        );
      }
    } else {
      for (var i = 0; i < _maxSlices - 1; i++) {
        slices.add(
          _AvatarSlice(
            label: valid[i].trim().substring(0, 1).toUpperCase(),
            color: _kContratColors[i % _kContratColors.length],
          ),
        );
      }
      slices.add(
        _AvatarSlice(
          label: '+${valid.length - (_maxSlices - 1)}',
          color: AppColors.onSurfaceVariant,
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SegmentedAvatarPainter(slices),
        // Tooltip avec la liste complète des locataires.
        child: Tooltip(
          message: valid.join('\n'),
          child: const SizedBox.expand(),
        ),
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
      final pos =
          center + Offset(math.cos(mid), math.sin(mid)) * (radius * 0.58);
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
        isNarrow: constraints.maxWidth < AppBreakpoints.tableToCards,
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
          : linkedCollectifIds.contains(
              e.id,
            ); // collectif avec ≥1 privatif visible
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
            PermissionGate(
              permission: Perm.edlAvenant,
              child: OutlinedButton.icon(
                onPressed: widget.onAvenant,
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: const Text('Avenant'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          PermissionGate(
            permission: Perm.edlCreate,
            child: FilledButton.icon(
              onPressed: widget.onNouveau,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau'),
            ),
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
          _colHeader('DT SIG. BAIL', _colFin),
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
          if (!isNarrow) ...[columnHeaders, const Divider(height: 1)],
          if (widget.shrinkWrap) listWidget else Expanded(child: listWidget),
        ],
      ),
    );
  }
}

/// Bouton d'action principal d'une ligne d'EDL, selon l'état :
/// - **non finalisé** → « Continuer » (édition).
/// - **finalisé + non signé par le locataire** → « Demander signature »
///   (envoie une demande au locataire ; anti-spam 1 / 5 jours).
/// - **finalisé + signé + éligible au bail** → « Générer bail » (ouvre le flux
///   bail : vérification garant + signature bailleur + aperçu).
class _EdlActionButton extends StatefulWidget {
  final EtatDesLieuxModel edl;
  final VoidCallback onContinuer;
  final bool compact;

  const _EdlActionButton({
    required this.edl,
    required this.onContinuer,
    this.compact = false,
  });

  @override
  State<_EdlActionButton> createState() => _EdlActionButtonState();
}

class _EdlActionButtonState extends State<_EdlActionButton> {
  bool _busy = false;
  // Copie locale de l'EDL : rafraîchie après signature du bail (le bouton
  // « Bail » bascule alors en « Visualiser le bail »).
  late EtatDesLieuxModel _edl = widget.edl;
  late DateTime? _lastReq = widget.edl.lastSignatureRequestAt;

  bool get _finalise => _edl.situation == SituationEdl.finalise;
  bool get _signed => _edl.locataireAccepte;

  int get _cooldown {
    final last = _lastReq;
    if (last == null) return 0;
    final r = 5 - DateTime.now().difference(last).inDays;
    return r > 0 ? r : 0;
  }

  @override
  Widget build(BuildContext context) {
    final edl = _edl;

    if (!_finalise) {
      return PermissionGate(
        permission: Perm.edlEdit,
        child: _btn(
          icon: Icons.edit_outlined,
          label: 'Continuer',
          onPressed: widget.onContinuer,
          tooltip: "Continuer l'édition de l'état des lieux",
        ),
      );
    }

    if (!_signed) {
      final canReq = _cooldown == 0 && !_busy;
      return PermissionGate(
        permission: Perm.edlEdit,
        child: _btn(
          icon: Icons.mark_email_unread_outlined,
          label: widget.compact ? 'Signature' : 'Demander signature',
          onPressed: canReq ? _requestSignature : null,
          tooltip: _cooldown > 0
              ? 'Demande déjà envoyée — réessayez dans $_cooldown jour(s)'
              : 'Demander au locataire de signer (e-mail)',
        ),
      );
    }

    if (edl.isBailEligible) {
      // Bail entièrement signé → verrouillé : le bouton devient « Visualiser ».
      if (edl.bailFullySigned) {
        return _btn(
          icon: Icons.visibility_outlined,
          label: widget.compact ? 'Voir bail' : 'Visualiser le bail',
          onPressed: _busy ? null : _visualiserBail,
          tooltip: 'Consulter / imprimer le bail signé (lecture seule)',
        );
      }
      return PermissionGate(
        permission: Perm.edlEdit,
        child: _btn(
          icon: Icons.description_outlined,
          label: widget.compact ? 'Bail' : 'Générer bail',
          onPressed: _busy ? null : _genererBail,
          tooltip: 'Générer et signer le contrat de bail',
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Recharge l'EDL après une opération de signature (le bouton « Bail » peut
  /// alors basculer en « Visualiser le bail »).
  Future<void> _refreshEdl() async {
    final fresh = await EtatDesLieuxDatasource.findById(_edl.id);
    if (mounted && fresh != null) setState(() => _edl = fresh);
  }

  /// Ouvre le bail en lecture seule (déjà signé par les deux parties).
  Future<void> _visualiserBail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BailPdfPreviewPage(edl: _edl, readOnly: true),
      ),
    );
  }

  Future<void> _requestSignature() async {
    setState(() => _busy = true);
    try {
      await EtatDesLieuxDatasource.requestSignature(widget.edl.id);
      if (!mounted) return;
      setState(() {
        _lastReq = DateTime.now();
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande de signature envoyée au locataire.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _genererBail() async {
    setState(() => _busy = true);
    final garantRes = await ensureBailGarant(context, _edl);
    if (garantRes == null || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final signed = await ensureBailSignature(
      context,
      garantRes.edl,
      role: 'proprietaire',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (signed == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BailPdfPreviewPage(edl: signed, role: 'proprietaire'),
      ),
    );
    // Au retour : la signature a pu être posée dans l'aperçu → rafraîchir pour
    // basculer éventuellement en « Visualiser le bail ».
    await _refreshEdl();
  }

  Widget _btn({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    final child = SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: _busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: widget.compact ? 14 : 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: widget.compact
            ? FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: const TextStyle(fontSize: 11),
              )
            : null,
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: child) : child;
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
    // Le collectif (partie=commune d'un bail individuel) n'apparaît plus dans
    // la liste : le lien coloré marque les EDL individuels d'un même contrat.
    return edl.partie == PartieEdl.commune
        ? 'Contrat$ref — $imm'
        : 'Contrat$ref — $imm\n(même couleur = même contrat de colocation)';
  }

  /// Pastille SITUATION ciente do parcours (EDL → bail) — widget partagé
  /// [EdlParcoursBadge] (même pastille dans la table du locataire).
  Widget _situationCell() => EdlParcoursBadge(edl: edl);

  @override
  Widget build(BuildContext context) {
    final typeBailLabel = edl.typeLabel;
    return compact ? _buildCompact(typeBailLabel) : _buildWide(typeBailLabel);
  }

  Widget _buildCompact(String typeBailLabel) {
    return Container(
      decoration: contratColor != null
          ? BoxDecoration(
              border: Border(left: BorderSide(color: contratColor!, width: 4)),
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
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
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
              Expanded(child: _kv('ÉTAT', edl.dateEdlFormatted)),
              Expanded(
                child: _kv(
                  'DT Sig. Bail',
                  edl.bailSignedAtFormatted ?? '—',
                  muted: edl.bailSignedAt == null,
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
                  _situationCell(),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (onVisualiser != null) ...[
                Tooltip(
                  message: "Visualiser l'état des lieux (lecture seule)",
                  child: OutlinedButton.icon(
                    onPressed: onVisualiser,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Voir EDL'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              // Action principale selon l'état : Continuer (édition) /
              // Demander signature (finalisé non signé) / Générer bail
              // (finalisé + signé + éligible).
              Expanded(
                child: _EdlActionButton(edl: edl, onContinuer: onVoir),
              ),
              if (onDelete != null)
                PermissionGate(
                  permission: Perm.edlDelete,
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: SizedBox(
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
                  ),
                ),
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
    // Barre colorée à gauche (bord) pour regrouper le contrat ; la marge gauche
    // est compensée de 4 px pour ne pas décaler le contenu vs les autres lignes.
    // `HoverTableRow` (même comportement que l'Inventaire) englobe la ligne
    // entière : la couleur de survol passe derrière (le Container interne n'a
    // pas de fond propre, seulement une bordure).
    return HoverTableRow(
      child: Container(
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
          top: 6,
          bottom: 6,
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
                  if (edl.code != null)
                    Text(
                      edl.code!,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 0.3,
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
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
              child: Center(child: _situationCell()),
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

            // DT Sig. Bail (date de signature du bail, ou —)
            SizedBox(
              width: _colFin,
              child: Text(
                edl.bailSignedAtFormatted ?? '—',
                textAlign: TextAlign.center,
                style: AppTypography.labelSm.copyWith(
                  color: edl.bailSignedAt == null
                      ? AppColors.onSurfaceVariant
                      : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Visualiser (œil + libellé « EDL ») — colonne réservée pour l'alignement.
            SizedBox(
              width: _colEye,
              height: 38,
              child: onVisualiser == null
                  ? null
                  : Tooltip(
                      message: "Visualiser l'état des lieux (lecture seule)",
                      child: OutlinedButton(
                        onPressed: onVisualiser,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.borderMd,
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.visibility_outlined, size: 15),
                            Text(
                              'EDL',
                              style: TextStyle(
                                fontSize: 8,
                                height: 1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Action principale (compacte) : Continuer / Demander signature /
            // Générer bail selon l'état. Colonne réservée pour l'alignement.
            SizedBox(
              width: _colBtn,
              child: _EdlActionButton(
                edl: edl,
                onContinuer: onVoir,
                compact: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PermissionGate(
              permission: Perm.edlDelete,
              child: SizedBox(
                width: _colDel,
                height: 32,
                child: Tooltip(
                  message: onDelete != null
                      ? "Supprimer l'état des lieux"
                      : "Suppression impossible (EDL finalisé ou lié)",
                  child: FilledButton(
                    onPressed: onDelete,
                    style: FilledButton.styleFrom(
                      backgroundColor: onDelete != null
                          ? AppColors.error
                          : AppColors.outlineVariant,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderMd,
                      ),
                    ),
                    child: const Icon(Icons.delete_outline, size: 16),
                  ),
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
  Set<int> _headerStepIndices =
      {}; // indices dos steps que são separadores de seção
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
    // Auto-fill surface m² depuis l'immeuble (location simple)
    if (imm?.bailLocation == true && imm?.totalM2 != null) {
      _surfaceCtrl.text = imm!.totalM2!.toStringAsFixed(0);
    } else {
      _surfaceCtrl
          .clear(); // bail individuel → rempli à la sélection de chambre
    }
    // Auto-fill adresse bailleur depuis l'immeuble
    if (imm != null) {
      final parts = [
        imm.address,
        imm.city,
      ].where((s) => s != null && s.isNotEmpty).toList();
      if (parts.isNotEmpty) _bailleurAdrCtrl.text = parts.join(', ');
    }
    // Auto-fill loyer
    if (imm?.bailLocation == true && imm?.prixLoyer != null) {
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
    final picked = await showAppDatePicker(
      context,
      initial: _dateEdl,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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
          'type_bail': _immeuble!.bailLocation ? 'location' : 'individuel',
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
        final typeBail = _immeuble!.bailLocation ? 'location' : 'individuel';
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
        Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            "Enregistrez d'abord les informations (« Suivant ») pour remplir cette section.",
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  /// Contenu de l'étape « Le bien » (en-tête du document).
  Widget _buildStepBien() {
    Widget field(
      TextEditingController c,
      String label, {
      TextInputType? keyboard,
    }) => Padding(
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
              child: field(
                _surfaceCtrl,
                'SURFACE (m²)',
                keyboard: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: field(
                _piecesCtrl,
                'PIÈCES PRINCIPALES',
                keyboard: TextInputType.number,
              ),
            ),
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

    // Le propriétaire signe l'EDL (dessin, import ou signature sauvegardée).
    final sig = await showSignatureDialog(context);
    if (sig == null || !mounted) return; // annulé

    setState(() => _isFinalising = true);
    try {
      await EtatDesLieuxDatasource.finaliser(
        _currentEdlId!,
        proprietaireSignatureUrl: sig.url,
      );
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
                Icon(
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
                : _immeuble!.bailLocation
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
                Icon(
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
          Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
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
            Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
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
        mk(
          'Le bien',
          'Surface, bailleur, en-tête (parties communes)',
          _buildStepBien(),
        ),
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
        mk(
          'Le bien',
          'Surface, bailleur, en-tête du document',
          _buildStepBien(),
        ),
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
                    ? SizedBox(
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
          // `Wrap` plutôt que `Row` : sur un écran très étroit, les deux
          // boutons passent à la ligne suivante au lieu de provoquer un
          // overflow (le libellé « Sauvegarder et sortir » est long).
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onClose(false),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Annuler'),
                style: AppTheme.cancelButtonStyle,
              ),
              if (!isFinalized)
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? SizedBox(
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
                  if (isFinalized &&
                      (widget.existingEdl?.locataireAccepte == true) &&
                      widget.existingEdl?.typeEdl == 'entree')
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BailPdfPreviewPage(
                            edl: widget.existingEdl!,
                            role: 'proprietaire',
                            readOnly: widget.existingEdl!.bailFullySigned,
                          ),
                        ),
                      ),
                      icon: Icon(
                        widget.existingEdl!.bailFullySigned
                            ? Icons.visibility_outlined
                            : Icons.description_outlined,
                      ),
                      label: Text(
                        widget.existingEdl!.bailFullySigned
                            ? 'Visualiser le bail'
                            : 'Bail',
                      ),
                    ),
                  if (!isFinalized)
                    OutlinedButton(
                      onPressed: _isFinalising ? null : _finaliser,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error),
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
                    : Row(mainAxisSize: MainAxisSize.min, children: actions);
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
                        return Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.secondary,
                        );
                      }
                      return null;
                    },
                    steps: _buildSteps(bundle, isFinalized),
                  ),
                ), // ConstrainedBox
              ), // Align
            ), // Expanded
          ], // Column children
        ); // Column / return
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
          builder: (_) =>
              _WallObsDialog(wallKey: wallKey, existing: existing, edlId: id),
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
          builder: (_) => _GeneralObsDialog(existing: existing, edlId: id),
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
    if (imm.bailIndividuel) return '${imm.name} (colocation)';
    return '${imm.name} (location)';
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
  // null quando o EDL está finalizado (substituído por onAvenant)
  final VoidCallback? onEditer;
  // mostrado apenas para EDLs finalizados (avenant direto)
  final VoidCallback? onAvenant;
  // Sélecteur « Vue résumée / Vue détaillée » affiché dans la barre du haut.
  final Widget? vueSelector;

  const _EdlDetailProprietairePage({
    required this.edl,
    required this.onClose,
    this.onEditer,
    this.onAvenant,
    this.vueSelector,
  });

  @override
  State<_EdlDetailProprietairePage> createState() =>
      _EdlDetailProprietairePageState();
}

class _EdlDetailProprietairePageState
    extends State<_EdlDetailProprietairePage> {
  static final _fmt = DateFormat('dd/MM/yyyy');
  late final Future<_DetailData> _dataFuture;

  static const _wallOrder = <String?>[
    'fond',
    'gauche',
    'droit',
    'porte',
    'sol',
    'plafond',
    null,
  ];
  static const _wallLabels = <String, String>{
    'fond': 'Mur du fond',
    'gauche': 'Mur gauche',
    'droit': 'Mur droit',
    'porte': "Mur d'entrée / Porte",
    'sol': 'Sol',
    'plafond': 'Plafond',
  };

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  /// Charge tout ce qu'il faut pour la fiche en lecture seule : observations
  /// (hors additions), preneurs (locataires), et les noms des pièces/chambres
  /// pour grouper les observations d'un EDL collectif.
  Future<_DetailData> _load() async {
    final edl = widget.edl;
    final results = await Future.wait([
      ObservationsEdlDatasource.listByEdl(edl.id),
      EdlDetailsDatasource.listPreneurs(edl.id),
      PiecesDatasource.listByImmeuble(edl.immeubleId),
      ChambresDatasource.listByImmeuble(edl.immeubleId),
    ]);
    final obs = (results[0] as List<ObservationEdl>)
        .where((o) => !o.isAddition)
        .toList();
    final pieces = results[2] as List<PieceModel>;
    final chambres = results[3] as List<ChambreModel>;
    return _DetailData(
      observations: obs,
      preneurs: results[1] as List<EdlPreneur>,
      pieceNames: {for (final p in pieces) p.id: p.nom},
      chambreNames: {for (final c in chambres) c.id: c.roomName},
    );
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

  /// Observations regroupées par pièce/chambre (EDL collectif) puis par mur.
  /// Pour un privatif single-room, il y a un seul groupe (« Général »).
  Widget _buildObservationsGroupees(
    List<ObservationEdl> obs,
    _DetailData data,
  ) {
    // Groupe par cible (pièce / chambre / général), en conservant un libellé.
    final groups = <String, ({String label, List<ObservationEdl> obs})>{};
    for (final o in obs) {
      final String key;
      final String label;
      if (o.pieceId != null) {
        key = 'piece:${o.pieceId}';
        label = data.pieceNames[o.pieceId] ?? 'Pièce';
      } else if (o.chambreId != null) {
        key = 'chambre:${o.chambreId}';
        label = data.chambreNames[o.chambreId] ?? 'Chambre';
      } else {
        key = 'general';
        label = 'Général';
      }
      groups.putIfAbsent(key, () => (label: label, obs: [])).obs.add(o);
    }

    final entries = groups.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En-tête de la pièce/chambre.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed.withValues(alpha: 0.25),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          group.label,
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final wallKey in _wallOrder)
                  if (group.obs.any((o) => o.wallKey == wallKey)) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.xs,
                        bottom: AppSpacing.xs,
                        left: AppSpacing.sm,
                      ),
                      child: Text(
                        (_wallLabels[wallKey] ?? 'Général').toUpperCase(),
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    for (final o in group.obs.where(
                      (o) => o.wallKey == wallKey,
                    ))
                      _EdlObsTile(obs: o),
                  ],
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final edl = widget.edl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: edl.typeEdl == 'entree'
              ? "État des lieux d'entrée"
              : 'État des lieux de sortie',
          leading: BackButton(onPressed: widget.onClose),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.vueSelector != null) ...[
                widget.vueSelector!,
                const SizedBox(width: AppSpacing.md),
              ],
              DocumentPdfButton(
                onPressed: () {
                  final edl = widget.edl;
                  if (edl.partie == PartieEdl.privative &&
                      edl.edlCollectifId != null) {
                    openEdlIndividuelPdfPreview(
                      context: context,
                      collectifId: edl.edlCollectifId!,
                      privatifId: edl.id,
                    );
                  } else {
                    openEdlCollectifPdfPreview(context: context, edlId: edl.id);
                  }
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              if (widget.onAvenant != null)
                FilledButton.icon(
                  onPressed: widget.onAvenant,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Avenant'),
                )
              else if (widget.onEditer != null)
                FilledButton.icon(
                  onPressed: widget.onEditer,
                  style: AppTheme.saveButtonStyle,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Éditer'),
                ),
            ],
          ),
        ),
        Expanded(child: _detailBody()),
      ],
    );
  }

  Widget _detailBody() {
    final edl = widget.edl;
    return SingleChildScrollView(
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

              // ── Locataire(s) ───────────────────────────────────────────
              _sectionTitle(
                edl.partie == PartieEdl.commune ? 'LOCATAIRES' : 'LOCATAIRE',
              ),
              FutureBuilder<_DetailData>(
                future: _dataFuture,
                builder: (context, snap) {
                  final preneurs = snap.data?.preneurs ?? const [];
                  final rows = <Widget>[];
                  if (preneurs.isNotEmpty) {
                    for (final p in preneurs) {
                      rows.add(_infoRow(p.nom ?? '—', p.email ?? ''));
                    }
                  } else if (edl.locataireNom != null) {
                    rows.add(_infoRow('Nom', edl.locataireNom!));
                    if (edl.locataireEmail != null) {
                      rows.add(_infoRow('E-mail', edl.locataireEmail!));
                    }
                    if (edl.locatairePhone != null &&
                        edl.locatairePhone!.isNotEmpty) {
                      rows.add(_infoRow('Téléphone', edl.locatairePhone!));
                    }
                  } else {
                    rows.add(
                      Text(
                        'Aucun locataire.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return _infoCard(rows);
                },
              ),
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
                _infoRow('Type de bail', edl.typeLabel),
                _infoRow('Date état des lieux', _fmt.format(edl.dateEtatLieux)),
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

              // ── État des pièces et chambres ────────────────────────────
              _sectionTitle(
                edl.partie == PartieEdl.commune
                    ? 'ÉTAT DES PIÈCES ET CHAMBRES'
                    : 'ÉTAT DE LA CHAMBRE',
              ),
              FutureBuilder<_DetailData>(
                future: _dataFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final data = snap.data;
                  final obs = data?.observations ?? const [];
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
                  return _buildObservationsGroupees(obs, data!);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Données chargées pour la fiche EDL en lecture seule.

class _DetailData {
  final List<ObservationEdl> observations;
  final List<EdlPreneur> preneurs;
  final Map<int, String> pieceNames;
  final Map<int, String> chambreNames;

  const _DetailData({
    required this.observations,
    required this.preneurs,
    required this.pieceNames,
    required this.chambreNames,
  });
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
                    child: PrivateImage(
                      ref: obs.photos[i],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
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
    final bg = muted ? AppColors.surfaceContainerHigh : AppColors.primaryFixed;
    final fg = muted
        ? AppColors.onSurfaceVariant
        : AppColors.onPrimaryFixedVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.borderFull),
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
          // Même garde-fou que _LocataireASignerBadge : la colonne SITUATION
          // est étroite → tronquer au lieu de déborder.
          Flexible(
            child: Text(
              situation.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
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
              ? SizedBox(
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
  // EDL de sortie : observations de l'ENTRÉE couplée, affichées en contrepoint
  // (lecture seule) sous le plan. Vide pour une entrée.
  final List<ObservationEdl> entreeObservations;
  final void Function(String wallKey) onEditWall;
  // Lecture seule (locataire ou EDL finalisé) : les murs ne sont plus éditables.
  final bool readOnly;

  const _RoomDiagram({
    required this.chambreName,
    this.planLabel,
    this.chambrePhoto,
    required this.observations,
    this.entreeObservations = const [],
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
            Icon(Icons.home_outlined, size: 18, color: AppColors.primary),
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
                          child:
                              (chambrePhoto != null &&
                                  chambrePhoto!.trim().isNotEmpty &&
                                  Uri.tryParse(
                                        chambrePhoto!.trim(),
                                      )?.hasScheme ==
                                      true)
                              ? CachedNetworkImage(
                                  imageUrl: chambrePhoto!.trim(),
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => Center(
                                    child: Icon(
                                      Icons.home_outlined,
                                      size: 36,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Center(
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
                                onTap: () =>
                                    readOnly ? null : onEditWall('plafond'),
                                alignTop: true,
                              ),
                            ),
                            Expanded(
                              child: _InnerZone(
                                label: 'Sol',
                                icon: Icons.expand_more,
                                obsCount: _obsCount('sol'),
                                onTap: () =>
                                    readOnly ? null : onEditWall('sol'),
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
        if (entreeObservations.where((o) => o.hasContent).isNotEmpty)
          _EntreeContrepoint(observations: entreeObservations),
      ],
    );
  }
}

/// Bloc de **contrepoint** (lecture seule) affichant l'état consigné à
/// l'ENTRÉE, sous le plan de la pièce/chambre d'un EDL de sortie.
class _EntreeContrepoint extends StatelessWidget {
  final List<ObservationEdl> observations;
  const _EntreeContrepoint({required this.observations});

  @override
  Widget build(BuildContext context) {
    final obs = observations.where((o) => o.hasContent).toList();
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.login,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                "Contrepoint — état d'entrée",
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final o in obs)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: AppSpacing.sm, top: 2),
                    color: o.isLocataire
                        ? AppColors.secondary
                        : AppColors.primary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.isLocataire
                              ? '${o.wallLabel} · Locataire'
                              : o.wallLabel,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        if (o.description != null && o.description!.isNotEmpty)
                          Text(o.description!, style: AppTypography.bodyMd),
                      ],
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
    'plafond',
    'fond',
    'gauche',
    'droit',
    'porte',
    'sol',
    null,
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
                      Icon(
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
              icon: Icon(
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
          Icon(
            Icons.person_outline,
            size: 12,
            color: AppColors.onTertiaryFixed,
          ),
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
  final int edlId;

  const _WallObsDialog({
    required this.wallKey,
    required this.edlId,
    this.existing,
  });

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
                folder: 'etat_de_lieux/${widget.edlId}/murs',
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
          style: AppTheme.saveButtonStyle,
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

  final int edlId;

  const _GeneralObsDialog({required this.edlId, this.existing});

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
                folder: 'etat_de_lieux/${widget.edlId}/general',
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
          style: AppTheme.saveButtonStyle,
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
  final int edlId;
  const _AdditionDialog({required this.comodos, required this.edlId});

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
      title: const Text('Ajouter un avenant'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'OÙ (comodo)',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<int>(
                initialValue: _comodoIndex,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (var i = 0; i < widget.comodos.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(widget.comodos[i].label),
                    ),
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
              Text(
                'PHOTO',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PhotoPickerField(
                folder: 'etat_de_lieux/${widget.edlId}/additions',
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
          style: AppTheme.saveButtonStyle,
          onPressed: () {
            final c = widget.comodos[_comodoIndex];
            Navigator.pop(context, (
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
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

/// Bandeau d'avertissement affiché quand le bail est signé des deux parties
/// mais que les échéances (loyer + caution) n'ont pas pu être générées —
/// remplace un échec silencieux par une cause explicite et actionnable.
class _EcheanceDiagBanner extends StatelessWidget {
  final EcheanceGenResult? reason;
  const _EcheanceDiagBanner({required this.reason});

  @override
  Widget build(BuildContext context) {
    final message = switch (reason) {
      EcheanceGenResult.missingDateDebutBail =>
        "La date de début du bail n'est pas renseignée : impossible de "
            'générer les échéances. Complétez-la ci-dessus.',
      EcheanceGenResult.missingLoyer =>
        "Aucun loyer n'est renseigné (ni sur l'état des lieux, ni sur la "
            'chambre/l\'immeuble) : impossible de générer les échéances.',
      EcheanceGenResult.missingDuree =>
        "La durée du bail (ou sa date de fin) n'est pas renseignée : "
            'impossible de générer les échéances.',
      _ => null,
    };
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: AppRadius.borderMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: AppColors.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Échéances non générées — $message',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
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
  // Mode super admin : bypass des verrous (édition possible même finalisé).
  final bool superAdmin;
  // Fourni quand cette page est embarquée dans la « Vue détaillée » du
  // visualiser (Vision générale) : rendu dans la MÊME barre d'en-tête que
  // Enregistrer/Fermer/Document (pas de barre séparée).
  final Widget? viewSelector;

  const EdlCollectifNonMeubleePage({
    super.key,
    required this.immeuble,
    required this.typeEdl,
    this.existingEdl,
    required this.onClose,
    this.isLocataire = false,
    this.meublee = false,
    this.lockLocataires = false,
    this.superAdmin = false,
    this.viewSelector,
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

  // Signature du BAIL (document distinct de l'EDL). État réactif local.
  bool _bailSignedProprio = false;
  bool _bailSignedLocataire = false;
  DateTime? _bailSignedAt;
  bool _isSigningBail = false;

  // Conditions obligatoires (bail location) : fenêtre d'avenant + caution.
  int? _avenantWindowSel;
  CautionMode? _cautionMode;
  Map<String, dynamic>? _cautionDetails;

  // Garant(s) du bail location — même champ `bail_avec_garant` que l'EDL
  // individuel (choix au niveau du contrat), mais les garants sont rattachés
  // PAR PRENEUR : `etat_de_lieux_garants` lie (edl, garant) et le garant porte
  // déjà son locataire (`Garants.locataire_id`) → regroupement par preneur.
  bool? _bailAvecGarant;
  EcheanceGenResult? _echeanceDiag;
  List<GarantModel> _linkedGarants = [];
  Map<String, List<GarantModel>> _activeGarantsByLocataire = {};
  // Anti-spam : une seule notification « garant requis » par ouverture de page.
  bool _garantNotifSent = false;

  List<PieceModel> _pieces = [];
  List<ChambreModel> _chambres = [];
  List<EdlPreneur> _preneurs = [];
  List<ObservationEdl> _observations = [];
  // EDL de sortie : observations de l'entrée couplée (contrepoint, lecture seule).
  List<ObservationEdl> _entreeObservations = [];
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
      _bailSignedProprio = edl.bailSignedBy('proprietaire');
      _bailSignedLocataire = edl.bailSignedBy('locataire');
      _bailSignedAt = edl.bailSignedAt;
      _avenantWindowSel = edl.avenantWindowDays;
      _cautionMode = CautionMode.fromRaw(edl.cautionMode);
      _cautionDetails = edl.cautionDetails;
      _bailAvecGarant = edl.bailAvecGarant;
    }
    _loadRooms();
    if (edl != null) {
      _loadPreneurs();
      _loadObservations();
      _loadEntreeObservations();
      if (widget.meublee) _loadSections();
      if (widget.lockLocataires) _loadPrivatifs();
      // Rattrapage : si le locataire a signé le bail en dernier, la génération
      // des échéances a été refusée par la RLS de Recettes sous sa session —
      // on la rejoue ici côté proprietaire (idempotent, no-op sinon).
      if (!_isLocataire && _bailSignedProprio && _bailSignedLocataire) {
        EtatDesLieuxDatasource.ensureBailEcheances(edl.id).then((r) {
          if (mounted) setState(() => _echeanceDiag = r);
        });
      }
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
    // Toujours en fin de table : max(ordre) + 1 (et non `length`, qui peut
    // entrer en collision avec un ordre existant après des suppressions).
    final nextOrdre = section.lignes.isEmpty
        ? 0
        : section.lignes.map((l) => l.ordre).reduce((a, b) => a > b ? a : b) +
              1;
    await EdlDetailsDatasource.createLigne(
      EdlLigne(
        sectionId: section.id!,
        equipement: 'Nouvel élément',
        ordre: nextOrdre,
      ),
    );
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

  /// Une fois finalisé (signé), plus aucun champ n'est modifiable — seul le
  /// super admin peut encore intervenir.
  bool get _readOnly =>
      !widget.superAdmin &&
      (_isLocataire || _situation == SituationEdl.finalise);

  /// Contenu structurel (pièces/chambres, murs, observations) figé une fois
  /// le collectif finalisé — pour les DEUX parties, seul le super admin y
  /// échappe.
  bool get _structLocked =>
      !widget.superAdmin && _situation == SituationEdl.finalise;

  // EDL privatifs (individuels) rattachés à ce collectif. Sert aux avenants,
  // à la date de finalisation par locataire et au verrouillage des chambres
  // dont l'EDL individuel est finalisé.
  List<EtatDesLieuxModel> _privatifs = [];
  List<EtatDesLieuxModel> get _avenants =>
      _privatifs.where((p) => p.isAvenant).toList();

  /// Chambres dont l'EDL individuel est finalisé → leurs observations sont en
  /// lecture seule dans le collectif (on ne modifie plus un individuel finalisé).
  Set<int> get _finalizedChambreIds => {
    for (final p in _privatifs)
      if (p.situation == SituationEdl.finalise && p.chambreId != null)
        p.chambreId!,
  };

  /// Privatif (EDL individuel) par locataire → date de finalisation affichée
  /// dans la carte du locataire.
  Map<String, EtatDesLieuxModel> get _privatifByLocataire => {
    for (final p in _privatifs)
      if (p.locataireId != null) p.locataireId!: p,
  };

  Future<void> _loadPrivatifs() async {
    if (_edlId == null) return;
    try {
      final privatifs = await EtatDesLieuxDatasource.listPrivativesByCollectif(
        _edlId!,
      );
      if (!mounted) return;
      setState(() => _privatifs = privatifs);
    } catch (_) {}
  }

  Future<void> _loadRooms() async {
    try {
      final pieces = await PiecesDatasource.listByImmeuble(widget.immeuble.id);
      final chambres = await ChambresDatasource.listByImmeubles([
        widget.immeuble.id,
      ]);
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
      // Les garants dépendent des preneurs (regroupement par locataire).
      await _loadGarantsLoc();
    } catch (_) {}
  }

  /// Charge les garants du bail location : ids rattachés à l'EDL
  /// (`etat_de_lieux_garants`) + garants actifs de chaque preneur ayant un
  /// compte (pour proposer le rattachement). Best-effort.
  Future<void> _loadGarantsLoc() async {
    if (_edlId == null) return;
    try {
      // Deux chargements indépendants en parallèle ; les actifs de TOUS les
      // preneurs viennent en une seule requête (pas de N+1 par preneur).
      final locIds = _preneurs
          .map((p) => p.locataireId)
          .whereType<String>()
          .toSet();
      final results = await Future.wait([
        EtatDesLieuxDatasource.listGarantIdsForEdl(
          _edlId!,
        ).then(GarantsDatasource.byIds),
        GarantsDatasource.activeByLocataires(locIds),
      ]);
      if (mounted) {
        setState(() {
          _linkedGarants = results[0] as List<GarantModel>;
          _activeGarantsByLocataire =
              results[1] as Map<String, List<GarantModel>>;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadObservations() async {
    if (_edlId == null) return;
    try {
      final obs = await ObservationsEdlDatasource.listByEdl(_edlId!);
      if (mounted) setState(() => _observations = obs);
    } catch (_) {}
  }

  /// EDL de sortie : charge les observations de l'ENTRÉE couplée (contrepoint).
  Future<void> _loadEntreeObservations() async {
    final entreeId = widget.existingEdl?.edlEntreeId;
    if (entreeId == null) return;
    try {
      final obs = await ObservationsEdlDatasource.listByEdl(entreeId);
      if (mounted) setState(() => _entreeObservations = obs);
    } catch (_) {}
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context,
      initial: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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
          // Bail location (ex-« collectif » : la valeur legacy a été migrée en
          // base vers 'location' — écrire 'collectif' cassait isBailEligible).
          typeBail: 'location',
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
      final items = await InventaireDatasource.listByImmeuble(
        widget.immeuble.id,
      );
      for (var pi = 0; pi < _pieces.length; pi++) {
        final p = _pieces[pi];
        final lignes = items
            .where((it) => it.pieceId == p.id)
            .toList()
            .asMap()
            .entries
            .map(
              (e) => EdlLigne(
                sectionId: 0,
                equipement: e.value.displayNom,
                natureNombre: e.value.quantite > 0
                    ? e.value.quantite.toString()
                    : null,
                ordre: e.key,
              ),
            )
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
      await EdlDetailsDatasource.createPreneur(
        EdlPreneur(
          etatDesLieuxId: _edlId!,
          locataireId: user.id,
          nom: user.fullName ?? user.email,
          ordre: _preneurs.length,
        ),
      );
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
          builder: (_) => _WallObsDialog(
            wallKey: wallKey,
            existing: existing,
            edlId: _edlId!,
          ),
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
          builder: (_) => _GeneralObsDialog(existing: existing, edlId: _edlId!),
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
    // Verrou : champs obligatoires du bail (avenant + caution) avant finalisation.
    if (widget.typeEdl == 'entree') {
      final missing = _missingBailLoc;
      if (missing.isNotEmpty) {
        _snack('Champs obligatoires manquants : ${missing.join(', ')}.');
        // Descend jusqu'à la configuration du bail (bas de page).
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        return;
      }
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

    // Demander les dates du bail avant de finaliser (bail location = commune)
    final bailResult = await showDialog<_BailDialogResult>(
      context: context,
      builder: (_) => const _FinaliserBailDialog(),
    );
    if (bailResult == null || !mounted) return;

    // Le propriétaire signe l'EDL avant de finaliser.
    final sig = await showSignatureDialog(context);
    if (sig == null || !mounted) return;

    setState(() => _isFinalising = true);
    try {
      await EtatDesLieuxDatasource.finaliser(
        _edlId!,
        dateDebutBail: bailResult.dateDebut,
        dateFinBail: bailResult.dateFin,
        dureeBailMois: bailResult.dureeMois,
        proprietaireSignatureUrl: sig.url,
      );
      if (mounted) setState(() => _situation = SituationEdl.finalise);
      _snack('État des lieux finalisé.');
      // Sortie : proposer un décompte de vétusté si dégradations.
      if (widget.typeEdl == 'sortie' && _edlId != null && mounted) {
        await proposerVetusteSiDegradation(context, _edlId!);
      }
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isFinalising = false);
    }
  }

  /// Accepter et signer (locataire) : grave `locataire_accepte` + date.
  Future<void> _accepter() async {
    if (_edlId == null) return;
    // Le locataire vérifie/crée sa signature, voit le PDF, puis signe.
    final edlModel = widget.existingEdl;
    String? sigUrl;
    if (edlModel != null) {
      sigUrl = await runLocataireSignatureFlow(context, edlModel);
    } else {
      sigUrl = (await showSignatureDialog(context))?.url;
    }
    if (sigUrl == null || !mounted) return;
    setState(() => _isFinalising = true);
    try {
      // La notification au propriétaire (in-app + e-mail) est centralisée dans
      // locataireAccepter → elle part quel que soit le chemin d'UI.
      await EtatDesLieuxDatasource.locataireAccepter(
        _edlId!,
        locataireSignatureUrl: sigUrl,
        locataireNom:
            AuthService.currentUser?.userMetadata?['full_name'] as String?,
        lieuLabel: widget.immeuble.name,
      );
      // Vérifie que la signature est bien enregistrée sur l'EDL.
      final ok = await EtatDesLieuxDatasource.isLocataireSigned(_edlId!);
      if (mounted) setState(() => _locataireAccepte = true);
      _snack(
        ok
            ? 'État des lieux accepté et signé ✓'
            : 'Accepté, mais la signature n\'a pas pu être confirmée — '
                  'rouvrez le document pour vérifier.',
      );
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isFinalising = false);
    }
  }

  // ── Signatures : EDL vs BAIL (deux documents distincts) ────────────────────
  String get _myRole => _isLocataire ? 'locataire' : 'proprietaire';
  bool get _edlSignedByMe =>
      _isLocataire ? _locataireAccepte : _situation == SituationEdl.finalise;
  bool get _edlFullySigned =>
      _situation == SituationEdl.finalise && _locataireAccepte;
  bool get _bailSignedByMe =>
      _isLocataire ? _bailSignedLocataire : _bailSignedProprio;
  bool get _bailFullySigned => _bailSignedProprio && _bailSignedLocataire;

  /// « Signer bail » (bail location) : disponible une fois l'EDL signé des deux
  /// parties. Réutilise la signature du profil (aperçu + apposition bail_).
  /// Une fois signé des deux côtés → échéances générées (à recevoir / à payer).
  Future<void> _signerBail() async {
    if (widget.existingEdl == null || _edlId == null) return;
    setState(() => _isSigningBail = true);
    try {
      final signed = await runSignerBailFlow(
        context,
        edlId: _edlId!,
        fallback: widget.existingEdl!,
        role: _myRole,
      );
      if (signed == null || !mounted) return;
      if (signed.bailSignedBy(_myRole)) {
        setState(() {
          if (_isLocataire) {
            _bailSignedLocataire = true;
          } else {
            _bailSignedProprio = true;
          }
          _bailSignedAt = signed.bailSignedAt ?? DateTime.now();
        });
        _snack('Bail signé.');
        // Bail signé des deux parties : rejoue la génération des échéances
        // pour afficher immédiatement la cause si elle échoue (au lieu
        // d'attendre une réouverture de la fiche).
        if (!_isLocataire && _bailSignedProprio && _bailSignedLocataire) {
          final r = await EtatDesLieuxDatasource.ensureBailEcheances(_edlId!);
          if (mounted) setState(() => _echeanceDiag = r);
        }
      }
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isSigningBail = false);
    }
  }

  /// Bouton « Document » avec choix EDL / Bail (popover). Le bail n'est proposé
  /// qu'une fois l'EDL signé des deux parties.
  Widget _documentButton() {
    final edl = widget.existingEdl;
    final canBail =
        edl != null && widget.typeEdl == 'entree' && _edlFullySigned;
    return DocumentChoiceButton(
      onEdl: () => openEdlCollectifPdfPreview(context: context, edlId: _edlId!),
      onBail: canBail
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BailPdfPreviewPage(
                  edl: edl,
                  role: _myRole,
                  readOnly: _bailFullySigned,
                ),
              ),
            )
          : null,
      bailLabel: _bailFullySigned ? 'Bail (signé)' : 'Bail',
    );
  }

  /// Bandeau d'état (situation + acceptation) affiché en haut du corps.
  Widget _statusBanner() {
    final accepte = _locataireAccepte;
    final finalise = _situation == SituationEdl.finalise;
    final (color, icon, label) = accepte
        ? (
            AppColors.primary,
            Icons.verified_outlined,
            'Accepté et signé par le locataire',
          )
        : finalise
        ? (
            AppColors.secondary,
            Icons.lock_outline,
            'Finalisé — en attente de la signature du locataire',
          )
        : (AppColors.onSurfaceVariant, Icons.edit_outlined, 'En cours');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
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
            child: Text(
              label,
              style: AppTypography.labelMd.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _headerAction() {
    final isEntree = widget.typeEdl == 'entree';
    // Le collectif d'un bail individuel (lockLocataires) ne se signe pas ici :
    // seuls les EDL individuels (privatifs) sont signés.
    final signable = _saved && !_lockLocataires;
    // 1) « Signer EDL » tant que l'utilisateur courant n'a pas signé l'EDL.
    final showSignEdl = signable && !_edlSignedByMe;
    // 2) « Signer bail » une fois l'EDL signé des DEUX parties (annexe complète)
    //    et si l'utilisateur n'a pas encore signé le bail. EDL d'entrée seul.
    final showSignBail =
        signable && isEntree && _edlFullySigned && !_bailSignedByMe;

    final signPerm = _isLocataire ? Perm.edlAccepter : Perm.edlFinaliser;
    final signEdlAction = _isLocataire ? _accepter : _finaliser;

    Widget spinner() => const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    final actions = <Widget>[
      if (widget.viewSelector != null) widget.viewSelector!,
      if (_saved) _documentButton(),
      if (showSignEdl)
        PermissionGate(
          permission: signPerm,
          child: FilledButton.icon(
            onPressed: _isFinalising ? null : signEdlAction,
            style: AppTheme.saveButtonStyle,
            icon: _isFinalising ? spinner() : const Icon(Icons.draw_outlined),
            label: const Text('Signer EDL'),
          ),
        ),
      if (showSignBail)
        PermissionGate(
          permission: signPerm,
          child: FilledButton.icon(
            onPressed: _isSigningBail ? null : _signerBail,
            style: AppTheme.saveButtonStyle,
            icon: _isSigningBail
                ? spinner()
                : const Icon(Icons.assignment_turned_in_outlined),
            label: const Text('Signer bail'),
          ),
        ),
    ];

    // EDL déjà finalisé ET signé : rien à enregistrer/fermer — juste la
    // flèche retour (comme la vue résumée) + les actions restantes.
    if (_edlFullySigned) {
      return Row(mainAxisSize: MainAxisSize.min, children: actions);
    }

    // Locataire : lecture seule (obs. sauvegardées inline) → pas d'Enregistrer.
    if (_isLocataire) {
      return FormHeaderActions(
        onClose: _handleClose,
        isSaving: _isSaving,
        extraActions: actions,
      );
    }
    return FormHeaderActions(
      onSave: _onSavePressed,
      onClose: _handleClose,
      isSaving: _isSaving,
      extraActions: actions,
    );
  }

  Widget? _headerLeading() => _edlFullySigned
      ? BackButton(onPressed: () => widget.onClose(false))
      : null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormPageHeader(
          title: "EDL — ${widget.immeuble.name}",
          leading: _headerLeading(),
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
                if (_saved) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildDiversSection(),
                ],
                if (_saved && widget.typeEdl == 'entree') ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildBailConfigLoc(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Configuration du bail (obligatoire) : fenêtre d'avenant + caution ───────

  List<String> get _missingBailLoc => [
    if (_avenantWindowSel == null) "Fenêtre d'avenant",
    if (_cautionMode == null) 'Mode de règlement de la caution',
    if (_bailAvecGarant == null) 'Bail avec garant ?',
    // « Avec garant » → chaque preneur AYANT UN COMPTE doit avoir ≥1 garant
    // rattaché (les invités sans compte ne bloquent pas la finalisation).
    if (_bailAvecGarant == true)
      for (final p in _preneurs)
        if (p.locataireId != null && _linkedGarantsOf(p.locataireId!).isEmpty)
          'Garant de ${p.nom ?? p.email ?? 'locataire'}',
  ];

  /// Garants rattachés à l'EDL appartenant à ce preneur.
  List<GarantModel> _linkedGarantsOf(String locataireId) =>
      _linkedGarants.where((g) => g.locataireId == locataireId).toList();

  Future<void> _setAvecGarantLoc(bool v) async {
    if (_edlId == null) return;
    setState(() => _bailAvecGarant = v);
    try {
      await EtatDesLieuxDatasource.setBailAvecGarant(_edlId!, v);
      // « Avec garant » → rattache automatiquement les garants actifs de
      // chaque preneur ; les preneurs sans garant sont prévenus (in-app).
      if (v) await _autoRattacherGarantsLoc();
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  /// Rattache tous les garants actifs de chaque preneur au bail (idempotent).
  /// Si au moins un preneur n'a aucun garant actif, une notification
  /// `bail_garant_requis` est envoyée (une seule fois par ouverture de page —
  /// la RPC commune notifie tous les preneurs du collectif).
  Future<void> _autoRattacherGarantsLoc() async {
    if (_edlId == null) return;
    var manquant = false;
    final aLier = <int>{};
    for (final p in _preneurs) {
      final lid = p.locataireId;
      if (lid == null) continue;
      final actifs = _activeGarantsByLocataire[lid] ?? const <GarantModel>[];
      if (actifs.isEmpty) {
        manquant = true;
        continue;
      }
      final dejaLies = _linkedGarantsOf(lid).map((g) => g.id).toSet();
      aLier.addAll(
        actifs.map((g) => g.id).where((id) => !dejaLies.contains(id)),
      );
    }
    // Un seul upsert groupé (au lieu d'un aller-retour par garant).
    try {
      await EtatDesLieuxDatasource.linkGarants(_edlId!, aLier);
    } catch (_) {}
    await _loadGarantsLoc();
    if (!manquant) {
      // Tous les preneurs ont désormais un garant actif rattaché : la
      // demande est satisfaite, on efface le rappel correspondant.
      await NotificationsDatasource.markReadForEdl(
        _edlId!,
        types: const ['bail_garant_requis'],
      );
    }
    if (manquant && !_garantNotifSent) {
      _garantNotifSent = true;
      try {
        await NotificationsDatasource.notifyEdlLocataire(
          edlId: _edlId!,
          type: 'bail_garant_requis',
          title: 'Garant requis pour votre bail',
          body:
              'Votre bail nécessite un garant. Ajoutez un garant ou '
              'activez-en un existant dans « Documents › Garants ».',
        );
      } catch (_) {}
      if (mounted) {
        _snack(
          'Certains locataires n\'ont pas de garant actif : '
          'ils ont été invités à en ajouter.',
        );
      }
    }
  }

  Future<void> _linkGarantLoc(int garantId) async {
    if (_edlId == null) return;
    try {
      await EtatDesLieuxDatasource.linkGarant(_edlId!, garantId);
      await _loadGarantsLoc();
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _unlinkGarantLoc(int garantId) async {
    if (_edlId == null) return;
    try {
      await EtatDesLieuxDatasource.unlinkGarant(_edlId!, garantId);
      await _loadGarantsLoc();
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _setAvenantLoc(int days) async {
    if (_edlId == null) return;
    setState(() => _avenantWindowSel = days);
    try {
      await EtatDesLieuxDatasource.setEdlAvenantWindow(_edlId!, days);
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _setCautionLoc(CautionMode m, Map<String, dynamic>? d) async {
    if (_edlId == null) return;
    setState(() {
      _cautionMode = m;
      _cautionDetails = d;
    });
    try {
      await EtatDesLieuxDatasource.setCaution(_edlId!, mode: m.raw, details: d);
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Widget _buildBailConfigLoc() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Configuration du bail', style: AppTypography.titleLg),
        const SizedBox(height: AppSpacing.sm),
        _EcheanceDiagBanner(reason: _echeanceDiag),
        _edlAvenantWindowCard(
          context,
          selected: _avenantWindowSel,
          canEdit: !_readOnly,
          onSelect: _setAvenantLoc,
        ),
        const SizedBox(height: AppSpacing.md),
        _edlCautionCard(
          context,
          mode: _cautionMode,
          details: _cautionDetails,
          readOnly: _readOnly,
          onChanged: _setCautionLoc,
        ),
        const SizedBox(height: AppSpacing.md),
        _garantChoiceSectionLoc(),
      ],
    );
  }

  /// Bloc « Bail avec garant ? » du bail location : choix avec/sans au niveau
  /// du contrat + garants rattachés **par preneur** (chaque garant appartient
  /// à un locataire via `Garants.locataire_id`).
  Widget _garantChoiceSectionLoc() {
    final canChoose = !_readOnly;
    // Retirer/ajouter un garant : tant que le bail n'est pas signé des deux
    // côtés (même règle que l'EDL individuel).
    final canManage =
        widget.superAdmin || !(_bailSignedProprio && _bailSignedLocataire);
    // Côté locataire, la RLS ne lui laisse lire que SES garants → n'afficher
    // (et n'évaluer) que son propre bloc — ceux des colocataires paraîtraient
    // vides. Le gate de finalisation (_missingBailLoc) reste côté proprietaire.
    final uid = AuthService.currentUser?.id;
    final preneursAvecCompte = _preneurs
        .where(
          (p) =>
              p.locataireId != null && (!_isLocataire || p.locataireId == uid),
        )
        .toList();
    final garantDone =
        _bailAvecGarant == false ||
        (_bailAvecGarant == true &&
            preneursAvecCompte.isNotEmpty &&
            preneursAvecCompte.every(
              (p) => _linkedGarantsOf(p.locataireId!).isNotEmpty,
            ));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _edlReqHeader(context, 'Bail avec garant ?', garantDone),
            const SizedBox(height: AppSpacing.sm),
            _edlAvecSansGarantChips(
              value: _bailAvecGarant,
              canChoose: canChoose,
              onSelect: _setAvecGarantLoc,
            ),
            if (_bailAvecGarant == true) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Garant(s) par locataire',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Fournis par chaque locataire. Obligatoire pour finaliser : '
                'chaque locataire ayant un compte doit avoir au moins un '
                'garant rattaché.',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (preneursAvecCompte.isEmpty)
                Text(
                  'Aucun locataire avec compte : ajoutez d\'abord les '
                  'locataires du contrat.',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              else
                for (final p in preneursAvecCompte)
                  _garantPreneurBlock(p, canManage: canManage),
            ],
          ],
        ),
      ),
    );
  }

  /// Sous-bloc garant d'UN preneur : garants rattachés (cartes), garants
  /// actifs restants (bouton « Ajouter »), ou bandeau « aucun garant actif ».
  Widget _garantPreneurBlock(EdlPreneur p, {required bool canManage}) {
    final lid = p.locataireId!;
    final linked = _linkedGarantsOf(lid);
    final actifs = _activeGarantsByLocataire[lid] ?? const <GarantModel>[];
    final linkedIds = linked.map((g) => g.id).toSet();
    final unlinked = actifs.where((g) => !linkedIds.contains(g.id)).toList();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  p.nom ?? p.email ?? 'Locataire',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (linked.isNotEmpty)
                Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ..._edlGarantCards(
            linked: linked,
            unlinked: unlinked,
            canManage: canManage,
            onLink: _linkGarantLoc,
            onUnlink: _unlinkGarantLoc,
          ),
          if (linked.isEmpty && actifs.isEmpty)
            _edlGarantRequisBanner(
              _edlGarantRequisMessage(isLocataire: _isLocataire),
            ),
        ],
      ),
    );
  }

  // Section « Divers » : observations libres rattachées à l'EDL collectif.
  Widget _buildDiversSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Divers', style: AppTypography.titleLg),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Observations libres reportées dans l\'état des lieux.',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        EdlDiversSection(
          edlId: _edlId!,
          readOnly:
              !widget.superAdmin &&
              (_isLocataire || _situation == SituationEdl.finalise),
          authorRole: _isLocataire ? 'locataire' : 'proprietaire',
        ),
      ],
    );
  }

  Widget _buildTopRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        if (wide) {
          // Pas d'IntrinsicHeight : la carte DATES contient une Row de blocs
          // avec Expanded, incompatible avec le calcul de dimensions
          // intrinsèques. Alignement en haut à la place.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildBienCard()),
              const SizedBox(width: AppSpacing.md),
              // DATES élargi : dates de l'EDL sur une ligne + date du bail sur
              // une autre.
              Expanded(flex: 2, child: _buildDatesCard()),
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
      },
    );
  }

  Widget _buildBienCard() {
    final imm = widget.immeuble;
    final lieu = [
      imm.address,
      imm.city,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');
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
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MetaChip(
                icon: Icons.square_foot,
                text: imm.totalM2 != null
                    ? '${imm.totalM2!.toStringAsFixed(0)} m²'
                    : '— m²',
              ),
              const SizedBox(width: AppSpacing.sm),
              const _MetaChip(
                icon: Icons.assignment_outlined,
                text: 'Collectif',
              ),
              const SizedBox(width: AppSpacing.sm),
              _MetaChip(
                icon: Icons.chair_outlined,
                text: widget.meublee ? 'Meublée' : 'Non meublée',
              ),
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
          onCreateNew: PermissionsService.instance.can(Perm.locatairesInvite)
              ? _openCreerLocataireDialog
              : null,
        ),
        if (!_saved) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Enregistrez d'abord pour ajouter des locataires.",
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ] else if (_preneurs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${_preneurs.length} locataire${_preneurs.length > 1 ? 's' : ''} ajouté${_preneurs.length > 1 ? 's' : ''} à droite.',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    final tenantsArea = _preneurs.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _saved ? 'Aucun locataire ajouté.' : '',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in _preneurs)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: IntrinsicWidth(
                    child: _TenantCard(
                      preneur: p,
                      readOnly: _isLocataire || _lockLocataires,
                      privatif: _lockLocataires
                          ? _privatifByLocataire[p.locataireId]
                          : null,
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
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            tenantsArea,
          ],
        ),
      );
    }

    return _sectionCard(
      title: 'LOCATAIRES',
      child: LayoutBuilder(
        builder: (context, constraints) {
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
        },
      ),
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
                  Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 18,
                    color: AppColors.onSurfaceVariant,
                  ),
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
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesCard() => _edlDatesCard(
    isEntree: widget.typeEdl == 'entree',
    date: _date,
    dateFinalisation: _dateFinalisation,
    bailSignedAt: _bailSignedAt,
    onPickDate: _readOnly ? null : _pickDate,
  );

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
              Icon(
                Icons.meeting_room_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('État des pièces et chambres', style: AppTypography.titleLg),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _saved
                ? 'Cliquez sur un mur, le sol ou le plafond pour ajouter une observation.'
                : "Enregistrez d'abord pour activer les observations.",
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_pieces.isEmpty && _chambres.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  "Aucune pièce ni chambre enregistrée pour cet immeuble.",
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
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
                    obs: _observations.where((o) => o.pieceId == p.id).toList(),
                    entreeObs: _entreeObservations
                        .where((o) => o.pieceId == p.id)
                        .toList(),
                    onEditWall: (k) => _openWall(k, pieceId: p.id),
                    onAddGeneral: () => _openGeneral(pieceId: p.id),
                    inventorySection: _sectionFor(p.nom),
                    // EDL (collectif) finalisé → lecture seule pour tous, sauf
                    // super admin.
                    readOnly: _structLocked,
                  ),
                for (final c in _chambres)
                  _buildRoomTile(
                    key: ValueKey('chambre-${c.id}'),
                    tileId: 'chambre-${c.id}',
                    icon: Icons.bed_outlined,
                    name: c.roomName,
                    planLabel: 'Plan de la chambre — ${c.roomName}',
                    photo:
                        c.mainPhoto ??
                        (c.roomPhotos.isNotEmpty ? c.roomPhotos.first : null),
                    obs: _observations
                        .where((o) => o.chambreId == c.id)
                        .toList(),
                    entreeObs: _entreeObservations
                        .where((o) => o.chambreId == c.id)
                        .toList(),
                    onEditWall: (k) => _openWall(k, chambreId: c.id),
                    onAddGeneral: () => _openGeneral(chambreId: c.id),
                    inventorySection: _sectionFor(c.roomName),
                    // EDL (collectif ou individuel de cette chambre) finalisé →
                    // lecture seule pour tous, sauf super admin.
                    readOnly:
                        _structLocked || _finalizedChambreIds.contains(c.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static const _wallKeys = [
    'fond',
    'gauche',
    'droit',
    'porte',
    'sol',
    'plafond',
  ];

  Widget _wallProgressBadge(List<ObservationEdl> obs) {
    final done = _wallKeys.where((k) => obs.any((o) => o.wallKey == k)).length;
    final color = done == 6
        ? AppColors.primary
        : (done > 0 ? AppColors.secondary : AppColors.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
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
    List<ObservationEdl> entreeObs = const [],
    required void Function(String wallKey) onEditWall,
    required VoidCallback onAddGeneral,
    EdlSection? inventorySection,
    // Chambre dont l'EDL individuel est finalisé → observations en lecture seule.
    bool readOnly = false,
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
          title: Text(
            name,
            style: AppTypography.titleLg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
                          entreeObservations: entreeObs,
                          readOnly: readOnly,
                          onEditWall: onEditWall,
                        ),
                      ),
                    ),
                  ),
                  if (readOnly) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            "EDL individuel finalisé : les observations de cette "
                            'chambre ne sont plus modifiables ici.',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!readOnly) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _saved ? onAddGeneral : null,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ajouter une observation générale'),
                      ),
                    ),
                  ],
                  if (obs.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ObservationsList(
                      observations: obs,
                      canModify: (o) =>
                          !readOnly && (!_isLocataire || o.isLocataire),
                      onEdit: (o) => o.wallKey != null
                          ? _openWall(
                              o.wallKey!,
                              existing: o,
                              pieceId: o.pieceId,
                              chambreId: o.chambreId,
                            )
                          : _openGeneral(
                              existing: o,
                              pieceId: o.pieceId,
                              chambreId: o.chambreId,
                            ),
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
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Inventaire',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
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
          Text(
            text,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  final EdlPreneur preneur;
  final VoidCallback onDelete;
  final bool readOnly;
  // EDL individuel (privatif) de ce locataire → statut + date de finalisation
  // affichés dans la carte (collectif d'un bail individuel).
  final EtatDesLieuxModel? privatif;

  const _TenantCard({
    required this.preneur,
    required this.onDelete,
    this.readOnly = false,
    this.privatif,
  });

  ({String label, Color color, IconData icon}) get _statut {
    final p = privatif!;
    if (p.situation == SituationEdl.finalise) {
      final d = p.dateFinalisation;
      return (
        label: d != null
            ? 'Finalisé le ${DateFormat('dd/MM/yyyy').format(d)}'
            : 'Finalisé · en attente de signature',
        color: AppColors.secondary,
        icon: Icons.check_circle_outline,
      );
    }
    return (
      label: 'EDL individuel en cours',
      color: AppColors.onSurfaceVariant,
      icon: Icons.schedule_outlined,
    );
  }

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
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                if (privatif != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statut.icon, size: 12, color: _statut.color),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _statut.label,
                          style: AppTypography.labelSm.copyWith(
                            color: _statut.color,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
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

/// Petite carte d'un garant du bail (même gabarit que [_TenantCard] pour le
/// locataire) : pastille + nom + type + suppression. Utilisée dans l'onglet
/// « Bail », sous « avec garant ».
class _GarantCard extends StatelessWidget {
  final GarantModel garant;
  final String name;
  final VoidCallback? onDelete;

  const _GarantCard({required this.garant, required this.name, this.onDelete});

  @override
  Widget build(BuildContext context) {
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
            backgroundColor: AppColors.success.withValues(alpha: 0.14),
            child: Icon(
              Icons.verified_user_outlined,
              size: 15,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  garant.typeGarant == 'morale'
                      ? 'Personne morale'
                      : 'Personne physique',
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
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            CardDeleteButton(onPressed: onDelete!),
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

  /// Forcer la création d'un nouveau collectif (nouvel an scolaire) même si un
  /// collectif ouvert existe déjà pour cet immeuble.
  final bool forceNewCollectif;

  /// Índice da aba a exibir na abertura (padrão 0). Usar `4` para abrir
  /// diretamente na aba Additions (atalho do locataire).
  final int initialTabIndex;

  // Mode super admin : bypass des verrous (édition possible même finalisé).
  final bool superAdmin;
  // Fourni quand cette page est embarquée dans la « Vue détaillée » du
  // visualiser (Vision générale) : rendu dans la MÊME barre d'en-tête que
  // Enregistrer/Fermer/Document (pas de barre séparée).
  final Widget? viewSelector;

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
    this.forceNewCollectif = false,
    this.initialTabIndex = 0,
    this.superAdmin = false,
    this.viewSelector,
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

  // Configuration/résiliation du bail (onglet « Bail »).
  int? _preavisMois;
  DateTime? _bailCongeDate;
  DateTime? _bailFinEffective;
  String? _bailResilieMotif;

  // Signature du BAIL (document distinct de l'EDL). État réactif local.
  bool _bailSignedProprio = false;
  bool _bailSignedLocataire = false;
  DateTime? _bailSignedAt; // date de signature du bail (la plus récente)
  bool _isSigningBail = false;

  // Conditions obligatoires (readiness) : avenant, garant, caution.
  int? _avenantWindowSel; // fenêtre d'avenant choisie (null = non choisie)
  bool? _bailAvecGarant; // avec/sans garant (null = non choisi)
  EcheanceGenResult? _echeanceDiag;
  bool _sortiePrete = false;
  CautionMode? _cautionMode; // mode de règlement de la caution
  Map<String, dynamic>? _cautionDetails;
  List<int> _garantIds = []; // garants rattachés à cet EDL
  List<GarantModel> _activeGarants = []; // garants actifs du locataire
  bool _garantPromptShown = false; // pop-up « insérer le garant » déjà proposé
  String? _profileSignatureUrl; // signature par défaut du profil (aperçu auto)

  List<PieceModel> _pieces = [];
  List<EdlPreneur> _preneurs = [];
  // Locataire de CETTE chambre (= locataire_id du privatif). Sert à n'afficher
  // que SON preneur, pas tous ceux du collectif (qui regroupe toutes les chambres).
  String? _privatifLocataireId;
  List<ObservationEdl> _obsPrivatif = [];
  List<ObservationEdl> _obsCollectif = [];
  // Ajouts (« additions ») faits après finalisation, dans la fenêtre d'1 mois.
  List<ObservationEdl> _additions = [];
  // EDL de sortie : observations de l'entrée couplée (contrepoint, lecture seule).
  List<ObservationEdl> _entreePrivatifObs = [];
  List<ObservationEdl> _entreeCollectifObs = [];

  final _scrollCtrl = ScrollController();
  final Map<String, String> _emailByLocataire = {};

  bool get _saved => _privatifId != null;
  bool get _isLocataire => widget.isLocataire;

  /// Une fois finalisé, l'EDL ne peut plus être modifié (seuls les ajouts via
  /// l'onglet Additions restent possibles, dans la fenêtre).
  bool get _finalise => _situation == SituationEdl.finalise;

  /// Bail résilié (rupture du contrat) : le document est figé, y compris
  /// pour le propriétaire — plus aucune modification, même hors Additions.
  bool get _resilie => _bailCongeDate != null;
  bool get _readOnly =>
      !widget.superAdmin && (_isLocataire || _finalise || _resilie);

  /// Durée (jours) de la fenêtre avenant/additions, fixée à la finalisation
  /// depuis la préférence du propriétaire (Vision générale).
  int get _avenantWindowDays =>
      widget.existingEdl?.avenantWindowDays ?? kDefaultAvenantWindowDays;

  /// Fenêtre d'ajout ouverte : EDL finalisé et avant `date_finalisation +
  /// fenêtre` (date_finalisation fixée à l'acceptation du locataire ; null =
  /// juste finalisé, pas encore accepté → fenêtre ouverte).
  bool get _additionsOpen {
    if (!_finalise) return false;
    // Bail résilié : le contrat est terminé, plus aucun ajout possible.
    if (_resilie) return false;
    // 0 (ou moins) = « Sans avenant » : aucune fenêtre.
    if (_avenantWindowDays <= 0) return false;
    final ref = _dateFinalisation;
    if (ref == null) return true;
    return DateTime.now().isBefore(ref.add(Duration(days: _avenantWindowDays)));
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      // 7 onglets : le garant est fusionné dans l'onglet « Bail » (plus d'onglet
      // « Garant » séparé) — EDL et bail restent deux documents distincts.
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 6),
    );
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
      // Le propriétaire consulte l'onglet Avenants/Additions : la demande
      // « nouvel avenant » est traitée, on efface le rappel correspondant.
      if (_tabCtrl.index == 5 && !_isLocataire && _privatifId != null) {
        NotificationsDatasource.markReadForEdl(
          _privatifId!,
          types: const ['edl_addition'],
        );
      }
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
      _bailSignedProprio = edl.bailSignedBy('proprietaire');
      _bailSignedLocataire = edl.bailSignedBy('locataire');
      _bailSignedAt = edl.bailSignedAt;
      _preavisMois = edl.preavisMois;
      _bailCongeDate = edl.bailCongeDate;
      _bailFinEffective = edl.bailFinEffective;
      _bailResilieMotif = edl.bailResilieMotif;
      _avenantWindowSel = edl.avenantWindowDays;
      _bailAvecGarant = edl.bailAvecGarant;
      _cautionMode = CautionMode.fromRaw(edl.cautionMode);
      _cautionDetails = edl.cautionDetails;
      _loadRooms();
      _loadAll();
      // Rattrapage : si le locataire a signé le bail en dernier, la génération
      // des échéances a été refusée par la RLS de Recettes sous sa session —
      // on la rejoue ici côté proprietaire (idempotent, no-op sinon).
      if (!widget.isLocataire && _bailSignedProprio && _bailSignedLocataire) {
        EtatDesLieuxDatasource.ensureBailEcheances(edl.id).then((r) {
          if (mounted) setState(() => _echeanceDiag = r);
        });
      }
      if (!widget.isLocataire && widget.typeEdl == 'entree') {
        EtatDesLieuxDatasource.sortieReadyForResiliation(edl.id).then((v) {
          if (mounted) setState(() => _sortiePrete = v);
        });
      }
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
    await Future.wait([
      _loadObservations(),
      _loadPreneurs(),
      _loadSections(),
      _loadGarants(),
    ]);
  }

  /// Charge les garants rattachés à l'EDL + les garants actifs du locataire
  /// (pour l'onglet « Garant » : sélection parmi les garants actifs).
  Future<void> _loadGarants() async {
    try {
      // Trois lectures indépendantes → en parallèle (1 RTT au lieu de 3).
      final (ids, active, sig) = await (
        _privatifId != null
            ? EtatDesLieuxDatasource.listGarantIdsForEdl(_privatifId!)
            : Future.value(<int>[]),
        _privatifLocataireId != null
            ? GarantsDatasource.activeByLocataire(_privatifLocataireId!)
            : Future.value(<GarantModel>[]),
        SignaturesDatasource.getSavedUrl(),
      ).wait;
      if (mounted) {
        setState(() {
          _garantIds = ids;
          _activeGarants = active;
          _profileSignatureUrl = sig;
        });
        // Côté locataire : proposer d'insérer son garant dans ce bail.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybePromptInsertGarant();
        });
      }
    } catch (_) {}
  }

  /// Conditions obligatoires manquantes (avenant, garant, caution).
  List<EdlRequirement> get _missingReq => EdlReadiness.missing(
    avenantWindowDays: _avenantWindowSel,
    bailAvecGarant: _bailAvecGarant,
    garantsCount: _garantIds.length,
    cautionMode: _cautionMode?.raw,
  );

  // Badge de l'onglet Bail : depuis la fusion de l'onglet « Garant » dans
  // « Bail », TOUTES les conditions manquantes s'affichent là.
  int get _bailBadge => _missingReq.length;

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
    // Toujours en fin de table : max(ordre) + 1 (et non `length`, qui peut
    // entrer en collision avec un ordre existant après des suppressions).
    final nextOrdre = section.lignes.isEmpty
        ? 0
        : section.lignes.map((l) => l.ordre).reduce((a, b) => a > b ? a : b) +
              1;
    await EdlDetailsDatasource.createLigne(
      EdlLigne(
        sectionId: section.id!,
        equipement: 'Nouvel élément',
        ordre: nextOrdre,
      ),
    );
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
      // EDL de sortie : contrepoint des observations d'entrée.
      final entreePrivatifId = widget.existingEdl?.edlEntreeId;
      if (entreePrivatifId != null) {
        final o = await ObservationsEdlDatasource.listByEdl(entreePrivatifId);
        if (mounted) {
          setState(
            () => _entreePrivatifObs = o.where((x) => !x.isAddition).toList(),
          );
        }
      }
      // Collectif de sortie → son edl_entree_id pointe vers le collectif d'entrée.
      if (_collectifId != null) {
        final sortieColl = await EtatDesLieuxDatasource.findById(_collectifId!);
        final entreeCollectifId = sortieColl?.edlEntreeId;
        if (entreeCollectifId != null) {
          final o = await ObservationsEdlDatasource.listByEdl(
            entreeCollectifId,
          );
          if (mounted) setState(() => _entreeCollectifObs = o);
        }
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
    final picked = await showAppDatePicker(
      context,
      initial: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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
          : widget.forceNewCollectif
          ? (await EtatDesLieuxDatasource.create(
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
            )).id
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

      // 1b) Nouveau contrat (collectif encore vide) : proposer au propriétaire
      // de copier les parties communes du dernier état des lieux de l'immeuble
      // (pièces, inventaire AVEC état + observations/photos). Choix Oui/Non.
      if (!_isLocataire && _privatifId == null && _collectifId != null) {
        await _maybeCopyCommonParts(_collectifId!);
      }

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
          await EtatDesLieuxDatasource.update(edl.id, {
            'edl_collectif_id': _collectifId,
          });
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

  /// Si [collectifId] est un **nouveau** collectif (encore vide) et qu'un état
  /// des lieux antérieur existe pour cet immeuble, propose au propriétaire de
  /// copier ses parties communes (pièces + inventaire AVEC état + observations +
  /// relevés). Choix Oui/Non — « Non » ⇒ aucune copie (auto-seed vierge ensuite).
  Future<void> _maybeCopyCommonParts(int collectifId) async {
    // Ne copie que dans un collectif vierge (sinon parties communes déjà là).
    final existing = await EdlDetailsDatasource.listSections(collectifId);
    if (existing.isNotEmpty) return;
    // Cherche le collectif le plus récent du même immeuble qui a du contenu.
    final all = await EtatDesLieuxDatasource.listAllCollectifs(
      immeubleId: widget.immeuble.id,
      typeEdl: widget.typeEdl,
    );
    EtatDesLieuxModel? source;
    for (final c in all) {
      if (c.id == collectifId) continue;
      final secs = await EdlDetailsDatasource.listSections(c.id);
      if (secs.isNotEmpty) {
        source = c;
        break;
      }
    }
    if (source == null || !mounted) return;
    final copy = await _askCopyCommonParts(source);
    if (copy != true) return;
    await EdlDetailsDatasource.copyStructureWithState(source.id, collectifId);
    await ObservationsEdlDatasource.copyCommonObservations(
      source.id,
      collectifId,
    );
    await EdlDetailsDatasource.copyReleves(source.id, collectifId);
  }

  /// Dialogue Oui/Non : copier les parties communes du dernier EDL.
  Future<bool?> _askCopyCommonParts(EtatDesLieuxModel source) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copier les parties communes ?'),
        content: Text(
          'Un état des lieux existe déjà pour cet immeuble '
          '(${_dateFmt.format(source.dateEtatLieux)}). Voulez-vous copier ses '
          'parties communes (pièces, inventaire et observations) dans ce nouvel '
          'état des lieux ? Vous pourrez ensuite les modifier librement, sans '
          'altérer l\'état des lieux précédent.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non, repartir de zéro'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, copier'),
          ),
        ],
      ),
    );
  }

  /// Importe l'inventaire : pièces communes → sections du collectif ;
  /// meubles de la chambre → section du privatif. Idempotent.
  Future<void> _autoSeed() async {
    try {
      final items = await InventaireDatasource.listByImmeuble(
        widget.immeuble.id,
      );
      EdlLigne ligneFrom(InventaireModel it, int ordre) => EdlLigne(
        sectionId: 0,
        equipement: it.displayNom,
        natureNombre: it.quantite > 0 ? it.quantite.toString() : null,
        ordre: ordre,
      );

      if (_collectifId != null) {
        final existing = await EdlDetailsDatasource.listSections(_collectifId!);
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
        final existing = await EdlDetailsDatasource.listSections(_privatifId!);
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
      discardLabel: noLocataire
          ? 'Annuler la création'
          : 'Quitter sans sauvegarder',
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
      await EdlDetailsDatasource.createPreneur(
        EdlPreneur(
          etatDesLieuxId: _collectifId!,
          locataireId: user.id,
          nom: user.fullName ?? user.email,
          ordre: _preneurs.length,
        ),
      );
      await _loadPreneurs();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _deletePreneur(int id) async {
    try {
      await EdlDetailsDatasource.deletePreneur(id);
      if (_privatifId != null) {
        await EtatDesLieuxDatasource.update(_privatifId!, {
          'locataire_id': null,
        });
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
          builder: (_) => _WallObsDialog(
            wallKey: wallKey,
            existing: existing,
            edlId: edlId,
          ),
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
          builder: (_) => _GeneralObsDialog(existing: existing, edlId: edlId),
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
    // Verrou : conditions obligatoires (avenant, garant, caution) avant de
    // pouvoir signer/finaliser. Ouvre l'onglet concerné si quelque chose manque.
    if (widget.typeEdl == 'entree') {
      final missing = _missingReq;
      if (missing.isNotEmpty) {
        _snack(
          'Champs obligatoires manquants : '
          '${missing.map((r) => r.label).join(', ')}.',
        );
        // Bail + garant sont désormais dans le même onglet « Bail » (index 6).
        _tabCtrl.animateTo(6);
        return;
      }
    }
    final ok = await _saveEdl();
    if (!ok || !mounted || _privatifId == null) return;

    final result = await showDialog<_BailDialogResult>(
      context: context,
      builder: (_) => const _FinaliserBailDialog(),
    );
    if (result == null || !mounted) return;

    // Le propriétaire signe l'EDL avant de finaliser.
    final sig = await showSignatureDialog(context);
    if (sig == null || !mounted) return;

    setState(() => _isFinalising = true);
    try {
      await EtatDesLieuxDatasource.finaliser(
        _privatifId!,
        dateDebutBail: result.dateDebut,
        dateFinBail: result.dateFin,
        dureeBailMois: result.dureeMois,
        chambreId: widget.chambre.id,
        typeEdl: widget.typeEdl,
        proprietaireSignatureUrl: sig.url,
      );
      if (mounted) setState(() => _situation = SituationEdl.finalise);
      _snack('État des lieux finalisé.');
      // Sortie : proposer un décompte de vétusté si dégradations.
      if (widget.typeEdl == 'sortie' && _privatifId != null && mounted) {
        await proposerVetusteSiDegradation(context, _privatifId!);
      }
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isFinalising = false);
    }
  }

  /// Accepter et signer (locataire) sur le privatif.
  Future<void> _accepter() async {
    if (_privatifId == null) return;
    // Le locataire vérifie/crée sa signature, voit le PDF, puis signe.
    final edlModel = widget.existingEdl;
    String? sigUrl;
    if (edlModel != null) {
      sigUrl = await runLocataireSignatureFlow(context, edlModel);
    } else {
      sigUrl = (await showSignatureDialog(context))?.url;
    }
    if (sigUrl == null || !mounted) return;
    setState(() => _isFinalising = true);
    try {
      // Notification au propriétaire centralisée dans locataireAccepter.
      await EtatDesLieuxDatasource.locataireAccepter(
        _privatifId!,
        locataireSignatureUrl: sigUrl,
        locataireNom:
            AuthService.currentUser?.userMetadata?['full_name'] as String?,
        lieuLabel: widget.chambre.roomName,
      );
      if (mounted) setState(() => _locataireAccepte = true);
      _snack('État des lieux accepté.');
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isFinalising = false);
    }
  }

  // ── Signatures : helpers d'état (EDL vs BAIL, deux documents distincts) ─────
  String get _myRole => _isLocataire ? 'locataire' : 'proprietaire';

  /// L'utilisateur courant a-t-il signé l'EDL ? (proprio = finalisé ; locataire
  /// = accepté).
  bool get _edlSignedByMe =>
      _isLocataire ? _locataireAccepte : _situation == SituationEdl.finalise;

  /// L'EDL est-il signé par les DEUX parties ? Condition pour signer le bail.
  bool get _edlFullySigned =>
      _situation == SituationEdl.finalise && _locataireAccepte;

  bool get _bailSignedByMe =>
      _isLocataire ? _bailSignedLocataire : _bailSignedProprio;

  /// « Signer bail » (proprio ou locataire) : n'est disponible qu'une fois l'EDL
  /// signé des deux côtés. Réutilise la signature du profil (aperçu + apposition
  /// dans les colonnes bail_). Une fois signé des deux côtés → échéances générées.
  Future<void> _signerBail() async {
    if (widget.existingEdl == null || _privatifId == null) return;
    // Garant obligatoire (si « avec garant ») avant de signer le bail.
    if (_bailAvecGarant == true && _garantIds.isEmpty) {
      _snack('Rattachez un garant avant de signer le bail.');
      _tabCtrl.animateTo(6);
      return;
    }
    setState(() => _isSigningBail = true);
    try {
      final signed = await runSignerBailFlow(
        context,
        edlId: _privatifId!,
        fallback: widget.existingEdl!,
        role: _myRole,
      );
      if (signed == null || !mounted) return;
      if (signed.bailSignedBy(_myRole)) {
        setState(() {
          if (_isLocataire) {
            _bailSignedLocataire = true;
          } else {
            _bailSignedProprio = true;
          }
          _bailSignedAt = signed.bailSignedAt ?? DateTime.now();
        });
        _snack('Bail signé.');
        if (!_isLocataire && _bailSignedProprio && _bailSignedLocataire) {
          final r = await EtatDesLieuxDatasource.ensureBailEcheances(
            _privatifId!,
          );
          if (mounted) setState(() => _echeanceDiag = r);
        }
      }
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isSigningBail = false);
    }
  }

  /// Bouton « Document » avec choix EDL / Bail (popover). Le bail n'est
  /// proposé qu'une fois l'EDL signé des deux parties (annexe complète).
  Widget _documentButton() {
    final edl = widget.existingEdl;
    final canBail =
        edl != null && widget.typeEdl == 'entree' && _edlFullySigned;
    return DocumentChoiceButton(
      onEdl: () => openEdlIndividuelPdfPreview(
        context: context,
        collectifId: _collectifId!,
        privatifId: _privatifId!,
      ),
      onBail: canBail
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BailPdfPreviewPage(
                  edl: edl,
                  role: _myRole,
                  readOnly: _bailFullySigned,
                ),
              ),
            )
          : null,
      bailLabel: _bailFullySigned ? 'Bail (signé)' : 'Bail',
    );
  }

  bool get _bailFullySigned => _bailSignedProprio && _bailSignedLocataire;

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
          Icon(
            Icons.note_add_outlined,
            size: 20,
            color: AppColors.onTertiaryFixed,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Avenant : ce locataire entre après l\'établissement de l\'état '
              'des lieux collectif. Il sera rattaché au contrat collectif existant.',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onTertiaryFixed,
              ),
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
        ? (
            AppColors.primary,
            Icons.verified_outlined,
            'Accepté et signé par le locataire',
          )
        : finalise
        ? (
            AppColors.secondary,
            Icons.lock_outline,
            'Finalisé — en attente de la signature du locataire',
          )
        : (AppColors.onSurfaceVariant, Icons.edit_outlined, 'En cours');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
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
            child: Text(
              label,
              style: AppTypography.labelMd.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _headerAction() {
    final canDocument = _saved && _collectifId != null && _privatifId != null;
    final isEntree = widget.typeEdl == 'entree';
    // 1) « Signer EDL » : tant que l'utilisateur courant n'a pas signé l'EDL.
    final showSignEdl = _saved && !_edlSignedByMe;
    // 2) « Signer bail » : seulement une fois l'EDL signé des DEUX parties
    //    (l'EDL est l'annexe du bail) et si l'utilisateur n'a pas encore signé
    //    le bail. Uniquement pour un EDL d'entrée.
    final showSignBail =
        _saved && isEntree && _edlFullySigned && !_bailSignedByMe;

    final signPerm = _isLocataire ? Perm.edlAccepter : Perm.edlFinaliser;
    final signEdlAction = _isLocataire ? _accepter : _finaliser;

    Widget spinner() => const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    final actions = <Widget>[
      if (widget.viewSelector != null) widget.viewSelector!,
      if (canDocument) _documentButton(),
      if (showSignEdl)
        PermissionGate(
          permission: signPerm,
          child: FilledButton.icon(
            onPressed: _isFinalising ? null : signEdlAction,
            style: AppTheme.saveButtonStyle,
            icon: _isFinalising ? spinner() : const Icon(Icons.draw_outlined),
            label: const Text('Signer EDL'),
          ),
        ),
      if (showSignBail)
        PermissionGate(
          permission: signPerm,
          child: FilledButton.icon(
            onPressed: _isSigningBail ? null : _signerBail,
            style: AppTheme.saveButtonStyle,
            icon: _isSigningBail
                ? spinner()
                : const Icon(Icons.assignment_turned_in_outlined),
            label: const Text('Signer bail'),
          ),
        ),
    ];

    // EDL déjà finalisé ET signé : rien à enregistrer/fermer — juste la
    // flèche retour (comme la vue résumée) + les actions restantes.
    if (_edlFullySigned) {
      return Row(mainAxisSize: MainAxisSize.min, children: actions);
    }

    // Locataire : lecture seule (obs. sauvegardées inline) → pas d'Enregistrer.
    if (_isLocataire) {
      return FormHeaderActions(
        onClose: _handleClose,
        isSaving: _isSaving,
        extraActions: actions,
      );
    }
    return FormHeaderActions(
      onSave: _onSavePressed,
      onClose: _handleClose,
      isSaving: _isSaving,
      extraActions: actions,
    );
  }

  Widget? _headerLeading() => _edlFullySigned
      ? BackButton(onPressed: () => widget.onClose(false))
      : null;

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormPageHeader(
          title: 'EDL — ${widget.immeuble.name} · ${widget.chambre.roomName}',
          leading: _headerLeading(),
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
                  AppTabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    tabs: [
                      const Tab(text: 'La chambre'),
                      const Tab(text: 'Parties communes'),
                      const Tab(text: 'Relevés'),
                      const Tab(text: 'Clés'),
                      const Tab(text: 'Divers'),
                      const Tab(text: 'Avenants'),
                      _tabWithBadge('Bail', _bailBadge),
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
                    4 => _buildDiversTab(),
                    5 => _buildAdditionsTab(),
                    _ => _buildBailConfigTab(),
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
        Icon(Icons.info_outline, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            "Enregistrez d'abord pour saisir le locataire, l'inventaire et les observations.",
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildTopRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
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
              // LOCATAIRE réduit, DATES élargi pour tenir les dates de l'EDL sur
              // une ligne + la date du bail sur une autre.
              Expanded(flex: 2, child: loc),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 4, child: dates),
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
      },
    );
  }

  Widget _buildBienCard() {
    final imm = widget.immeuble;
    final lieu = [
      imm.address,
      imm.city,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');
    return _sectionCard(
      title: 'BIEN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${imm.name} · ${widget.chambre.roomName}',
            style: AppTypography.titleLg,
          ),
          if (lieu.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              lieu,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
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
                icon: Icons.assignment_outlined,
                text: 'Individuel (Colocation)',
              ),
              _MetaChip(
                icon: Icons.chair_outlined,
                text: widget.meublee ? 'Meublée' : 'Non meublée',
              ),
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
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
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
            onCreateNew: PermissionsService.instance.can(Perm.locatairesInvite)
                ? _openCreerLocataireDialog
                : null,
          ),
          if (!_saved) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              "Le locataire sera enregistré à la sauvegarde.",
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDatesCard() => _edlDatesCard(
    isEntree: widget.typeEdl == 'entree',
    date: _date,
    dateFinalisation: _dateFinalisation,
    bailSignedAt: _bailSignedAt,
    onPickDate: _readOnly ? null : _pickDate,
    extra: [
      // Date limite d'avenant : visible UNIQUEMENT après finalisation, et
      // seulement si une fenêtre est configurée (> 0 jour).
      if (_finalise && _avenantWindowDays > 0) ...[
        const SizedBox(height: AppSpacing.md),
        _edlDateBlock(
          label: "Date limite d'avenant",
          value: _dateFinalisation != null
              ? _dateFmt.format(
                  _dateFinalisation!.add(Duration(days: _avenantWindowDays)),
                )
              : 'Dès la signature',
          icon: Icons.event_busy_outlined,
          muted: _dateFinalisation == null,
        ),
      ],
    ],
  );

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
          photo:
              c.mainPhoto ??
              (c.roomPhotos.isNotEmpty ? c.roomPhotos.first : null),
          obs: _obsPrivatif,
          entreeObs: _entreePrivatifObs,
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
        // Avenant du locataire sur les parties communes (fenêtre de 30 jours).
        if (_isLocataire) _buildCommuneAvenantSection(),
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
              entreeObs: _entreeCollectifObs
                  .where((o) => o.pieceId == p.id)
                  .toList(),
              edlId: _collectifId!,
              pieceId: p.id,
              // Inventaire de la pièce intégré DANS son accordéon.
              inventorySection: _sectionFor(_collectifSections, p.nom),
            ),
      ],
    );
  }

  /// Comodos = pièces communes uniquement (avenant du locataire sur le commun).
  List<({String label, int? pieceId, int? chambreId})> get _communeComodos => [
    for (final p in _pieces) (label: p.nom, pieceId: p.id, chambreId: null),
  ];

  /// Section « Avenant » dans l'onglet Parties communes (côté locataire).
  ///
  /// Après finalisation et **pendant 30 jours** (`_additionsOpen`), le locataire
  /// disposant de la permission `edl.avenant` peut ajouter un avenant à une pièce
  /// commune. C'est enregistré comme une *addition* sur le privatif (pas sur le
  /// collectif), avec notification au propriétaire — il visualise le collectif
  /// mais n'y écrit pas directement.
  Widget _buildCommuneAvenantSection() {
    // Tant que l'EDL n'est pas finalisé, aucun avenant/addition n'est possible →
    // on n'affiche aucun message (la section n'apparaît qu'après finalisation).
    if (!_finalise) return const SizedBox.shrink();
    final avenants = _additions.where((a) => a.pieceId != null).toList();
    final (icon, color, text) = switch (true) {
      _ when _additionsOpen => (
        Icons.edit_calendar_outlined,
        AppColors.primary,
        _dateFinalisation != null
            ? 'Vous pouvez ajouter un avenant aux parties communes jusqu\'au '
                  '${_dateFmt.format(DateTime(_dateFinalisation!.year, _dateFinalisation!.month + 1, _dateFinalisation!.day))}.'
            : 'Vous pouvez ajouter un avenant aux parties communes (fenêtre de 30 jours).',
      ),
      _ => (
        Icons.lock_clock_outlined,
        AppColors.error,
        'La période d\'avenant (30 jours après la finalisation) est terminée.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                child: Text(
                  text,
                  style: AppTypography.bodyMd.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
        if (_additionsOpen)
          PermissionGate(
            permission: Perm.edlAvenant,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: FilledButton.icon(
                  onPressed: () => _addAddition(comodos: _communeComodos),
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: const Text('Ajouter un avenant'),
                ),
              ),
            ),
          ),
        if (avenants.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Avenants — parties communes',
            style: AppTypography.titleLg.copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final a in avenants) _additionCard(a),
        ],
        const SizedBox(height: AppSpacing.md),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildRelevesTab() {
    // Compteurs de l'immeuble (partagés) → collectif ;
    // relevé d'entrée individuel (index à l'entrée de CE locataire) → privatif.
    if (_collectifId == null || _privatifId == null) return _emptyTab('—');
    if (_isLocataire) {
      return _emptyTab('Les relevés sont gérés par le propriétaire.');
    }
    if (_readOnly) {
      return _emptyTab(
        'État des lieux finalisé — les relevés sont verrouillés.',
      );
    }
    // Deux sections en cartes distinctes (même présentation que l'onglet Bail
    // / Clés) : compteurs partagés de l'immeuble + relevé d'entrée individuel.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _relevesCard(
            title: "Compteurs de l'immeuble",
            subtitle:
                'Partagés entre les colocataires (eau, gaz, électricité, chauffage…).',
            child: EdlRelevesSection(edlId: _collectifId!),
          ),
          const SizedBox(height: AppSpacing.md),
          _relevesCard(
            title: "Relevé d'entrée individuel",
            subtitle:
                "Index des compteurs à l'entrée de ce locataire — peut différer "
                "d'un colocataire entré à une autre date.",
            child: EdlRelevesSection(edlId: _privatifId!),
          ),
        ],
      ),
    );
  }

  /// Carte d'une section de relevés (même gabarit que les cartes de l'onglet
  /// Bail) : titre + sous-titre + contenu.
  Widget _relevesCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    ),
  );

  Widget _buildClesTab() {
    // Remise des clés → privatif (la chambre louée).
    if (_privatifId == null) return _emptyTab('—');
    if (_isLocataire) {
      return _emptyTab('La remise des clés est gérée par le propriétaire.');
    }
    if (_readOnly) {
      return _emptyTab(
        'État des lieux finalisé — la remise des clés est verrouillée.',
      );
    }
    return EdlClesSection(edlId: _privatifId!);
  }

  // ── Onglet Divers (observations libres, rattachées au privatif) ─────────────
  Widget _buildDiversTab() {
    if (_privatifId == null) {
      return _emptyTab('Enregistrez d\'abord l\'état des lieux.');
    }
    return EdlDiversSection(
      edlId: _privatifId!,
      readOnly: _readOnly,
      authorRole: _isLocataire ? 'locataire' : 'proprietaire',
    );
  }

  // ── Onglet Additions (ajouts post-finalisation, fenêtre d'1 mois) ───────────

  /// Comodos sélectionnables pour une addition : la chambre + les pièces communes.
  List<({String label, int? pieceId, int? chambreId})> get _comodos => [
    (
      label: widget.chambre.roomName,
      pieceId: null,
      chambreId: widget.chambre.id,
    ),
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
            child: PermissionGate(
              permission: Perm.edlAddition,
              child: FilledButton.icon(
                onPressed: _addAddition,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un avenant'),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (_additions.isEmpty)
          _emptyTab('Aucun avenant pour le moment.')
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
        "Les avenants seront possibles une fois l'état des lieux finalisé "
            '(pendant 1 mois), pour signaler un élément non vérifié.',
      ),
      _ when _additionsOpen => (
        Icons.edit_calendar_outlined,
        AppColors.primary,
        _dateFinalisation != null
            ? 'Vous pouvez ajouter des éléments jusqu\'au '
                  '${_dateFmt.format(DateTime(_dateFinalisation!.year, _dateFinalisation!.month + 1, _dateFinalisation!.day))}.'
            : 'Vous pouvez ajouter des éléments non vérifiés (fenêtre d\'1 mois).',
      ),
      _ => (
        Icons.lock_clock_outlined,
        AppColors.error,
        'La période d\'ajout (1 mois après la finalisation) est terminée.',
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
            child: Text(
              text,
              style: AppTypography.bodyMd.copyWith(color: color),
            ),
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
              Icon(
                Icons.add_location_alt_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _comodoLabel(a),
                  style: AppTypography.titleLg.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      (a.isLocataire ? AppColors.secondary : AppColors.primary)
                          .withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(
                  a.isLocataire ? 'Locataire' : 'Propriétaire',
                  style: AppTypography.labelSm.copyWith(
                    color: a.isLocataire
                        ? AppColors.secondary
                        : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (stamp != null) ...[
            const SizedBox(height: 2),
            Text(
              'Ajouté le $stamp',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
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
                    child: PrivateImage(
                      ref: url,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addAddition({
    List<({String label, int? pieceId, int? chambreId})>? comodos,
  }) async {
    final res =
        await showDialog<
          ({
            String? description,
            List<String> photos,
            int? pieceId,
            int? chambreId,
          })
        >(
          context: context,
          builder: (_) => _AdditionDialog(
            comodos: comodos ?? _comodos,
            edlId: _privatifId!,
          ),
        );
    if (res == null || !mounted) return;
    if ((res.description == null || res.description!.isEmpty) &&
        res.photos.isEmpty) {
      _snack('Ajoutez au moins une observation ou une photo.');
      return;
    }
    try {
      await ObservationsEdlDatasource.insertAddition(
        ObservationEdl(
          etatDesLieuxId: _privatifId!,
          pieceId: res.pieceId,
          chambreId: res.chambreId,
          description: res.description,
          photos: res.photos,
          authorRole: _isLocataire ? 'locataire' : 'proprietaire',
          isAddition: true,
        ),
      );
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
          title: 'Nouvel avenant',
          body:
              '${nom ?? 'Le locataire'} a ajouté un élément ($comodo) à '
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
      if (mounted) _snack('Avenant enregistré.');
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  // ── Onglet Bail (configuration du préavis + résiliation) ────────────────────

  /// Préavis légal par défaut selon la modalité (meublé = 1 mois, vide = 3).
  int get _preavisDefaut => widget.meublee ? 1 : 3;
  int get _preavisEffectif => _preavisMois ?? _preavisDefaut;

  Future<void> _setPreavis(int? mois) async {
    if (_privatifId == null) return;
    setState(() => _preavisMois = mois);
    try {
      await EtatDesLieuxDatasource.setBailPreavis(_privatifId!, mois);
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _rompreBail() async {
    if (_privatifId == null) return;
    final res =
        await showDialog<({DateTime conge, String? motif, bool proRata})>(
          context: context,
          builder: (_) => _RompreBailDialog(preavisMois: _preavisEffectif),
        );
    if (res == null || !mounted) return;
    try {
      final settlement = await EtatDesLieuxDatasource.resilierBail(
        _privatifId!,
        congeDate: res.conge,
        preavisMois: _preavisEffectif,
        motif: res.motif,
        proRata: res.proRata,
      );
      final fin = EtatDesLieuxModel.finPreavis(res.conge, _preavisEffectif);
      setState(() {
        _bailCongeDate = res.conge;
        _bailFinEffective = fin;
        _bailResilieMotif = res.motif;
      });
      final dateLabel = DateFormat('dd/MM/yyyy').format(fin);
      if (settlement.rembourse) {
        _snack(
          'Bail résilié — fin effective le $dateLabel. Caution de '
          '${settlement.cautionMontant?.toStringAsFixed(2)} € remboursée '
          'intégralement (aucun litige).',
        );
      } else if (settlement.blockReason != null) {
        _snack(
          'Bail résilié — fin effective le $dateLabel. '
          '${settlement.blockReason}',
        );
      } else {
        _snack('Bail résilié — fin effective le $dateLabel.');
      }
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _annulerResiliation() async {
    if (_privatifId == null) return;
    try {
      await EtatDesLieuxDatasource.annulerResiliation(_privatifId!);
      setState(() {
        _bailCongeDate = null;
        _bailFinEffective = null;
        _bailResilieMotif = null;
      });
      _snack('Résiliation annulée. Les échéances retirées ont été restaurées.');
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _voirActeResiliation() async {
    if (_privatifId == null) return;
    try {
      final data = await ResiliationPdfData.fromEntree(_privatifId!);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResiliationPdfPreviewPage(data: data),
        ),
      );
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  // ── Champs obligatoires (avenant, garant, caution, signature) ───────────────

  Future<void> _setAvenant(int days) async {
    if (_privatifId == null) return;
    setState(() => _avenantWindowSel = days);
    try {
      await EtatDesLieuxDatasource.setEdlAvenantWindow(_privatifId!, days);
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _setAvecGarant(bool v) async {
    if (_privatifId == null) return;
    setState(() => _bailAvecGarant = v);
    try {
      await EtatDesLieuxDatasource.setBailAvecGarant(_privatifId!, v);
      // « Avec garant » → le garant vient du locataire : on rattache
      // automatiquement ses garants actifs. Si aucun → on le prévient.
      if (v) await _autoRattacherGarants();
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  /// Rattache automatiquement **tous** les garants actifs du locataire au bail
  /// (idempotent). Si le locataire n'a aucun garant actif, il est prévenu
  /// (notification in-app) qu'il doit en ajouter/activer un.
  Future<void> _autoRattacherGarants() async {
    if (_privatifId == null) return;
    if (_activeGarants.isEmpty) {
      try {
        await NotificationsDatasource.notifyEdlLocataire(
          edlId: _privatifId!,
          type: 'bail_garant_requis',
          title: 'Garant requis pour votre bail',
          body:
              'Votre bail nécessite un garant. Ajoutez un garant ou '
              'activez-en un existant dans « Documents › Garants ».',
        );
      } catch (_) {}
      if (mounted) {
        _snack('Aucun garant actif : le locataire a été invité à en ajouter.');
      }
      return;
    }
    final toLink = _activeGarants
        .where((g) => !_garantIds.contains(g.id))
        .toList();
    // Un seul upsert groupé (au lieu d'un aller-retour par garant).
    try {
      await EtatDesLieuxDatasource.linkGarants(
        _privatifId!,
        toLink.map((g) => g.id),
      );
    } catch (_) {}
    if (mounted && toLink.isNotEmpty) {
      setState(() => _garantIds = [..._garantIds, ...toLink.map((g) => g.id)]);
    }
  }

  /// Côté locataire : propose (une fois) d'insérer ses garants actifs dans ce
  /// bail, avec un récapitulatif des données de l'EDL, quand le bail est
  /// « avec garant » mais qu'aucun garant n'est encore rattaché.
  Future<void> _maybePromptInsertGarant() async {
    if (_garantPromptShown) return;
    if (!_isLocataire || _bailAvecGarant != true) return;
    if (_garantIds.isNotEmpty || _activeGarants.isEmpty) return;
    _garantPromptShown = true;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmInsertGarantDialog(
        garants: _activeGarants,
        bienLabel: '${widget.immeuble.name} · ${widget.chambre.roomName}',
        dateLabel: _dateFmt.format(_date),
      ),
    );
    if (ok == true) await _autoRattacherGarants();
  }

  Future<void> _setCautionMode(CautionMode m, Map<String, dynamic>? d) async {
    if (_privatifId == null) return;
    setState(() {
      _cautionMode = m;
      _cautionDetails = d;
    });
    try {
      await EtatDesLieuxDatasource.setCaution(
        _privatifId!,
        mode: m.raw,
        details: d,
      );
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  /// Crée / modifie la signature **par défaut du profil** (reprise
  /// automatiquement à la signature de l'EDL et du bail). N'appose PAS de
  /// signature sur le bail : l'apposition se fait via « Signer bail ».
  Future<void> _editSignature() async {
    final res = await showSignatureDialog(
      context,
      existingUrl: _profileSignatureUrl,
    );
    if (res == null || !mounted) return;
    try {
      // On enregistre comme signature par défaut du profil.
      await SignaturesDatasource.saveUrl(res.url);
      setState(() => _profileSignatureUrl = res.url);
      _snack('Signature enregistrée.');
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  /// En-tête d'un champ obligatoire : titre + astérisque rouge + pastille
  /// « Obligatoire » (ou coche verte si [done]).
  Widget _avenantSection() => _edlAvenantWindowCard(
    context,
    selected: _avenantWindowSel,
    canEdit: !_readOnly,
    onSelect: _setAvenant,
  );

  /// Bloc UNIQUE « Bail avec garant ? » + garant(s) : le choix avec/sans et la
  /// liste des garants (petites cartes) vivent dans la même carte. Le garant est
  /// fourni par le locataire (auto-rattaché). **Obligatoire** : si aucun garant
  /// n'est rattaché en mode « avec garant », le bail ne peut pas être signé.
  Widget _garantChoiceSection() {
    // Le choix avec/sans reste au propriétaire (et verrouillé après
    // finalisation/résiliation).
    final canChoose = !_readOnly;
    // Retirer/ajouter un garant : les DEUX parties, tant que le bail n'est pas
    // signé des deux côtés (retirer rend le champ obligatoire à nouveau) — et
    // plus du tout une fois le bail résilié.
    final canManageGarant =
        widget.superAdmin || (!_bailFullySigned && !_resilie);
    final linked = _activeGarants
        .where((g) => _garantIds.contains(g.id))
        .toList();
    final unlinked = _activeGarants
        .where((g) => !_garantIds.contains(g.id))
        .toList();
    final garantDone =
        _bailAvecGarant == false ||
        (_bailAvecGarant == true && _garantIds.isNotEmpty);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _edlReqHeader(context, 'Bail avec garant ?', garantDone),
            const SizedBox(height: AppSpacing.sm),
            _edlAvecSansGarantChips(
              value: _bailAvecGarant,
              canChoose: canChoose,
              onSelect: _setAvecGarant,
            ),
            // Garant(s) — dans le MÊME bloc, sous le choix « avec garant ».
            if (_bailAvecGarant == true) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Garant(s) du bail',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Fourni par le locataire. Obligatoire pour signer le bail.',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_activeGarants.isEmpty)
                _garantRequisBanner()
              else ...[
                ..._edlGarantCards(
                  linked: linked,
                  unlinked: unlinked,
                  canManage: canManageGarant,
                  onLink: _linkGarant,
                  onUnlink: _unlinkGarant,
                ),
                if (linked.isEmpty && unlinked.isEmpty) _garantRequisBanner(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Bandeau d'alerte « garant requis » (aucun garant actif du locataire).
  Widget _garantRequisBanner() => _edlGarantRequisBanner(
    _edlGarantRequisMessage(isLocataire: _isLocataire),
  );

  Widget _signatureSection() {
    final hasSig =
        _profileSignatureUrl != null && _profileSignatureUrl!.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ma signature',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (hasSig) ...[
              // Signature du profil reprise automatiquement (aperçu).
              Container(
                width: 320,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.outlineVariant),
                  borderRadius: AppRadius.borderMd,
                ),
                child: PrivateImage(
                  ref: _profileSignatureUrl!,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  style: AppTheme.editButtonStyle,
                  onPressed: _editSignature,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Cette signature sera utilisée automatiquement pour signer '
                "l'état des lieux et le bail.",
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ] else ...[
              Text(
                'Aucune signature enregistrée. Créez-en une : elle sera reprise '
                'automatiquement au moment de signer.',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  style: AppTheme.saveButtonStyle,
                  onPressed: _editSignature,
                  icon: const Icon(Icons.draw_outlined, size: 18),
                  label: const Text('Créer ma signature'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBailConfigTab() {
    if (widget.typeEdl != 'entree') {
      return _emptyTab(
        "La configuration du bail concerne l'état des lieux d'entrée.",
      );
    }
    if (_privatifId == null) {
      return _emptyTab('Enregistrez d\'abord l\'état des lieux.');
    }
    final df = DateFormat('dd/MM/yyyy');
    final resilie = _bailCongeDate != null;
    final canEditPreavis = !_isLocataire && !resilie;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EcheanceDiagBanner(reason: _echeanceDiag),
        // Conditions obligatoires (avenant, garant, caution, signature).
        _avenantSection(),
        const SizedBox(height: AppSpacing.md),
        // Bloc unique : choix « avec garant » + garant(s) (petites cartes).
        _garantChoiceSection(),
        const SizedBox(height: AppSpacing.md),
        _edlCautionCard(
          context,
          mode: _cautionMode,
          details: _cautionDetails,
          readOnly: _readOnly,
          onChanged: _setCautionMode,
        ),
        const SizedBox(height: AppSpacing.md),
        _signatureSection(),
        const SizedBox(height: AppSpacing.md),
        // Modalité + préavis configurable.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modalité & préavis',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.meublee
                      ? 'Bail meublé — préavis légal par défaut : 1 mois.'
                      : 'Location vide — préavis légal par défaut : 3 mois.',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Expanded(child: Text('Préavis (mois)')),
                    if (canEditPreavis)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _preavisEffectif <= 1
                            ? null
                            : () => _setPreavis(_preavisEffectif - 1),
                      ),
                    Text(
                      '$_preavisEffectif',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (canEditPreavis)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _setPreavis(_preavisEffectif + 1),
                      ),
                    if (canEditPreavis && _preavisMois != null)
                      TextButton(
                        onPressed: () => _setPreavis(null),
                        child: const Text('Défaut'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Résiliation.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Résiliation du bail',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (resilie) ...[
                  Text('Congé notifié le ${df.format(_bailCongeDate!)}.'),
                  if (_bailFinEffective != null)
                    Text(
                      'Fin effective : ${df.format(_bailFinEffective!)} '
                      '(préavis $_preavisEffectif mois).',
                    ),
                  if (_bailResilieMotif != null &&
                      _bailResilieMotif!.isNotEmpty)
                    Text('Motif : ${_bailResilieMotif!}'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Le locataire doit le loyer jusqu\'à la fin effective ; '
                    'les échéances au-delà ont été retirées.',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (!_isLocataire) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _annulerResiliation,
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Annuler la résiliation'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DocumentPdfButton(
                          label: "Acte de résiliation",
                          onPressed: _voirActeResiliation,
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  Text(
                    _isLocataire
                        ? 'Aucune résiliation en cours.'
                        : 'Enregistrez le congé du locataire pour rompre le '
                              'bail. La fin effective est calculée selon le '
                              'préavis, et les loyers au-delà sont retirés.',
                  ),
                  if (!_isLocataire) ...[
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        style: AppTheme.deleteButtonStyle,
                        // Le gate porte sur la signature du BAIL (document
                        // distinct de l'EDL) ET sur l'existence d'un état des
                        // lieux de sortie finalisé + accepté par le locataire
                        // — on ne rompt pas un bail sans départ constaté.
                        onPressed: (_bailSignedLocataire && _sortiePrete)
                            ? _rompreBail
                            : null,
                        icon: const Icon(Icons.event_busy, size: 18),
                        label: const Text('Rompre le bail'),
                      ),
                    ),
                    if (!_bailSignedLocataire)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'Disponible une fois le bail signé par le locataire.',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      )
                    else if (!_sortiePrete)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          "Requiert un état des lieux de sortie finalisé et "
                          "signé par le locataire (onglet « Sortie »).",
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Onglet Garant (sélection des garants actifs du locataire) ───────────────

  Future<void> _linkGarant(int id) async {
    if (_privatifId == null) return;
    setState(() => _garantIds = [..._garantIds, id]);
    try {
      await EtatDesLieuxDatasource.linkGarant(_privatifId!, id);
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _unlinkGarant(int id) async {
    if (_privatifId == null) return;
    setState(() => _garantIds = _garantIds.where((x) => x != id).toList());
    try {
      await EtatDesLieuxDatasource.unlinkGarant(_privatifId!, id);
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  /// Onglet avec pastille rouge du nombre de champs obligatoires manquants.
  Widget _tabWithBadge(String label, int count) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: AppColors.onError,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _emptyTab(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Center(
      child: Text(
        t,
        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
      ),
    ),
  );

  static const _wallKeys = [
    'fond',
    'gauche',
    'droit',
    'porte',
    'sol',
    'plafond',
  ];

  Widget _obsBadge(List<ObservationEdl> obs) {
    final done = _wallKeys.where((k) => obs.any((o) => o.wallKey == k)).length;
    final color = done == 6
        ? AppColors.primary
        : (done > 0 ? AppColors.secondary : AppColors.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
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

  /// Bloc accordéon (comme le collectif) : en-tête cliquable + plan de murs
  /// (6 zones) + observations dans le corps dépliable.
  Widget _buildRoomBlock({
    required String tileId,
    required String name,
    required String planLabel,
    String? photo,
    required List<ObservationEdl> obs,
    List<ObservationEdl> entreeObs = const [],
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
          title: Text(
            name,
            style: AppTypography.titleLg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
                      entreeObservations: entreeObs,
                      readOnly: _readOnly,
                      onEditWall: (k) => _openWall(
                        k,
                        edlId: edlId,
                        pieceId: pieceId,
                        chambreId: chambreId,
                      ),
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
                          chambreId: chambreId,
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ajouter une observation générale'),
                      ),
                    ),
                  ],
                  if (obs.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ObservationsList(
                      observations: obs,
                      // Une fois finalisé/résilié, plus rien n'est
                      // modifiable/supprimable (sauf super admin).
                      canModify: (o) =>
                          widget.superAdmin ||
                          (!_finalise &&
                              !_resilie &&
                              (!_isLocataire || o.isLocataire)),
                      onEdit: (o) => o.wallKey != null
                          ? _openWall(
                              o.wallKey!,
                              existing: o,
                              edlId: edlId,
                              pieceId: o.pieceId,
                              chambreId: o.chambreId,
                            )
                          : _openGeneral(
                              existing: o,
                              edlId: edlId,
                              pieceId: o.pieceId,
                              chambreId: o.chambreId,
                            ),
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
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Inventaire',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
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
// Pop-up (côté locataire) : confirmer l'insertion de son/ses garant(s) dans le
// bail en cours, avec un récapitulatif des données de l'EDL.

class _ConfirmInsertGarantDialog extends StatelessWidget {
  final List<GarantModel> garants;
  final String bienLabel;
  final String dateLabel;

  const _ConfirmInsertGarantDialog({
    required this.garants,
    required this.bienLabel,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insérer votre garant au bail ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ce bail requiert un garant. Voulez-vous y insérer '
            '${garants.length > 1 ? 'vos garants actifs' : 'votre garant actif'} '
            'ci-dessous ?',
            style: AppTypography.bodyMd,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final g in garants)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(g.displayName, style: AppTypography.bodyMd),
                  ),
                ],
              ),
            ),
          const Divider(height: AppSpacing.lg),
          Text(
            'Bien : $bienLabel',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            "Date de l'état des lieux : $dateLabel",
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          style: AppTheme.cancelButtonStyle,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          style: AppTheme.saveButtonStyle,
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Insérer ce garant'),
        ),
      ],
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
    final picked = await showAppDatePicker(
      context,
      initial: _dateDebut,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() {
        _dateDebut = picked;
        _dateFin = _calcDateFin(picked, _dureeMois);
      });
    }
  }

  Future<void> _pickDateFin() async {
    final picked = await showAppDatePicker(
      context,
      initial: _dateFin,
      firstDate: _dateDebut,
      lastDate: DateTime(2060),
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: AppColors.primary,
          ),
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
        // Pas de minWidth : sur un écran étroit (< 420px), un plancher fixe
        // forcerait le contenu à dépasser l'espace disponible (overflow).
        constraints: const BoxConstraints(maxWidth: 480),
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
                    .map(
                      (d) => ChoiceChip(
                        label: Text('$d mois'),
                        selected: d == _dureeMois,
                        onSelected: (_) => _onDureeChanged(d),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              _label('DATE DE FIN DU BAIL'),
              _dateField(_dateFin, _pickDateFin),
              const SizedBox(height: 4),
              Text(
                'Calculée automatiquement, modifiable si besoin.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
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

/// Dialogue « Rompre le bail » : date du congé (défaut = aujourd'hui) + motif
/// optionnel, avec aperçu de la fin effective (congé + préavis).
class _RompreBailDialog extends StatefulWidget {
  final int preavisMois;
  const _RompreBailDialog({required this.preavisMois});

  @override
  State<_RompreBailDialog> createState() => _RompreBailDialogState();
}

class _RompreBailDialogState extends State<_RompreBailDialog> {
  DateTime _conge = DateTime.now();
  final _motifCtrl = TextEditingController();
  bool _proRata = false;

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    final fin = EtatDesLieuxModel.finPreavis(_conge, widget.preavisMois);
    return AlertDialog(
      title: const Text('Rompre le bail'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Date du congé')),
              TextButton.icon(
                icon: const Icon(Icons.event, size: 18),
                label: Text(df.format(_conge)),
                onPressed: () async {
                  final picked = await showAppDatePicker(
                    context,
                    initial: _conge,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _conge = picked);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _motifCtrl,
            decoration: const InputDecoration(
              labelText: 'Motif (optionnel)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Fin effective : ${df.format(fin)} '
            '(préavis ${widget.preavisMois} mois).',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Mois de la fin effective', style: AppTypography.labelMd),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Mois complet')),
              ButtonSegment(value: true, label: Text('Prorata (jours)')),
            ],
            selected: {_proRata},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _proRata = s.first),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _proRata
                ? 'Le locataire ne paie que les jours occupés du mois de départ.'
                : 'Le locataire paie le mois de départ en entier.',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: AppTheme.deleteButtonStyle,
          onPressed: () => Navigator.of(context).pop((
            conge: _conge,
            motif: _motifCtrl.text.trim().isEmpty
                ? null
                : _motifCtrl.text.trim(),
            proRata: _proRata,
          )),
          child: const Text('Rompre le bail'),
        ),
      ],
    );
  }
}

/// Sélecteur du mode de règlement de la caution + champs de détails selon le
/// mode (chèque → banque/numéro/titulaire ; virement → IBAN ; Wero/PayPal →
/// référence ; espèces → aucun). Émet (mode, détails) via [onChanged].
class _CautionEditor extends StatefulWidget {
  final CautionMode? initialMode;
  final Map<String, dynamic>? initialDetails;
  final bool readOnly;
  final void Function(CautionMode mode, Map<String, dynamic>? details)
  onChanged;

  const _CautionEditor({
    required this.initialMode,
    required this.initialDetails,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  State<_CautionEditor> createState() => _CautionEditorState();
}

class _CautionEditorState extends State<_CautionEditor> {
  CautionMode? _mode;
  late Map<String, dynamic> _details;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _details = Map<String, dynamic>.of(widget.initialDetails ?? const {});
  }

  void _emit() {
    if (_mode != null) {
      widget.onChanged(_mode!, _details.isEmpty ? null : _details);
    }
  }

  Widget _field(String key, String label) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: TextFormField(
      initialValue: _details[key] as String?,
      readOnly: widget.readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) => _details[key] = v,
      onEditingComplete: _emit,
      onTapOutside: (_) => _emit(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in CautionMode.values)
              ChoiceChip(
                label: Text(m.label),
                selected: _mode == m,
                onSelected: widget.readOnly
                    ? null
                    : (_) {
                        setState(() => _mode = m);
                        _emit();
                      },
              ),
          ],
        ),
        if (_mode == CautionMode.cheque) ...[
          _field('banque', 'Banque'),
          _field('numero', 'Numéro du chèque'),
          _field('titulaire', 'Titulaire du compte'),
        ] else if (_mode == CautionMode.virement) ...[
          _field('iban', 'IBAN (optionnel)'),
        ] else if (_mode == CautionMode.weroPaypal) ...[
          _field('reference', 'Référence / e-mail (optionnel)'),
        ],
      ],
    );
  }
}
