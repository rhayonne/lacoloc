import 'package:habitafrance/data/models/profile_visibility.dart';

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

  /// Champs que l'utilisateur accepte de montrer à l'autre partie
  /// (`Users_Client.profile_visibility`). Défaut = tout visible.
  final ProfileVisibility profileVisibility;

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
    this.profileVisibility = ProfileVisibility.defaults,
  });

  UserType? get resolvedType => typeUserRef?.userType;

  /// Idade calculada a partir de `date_of_birth` (regra do projeto : `age` só
  /// é fallback legado). Null se nenhum dos dois estiver disponível.
  int? get calculatedAge {
    final dob = dateOfBirth;
    if (dob == null) return age;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

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
    final typeRef = rawRef is Map
        ? UserTypeRef.fromMap(Map<String, dynamic>.from(rawRef))
        : null;
    // Sans embed du type, on ne peut pas savoir : on prend le défaut le plus
    // protecteur plutôt que le plus bavard.
    final estLocataire = typeRef?.userType == UserType.locataire;
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
      typeUserRef: typeRef,
      active: (json['active'] as bool?) ?? true,
      groupId: json['group_id'] != null
          ? (json['group_id'] as num).toInt()
          : null,
      entrepriseId: json['entreprise_id'] != null
          ? (json['entreprise_id'] as num).toInt()
          : null,
      // Colonne optionnelle : absente (schéma pas encore migré) → défaut du
      // rôle. Un bailleur ne diffuse rien tant qu'il ne l'a pas choisi.
      profileVisibility: ProfileVisibility.fromRaw(
        json['profile_visibility'],
        fallback: ProfileVisibility.defaultsFor(isLocataire: estLocataire),
      ),
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
