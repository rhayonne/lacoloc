class PermissionRef {
  final int id;
  final String key;
  final String label;
  final String? description;
  final String category;

  const PermissionRef({
    required this.id,
    required this.key,
    required this.label,
    this.description,
    required this.category,
  });

  factory PermissionRef.fromMap(Map<String, dynamic> map) => PermissionRef(
        id: map['id'] as int,
        key: map['key'] as String,
        label: map['label'] as String,
        description: map['description'] as String?,
        category: map['category'] as String,
      );
}

class UserPermission {
  final String userId;
  final int permissionId;
  final DateTime grantedAt;
  final PermissionRef permission;

  const UserPermission({
    required this.userId,
    required this.permissionId,
    required this.grantedAt,
    required this.permission,
  });

  factory UserPermission.fromMap(Map<String, dynamic> map) {
    final ref = map['Permissions_Reference'] as Map<String, dynamic>;
    return UserPermission(
      userId: map['user_id'] as String,
      permissionId: map['permission_id'] as int,
      grantedAt: DateTime.parse(map['granted_at'] as String),
      permission: PermissionRef.fromMap(ref),
    );
  }
}
