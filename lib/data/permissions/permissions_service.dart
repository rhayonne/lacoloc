import 'package:flutter/foundation.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/user_management.dart';

/// Chaves de permissão (espelham `Permissions_Reference.key`).
/// Use estas constantes em vez de strings cruas ao chamar
/// [PermissionsService.can] ou [PermissionGate].
abstract final class Perm {
  // Immeubles
  static const immeublesCreate = 'immeubles.create';
  static const immeublesEdit = 'immeubles.edit';
  static const immeublesDelete = 'immeubles.delete';
  // Chambres
  static const chambresCreate = 'chambres.create';
  static const chambresEdit = 'chambres.edit';
  static const chambresDelete = 'chambres.delete';
  // Pièces
  static const piecesCreate = 'pieces.create';
  static const piecesEdit = 'pieces.edit';
  static const piecesDelete = 'pieces.delete';
  // Inventaire
  static const inventaireCreate = 'inventaire.create';
  static const inventaireEdit = 'inventaire.edit';
  static const inventaireDelete = 'inventaire.delete';
  // Visites
  static const visitesCreate = 'visites.create';
  static const visitesEdit = 'visites.edit';
  static const visitesDelete = 'visites.delete';
  // État des lieux
  static const edlCreate = 'edl.create';
  static const edlEdit = 'edl.edit';
  static const edlDelete = 'edl.delete';
  static const edlFinaliser = 'edl.finaliser';
  static const edlAvenant = 'edl.avenant';
  static const edlAddition = 'edl.addition';
  static const edlAccepter = 'edl.accepter';
  // Finances
  static const facturesCreate = 'factures.create';
  static const facturesEdit = 'factures.edit';
  static const facturesDelete = 'factures.delete';
  static const fournisseursCreate = 'fournisseurs.create';
  static const fournisseursEdit = 'fournisseurs.edit';
  static const fournisseursDelete = 'fournisseurs.delete';
  // Locataires
  static const locatairesInvite = 'locataires.invite';
  static const locatairesView = 'locataires.view';
  // Interactions
  static const demandesView = 'demandes.view';
  static const demandesManage = 'demandes.manage';
  // Administration (super admin)
  static const usersManage = 'users.manage';
  static const permissionsManage = 'permissions.manage';
  static const entreprisesManage = 'entreprises.manage';
  static const referenceManage = 'reference.manage';
  // Entreprise (admin de groupe)
  static const entrepriseComptes = 'entreprise.comptes';
}

/// Permissões efetivas do usuário autenticado, em cache na memória.
///
/// As permissões efetivas (grupo ∪ individuais, zeradas se inativo) são
/// calculadas **no banco** pela RPC `user_effective_permission_ids`. Este
/// serviço apenas as carrega e expõe `can(key)` para o gating de UI — a
/// segurança real continua no RLS/funções do servidor.
///
/// Ciclo de vida: [load] no login, [clear] no logout (em `my_app.dart`).
class PermissionsService {
  PermissionsService._();
  static final PermissionsService instance = PermissionsService._();

  /// Incrementa a cada (re)carga — para `ValueListenableBuilder` reagir.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Set<String> _keys = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Carrega as permissões efetivas do usuário atual.
  Future<void> load() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) {
      _keys = {};
      _loaded = true;
      revision.value++;
      return;
    }
    try {
      final ids = await UserManagementDatasource.effectivePermissionIds(uid);
      final all = await UserManagementDatasource.listAllPermissions();
      _keys = all
          .where((p) => ids.contains(p.id))
          .map((p) => p.key)
          .toSet();
    } catch (_) {
      // Em caso de falha de rede, não bloqueia a app — mantém vazio.
      _keys = {};
    }
    _loaded = true;
    revision.value++;
  }

  void clear() {
    _keys = {};
    _loaded = false;
    revision.value++;
  }

  /// `true` se o usuário possui a permissão [key]. Antes da carga, retorna
  /// `false` (o gating só libera após [load], chamado no login).
  bool can(String key) => _keys.contains(key);

  /// `true` se o usuário tem ao menos uma das [keys].
  bool canAny(Iterable<String> keys) => keys.any(_keys.contains);
}
