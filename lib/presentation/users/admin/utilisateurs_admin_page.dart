import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/user_management.dart';
import 'package:lacoloc_front/data/models/permission.dart';
import 'package:lacoloc_front/data/models/user_group.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/presentation/widgets/app_list_search_field.dart';
import 'package:lacoloc_front/utils/email_field.dart';
import 'package:lacoloc_front/utils/phone_field.dart';

// Nomes legíveis por categoria de permissão
const _categoryLabels = {
  'immeubles': 'Immeubles',
  'chambres': 'Chambres',
  'pieces': 'Pièces',
  'inventaire': 'Inventaire',
  'visites': 'Visites',
  'etat_de_lieux': 'État des lieux',
  'finances': 'Finances',
  'locataires': 'Locataires',
  'interactions': 'Interactions',
  'entreprise': 'Entreprise',
  'administration': 'Administration',
};

const _green = Color(0xFF2E7D32);

/// Pacote de dados carregados de uma só vez para a página.
class _AdminData {
  final List<UsersClient> users;
  final List<PermissionRef> permissions;
  final List<UserGroup> groups;
  const _AdminData(this.users, this.permissions, this.groups);
}

class UtilisateursAdminPage extends StatefulWidget {
  const UtilisateursAdminPage({super.key});

  @override
  State<UtilisateursAdminPage> createState() => _UtilisateursAdminPageState();
}

class _UtilisateursAdminPageState extends State<UtilisateursAdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late Future<_AdminData> _future;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _reload() {
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  Future<_AdminData> _load() async {
    final results = await Future.wait([
      UserManagementDatasource.listAll(),
      UserManagementDatasource.listAllPermissions(),
      UserManagementDatasource.listGroups(),
    ]);
    return _AdminData(
      results[0] as List<UsersClient>,
      results[1] as List<PermissionRef>,
      results[2] as List<UserGroup>,
    );
  }

