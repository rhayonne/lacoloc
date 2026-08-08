import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:habitafrance/utils/media_embed.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:habitafrance/data/cache/realtime_refresh_mixin.dart';
import 'package:habitafrance/data/datasources/demandes_contact.dart';
import 'package:habitafrance/data/datasources/messages.dart';
import 'package:habitafrance/data/permissions/permissions_service.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/presentation/widgets/conversation_view.dart';
import 'package:habitafrance/presentation/widgets/permission_gate.dart';
import 'package:habitafrance/data/models/demande_contact.dart';
import 'package:habitafrance/data/models/notification_model.dart';
import 'package:habitafrance/presentation/chambres/chambre_detail_page.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Page « Messages » du propriétaire — les prises de contact des locataires,
/// façon messagerie : **liste** à gauche + **fiche détail** à droite ; le
/// **fil de discussion** vient prendre la place de la liste (glissé depuis la
/// gauche) quand on clique « Discuter ». Plus d'acceptation préalable : dès
/// qu'un locataire écrit, le fil est ouvert. Les notifications vivent dans la
/// Vue générale, pas ici. Rafraîchissement **automatique** (Realtime).
class InteractionsPage extends StatelessWidget {
  const InteractionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTopBar(title: 'Messages'),
        Expanded(child: _MessagesTab()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MessagesTab extends StatefulWidget {
  const _MessagesTab();

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> with RealtimeRefreshMixin {
  bool _loading = true;
  String? _error;
  List<DemandeContactModel> _demandes = [];
  Map<int, int> _unread = const {};
  Map<int, String> _searchText = const {};

  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Filtre de statut actif (null = tous).
  StatutDemande? _statutFilter;

  /// Demande sélectionnée (fiche détail à droite).
  int? _selectedId;

  /// Le fil de discussion prend la place de la liste.
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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted && _demandes.isEmpty) setState(() => _loading = true);
    try {
      final data = await DemandesContactDatasource.listByOwner(refresh: true);
      final ids = data.map((d) => d.id).toList();
      final results = await Future.wait([
        MessagesDatasource.unreadCountByDemande(refresh: true),
        MessagesDatasource.searchableTextByDemande(ids, refresh: true),
      ]);
      if (!mounted) return;
      setState(() {
        _demandes = data;
        _unread = results[0] as Map<int, int>;
        _searchText = results[1] as Map<int, String>;
        _loading = false;
        _error = null;
        // Garder une sélection valide.
        if (_selectedId != null &&
            !_demandes.any((d) => d.id == _selectedId)) {
          _selectedId = null;
          _chatOpen = false;
        }
      });
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

  /// Filtre : recherche (nom OU contenu du fil, borné par la RLS) + statut.
  List<DemandeContactModel> get _filtered {
    return _demandes.where((d) {
      if (_statutFilter != null && d.statut != _statutFilter) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final nom = (d.locataireFullName ?? '').toLowerCase();
      final texte = (_searchText[d.id] ?? '').toLowerCase();
      return nom.contains(q) || texte.contains(q);
    }).toList();
  }

  Map<StatutDemande, int> get _counts {
    final m = {for (final s in StatutDemande.values) s: 0};
    for (final d in _demandes) {
      m[d.statut] = (m[d.statut] ?? 0) + 1;
    }
    return m;
  }

  void _select(DemandeContactModel d) {
    setState(() {
      _selectedId = d.id;
      _chatOpen = false;
    });
  }

  /// Ouvre le fil : `nouveau` → `non_repondu` (vu, pas encore répondu).
  Future<void> _openChat(DemandeContactModel d) async {
    setState(() {
      _selectedId = d.id;
      _chatOpen = true;
    });
    if (d.statut == StatutDemande.nouveau) {
      try {
        await DemandesContactDatasource.markVu(d.id);
        await _load();
      } catch (_) {/* best-effort */}
    }
  }

  void _closeChat() {
    setState(() => _chatOpen = false);
    _load();
  }

  Future<void> _markRepondu(DemandeContactModel d) async {
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

  void _email(DemandeContactModel d) {
    final mail = d.locataireEmail;
    if (mail == null || mail.isEmpty) return;
    launchUrl(Uri(scheme: 'mailto', path: mail));
  }

  void _voirAnnonce(DemandeContactModel d) {
    if (d.chambreId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChambreDetailPage(chambreId: d.chambreId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Barre d'outils : recherche + filtres de statut (pas de refresh) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Rechercher un locataire ou dans les messages…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border:
                      OutlineInputBorder(borderRadius: AppRadius.borderMd),
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
                selected: _statutFilter,
                total: _demandes.length,
                counts: _counts,
                onSelect: (s) => setState(() => _statutFilter = s),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Erreur : $_error',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(color: AppColors.error)),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_demandes.isEmpty) {
      return _empty('Aucun message pour le moment.');
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 820;
        final sel = _selected;

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Zone gauche : liste ↔ fil (glisse depuis la gauche).
              Expanded(
                child: _SwitcherSlide(
                  fromLeft: true,
                  child: _chatOpen && sel != null
                      ? _chat(sel, key: const ValueKey('chat'))
                      : _list(key: const ValueKey('list')),
                ),
              ),
              if (sel != null) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 360,
                  // Fiche détail : glisse depuis la droite à chaque sélection.
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
              fromLeft: true, child: _chat(sel, key: const ValueKey('chat')));
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

  Widget _empty(String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 56, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(msg,
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );

  Widget _list({Key? key}) {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return _empty(_query.isNotEmpty
          ? 'Aucun résultat pour « $_query ».'
          : 'Aucun message pour ce filtre.');
    }
    return ListView.separated(
      key: key,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final d = filtered[i];
        return _MessageRow(
          demande: d,
          selected: d.id == _selectedId,
          unread: _unread[d.id] ?? 0,
          snippet: (_searchText[d.id] ?? '').trim(),
          onTap: () => _select(d),
          onDiscuter: () => _openChat(d),
        );
      },
    );
  }

  Widget _detail(DemandeContactModel d, {Key? key, bool showBack = false}) {
    return _DetailPanel(
      key: key,
      demande: d,
      showBack: showBack,
      onBack: () => setState(() => _selectedId = null),
      onEmail: () => _email(d),
      onDiscuter: () => _openChat(d),
      onVoirAnnonce: () => _voirAnnonce(d),
    );
  }

  Widget _chat(DemandeContactModel d, {Key? key}) {
    return ConversationView(
      key: key,
      demande: d,
      onClose: _closeChat,
      onSent: () => _markRepondu(d),
      headerActions: [
        // Gérer une demande (ignorer) est réservé à `demandes.manage` — les
        // sous-comptes d'entreprise sans ce droit ne voient pas l'action.
        if (d.statut != StatutDemande.ignore)
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
// Filtres de statut (chips avec compteurs)

class _FilterChips extends StatelessWidget {
  final StatutDemande? selected;
  final int total;
  final Map<StatutDemande, int> counts;
  final ValueChanged<StatutDemande?> onSelect;

  const _FilterChips({
    required this.selected,
    required this.total,
    required this.counts,
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
          for (final s in StatutDemande.values) ...[
            const SizedBox(width: AppSpacing.xs),
            _chip(s.label, counts[s] ?? 0, selected == s,
                () => onSelect(selected == s ? null : s), _statutColor(s)),
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

/// Couleur sémantique d'un statut (dérivée du thème).
Color _statutColor(StatutDemande s) => switch (s) {
      StatutDemande.nouveau => AppColors.primary,
      StatutDemande.nonRepondu => AppColors.secondary,
      StatutDemande.repondu => AppColors.success,
      StatutDemande.ignore => AppColors.onSurfaceVariant,
    };

class _StatutBadge extends StatelessWidget {
  final StatutDemande statut;
  const _StatutBadge(this.statut);

  @override
  Widget build(BuildContext context) {
    final color = _statutColor(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(statut.label,
              style: AppTypography.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar à initiales (couleur déterministe du thème)

Color _avatarColor(String key) {
  final colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.tertiary,
    AppColors.error,
  ];
  return colors[key.hashCode.abs() % colors.length];
}

String _initiales(String? nom) {
  final parts = (nom ?? '').trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

class _Avatar extends StatelessWidget {
  final String? nom;
  final double size;
  const _Avatar({required this.nom, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(nom ?? '?');
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        _initiales(nom),
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne de la liste (modèle Page.html .rowline)

class _MessageRow extends StatelessWidget {
  final DemandeContactModel demande;
  final bool selected;
  final int unread;
  final String snippet;
  final VoidCallback onTap;
  final VoidCallback onDiscuter;

  const _MessageRow({
    required this.demande,
    required this.selected,
    required this.unread,
    required this.snippet,
    required this.onTap,
    required this.onDiscuter,
  });

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final bien = [d.chambreName, d.immeubleName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' — ');
    final date = DateFormat('dd/MM/yyyy').format(d.createdAt);

    return Material(
      color: selected
          ? AppColors.primaryFixed.withValues(alpha: 0.35)
          : AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.borderLg,
      child: InkWell(
        borderRadius: AppRadius.borderLg,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderLg,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _Avatar(nom: d.locataireFullName, size: 44),
                  if (unread > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.surfaceContainerLowest,
                              width: 2),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text('$unread',
                            textAlign: TextAlign.center,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onError,
                              fontSize: 10,
                              height: 1,
                            )),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            d.locataireFullName ?? '—',
                            style: AppTypography.titleLs,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (d.calculatedAge != null) ...[
                          const SizedBox(width: 6),
                          Text('· ${d.calculatedAge} ans',
                              style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant)),
                        ],
                      ],
                    ),
                    if (bien.isNotEmpty)
                      Text(bien,
                          style: AppTypography.labelSm
                              .copyWith(color: AppColors.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('« $snippet »',
                          style: AppTypography.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(date,
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  _StatutBadge(d.statut),
                  const SizedBox(height: 4),
                  // Accès direct au fil (comme une messagerie : un clic = le
                  // fil), en plus de la sélection qui ouvre la fiche détail.
                  TextButton.icon(
                    onPressed: onDiscuter,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.forum_outlined, size: 16),
                    label: const Text('Discuter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fiche détail (modèle Page.html .detail)

class _DetailPanel extends StatelessWidget {
  final DemandeContactModel demande;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onEmail;
  final VoidCallback onDiscuter;
  final VoidCallback onVoirAnnonce;

  const _DetailPanel({
    super.key,
    required this.demande,
    required this.showBack,
    required this.onBack,
    required this.onEmail,
    required this.onDiscuter,
    required this.onVoirAnnonce,
  });

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final bien = [d.chambreName, d.immeubleName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' — ');
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(d.createdAt);

    return Container(
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Héro
          Container(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.25),
              border: Border(
                  bottom: BorderSide(color: AppColors.outlineVariant)),
            ),
            child: Column(
              children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Retour',
                      onPressed: onBack,
                    ),
                  ),
                _Avatar(nom: d.locataireFullName, size: 64),
                const SizedBox(height: AppSpacing.sm),
                Text(d.locataireFullName ?? '—',
                    style: AppTypography.titleLg,
                    textAlign: TextAlign.center),
                if (bien.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(bien,
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.primary),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: AppSpacing.sm),
                _StatutBadge(d.statut),
              ],
            ),
          ),
          // Corps
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _field(Icons.cake_outlined, 'Âge',
                    d.calculatedAge != null ? '${d.calculatedAge} ans' : '—'),
                _field(Icons.phone_outlined, 'Téléphone',
                    d.locatairePhone ?? '—'),
                _field(Icons.mail_outline, 'E-mail', d.locataireEmail ?? '—'),
                _field(Icons.event_outlined, 'Reçu le', dateStr),
                if (d.chambreId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Voir l\'annonce'),
                        onPressed: onVoirAnnonce,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Pied : E-mail + Discuter
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border:
                  Border(top: BorderSide(color: AppColors.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton.cancel(
                    size: AppButtonSize.compact,
                    fullWidth: true,
                    icon: Icons.mail_outline,
                    label: 'E-mail',
                    onPressed: (d.locataireEmail ?? '').isEmpty ? null : onEmail,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton.primary(
                    size: AppButtonSize.compact,
                    fullWidth: true,
                    icon: Icons.forum_outlined,
                    label: 'Discuter',
                    onPressed: onDiscuter,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 1),
                  Text(value, style: AppTypography.bodyMd),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

/// Bouton d'accès au fil de discussion (avec pastille de non-lus). Partagé avec
/// l'écran locataire (« Mes discussions »). La messagerie étant toujours
/// ouverte, il est toujours actif.
class DiscussionButton extends StatelessWidget {
  final DemandeContactModel demande;
  final int unread;
  final VoidCallback onPressed;

  const DiscussionButton({
    super.key,
    required this.demande,
    required this.unread,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const icone = Icon(Icons.forum_outlined, size: 18);
    return Tooltip(
      message: 'Ouvrir la discussion',
      child: TextButton.icon(
        onPressed: onPressed,
        icon: unread > 0
            ? Badge(label: Text('$unread'), child: icone)
            : icone,
        label: const Text('Discuter'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Carte de notification réutilisable (Interactions + Vue générale).
class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const NotificationCard({super.key, required this.notification, this.onTap});

  IconData get _icon => switch (notification.type) {
        'edl_accepte' => Icons.verified_outlined,
        'admin_message' => Icons.campaign_outlined,
        'nouvelle_demande' => Icons.person_add_alt_outlined,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(
      notification.createdAt.toLocal(),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: unread
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.borderMd,
          border: Border.all(
            color: unread
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: AppTypography.titleLg.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      )),
                  if (notification.body != null &&
                      notification.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    // Rendu Markdown (sans HTML brut → pas d'injection XSS).
                    MarkdownBody(
                      data: notification.body!,
                      onTapLink: (text, href, title) {
                        if (href != null) {
                          launchUrl(Uri.parse(href),
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                  if (notification.mediaType != null &&
                      notification.mediaUrl != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    MessageMediaView(
                      mediaType: notification.mediaType,
                      mediaUrl: notification.mediaUrl,
                      height: 200,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(dateStr,
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4, left: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
