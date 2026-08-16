import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/datasources/user_management.dart';
import 'package:habitafrance/data/models/permission.dart';
import 'package:habitafrance/data/models/user_group.dart';
import 'package:habitafrance/data/models/users_client.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_tab_bar.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/presentation/widgets/app_list_search_field.dart';
import 'package:habitafrance/presentation/widgets/filter_button.dart';
import 'package:habitafrance/utils/email_field.dart';
import 'package:habitafrance/utils/phone_field.dart';

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

/// Vert « actif / envoyé ». Passe par le token du thème : un vert foncé en
/// dur devenait illisible sur fond sombre.
Color get _green => AppColors.success;

/// Pacote de dados carregados de uma só vez para a página.
class _AdminData {
  final List<UsersClient> users;
  final List<PermissionRef> permissions;
  final List<UserGroup> groups;
  const _AdminData(this.users, this.permissions, this.groups);
}

/// Date d'inscription affichée dans la liste et utilisée pour le tri.
final DateFormat _dateInscription = DateFormat('dd/MM/yyyy');

class UtilisateursAdminPage extends StatefulWidget {
  /// Sous-onglet actif (0 = Utilisateurs, 1 = Groupes) quand piloté par les
  /// sous-menus de la sidebar (`showTabBar = false`).
  final int initialTab;

  /// Ouvre la page **centrée sur un compte** : la liste est réduite à celui-ci.
  /// Utilisé par la notification « nouvelle demande de compte propriétaire » du
  /// tableau de bord — un avis qui n'aide que s'il mène au geste (activer).
  final String? focusUserId;

  /// `true` = affiche les onglets internes (mode hérité) ; `false` = navigation
  /// par sous-menus (pas d'onglets ni de balayage du contenu).
  final bool showTabBar;