  Future<void> _showCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateUserDialog(),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Utilisateurs & Groupes',
                    style: AppTypography.headlineMd),
              ),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Nouvel utilisateur'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Utilisateurs'),
              Tab(text: 'Groupes'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<_AdminData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Erreur : ${snap.error}'));
                }
                final data = snap.data!;
                return TabBarView(
                  controller: _tab,
                  children: [
                    _UsersTab(data: data, onChanged: _reload),
                    _GroupsTab(data: data, onChanged: _reload),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aba: Utilisateurs ────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  final _AdminData data;
  final VoidCallback onChanged;
  const _UsersTab({required this.data, required this.onChanged});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

/// Filtros disponíveis abaixo da busca.
enum _UserFilter { actifs, inactifs, proprietaires, locataires, superAdmins }

extension on _UserFilter {
  String get label => switch (this) {
        _UserFilter.actifs => 'Actifs',
        _UserFilter.inactifs => 'Inactifs',
        _UserFilter.proprietaires => 'Propriétaires',
        _UserFilter.locataires => 'Locataires',
        _UserFilter.superAdmins => 'Super Admin',
      };
}

class _UsersTabState extends State<_UsersTab> {
  String _search = '';
  final Set<_UserFilter> _filters = {};

  Future<void> _toggleActive(UsersClient user) async {
    try {
      await UserManagementDatasource.toggleActive(user.id,
          active: !user.active);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  bool _matches(UsersClient u) {
    if (_search.isNotEmpty) {
      final hit = (u.fullName ?? '').toLowerCase().contains(_search) ||
          u.email.toLowerCase().contains(_search);
      if (!hit) return false;
    }
    // Status (OR dentro da dimensão)
    final statusFilters =
        _filters.where((f) => f == _UserFilter.actifs || f == _UserFilter.inactifs);
    if (statusFilters.isNotEmpty) {
      final ok = (u.active && statusFilters.contains(_UserFilter.actifs)) ||
          (!u.active && statusFilters.contains(_UserFilter.inactifs));
      if (!ok) return false;
    }
    // Tipo (OR dentro da dimensão)
    final typeFilters = _filters.where((f) =>
        f == _UserFilter.proprietaires ||
        f == _UserFilter.locataires ||
        f == _UserFilter.superAdmins);
    if (typeFilters.isNotEmpty) {
      final t = u.resolvedType;
      final ok = (t == UserType.proprietaire &&
              typeFilters.contains(_UserFilter.proprietaires)) ||
          (t == UserType.locataire &&
              typeFilters.contains(_UserFilter.locataires)) ||
          (t == UserType.superAdmin &&
              typeFilters.contains(_UserFilter.superAdmins));
      if (!ok) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.data.users.where(_matches).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppListSearchField(
          hint: 'Rechercher par nom ou e-mail…',
          onChanged: (q) => setState(() => _search = q),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Filtros
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: _UserFilter.values.map((f) {
            final selected = _filters.contains(f);
            return FilterChip(
              label: Text(f.label),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) {
                  _filters.add(f);
                } else {
                  _filters.remove(f);
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Text('Aucun utilisateur trouvé.',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant)),
                )
              : ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _UserCard(
                    key: ValueKey(users[i].id),
                    user: users[i],
                    permissions: widget.data.permissions,
                    groups: widget.data.groups,
                    onToggleActive: () => _toggleActive(users[i]),
                    onSaved: widget.onChanged,
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Card de usuário (com accordéon de permissões) ───────────────────────────

class _UserCard extends StatefulWidget {
  final UsersClient user;
  final List<PermissionRef> permissions;
  final List<UserGroup> groups;
  final VoidCallback onToggleActive;
  final VoidCallback onSaved;

  const _UserCard({
    super.key,
    required this.user,
    required this.permissions,
    required this.groups,
    required this.onToggleActive,
    required this.onSaved,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _expanded = false;
  bool _loading = false;
  bool _saving = false;
  bool _loaded = false;

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (_) => _PasswordDialog(user: widget.user),
    );
  }

  int? _selectedGroupId; // grupo escolhido no dropdown (null = Personnalisé)
  final Set<int> _checked = {}; // permissões marcadas

  UserGroup? _groupById(int? id) {
    if (id == null) return null;
    for (final g in widget.groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  Future<void> _toggleExpand() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    setState(() => _expanded = true);
    if (_loaded) return;
    setState(() => _loading = true);
    try {
      final individual =
          await UserManagementDatasource.getUserPermissions(widget.user.id);
      final group = _groupById(widget.user.groupId);
      final effective = <int>{
        ...?group?.permissionIds,
        ...individual.map((p) => p.permissionId),
      };
      setState(() {
        _selectedGroupId = widget.user.groupId;
        _checked
          ..clear()
          ..addAll(effective);
        _loaded = true;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  void _onPickGroup(int? groupId) {
    setState(() {
      _selectedGroupId = groupId;
      final g = _groupById(groupId);
      if (g != null) {
        // Prévia: aplica as permissões do grupo
        _checked
          ..clear()
          ..addAll(g.permissionIds);
      }
      // Personnalisé: mantém o que está marcado
    });
  }

  void _onTogglePermission(int permId, bool value) {
    setState(() {
      if (value) {
        _checked.add(permId);
      } else {
        _checked.remove(permId);
      }
      // Se divergir do grupo selecionado, vira "Personnalisé"
      final g = _groupById(_selectedGroupId);
      if (g != null && !_setEquals(_checked, g.permissionIds)) {
        _selectedGroupId = null;
      }
    });
  }

  bool _setEquals(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final adminId = AuthService.currentUser!.id;
      final g = _groupById(_selectedGroupId);
      if (g != null && _setEquals(_checked, g.permissionIds)) {
        // Membro do grupo: limpa individuais, herda do grupo
        await UserManagementDatasource.setUserGroup(widget.user.id, g.id);
        await UserManagementDatasource.setPermissions(
            widget.user.id, [], adminId);
      } else {
        // Personnalisé: destaca do grupo e grava individuais
        await UserManagementDatasource.setUserGroup(widget.user.id, null);
        await UserManagementDatasource.setPermissions(
            widget.user.id, _checked.toList(), adminId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions enregistrées.')),
        );
        setState(() => _saving = false);
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final typeLabel = user.typeUserRef?.label ?? '—';
    final isAdmin = user.resolvedType == UserType.superAdmin;
    final groupName = _groupById(user.groupId)?.name;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          // Cabeçalho da linha
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isAdmin
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.primaryFixed,
                  child: Text(
                    (user.fullName ?? user.email).substring(0, 1).toUpperCase(),
                    style: AppTypography.labelMd.copyWith(
                      color: isAdmin ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName ?? user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMd
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${user.email}  ·  $typeLabel'
                        '${groupName != null ? '  ·  $groupName' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusChip(active: user.active),
                const SizedBox(width: AppSpacing.sm),
                // Botão Permissions (maior, ao lado de Actif)
                OutlinedButton.icon(
                  onPressed: _toggleExpand,
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.shield_outlined,
                    size: 18,
                  ),
                  label: const Text('Permissions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: 'Mot de passe',
                  child: IconButton.outlined(
                    onPressed: _showPasswordDialog,
                    icon: const Icon(Icons.key_outlined, size: 18),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      side: const BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: user.active ? 'Désactiver' : 'Activer',
                  child: Switch(
                    value: user.active,
                    onChanged: (_) => widget.onToggleActive(),
                  ),
                ),
              ],
            ),
          ),
          // Accordéon
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _loading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildAccordion(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordion() {
    if (!_loaded) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.user.active)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: AppRadius.borderSm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Utilisateur inactif — toutes les permissions sont '
                      'suspendues tant que le compte est désactivé.',
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          // Seletor de grupo
          Row(
            children: [
              const Icon(Icons.groups_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Groupe', style: AppTypography.labelMd),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedGroupId,
                  isDense: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Personnalisé (aucun groupe)'),
                    ),
                    ...widget.groups.map(
                      (g) => DropdownMenuItem<int?>(
                        value: g.id,
                        child: Text(g.name),
                      ),
                    ),
                  ],
                  onChanged: _onPickGroup,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Permissions',
            style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          _PermissionGrid(
            permissions: widget.permissions,
            checked: _checked,
            onToggle: _onTogglePermission,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aba: Groupes ─────────────────────────────────────────────────────────────

class _GroupsTab extends StatelessWidget {
  final _AdminData data;
  final VoidCallback onChanged;
  const _GroupsTab({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withValues(alpha: 0.4),
            borderRadius: AppRadius.borderSm,
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Modifier les permissions d\'un groupe les applique '
                  'automatiquement à tous ses membres (sauf utilisateurs '
                  'personnalisés).',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: data.groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _GroupCard(
              key: ValueKey(data.groups[i].id),
              group: data.groups[i],
              permissions: data.permissions,
              memberCount: data.users
                  .where((u) => u.groupId == data.groups[i].id)
                  .length,
              onSaved: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatefulWidget {
  final UserGroup group;
  final List<PermissionRef> permissions;
  final int memberCount;
  final VoidCallback onSaved;

  const _GroupCard({
    super.key,
    required this.group,
    required this.permissions,
    required this.memberCount,
    required this.onSaved,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = false;
  bool _saving = false;
  late final Set<int> _checked = {...widget.group.permissionIds};

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserManagementDatasource.setGroupPermissions(
          widget.group.id, _checked.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Groupe « ${widget.group.name} » mis à jour '
              '(${widget.memberCount} membre(s)).',
            ),
          ),
        );
        setState(() => _saving = false);
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.groups, color: AppColors.primary),
            title: Text(widget.group.name,
                style:
                    AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${widget.memberCount} membre(s)  ·  '
              '${_checked.length} permission(s)',
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.outlineVariant)),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PermissionGrid(
                    permissions: widget.permissions,
                    checked: _checked,
                    onToggle: (id, v) => setState(() {
                      if (v) {
                        _checked.add(id);
                      } else {
                        _checked.remove(id);
                      }
                    }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Enregistrer le groupe'),
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

// ─── Grade de permissões reutilizável (categorias + checkboxes) ──────────────

class _PermissionGrid extends StatelessWidget {
  final List<PermissionRef> permissions;
  final Set<int> checked;
  final void Function(int permId, bool value) onToggle;

  const _PermissionGrid({
    required this.permissions,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<PermissionRef>>{};
    for (final p in permissions) {
      categories.putIfAbsent(p.category, () => []).add(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.entries.map((entry) {
        final catLabel = _categoryLabels[entry.key] ?? entry.key;
        final perms = entry.value;
        final allGranted = perms.every((p) => checked.contains(p.id));
        final anyGranted = perms.any((p) => checked.contains(p.id));

        void toggleAll() {
          for (final p in perms) {
            onToggle(p.id, !allGranted);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: toggleAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Checkbox(
                      value: allGranted ? true : (anyGranted ? null : false),
                      tristate: true,
                      onChanged: (_) => toggleAll(),
                    ),
                    Text(
                      catLabel.toUpperCase(),
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...perms.map(
              (p) => CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding:
                    const EdgeInsets.only(left: AppSpacing.lg, right: 0),
                title: Text(p.label, style: AppTypography.bodyMd),
                subtitle: p.description != null
                    ? Text(p.description!,
                        style: AppTypography.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant))
                    : null,
                value: checked.contains(p.id),
                onChanged: (v) => onToggle(p.id, v ?? false),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Chip de status ───────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? _green.withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        active ? 'Actif' : 'Inactif',
        style: AppTypography.labelSm.copyWith(
          color: active ? _green : AppColors.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Dialog criar usuário ─────────────────────────────────────────────────────

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _loading = false;
  int _selectedTypeId = 2; // proprietaire por padrão

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final v = _formKey.currentState!.value;
    setState(() => _loading = true);
    try {
      await UserManagementDatasource.createUser(
        email: v['email'] as String,
        fullName: v['full_name'] as String,
        typeUserId: _selectedTypeId,
        phone: v['phone'] as String?,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un utilisateur'),
      content: SizedBox(
        width: 400,
        child: FormBuilder(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderTextField(
                name: 'full_name',
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: FormBuilderValidators.required(),
              ),
              const SizedBox(height: AppSpacing.md),
              EmailField(name: 'email'),
              const SizedBox(height: AppSpacing.md),
              PhoneField(name: 'phone'),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: _selectedTypeId,
                decoration: const InputDecoration(
                  labelText: 'Type de compte',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                // Admin de groupe é criado via « Comptes Entreprises » (precisa
                // de uma empresa) — fora deste dialog genérico.
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Locataire')),
                  DropdownMenuItem(value: 2, child: Text('Propriétaire')),
                  DropdownMenuItem(value: 3, child: Text('Super Admin')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedTypeId = v);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer'),
        ),
      ],
    );
  }
}

// ─── Dialog de gestion du mot de passe ───────────────────────────────────────

class _PasswordDialog extends StatefulWidget {
  final UsersClient user;
  const _PasswordDialog({required this.user});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  bool _sendingLink = false;
  bool _linkSent = false;
  String? _errorLink;

  bool _settingPw = false;
  String? _errorPw;

  Future<void> _sendLink() async {
    setState(() {
      _sendingLink = true;
      _errorLink = null;
    });
    try {
      await UserManagementDatasource.sendPasswordResetLink(
        userId: widget.user.id,
        email: widget.user.email,
        fullName: widget.user.fullName,
      );
      if (mounted) setState(() { _sendingLink = false; _linkSent = true; });
    } catch (e) {
      if (mounted) setState(() { _sendingLink = false; _errorLink = '$e'; });
    }
  }

  Future<void> _setPassword() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    final pw = values['password'] as String;
    final confirm = values['confirm'] as String;
    // Vérification explicite que les deux champs sont identiques avant l'envoi.
    if (pw != confirm) {
      setState(() => _errorPw = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() { _settingPw = true; _errorPw = null; });
    try {
      await UserManagementDatasource.setUserPassword(
        userId: widget.user.id,
        newPassword: pw,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _settingPw = false; _errorPw = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.fullName ?? widget.user.email;
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Mot de passe'),
          Text(
            name,
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
      contentPadding:
          const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Option 1 : lien de réinitialisation ──────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.18),
                borderRadius: AppRadius.borderMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mail_outline,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Envoyer un lien de réinitialisation',
                        style: AppTypography.bodyMd
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Un e-mail avec un lien d\'activation sera envoyé à '
                    '${widget.user.email}.',
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  if (_errorLink != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(_errorLink!,
                        style: AppTypography.labelSm
                            .copyWith(color: AppColors.error)),
                  ],
                  if (_linkSent) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 15, color: _green),
                        const SizedBox(width: 4),
                        Text('Lien envoyé !',
                            style: AppTypography.labelSm
                                .copyWith(color: _green)),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _sendingLink || _linkSent ? null : _sendLink,
                    icon: _sendingLink
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            _linkSent
                                ? Icons.check
                                : Icons.send_outlined,
                            size: 16),
                    label: Text(_linkSent ? 'Envoyé' : 'Envoyer le lien'),
                    style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ),

            // ── Séparateur "ou" ───────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm),
                    child: Text('ou',
                        style: AppTypography.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            ),

            // ── Option 2 : définir directement ───────────────────────────────
            Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 18, color: AppColors.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Définir un nouveau mot de passe',
                  style: AppTypography.bodyMd
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FormBuilder(
              key: _formKey,
              child: Column(
                children: [
                  FormBuilderTextField(
                    name: 'password',
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.minLength(6,
                          errorText: '6 caractères minimum'),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FormBuilderTextField(
                    name: 'confirm',
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      final pw = _formKey.currentState
                          ?.fields['password']?.transformedValue as String?;
                      if (val == null || val.isEmpty) {
                        return 'Champ requis';
                      }
                      if (val != pw) {
                        return 'Les mots de passe ne correspondent pas';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            if (_errorPw != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_errorPw!,
                  style:
                      AppTypography.labelSm.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _settingPw ? null : _setPassword,
              icon: _settingPw
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 16),
              label: const Text('Enregistrer le mot de passe'),
              style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
