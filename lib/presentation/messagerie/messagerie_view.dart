import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:habitafrance/data/cache/realtime_refresh_mixin.dart';
import 'package:habitafrance/data/datasources/demandes_contact.dart';
import 'package:habitafrance/data/datasources/messages.dart';
import 'package:habitafrance/data/models/demande_contact.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:habitafrance/data/permissions/permissions_service.dart';
import 'package:habitafrance/presentation/chambres/chambre_detail_page.dart';
import 'package:habitafrance/presentation/messagerie/messagerie_model.dart';
import 'package:habitafrance/presentation/messagerie/messagerie_row.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/presentation/widgets/conversation_view.dart';
import 'package:habitafrance/presentation/widgets/permission_gate.dart';
import 'package:habitafrance/presentation/widgets/user_profile_card.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// **Écran de messagerie partagé** — une seule implémentation pour le
/// propriétaire (« Messages ») et le locataire (« Mes discussions »).
///
/// Ce qui dépend du rôle est concentré dans [MessagerieRoleConfig] (source des
/// données, libellés, filtres, droit de gérer une demande) ; la mise en page,
/// la recherche, la fiche de profil et le fil sont communs. Ajouter un
/// comportement ici le donne aux deux profils — c'est voulu.
///
/// Disposition :
/// - **large** : liste à gauche + fiche de profil à droite ; le fil vient
///   prendre la place de la liste ;
/// - **étroit** : un seul volet à la fois (liste → fiche → fil).
///
/// La **barre de titre reste toujours affichée** ; la barre d'outils
/// (recherche + filtres) n'apparaît qu'à la racine, jamais pendant une
/// conversation — on ne cherche pas dans une liste qu'on ne voit pas.
class MessagerieView extends StatefulWidget {
  final MessagerieRole role;

  /// Titre de la barre supérieure (« Messages », « Mes discussions »…).
  final String title;

  /// Ouvre directement ce fil au premier chargement (ex. clic sur
  /// « Discuter avec le propriétaire » depuis une annonce).
  final int? initialDemandeId;

  /// Consommé une fois le fil ouvert, pour que revenir à la liste ne le
  /// rouvre pas en boucle.
  final VoidCallback? onInitialDemandeConsumed;

  /// Ouvre l'annonce d'une chambre. Par défaut : pousse la fiche publique.
  /// Les écrans qui affichent leurs fiches dans le cadre passent la leur.
  final void Function(int chambreId)? onVoirAnnonce;

  const MessagerieView({
    super.key,
    required this.role,
    required this.title,
    this.initialDemandeId,
    this.onInitialDemandeConsumed,
    this.onVoirAnnonce,
  });

  @override
  State<MessagerieView> createState() => _MessagerieViewState();
}

