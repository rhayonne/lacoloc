import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/permission.dart';
import 'package:lacoloc_front/data/models/user_group.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementDatasource {
  UserManagementDatasource._();

  static final _db = Supabase.instance.client;

  static const _selectUser =
      'id, email, full_name, phone, created_at, active, type_user_id, group_id, '
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
    await _callManageUserAuth(userId, active: active);
    return UsersClient.fromJson(row);
  }

  /// Bane ou desbane o utilizador no Supabase Auth via a edge function
  /// `manage-user-auth`. Falhas silenciosas — o estado no banco já foi gravado.
  static Future<void> _callManageUserAuth(String userId, {required bool active}) async {
    try {
      await _db.functions.invoke('manage-user-auth', body: {
        'targetUserId': userId,
        'action': active ? 'unban' : 'ban',
      });
    } catch (_) {}
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

  // ─── Grupos de usuários ─────────────────────────────────────────────────────

  /// Lista todos os grupos com as permissões de cada um (embed).
  static Future<List<UserGroup>> listGroups() async {
    final rows = await _db
        .from('User_Groups')
        .select('id, code, name, description, type_user_id, '
            'User_Group_Permissions(permission_id)')
        .order('id');
    return rows.map((r) => UserGroup.fromMap(r)).toList();
  }

  /// Substitui o conjunto de permissões de um grupo. Afeta todos os membros,
  /// pois as permissões efetivas são derivadas do grupo no banco.
  static Future<void> setGroupPermissions(
    int groupId,
    List<int> permissionIds,
  ) async {
    await _db
        .from('User_Group_Permissions')
        .delete()
        .eq('group_id', groupId);
    if (permissionIds.isEmpty) return;
    await _db.from('User_Group_Permissions').insert(
          permissionIds
              .map((pid) => {'group_id': groupId, 'permission_id': pid})
              .toList(),
        );
  }

  /// Insere/remove um usuário de um grupo (`null` = sem grupo).
  static Future<UsersClient> setUserGroup(String userId, int? groupId) async {
    final row = await _db
        .from('Users_Client')
        .update({'group_id': groupId})
        .eq('id', userId)
        .select(_selectUser)
        .single();
    return UsersClient.fromJson(row);
  }

  /// IDs das permissões **efetivas** de um usuário (grupo ∪ individuais,
  /// zeradas se inativo) — via RPC que reflete a regra do banco.
  static Future<Set<int>> effectivePermissionIds(String userId) async {
    final rows = await _db.rpc(
      'user_effective_permission_ids',
      params: {'p_user': userId},
    );
    if (rows is! List) return {};
    return rows.map((e) => (e as num).toInt()).toSet();
  }

  /// Envoie un nouveau lien de réinitialisation à l'utilisateur.
  /// Délègue à `EtatDesLieuxDatasource.resendInvitation` pour réutiliser
  /// la logique d'override dev (ADDR_MAIL_CONFIRMATION) et redirectTo.
  static Future<void> sendPasswordResetLink({
    required String userId,
    required String email,
    String? fullName,
  }) async {
    await EtatDesLieuxDatasource.resendInvitation(
      userId: userId,
      email: email,
      fullName: fullName,
    );
  }

  /// Définit directement un nouveau mot de passe via l'edge function
  /// `manage-user-auth` (action `set_password`). Réservé aux super_admin.
  static Future<void> setUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    final res = await _db.functions.invoke('manage-user-auth', body: {
      'targetUserId': userId,
      'action': 'set_password',
      'newPassword': newPassword,
    });
    final data = res.data;
    if (res.status != 200 || (data is Map && data['error'] != null)) {
      throw Exception((data is Map ? data['error'] : null) ?? 'Erreur inconnue');
    }
  }

  static Future<UsersClient> createUser({
    required String email,
    required String fullName,
    required int typeUserId,
    String? phone,
  }) async {
    // Reusa inviteLocataire → envia `mailTo` (em **dev**, entrega na caixa de
    // teste `ADDR_MAIL_CONFIRMATION` do .env.dev ; em **prod**, sem override) +
    // `redirectTo` (URL de ativação). Sem isso, o e-mail ia para o endereço real.
    final userId = await EtatDesLieuxDatasource.inviteLocataire(
      fullName: fullName,
      email: email,
      proprietaireId: Supabase.instance.client.auth.currentUser!.id,
      phone: phone,
    );
    // Atualiza o tipo do usuário
    return updateUserType(userId, typeUserId);
  }
}
