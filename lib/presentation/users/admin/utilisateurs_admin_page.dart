import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/user_management.dart';
import 'package:lacoloc_front/data/models/permission.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/email_field.dart';
import 'package:lacoloc_front/utils/phone_field.dart';

// Nomes legíveis por categoria de permissão
const _categoryLabels = {
  'etat_de_lieux': 'État des lieux',
  'finances': 'Finances',
  'immeubles': 'Immeubles',
  'chambres': 'Chambres',
  'locataires': 'Locataires',
};

class UtilisateursAdminPage extends StatefulWidget {
  const UtilisateursAdminPage({super.key});

  @override
  State<UtilisateursAdminPage> createState() => _UtilisateursAdminPageState();
}

class _UtilisateursAdminPageState extends State<UtilisateursAdminPage> {
  late Future<List<UsersClient>> _futureUsers;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _futureUsers = UserManagementDatasource.listAll());
  }

  Future<void> _showCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateUserDialog(onCreated: _refresh),
    );
    if (created == true) _refresh();
  }

  Future<void> _showPermissionsDialog(UsersClient user) async {
    await showDialog(
      context: context,
      builder: (_) => _GestionPermissionsDialog(user: user),
    );
  }

  Future<void> _toggleActive(UsersClient user) async {
    final newActive = !user.active;
    try {
      await UserManagementDatasource.toggleActive(user.id, active: newActive);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
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
                child: Text('Utilisateurs', style: AppTypography.headlineMd),
              ),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Nouvel utilisateur'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher par nom ou e-mail…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<UsersClient>>(
              future: _futureUsers,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Erreur : ${snap.error}'));
                }
                final all = snap.data ?? [];
                final users = _search.isEmpty
                    ? all
                    : all.where((u) {
                        return (u.fullName ?? '').toLowerCase().contains(_search) ||
                            u.email.toLowerCase().contains(_search);
                      }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun utilisateur trouvé.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _UserTile(
                    user: users[i],
                    onPermissions: () => _showPermissionsDialog(users[i]),
                    onToggleActive: () => _toggleActive(users[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tile de usuário ─────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final UsersClient user;
  final VoidCallback onPermissions;
  final VoidCallback onToggleActive;

  const _UserTile({
    required this.user,
    required this.onPermissions,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = user.typeUserRef?.label ?? '—';
    final isAdmin = user.resolvedType == UserType.superAdmin;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
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
      title: Text(
        user.fullName ?? user.email,
        style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${user.email}  ·  $typeLabel',
        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusChip(active: user.active),
          const SizedBox(width: AppSpacing.sm),
          if (!isAdmin)
            IconButton(
              tooltip: 'Gérer les permissions',
              icon: const Icon(Icons.shield_outlined, size: 20),
              onPressed: onPermissions,
            ),
          Switch(
            value: user.active,
            onChanged: (_) => onToggleActive(),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        active ? 'Actif' : 'Inactif',
        style: AppTypography.labelSm.copyWith(
          color: active ? const Color(0xFF2E7D32) : AppColors.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Dialog criar usuário ─────────────────────────────────────────────────────

class _CreateUserDialog extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateUserDialog({required this.onCreated});

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
      if (mounted) {
        Navigator.pop(context, true);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
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

// ─── Dialog de gestão de permissões ──────────────────────────────────────────

class _GestionPermissionsDialog extends StatefulWidget {
  final UsersClient user;
  const _GestionPermissionsDialog({required this.user});

  @override
  State<_GestionPermissionsDialog> createState() =>
      _GestionPermissionsDialogState();
}

class _GestionPermissionsDialogState extends State<_GestionPermissionsDialog> {
  List<PermissionRef>? _allPermissions;
  Set<int> _granted = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      UserManagementDatasource.listAllPermissions(),
      UserManagementDatasource.getUserPermissions(widget.user.id),
    ]);
    final allPerms = results[0] as List<PermissionRef>;
    final userPerms = results[1] as List<UserPermission>;
    setState(() {
      _allPermissions = allPerms;
      _granted = userPerms.map((up) => up.permissionId).toSet();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final adminId = AuthService.currentUser!.id;
      await UserManagementDatasource.setPermissions(
        widget.user.id,
        _granted.toList(),
        adminId,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.fullName ?? widget.user.email;
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Permissions'),
          Text(
            name,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildPermissionsList(),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _buildPermissionsList() {
    final all = _allPermissions ?? [];
    // Agrupa por categoria
    final categories = <String, List<PermissionRef>>{};
    for (final p in all) {
      categories.putIfAbsent(p.category, () => []).add(p);
    }

    return ListView(
      children: categories.entries.map((entry) {
        final catLabel =
            _categoryLabels[entry.key] ?? entry.key;
        final perms = entry.value;
        final allGranted = perms.every((p) => _granted.contains(p.id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header da categoria com checkbox "selecionar todos"
            InkWell(
              onTap: () {
                setState(() {
                  if (allGranted) {
                    for (final p in perms) { _granted.remove(p.id); }
                  } else {
                    for (final p in perms) { _granted.add(p.id); }
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: allGranted
                          ? true
                          : perms.any((p) => _granted.contains(p.id))
                              ? null
                              : false,
                      tristate: true,
                      onChanged: (_) {
                        setState(() {
                          if (allGranted) {
                            for (final p in perms) { _granted.remove(p.id); }
                          } else {
                            for (final p in perms) { _granted.add(p.id); }
                          }
                        });
                      },
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
                title: Text(p.label, style: AppTypography.bodyMd),
                subtitle: p.description != null
                    ? Text(
                        p.description!,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      )
                    : null,
                value: _granted.contains(p.id),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _granted.add(p.id);
                    } else {
                      _granted.remove(p.id);
                    }
                  });
                },
              ),
            ),
            const Divider(),
          ],
        );
      }).toList(),
    );
  }
}
