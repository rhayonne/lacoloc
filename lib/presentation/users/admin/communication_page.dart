import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/communication.dart';
import 'package:lacoloc_front/data/datasources/user_management.dart';
import 'package:lacoloc_front/data/models/admin_message.dart';
import 'package:lacoloc_front/data/models/user_group.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/media_embed.dart';

/// Cible de diffusion d'un message du super admin.
enum _Audience { tous, type, groupe, specifiques }

extension _AudienceLabel on _Audience {
  String get label => switch (this) {
        _Audience.tous => 'Tous les utilisateurs',
        _Audience.type => "Par type d'utilisateur",
        _Audience.groupe => 'Par groupe / entreprise',
        _Audience.specifiques => 'Utilisateurs spécifiques',
      };

  IconData get icon => switch (this) {
        _Audience.tous => Icons.groups_outlined,
        _Audience.type => Icons.badge_outlined,
        _Audience.groupe => Icons.business_outlined,
        _Audience.specifiques => Icons.person_search_outlined,
      };
}

enum _MediaKind { aucun, image, youtube }

const _typeLabels = {
  'locataire': 'Locataires',
  'proprietaire': 'Propriétaires',
  'admin_groupe': 'Admins de groupe',
  'super_admin': 'Super admins',
};

/// Section « Communication » du super admin : composer un message (markdown +
/// média) et le diffuser à une audience ; consulter l'historique des envois.
class CommunicationPage extends StatefulWidget {
  const CommunicationPage({super.key});

  @override
  State<CommunicationPage> createState() => _CommunicationPageState();
}