class _MessagerieViewState extends State<MessagerieView>
    with RealtimeRefreshMixin {
  late final MessagerieRoleConfig _config = MessagerieRoleConfig(widget.role);

  bool _loading = true;
  String? _error;
  List<DemandeContactModel> _demandes = [];
  Map<int, int> _unread = const {};
  Map<int, String> _searchText = const {};

  /// Fiches des interlocuteurs, **filtrées par le serveur** (RPC
  /// `demande_counterpart_profiles`). L'écran ne voit donc jamais un champ que
  /// son propriétaire a masqué — il n'a même pas transité par le réseau.
  Map<int, ProfileCardData> _profils = const {};

  final _searchCtrl = TextEditingController();
  String _query = '';
  MessagerieStatutFilter? _statutFilter;

  /// Demande sélectionnée (fiche de profil).
  int? _selectedId;

  /// Le fil prend la place de la liste.
  bool _chatOpen = false;

  @override
  Set<String> get watchedEntities => {'demandes', 'messages'};

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MessagerieView old) {
    super.didUpdateWidget(old);
    // Un nouveau fil demandé depuis l'extérieur (annonce → discussion).
    final wanted = widget.initialDemandeId;
    if (wanted != null && wanted != old.initialDemandeId) {
      _openDemandeById(wanted);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted && _demandes.isEmpty) setState(() => _loading = true);
    try {
      final data = _config.isProprietaire
          ? await DemandesContactDatasource.listByOwner(refresh: true)
          : await DemandesContactDatasource.listByLocataire(refresh: true);
      final ids = data.map((d) => d.id).toList();
      final results = await Future.wait([
        MessagesDatasource.unreadCountByDemande(refresh: true),
        MessagesDatasource.searchableTextByDemande(ids, refresh: true),
        DemandesContactDatasource.counterpartProfiles(ids, refresh: true),
      ]);
      if (!mounted) return;
      setState(() {
        _demandes = data;
        _unread = results[0] as Map<int, int>;
        _searchText = results[1] as Map<int, String>;
        _profils = results[2] as Map<int, ProfileCardData>;
        _loading = false;
        _error = null;
        if (_selectedId != null && !data.any((d) => d.id == _selectedId)) {
          _selectedId = null;
          _chatOpen = false;
        }
      });
      final wanted = widget.initialDemandeId;
      if (wanted != null && !_chatOpen) _openDemandeById(wanted);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  DemandeContactModel? get _selected =>
      _demandes.where((d) => d.id == _selectedId).firstOrNull;

  List<DemandeContactModel> get _filtered => filterDemandes(
        demandes: _demandes,
        profils: _profils,
        query: _query,
        searchText: _searchText,
        statutFilter: _statutFilter,
      );

  void _select(DemandeContactModel d) {
    setState(() {
      _selectedId = d.id;
      _chatOpen = false;
    });
  }

  /// Ouvre le fil. Côté propriétaire, `nouveau` → `non_repondu` (vu).
  Future<void> _openChat(DemandeContactModel d) async {
    setState(() {
      _selectedId = d.id;
      _chatOpen = true;
    });
    if (_config.canManageStatut && d.statut == StatutDemande.nouveau) {
      try {
        await DemandesContactDatasource.markVu(d.id);
        await _load();
      } catch (_) {/* best-effort */}
    }
  }

  /// Ouvre un fil désigné par son id (demande venue d'un autre écran).
  void _openDemandeById(int id) {
    final d = _demandes.where((x) => x.id == id).firstOrNull;
    if (d == null) return; // pas encore chargé : `_load` réessaiera.
    _openChat(d);
    widget.onInitialDemandeConsumed?.call();
  }

  void _closeChat() {
    setState(() => _chatOpen = false);
    _load();
  }

  Future<void> _markRepondu(DemandeContactModel d) async {
    if (!_config.canManageStatut) return;
    try {
      await DemandesContactDatasource.markRepondu(d.id);
      await _load();
    } catch (_) {/* best-effort */}
  }

  Future<void> _ignorer(DemandeContactModel d) async {
    try {
      await DemandesContactDatasource.ignorer(d.id);
      if (mounted) setState(() => _chatOpen = false);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  void _email(String mail) => launchUrl(Uri(scheme: 'mailto', path: mail));

  void _voirAnnonce(DemandeContactModel d) {
    final id = d.chambreId;
    if (id == null) return;
    final handler = widget.onVoirAnnonce;
    if (handler != null) {
      handler(id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChambreDetailPage(chambreId: id)),
    );
  }

  // ── Rendu ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // La barre de titre ne disparaît jamais — même en pleine conversation,
        // l'utilisateur doit savoir où il est.
        AppTopBar(title: widget.title),
        // Barre d'outils réservée à la racine de la messagerie.
        if (!_chatOpen && _demandes.isNotEmpty) _toolbar(),
        if (!_chatOpen && _demandes.isNotEmpty) const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _toolbar() {
    final counts = countByFilter(_demandes, _config.filters);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: _config.searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Effacer',
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FilterChips(
            filters: _config.filters,
            selected: _statutFilter,
            total: _demandes.length,
            counts: counts,
            colorOf: (f) => _chipColor(f),
            onSelect: (f) => setState(() => _statutFilter = f),
          ),
        ],
      ),
    );
  }

  Color _chipColor(MessagerieStatutFilter f) {
    if (f.statuts.contains(StatutDemande.repondu)) return AppColors.success;
    if (f.statuts.contains(StatutDemande.nouveau) && f.statuts.length == 1) {
      return AppColors.primary;
    }
    if (f.statuts.contains(StatutDemande.nonRepondu) && f.statuts.length == 1) {
      return AppColors.secondary;
    }
    return AppColors.onSurfaceVariant;
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur : $_error',
                  textAlign: TextAlign.center,
                  style:
                      AppTypography.bodyMd.copyWith(color: AppColors.error)),
              const SizedBox(height: AppSpacing.md),
              AppButton.primary(
                icon: Icons.refresh,
                label: 'Réessayer',
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }
    if (_demandes.isEmpty) {
      return _empty(_config.emptyTitle, hint: _config.emptyHint);
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 820;
        final sel = _selected;

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SwitcherSlide(
                  fromLeft: true,
                  child: _chatOpen && sel != null
                      ? _chat(sel, narrow: false, key: const ValueKey('chat'))
                      : _list(key: const ValueKey('list')),
                ),
              ),
              if (sel != null) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 360,
                  child: _SwitcherSlide(
                    fromLeft: false,
                    child: _detail(sel, key: ValueKey('detail-${sel.id}')),
                  ),
                ),
              ],
            ],
          );
        }

        // Étroit : un seul volet à la fois.
        if (_chatOpen && sel != null) {
          return _SwitcherSlide(
            fromLeft: true,
            child: _chat(sel, narrow: true, key: const ValueKey('chat')),
          );
        }
        if (sel != null) {
          return _SwitcherSlide(
            fromLeft: false,
            child: _detail(sel,
                key: ValueKey('detail-${sel.id}'), showBack: true),
          );
        }
        return _list(key: const ValueKey('list'));
      },
    );
  }

  Widget _empty(String msg, {String? hint}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined,
                  size: 56, color: AppColors.onSurfaceVariant),
              const SizedBox(height: AppSpacing.md),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
              if (hint != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(hint,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      );

  Widget _list({Key? key}) {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return _empty(_query.isNotEmpty
          ? 'Aucun résultat pour « $_query ».'
          : 'Aucune discussion pour ce filtre.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        key: key,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final d = filtered[i];
          return MessagerieRow(
            demande: d,
            profil: _profils[d.id],
            config: _config,
            selected: d.id == _selectedId,
            unread: _unread[d.id] ?? 0,
            snippet: (_searchText[d.id] ?? '').trim(),
            onTap: () => _select(d),
            onDiscuter: () => _openChat(d),
          );
        },
      ),
    );
  }

  Widget _detail(DemandeContactModel d, {Key? key, bool showBack = false}) {
    // Le bien n'est pas connu de la RPC (elle ne parle que des personnes) : on
    // l'ajoute ici comme sous-titre de la fiche.
    final profil = (_profils[d.id] ?? ProfileCardData(fullName: null))
        .withSubtitle(d.bienLabel);
    final mail = profil.email;
    return UserProfileCard(
      key: key,
      data: profil,
      badge: ProfilePill(
        label: _config.statutLabel(d),
        color: statutColor(_config, d),
      ),
      onBack: showBack ? () => setState(() => _selectedId = null) : null,
      // Fermer la fiche : elle est un volet, pas une page — on doit pouvoir
      // la refermer et revenir à la seule liste.
      onClose: () => setState(() => _selectedId = null),
      links: [
        if (d.chambreId != null)
          ProfileCardLink(
            icon: Icons.open_in_new,
            label: 'Voir l\'annonce',
            onTap: () => _voirAnnonce(d),
          ),
      ],
      actions: [
        AppButton.cancel(
          size: AppButtonSize.compact,
          fullWidth: true,
          icon: Icons.mail_outline,
          label: 'E-mail',
          onPressed:
              (mail == null || mail.isEmpty) ? null : () => _email(mail),
        ),
        AppButton.primary(
          size: AppButtonSize.compact,
          fullWidth: true,
          icon: Icons.chat_bubble_outline,
          label: 'Discuter',
          onPressed: () => _openChat(d),
        ),
      ],
    );
  }

  Widget _chat(DemandeContactModel d, {required bool narrow, Key? key}) {
    return ConversationView(
      key: key,
      demande: d,
      interlocuteur: _profils[d.id],
      onClose: _closeChat,
      onSent: () => _markRepondu(d),
      headerActions: [
        // En étroit, la fiche de profil n'est pas visible à côté : on y accède
        // depuis l'en-tête du fil.
        if (narrow)
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'Voir le profil',
            onPressed: () => setState(() => _chatOpen = false),
          ),
        // Ignorer une demande est réservé au propriétaire (droit
        // `demandes.manage` : les sous-comptes d'entreprise sans ce droit ne
        // voient pas l'action).
        if (_config.canManageStatut && d.statut != StatutDemande.ignore)
          PermissionGate(
            permission: Perm.demandesManage,
            child: IconButton(
              icon: const Icon(Icons.block_outlined),
              tooltip: 'Ignorer cette demande',
              onPressed: () => _ignorer(d),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transition partagée : glissé + fondu (depuis la gauche ou la droite).

class _SwitcherSlide extends StatelessWidget {
  final Widget child;
  final bool fromLeft;
  const _SwitcherSlide({required this.child, required this.fromLeft});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        final begin = Offset(fromLeft ? -0.12 : 0.12, 0);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: begin, end: Offset.zero).animate(anim),
            child: child,
          ),
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Onglets-filtres (chips avec compteurs), défilables horizontalement.
class _FilterChips extends StatelessWidget {
  final List<MessagerieStatutFilter> filters;
  final MessagerieStatutFilter? selected;
  final int total;
  final Map<String, int> counts;
  final Color Function(MessagerieStatutFilter) colorOf;
  final ValueChanged<MessagerieStatutFilter?> onSelect;

  const _FilterChips({
    required this.filters,
    required this.selected,
    required this.total,
    required this.counts,
    required this.colorOf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('Tous', total, selected == null, () => onSelect(null),
              AppColors.primary),
          for (final f in filters) ...[
            const SizedBox(width: AppSpacing.xs),
            _chip(f.label, counts[f.label] ?? 0, selected == f,
                () => onSelect(selected == f ? null : f), colorOf(f)),
          ],
        ],
      ),
    );
  }

  Widget _chip(
      String label, int count, bool on, VoidCallback onTap, Color color) {
    return InkWell(
      borderRadius: AppRadius.borderFull,
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: on ? color : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: on ? color : AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTypography.labelSm.copyWith(
                  color: on ? AppColors.onPrimary : AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: on
                    ? AppColors.onPrimary.withValues(alpha: 0.2)
                    : AppColors.surfaceContainerHigh,
                borderRadius: AppRadius.borderFull,
              ),
              child: Text('$count',
                  style: AppTypography.labelSm.copyWith(
                    color: on ? AppColors.onPrimary : AppColors.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
