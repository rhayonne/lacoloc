import 'package:lacoloc_front/data/models/permission.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementDatasource {
  UserManagementDatasource._();

  static final _db = Supabase.instance.client;

  static const _selectUser =
      'id, email, full_name, phone, created_at, active, type_user_id, '
      'User_Types_Reference(id, code, label)';

  static Future<List<UsersClient>> listAll() async {
    final rows = await _db
        .from('Users_Client')
        .select(_selectUser)
        .order('created_at', ascending: false);
    return rows.map((r) => UsersClient.fromJson(r)).toList();
  }

  static Future<UsersClient> updateUserType(
    String userId,
    int typeUserId,
  ) async {
    final row = await _db
        .from('Users_Client')
        .update({'type_user_id': typeUserId})
        .eq('id', userId)
        .select(_selectUser)
        .single();
    return UsersClient.fromJson(row);
  }

  static Future<UsersClient> toggleActive(
    String userId, {
    required bool active,
  }) async {
    final row = await _db
        .from('Users_Client')
        .update({'active': active})
        .eq('id', userId)
        .select(_selectUser)
        .single();
    return UsersClient.fromJson(row);
  }

  static Future<List<UserPermission>> getUserPermissions(
    String userId,
  ) async {
    final rows = await _db
        .from('User_Permissions')
        .select('user_id, permission_id, granted_at, Permissions_Reference(id, key, label, category)')
        .eq('user_id', userId);
    return rows.map((r) => UserPermission.fromMap(r)).toList();
  }

  static Future<void> grantPermission(
    String userId,
    int permissionId,
    String grantedBy,
  ) async {
    await _db.from('User_Permissions').upsert({
      'user_id': userId,
      'permission_id': permissionId,
      'granted_by': grantedBy,
    });
  }

  static Future<void> revokePermission(
    String userId,
    int permissionId,
  ) async {
    await _db
        .from('User_Permissions')
        .delete()
        .eq('user_id', userId)
        .eq('permission_id', permissionId);
  }

  static Future<void> setPermissions(
    String userId,
    List<int> permissionIds,
    String grantedBy,
  ) async {
    // Remove todas as permissões existentes do usuário
    await _db.from('User_Permissions').delete().eq('user_id', userId);
    if (permissionIds.isEmpty) return;
    // Insere as novas permissões
    await _db.from('User_Permissions').insert(
      permissionIds
          .map((pid) => {
                'user_id': userId,
                'permission_id': pid,
                'granted_by': grantedBy,
              })
          .toList(),
    );
  }

  static Future<List<PermissionRef>> listAllPermissions() async {
    final rows = await _db
        .from('Permissions_Reference')
        .select('id, key, label, description, category')
        .order('category')
        .order('id');
    return rows.map((r) => PermissionRef.fromMap(r)).toList();
  }

  static Future<UsersClient> createUser({
    required String email,
    required String fullName,
    required int typeUserId,
    String? phone,
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'invite-locataire',
      body: {
        'fullName': fullName,
        'email': email,
        'proprietaireId': Supabase.instance.client.auth.currentUser!.id,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    final userId = data['userId'] as String;
    // Atualiza o tipo do usuário
    return updateUserType(userId, typeUserId);
  }
}