class _CommunicationPageState extends State<CommunicationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _mediaCtrl = TextEditingController();

  late Future<void> _loadFuture;
  List<UsersClient> _users = [];
  List<UserGroup> _groups = [];

  _Audience _audience = _Audience.tous;
  final Set<String> _selectedTypes = {};
  int? _selectedGroupId;
  final Set<String> _selectedUserIds = {};
  String _search = '';

  _MediaKind _mediaKind = _MediaKind.aucun;
  bool _showPreview = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadFuture = _load();
    _titleCtrl.addListener(_onChanged);
    _mediaCtrl.addListener(_onChanged);
    _searchCtrl.addListener(
        () => setState(() => _search = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _tab.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _searchCtrl.dispose();
    _mediaCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _load() async {
    final users = await UserManagementDatasource.listAll();
    List<UserGroup> groups = [];
    try {
      groups = await UserManagementDatasource.listGroups();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _users = users;
      _groups = groups;
    });
  }

  // ── Audience ────────────────────────────────────────────────────────────────

  List<UsersClient> get _recipients {
    final selfId = AuthService.currentUser?.id;
    final base = _users.where((u) => u.active && u.id != selfId);
    return switch (_audience) {
      _Audience.tous => base.toList(),
      _Audience.type =>
        base.where((u) => _selectedTypes.contains(u.typeUserRef?.code)).toList(),
      _Audience.groupe => _selectedGroupId == null
          ? const []
          : base.where((u) => u.groupId == _selectedGroupId).toList(),
      _Audience.specifiques =>
        base.where((u) => _selectedUserIds.contains(u.id)).toList(),
    };
  }

  String get _audienceLabel {
    switch (_audience) {
      case _Audience.tous:
        return 'Tous les utilisateurs';
      case _Audience.type:
        final names =
            _selectedTypes.map((c) => _typeLabels[c] ?? c).join(', ');
        return 'Types : $names';
      case _Audience.groupe:
        final g = _groups.where((x) => x.id == _selectedGroupId).firstOrNull;
        return 'Groupe : ${g?.name ?? '—'}';
      case _Audience.specifiques:
        return 'Utilisateurs spécifiques (${_selectedUserIds.length})';
    }
  }

  // ── Média ───────────────────────────────────────────────────────────────────

  /// Valeur de média validée (URL image ou id YouTube), ou null si invalide.
  String? get _mediaValue {
    final raw = _mediaCtrl.text.trim();
    if (_mediaKind == _MediaKind.aucun || raw.isEmpty) return null;
    if (_mediaKind == _MediaKind.image) return isHttpUrl(raw) ? raw : null;
    return parseYoutubeId(raw); // youtube → id canonique
  }

  bool get _mediaOk => _mediaKind == _MediaKind.aucun || _mediaValue != null;

  String? get _mediaTypeStr => switch (_mediaKind) {
        _MediaKind.image => kMediaImage,
        _MediaKind.youtube => kMediaYoutube,
        _MediaKind.aucun => null,
      };

  bool get _canSend =>
      _titleCtrl.text.trim().isNotEmpty &&
      _recipients.isNotEmpty &&
      _mediaOk &&
      !_sending;

  Future<void> _send() async {
    final recipients = _recipients;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Envoyer le message ?'),
        content: Text(
          'Ce message sera envoyé à ${recipients.length} '
          'utilisateur${recipients.length > 1 ? 's' : ''} '
          '(${_audience.label.toLowerCase()}).',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: AppTheme.saveButtonStyle,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    try {
      await CommunicationDatasource.sendMessage(
        recipientIds: recipients.map((u) => u.id).toList(),
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
        mediaType: _mediaTypeStr,
        mediaUrl: _mediaValue,
        audienceLabel: _audienceLabel,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _titleCtrl.clear();
        _bodyCtrl.clear();
        _mediaCtrl.clear();
        _mediaKind = _MediaKind.aucun;
        _selectedUserIds.clear();
        _showPreview = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message envoyé à ${recipients.length} '
              'utilisateur${recipients.length > 1 ? 's' : ''}.'),
          backgroundColor: AppColors.success,
        ),
      );
      _tab.animateTo(1); // basculer vers l'historique
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Communication', style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Envoyez un message (texte Markdown + média) qui apparaîtra dans le '
            'tableau de bord et les messages des utilisateurs choisis.',
            style:
                AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Nouveau message'),
              Tab(text: 'Historique'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<void>(
              future: _loadFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return TabBarView(
                  controller: _tab,
                  children: [_composeTab(), _historyTab()],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _composeTab() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardBox(title: '1 · Destinataires', child: _audienceSelector()),
              const SizedBox(height: AppSpacing.lg),
              _cardBox(title: '2 · Message', child: _composer()),
              const SizedBox(height: AppSpacing.lg),
              _sendBar(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardBox({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleLg),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  // ── Destinataires ──────────────────────────────────────────────────────────

  Widget _audienceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _Audience.values.map((a) {
            final sel = _audience == a;
            return ChoiceChip(
              avatar: Icon(a.icon,
                  size: 18,
                  color: sel ? AppColors.onPrimary : AppColors.onSurfaceVariant),
              label: Text(a.label),
              selected: sel,
              onSelected: (_) => setState(() => _audience = a),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        _audienceDetail(),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(Icons.people_alt_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text('${_recipients.length} destinataire(s)',
                style: AppTypography.labelMd.copyWith(color: AppColors.primary)),
          ],
        ),
      ],
    );
  }

  Widget _audienceDetail() {
    switch (_audience) {
      case _Audience.tous:
        return Text('Le message sera envoyé à tous les utilisateurs actifs.',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant));
      case _Audience.type:
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: _typeLabels.entries.map((e) {
            final sel = _selectedTypes.contains(e.key);
            return FilterChip(
              label: Text(e.value),
              selected: sel,
              onSelected: (v) => setState(() {
                if (v) {
                  _selectedTypes.add(e.key);
                } else {
                  _selectedTypes.remove(e.key);
                }
              }),
            );
          }).toList(),
        );
      case _Audience.groupe:
        if (_groups.isEmpty) {
          return Text('Aucun groupe disponible.',
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant));
        }
        return DropdownButtonFormField<int>(
          initialValue: _selectedGroupId,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Groupe', border: OutlineInputBorder()),
          items: _groups
              .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))
              .toList(),
          onChanged: (v) => setState(() => _selectedGroupId = v),
        );
      case _Audience.specifiques:
        return _userPicker();
    }
  }

  Widget _userPicker() {
    final selfId = AuthService.currentUser?.id;
    final filtered = _users
        .where((u) => u.active && u.id != selfId)
        .where((u) => _search.isEmpty
            ? true
            : '${u.fullName ?? ''} ${u.email}'.toLowerCase().contains(_search))
        .take(50)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Rechercher par nom ou email…',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('Aucun utilisateur.',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    return CheckboxListTile(
                      dense: true,
                      value: _selectedUserIds.contains(u.id),
                      title: Text(u.fullName?.isNotEmpty == true
                          ? u.fullName!
                          : u.email),
                      subtitle: Text(
                        '${u.email} · ${_typeLabels[u.typeUserRef?.code] ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selectedUserIds.add(u.id);
                        } else {
                          _selectedUserIds.remove(u.id);
                        }
                      }),
                    );
                  },
                ),
        ),
        if (_selectedUserIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text('${_selectedUserIds.length} sélectionné(s)',
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ),
      ],
    );
  }

  // ── Composer (markdown + média) ──────────────────────────────────────────────

  Widget _composer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
              labelText: 'Titre *', border: OutlineInputBorder()),
          maxLength: 120,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _bodyCtrl,
          decoration: const InputDecoration(
            labelText: 'Message (Markdown)',
            helperText: 'Markdown supporté : **gras**, *italique*, listes, [liens](url)…',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          minLines: 4,
          maxLines: 12,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Média
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<_MediaKind>(
                initialValue: _mediaKind,
                decoration: const InputDecoration(
                    labelText: 'Média', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: _MediaKind.aucun, child: Text('Aucun')),
                  DropdownMenuItem(value: _MediaKind.image, child: Text('Image (URL)')),
                  DropdownMenuItem(
                      value: _MediaKind.youtube, child: Text('Vidéo YouTube')),
                ],
                onChanged: (v) =>
                    setState(() => _mediaKind = v ?? _MediaKind.aucun),
              ),
            ),
          ],
        ),
        if (_mediaKind != _MediaKind.aucun) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _mediaCtrl,
            decoration: InputDecoration(
              labelText: _mediaKind == _MediaKind.image
                  ? "URL de l'image (https://…)"
                  : 'Lien ou ID YouTube',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _mediaCtrl.text.trim().isNotEmpty && !_mediaOk
                  ? (_mediaKind == _MediaKind.image
                      ? 'URL http(s) invalide'
                      : 'Lien/ID YouTube invalide')
                  : null,
              suffixIcon: _mediaValue != null
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : null,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        // Aperçu
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _showPreview = !_showPreview),
              icon: Icon(_showPreview
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              label: Text(_showPreview ? "Masquer l'aperçu" : 'Aperçu'),
            ),
          ],
        ),
        if (_showPreview) _preview(),
      ],
    );
  }

  Widget _preview() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_titleCtrl.text.trim().isNotEmpty)
            Text(_titleCtrl.text.trim(), style: AppTypography.titleLg),
          if (_bodyCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            MarkdownBody(data: _bodyCtrl.text.trim(), selectable: true),
          ],
          if (_mediaValue != null) ...[
            const SizedBox(height: AppSpacing.sm),
            MessageMediaView(mediaType: _mediaTypeStr, mediaUrl: _mediaValue),
          ],
        ],
      ),
    );
  }

  Widget _sendBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilledButton.icon(
          style: AppTheme.saveButtonStyle,
          onPressed: _canSend ? _send : null,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_outlined, size: 18),
          label: const Text('Envoyer le message'),
        ),
      ],
    );
  }

  // ── Historique ──────────────────────────────────────────────────────────────

  Widget _historyTab() {
    return FutureBuilder<List<AdminMessage>>(
      future: CommunicationDatasource.listSentMessages(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erreur : ${snap.error}'));
        }
        final msgs = snap.data ?? [];
        if (msgs.isEmpty) {
          return Center(
            child: Text('Aucun message envoyé.',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
          );
        }
        final fmt = DateFormat('dd/MM/yyyy HH:mm');
        return ListView.separated(
          itemCount: msgs.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) {
            final m = msgs[i];
            return Container(
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
                      Expanded(
                          child:
                              Text(m.title, style: AppTypography.titleLg)),
                      if (m.mediaType != null)
                        Icon(
                          m.mediaType == kMediaYoutube
                              ? Icons.smart_display_outlined
                              : Icons.image_outlined,
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                    ],
                  ),
                  if (m.body != null && m.body!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    MarkdownBody(data: m.body!.trim()),
                  ],
                  if (m.mediaType != null && m.mediaUrl != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    MessageMediaView(
                        mediaType: m.mediaType, mediaUrl: m.mediaUrl, height: 180),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _meta(Icons.group_outlined, m.audience ?? '—'),
                      _meta(Icons.send_outlined,
                          '${m.recipientsCount} destinataire(s)'),
                      _meta(Icons.schedule, fmt.format(m.createdAt)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text,
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}
