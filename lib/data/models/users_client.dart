/// Tipos possíveis de cliente da plataforma.
/// O [raw] corresponde ao campo `code` em `User_Types_Reference`.
enum UserType {
  locataire,
  proprietaire,
  adminGroupe,
  superAdmin;

  String get raw => switch (this) {
        UserType.locataire => 'locataire',
        UserType.proprietaire => 'proprietaire',
        UserType.adminGroupe => 'admin_groupe',
        UserType.superAdmin => 'super_admin',
      };

  static UserType? tryParse(String? raw) {
    if (raw == null) return null;
    return switch (raw) {
      'locataire' => UserType.locataire,
      'proprietaire' => UserType.proprietaire,
      'admin_groupe' => UserType.adminGroupe,
      'super_admin' => UserType.superAdmin,
      _ => null,
    };
  }
}

/// Linha de `User_Types_Reference` — tabela de referência dos tipos de usuário.
class UserTypeRef {
  final int id;
  final String code;
  final String label;
  final String? description;

  const UserTypeRef({
    required this.id,
    required this.code,
    required this.label,
    this.description,
  });

  factory UserTypeRef.fromMap(Map<String, dynamic> map) => UserTypeRef(
        id: map['id'] as int,
        code: map['code'] as String,
        label: map['label'] as String,
        description: map['description'] as String?,
      );

  UserType? get userType => UserType.tryParse(code);
}

class UsersClient {
  final String id; // uuid do auth.users
  final DateTime createdAt;
  final String email;
  final String? fullName;
  final String? phone;
  final int? age;
  final DateTime? dateOfBirth;
  final int? typeUserId;
  final UserTypeRef? typeUserRef;
  final bool active;
  final int? groupId;
  final int? entrepriseId;

  UsersClient({
    required this.id,
    required this.createdAt,
    required this.email,
    this.fullName,
    this.phone,
    this.age,
    this.dateOfBirth,
    this.typeUserId,
    this.typeUserRef,
    this.active = true,
    this.groupId,
    this.entrepriseId,
  });

  UserType? get resolvedType => typeUserRef?.userType;

  /// Libellé lisible du type d'utilisateur pour l'affichage (carte sidebar, etc.).
  /// « Propriétaire entreprise » = un propriétaire rattaché à une entreprise
  /// (sous l'admin d'entreprise) ; « Propriétaire » = indépendant.
  String get typeDisplayLabel => switch (resolvedType) {
        UserType.locataire => 'Locataire',
        UserType.proprietaire =>
          entrepriseId != null ? 'Propriétaire entreprise' : 'Propriétaire',
        UserType.adminGroupe => 'Admin entreprise',
        UserType.superAdmin => 'Super Admin',
        null => typeUserRef?.label ?? 'Utilisateur',
      };

  factory UsersClient.fromJson(Map<String, dynamic> json) {
    final rawRef = json['User_Types_Reference'];
    return UsersClient(
      id: json['id'].toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      email: (json['email'] ?? json['login'] ?? '') as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      age: json['age'] as int?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      typeUserId: json['type_user_id'] as int?,
      typeUserRef: rawRef is Map
          ? UserTypeRef.fromMap(Map<String, dynamic>.from(rawRef))
          : null,
      active: (json['active'] as bool?) ?? true,
      groupId: json['group_id'] != null
          ? (json['group_id'] as num).toInt()
          : null,
      entrepriseId: json['entreprise_id'] != null
          ? (json['entreprise_id'] as num).toInt()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'email': email,
      'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (age != null) 'age': age,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth!.toIso8601String().substring(0, 10),
      if (typeUserId != null) 'type_user_id': typeUserId,
      'active': active,
    };
  }
}
