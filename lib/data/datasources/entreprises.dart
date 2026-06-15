import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/entreprise.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestão de contas empresa (multi-tenant). Uso **super admin** para criar/editar
/// empresas e seus admins de groupe. As leituras de membros/empresa também servem
/// ao próprio admin de groupe (config da empresa — fase 2).
class EntreprisesDatasource {
  EntreprisesDatasource._();

  static final _db = Supabase.instance.client;
  static const _selectUser =
      'id, email, full_name, phone, created_at, active, type_user_id, group_id, '
      'entreprise_id, User_Types_Reference(id, code, label)';

  // ─── Empresas ───────────────────────────────────────────────────────────────

  static Future<List<Entreprise>> listAll() async {
    final rows = await _db
        .from('Entreprises')
        .select('id, name, domain, active, created_at')
        .order('created_at', ascending: false);
    return rows.map((r) => Entreprise.fromMap(r)).toList();
  }

  static Future<Entreprise?> byId(int id) async {
    final row = await _db
        .from('Entreprises')
        .select('id, name, domain, active, created_at')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Entreprise.fromMap(row);
  }

  static Future<Entreprise> create({
    required String name,
    String? domain,
  }) async {
    final row = await _db
        .from('Entreprises')
        .insert({
          'name': name,
          if (domain != null && domain.isNotEmpty) 'domain': domain,
          'created_by': _db.auth.currentUser?.id,
        })
        .select('id, name, domain, active, created_at')
        .single();
    return Entreprise.fromMap(row);
  }

  /// Atualiza nome/domínio/ativo. O **domínio só pode ser alterado pelo super
  /// admin** (forçado pelo RLS `entreprises_write`). Quando `active` muda,
  /// bane/desbane todos os membros no Supabase Auth em cascata.
  static Future<Entreprise> update(
    int id, {
    String? name,
    String? domain,
    bool? active,
  }) async {
    final row = await _db
        .from('Entreprises')
        .update({
          'name': ?name,
          'domain': ?domain,
          'active': ?active,
        })
        .eq('id', id)
        .select('id, name, domain, active, created_at')
        .single();
    if (active != null) {
      final members = await listMembers(id);
      await Future.wait(
        members.map((m) => _callManageUserAuth(m.id, active: active)),
      );
    }
    return Entreprise.fromMap(row);
  }

  // ─── Membros ────────────────────────────────────────────────────────────────

  static Future<List<UsersClient>> listMembers(int entrepriseId) async {
    final rows = await _db
        .from('Users_Client')
        .select(_selectUser)
        .eq('entreprise_id', entrepriseId)
        .order('created_at');
    return rows.map((r) => UsersClient.fromJson(r)).toList();
  }

  /// Envia um **e-mail de réinitialisation de mot de passe** a um membro: gera
  /// uma nova senha temporária + link de ativação (sem precisar da senha
  /// anterior). Em dev, entregue na caixa de teste `ADDR_MAIL_CONFIRMATION`.
  /// Usado pelo admin de groupe (e pelo super admin).
  static Future<void> resetPassword({
    required String userId,
    required String email,
    String? fullName,
  }) {
    return EtatDesLieuxDatasource.resendInvitation(
      userId: userId,
      email: email,
      fullName: fullName,
    );
  }

  /// Ativa/desativa um membro (super admin ou admin de groupe). Um usuário inativo
  /// perde todas as permissões efetivas (banco) **e** é banido no Supabase Auth
  /// (não consegue mais fazer login enquanto desativado).
  static Future<UsersClient> setMemberActive(String userId, bool active) async {
    final row = await _db
        .from('Users_Client')
        .update({'active': active})
        .eq('id', userId)
        .select(_selectUser)
        .single();
    await _callManageUserAuth(userId, active: active);
    return UsersClient.fromJson(row);
  }

  /// Cria o **admin de groupe** de uma empresa (super admin). Reusa a edge
  /// function de convite (senha temporária + e-mail de ativação) e depois define
  /// tipo `admin_groupe`, a empresa e o grupo `admin_groupe`.
  static Future<UsersClient> createAdminGroupe({
    required int entrepriseId,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    final userId = await _inviteUser(fullName: fullName, email: email, phone: phone);
    return _assignToCompany(
      userId: userId,
      entrepriseId: entrepriseId,
      typeCode: 'admin_groupe',
      groupCode: 'admin_groupe',
    );
  }

  /// Cria um **propriétaire** dentro de uma empresa (usado pelo admin de groupe —
  /// fase 2). O e-mail final é `local@domain` da empresa.
  static Future<UsersClient> createProprietaire({
    required int entrepriseId,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    final userId = await _inviteUser(fullName: fullName, email: email, phone: phone);
    return _assignToCompany(
      userId: userId,
      entrepriseId: entrepriseId,
      typeCode: 'proprietaire',
      groupCode: 'proprietaires',
    );
  }

  // ─── Auth ban/unban ─────────────────────────────────────────────────────────

  /// Bane ou desbane o utilizador no Supabase Auth via a edge function
  /// `manage-user-auth`. Sem lançar exceção em caso de falha — o estado no
  /// banco já foi atualizado; o ban Auth é uma camada extra de segurança.
  static Future<void> _callManageUserAuth(String userId, {required bool active}) async {
    try {
      await _db.functions.invoke('manage-user-auth', body: {
        'targetUserId': userId,
        'action': active ? 'unban' : 'ban',
      });
    } catch (_) {}
  }

  // ─── Internos ───────────────────────────────────────────────────────────────

  /// Convida o usuário via a mesma rota que os locataires : a edge function
  /// `invite-locataire` com **`mailTo`** (caixa de teste em dev →
  /// `ADDR_MAIL_CONFIRMATION`) e **`redirectTo`** (URL de ativação correta).
  /// Reusa `EtatDesLieuxDatasource.inviteLocataire` para não duplicar a lógica.
  static Future<String> _inviteUser({
    required String fullName,
    required String email,
    String? phone,
  }) {
    return EtatDesLieuxDatasource.inviteLocataire(
      fullName: fullName,
      email: email,
      proprietaireId: _db.auth.currentUser!.id,
      phone: phone,
    );
  }

  static Future<UsersClient> _assignToCompany({
    required String userId,
    required int entrepriseId,
    required String typeCode,
    required String groupCode,
  }) async {
    final typeRow = await _db
        .from('User_Types_Reference')
        .select('id')
        .eq('code', typeCode)
        .single();
    final groupRow = await _db
        .from('User_Groups')
        .select('id')
        .eq('code', groupCode)
        .single();
    final row = await _db
        .from('Users_Client')
        .update({
          'type_user_id': typeRow['id'],
          'group_id': groupRow['id'],
          'entreprise_id': entrepriseId,
        })
        .eq('id', userId)
        .select(_selectUser)
        .single();
    return UsersClient.fromJson(row);
  }
}