  const UtilisateursAdminPage({
    super.key,
    this.initialTab = 0,
    this.focusUserId,
    this.showTabBar = true,
  });

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
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
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
    // Mode sous-menus (défaut de la coquille) : pas d'onglets, pas de balayage
    // du contenu ; le titre = le nom du sous-menu et l'action « Nouvel
    // utilisateur » n'apparaît que sur le sous-menu Utilisateurs.
    final submenuMode = !widget.showTabBar;
    final activeIndex = widget.initialTab;
    final title = submenuMode
        ? (activeIndex == 0 ? 'Utilisateurs' : 'Groupes')
        : 'Utilisateurs & Groupes';
    final showCreate = submenuMode ? activeIndex == 0 : true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: title,
          trailing: showCreate
              ? AppButton.primary(
                  size: AppButtonSize.compact,
                  icon: Icons.person_add_outlined,
                  label: 'Nouvel utilisateur',
                  onPressed: _showCreateDialog,
                )
              : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!submenuMode) ...[
                  AppTabBar(
                    controller: _tab,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Utilisateurs'),
                      Tab(text: 'Groupes'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
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
                      if (submenuMode) {
                        // Rendu direct du sous-onglet actif : aucun TabBarView
                        // → le contenu ne peut pas être balayé.
                        return activeIndex == 0
                            ? _UsersTab(
                                data: data,
                                onChanged: _reload,
                                focusUserId: widget.focusUserId,
                              )
                            : _GroupsTab(data: data, onChanged: _reload);
                      }
                      return TabBarView(
                        controller: _tab,
                        children: [
                          _UsersTab(
                            data: data,
                            onChanged: _reload,
                            focusUserId: widget.focusUserId,
                          ),
                          _GroupsTab(data: data, onChanged: _reload),
                        ],
                      );
                    },
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

// ─── Aba: Utilisateurs ────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  final _AdminData data;
  final VoidCallback onChanged;
  final String? focusUserId;

  const _UsersTab({
    required this.data,
    required this.onChanged,
    this.focusUserId,
  });

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

/// Filtros disponíveis abaixo da busca.
enum _UserFilter { actifs, inactifs, proprietaires, locataires, superAdmins,
  adminsSysteme }

extension on _UserFilter {
  String get label => switch (this) {
    _UserFilter.actifs => 'Actifs',
    _UserFilter.inactifs => 'Inactifs',
    _UserFilter.proprietaires => 'Propriétaires',
    _UserFilter.locataires => 'Locataires',
    _UserFilter.superAdmins => 'Super Admin',
    _UserFilter.adminsSysteme => 'Admin Sys.',
  };
}

/// Chip de filtre compact (même style que l'Inventaire/EDL/Lots) : pill,
/// compteur, coche quand sélectionné. Ici plusieurs chips peuvent être
/// sélectionnés à la fois (filtre multi-sélection par dimension).
class _AdminFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _AdminFilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 13, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: AppRadius.borderFull,
              ),
              child: Text(
                '$count',
                style: AppTypography.labelSm.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTabState extends State<_UsersTab> {
  String _search = '';
  final Set<_UserFilter> _filters = {};
  bool _filterOpen = false;

  Future<void> _toggleActive(UsersClient user) async {
    try {
      await UserManagementDatasource.toggleActive(
        user.id,
        active: !user.active,
      );
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  bool _inCategory(UsersClient u, _UserFilter f) => switch (f) {
    _UserFilter.actifs => u.active,
    _UserFilter.inactifs => !u.active,
    _UserFilter.proprietaires => u.resolvedType == UserType.proprietaire,
    _UserFilter.locataires => u.resolvedType == UserType.locataire,
    _UserFilter.superAdmins => u.resolvedType == UserType.superAdmin,
    _UserFilter.adminsSysteme => u.resolvedType == UserType.adminSysteme,
  };

  /// Compte sur lequel la page est centrée, tant que l'utilisateur n'a pas
  /// cliqué « Voir tous » (le focus vient d'une notification, il ne doit pas
  /// coincer la page).
  String? _focus;

  /// Ordre de la liste. Par défaut les inscriptions récentes en tête.
  bool _plusRecentsDabord = true;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusUserId;
  }

  bool _matches(UsersClient u) {
    // Le focus court-circuite recherche et filtres : on vient traiter CE compte.
    if (_focus != null) return u.id == _focus;
    if (_search.isNotEmpty) {
      final hit =
          (u.fullName ?? '').toLowerCase().contains(_search) ||
          u.email.toLowerCase().contains(_search);
      if (!hit) return false;
    }
    // Status (OR dentro da dimensão)
    final statusFilters = _filters.where(
      (f) => f == _UserFilter.actifs || f == _UserFilter.inactifs,
    );
    if (statusFilters.isNotEmpty) {
      final ok =
          (u.active && statusFilters.contains(_UserFilter.actifs)) ||
          (!u.active && statusFilters.contains(_UserFilter.inactifs));
      if (!ok) return false;
    }
    // Tipo (OR dentro da dimensão)
    final typeFilters = _filters.where(
      (f) =>
          f == _UserFilter.proprietaires ||
          f == _UserFilter.locataires ||
          f == _UserFilter.superAdmins ||
          f == _UserFilter.adminsSysteme,
    );
    if (typeFilters.isNotEmpty) {
      final t = u.resolvedType;
      final ok =
          (t == UserType.proprietaire &&
              typeFilters.contains(_UserFilter.proprietaires)) ||
          (t == UserType.locataire &&
              typeFilters.contains(_UserFilter.locataires)) ||
          (t == UserType.superAdmin &&
              typeFilters.contains(_UserFilter.superAdmins)) ||
          (t == UserType.adminSysteme &&
              typeFilters.contains(_UserFilter.adminsSysteme));
      if (!ok) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.data.users.where(_matches).toList()
      // Les plus récents d'abord : sur cet écran on vient traiter les
      // inscriptions du jour (activer un propriétaire), pas relire les
      // anciennes.
      ..sort((a, b) => _plusRecentsDabord
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sans ce bandeau, un admin arrivant depuis une notification verrait
        // « un seul utilisateur » sans comprendre pourquoi.
        if (_focus != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: AppRadius.borderMd,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 18,
                  color: AppColors.onPrimaryFixedVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Affichage centré sur le compte à activer.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onPrimaryFixedVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _focus = null),
                  child: const Text('Voir tous les utilisateurs'),
                ),
              ],
            ),
          ),
        // Recherche + bouton « Filtres » (le panneau de chips s'ouvre au clic,
        // au lieu d'occuper l'écran en permanence).
        Row(
          children: [
            Expanded(
              child: AppListSearchField(
                hint: 'Rechercher par nom ou e-mail…',
                onChanged: (q) => setState(() => _search = q),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Tooltip(
              message: _plusRecentsDabord
                  ? 'Plus récents d\'abord'
                  : 'Plus anciens d\'abord',
              child: IconButton.outlined(
                onPressed: () =>
                    setState(() => _plusRecentsDabord = !_plusRecentsDabord),
                icon: Icon(
                  _plusRecentsDabord
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 18,
                ),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  side: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            FilterButton(
              isOpen: _filterOpen,
              activeCount: _filters.length,
              onTap: () => setState(() => _filterOpen = !_filterOpen),
            ),
          ],
        ),
        // Panneau de filtres (inline, ouvre/ferme avec le bouton).
        if (_filterOpen) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.borderLg,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _UserFilter.values.map((f) {
                final selected = _filters.contains(f);
                final count = widget.data.users
                    .where((u) => _inCategory(u, f))
                    .length;
                return _AdminFilterChip(
                  label: f.label,
                  count: count,
                  selected: selected,
                  onTap: () => setState(() {
                    if (selected) {
                      _filters.remove(f);
                    } else {
                      _filters.add(f);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Text(
                    'Aucun utilisateur trouvé.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
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

  bool _envoiActivation = false;

  /// Prévient l'utilisateur que son compte est ouvert, avec le lien vers son
  /// espace, le manuel et l'adresse de support. Tout le contenu est construit
  /// côté serveur (`notify-activation`) : ici on ne transmet qu'un id.
  Future<void> _envoyerActivation() async {
    setState(() => _envoiActivation = true);
    try {
      await UserManagementDatasource.sendActivationEmail(widget.user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('E-mail d\'activation envoyé à ${widget.user.email}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _envoiActivation = false);
    }
  }

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
      final individual = await UserManagementDatasource.getUserPermissions(
        widget.user.id,
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
          widget.user.id,
          [],
          adminId,
        );
      } else {
        // Personnalisé: destaca do grupo e grava individuais
        await UserManagementDatasource.setUserGroup(widget.user.id, null);
        await UserManagementDatasource.setPermissions(
          widget.user.id,
          _checked.toList(),
          adminId,
        );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final identity = Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isAdmin
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.primaryFixed,
                      child: Text(
                        (user.fullName ?? user.email)
                            .substring(0, 1)
                            .toUpperCase(),
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
                            style: AppTypography.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${user.email}  ·  $typeLabel'
                            '${groupName != null ? '  ·  $groupName' : ''}'
                            '  ·  Inscrit le '
                            '${_dateInscription.format(user.createdAt.toLocal())}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusChip(active: user.active),
                  ],
                );

                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão Permissions (compacto, ao lado de Actif)
                    AppButton.edit(
                      size: AppButtonSize.compact,
                      icon: _expanded
                          ? Icons.expand_less
                          : Icons.shield_outlined,
                      label: 'Permissions',
                      onPressed: _toggleExpand,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Tooltip(
                      message: 'Mot de passe',
                      child: IconButton.outlined(
                        onPressed: _showPasswordDialog,
                        icon: const Icon(Icons.key_outlined, size: 18),
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.onSurfaceVariant,
                          side: BorderSide(color: AppColors.outlineVariant),
                        ),
                      ),
                    ),
                    // Prévenir l'intéressé n'a de sens qu'une fois le compte
                    // réellement actif — sinon on annoncerait une activation
                    // qui n'a pas eu lieu (l'edge function le refuse aussi).
                    if (user.active) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Tooltip(
                        message: 'Envoyer l\'e-mail d\'activation',
                        child: IconButton.outlined(
                          onPressed: _envoiActivation
                              ? null
                              : _envoyerActivation,
                          icon: _envoiActivation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.mark_email_read_outlined,
                                  size: 18,
                                ),
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.onSurfaceVariant,
                            side: BorderSide(color: AppColors.outlineVariant),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.sm),
                    Tooltip(
                      message: user.active ? 'Désactiver' : 'Activer',
                      child: Switch(
                        value: user.active,
                        onChanged: (_) => widget.onToggleActive(),
                      ),
                    ),
                  ],
                );

                // En dessous d'~560px, les actions (Permissions/clé/switch)
                // passent sous l'identité pour éviter d'écraser le nom/email.
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: AppSpacing.sm),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: AppSpacing.sm),
                    actions,
                  ],
                );
              },
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
      decoration: BoxDecoration(
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
                  Icon(Icons.info_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Utilisateur inactif — toutes les permissions sont '
                      'suspendues tant que le compte est désactivé.',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Seletor de grupo
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 18, color: AppColors.primary),
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
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
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
            child: AppButton.save(
              label: 'Enregistrer',
              isBusy: _saving,
              onPressed: _saving ? null : _save,
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
              Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Modifier les permissions d\'un groupe les applique '
                  'automatiquement à tous ses membres (sauf utilisateurs '
                  'personnalisés).',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
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
        widget.group.id,
        _checked.toList(),
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
            leading: Icon(Icons.groups, color: AppColors.primary),
            title: Text(
              widget.group.name,
              style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${widget.memberCount} membre(s)  ·  '
              '${_checked.length} permission(s)',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.outlineVariant),
                ),
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
                    child: AppButton.save(
                      label: 'Enregistrer le groupe',
                      isBusy: _saving,
                      onPressed: _saving ? null : _save,
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
                contentPadding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: 0,
                ),
                title: Text(p.label, style: AppTypography.bodyMd),
                subtitle: p.description != null
                    ? Text(
                        p.description!,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      )
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
        AppButton.cancel(
          label: 'Annuler',
          onPressed: _loading ? null : () => Navigator.pop(context),
        ),
        AppButton.save(
          label: 'Créer',
          isBusy: _loading,
          onPressed: _loading ? null : _submit,
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
      if (mounted) {
        setState(() {
          _sendingLink = false;
          _linkSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendingLink = false;
          _errorLink = '$e';
        });
      }
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
    setState(() {
      _settingPw = true;
      _errorPw = null;
    });
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
      if (mounted) {
        setState(() {
          _settingPw = false;
          _errorPw = '$e';
        });
      }
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
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
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
                      Icon(
                        Icons.mail_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Envoyer un lien de réinitialisation',
                        style: AppTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Un e-mail avec un lien d\'activation sera envoyé à '
                    '${widget.user.email}.',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (_errorLink != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _errorLink!,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  if (_linkSent) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 15,
                          color: _green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Lien envoyé !',
                          style: AppTypography.labelSm.copyWith(color: _green),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.primary(
                    size: AppButtonSize.compact,
                    icon: _linkSent ? Icons.check : Icons.send_outlined,
                    label: _linkSent ? 'Envoyé' : 'Envoyer le lien',
                    isBusy: _sendingLink,
                    onPressed: _sendingLink || _linkSent ? null : _sendLink,
                  ),
                ],
              ),
            ),

            // ── Séparateur "ou" ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      'ou',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            ),

            // ── Option 2 : définir directement ───────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Définir un nouveau mot de passe',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                      FormBuilderValidators.minLength(
                        6,
                        errorText: '6 caractères minimum',
                      ),
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
                      final pw =
                          _formKey
                                  .currentState
                                  ?.fields['password']
                                  ?.transformedValue
                              as String?;
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
              Text(
                _errorPw!,
                style: AppTypography.labelSm.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            AppButton.save(
              size: AppButtonSize.compact,
              label: 'Enregistrer le mot de passe',
              isBusy: _settingPw,
              onPressed: _settingPw ? null : _setPassword,
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
