/// Grupo de usuários — agrega um conjunto de permissões herdadas por todos os
/// membros. Espelha a tabela `User_Groups` (+ `User_Group_Permissions`).
///
/// Modelo de membership: **1 grupo por usuário** (`Users_Client.group_id`).
/// As permissões efetivas de um usuário = permissões do grupo ∪ individuais,
/// **zeradas** se o usuário estiver inativo (regra forçada no banco via
/// `user_effective_permission_ids` / `has_permission`).
class UserGroup {
  final int id;
  final String code;
  final String name;
  final String? description;
  final int? typeUserId;

  /// IDs das permissões do grupo (preenchido quando carregado com embed).
  final Set<int> permissionIds;

  const UserGroup({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.typeUserId,
    this.permissionIds = const {},
  });

  factory UserGroup.fromMap(Map<String, dynamic> map) {
    final rawPerms = map['User_Group_Permissions'];
    final perms = <int>{};
    if (rawPerms is List) {
      for (final p in rawPerms) {
        if (p is Map && p['permission_id'] != null) {
          perms.add((p['permission_id'] as num).toInt());
        }
      }
    }
    return UserGroup(
      id: (map['id'] as num).toInt(),
      code: map['code'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      typeUserId: map['type_user_id'] != null
          ? (map['type_user_id'] as num).toInt()
          : null,
      permissionIds: perms,
    );
  }

  UserGroup copyWith({Set<int>? permissionIds}) => UserGroup(
        id: id,
        code: code,
        name: name,
        description: description,
        typeUserId: typeUserId,
        permissionIds: permissionIds ?? this.permissionIds,
      );
}
