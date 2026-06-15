---
name: permissions-groups
description: Arquitetura de grupos de usuários e permissões efetivas (User_Groups, enforcement de inativo)
metadata:
  type: project
---

Sistema de permissões da `UtilisateursAdminPage` (super admin), implementado 2026-06-10.

**Tabelas:** `User_Groups` (code/name/type_user_id), `User_Group_Permissions` (group_id↔permission_id), `Users_Client.group_id` (1 grupo por usuário). 3 grupos seed: `proprietaires` (18 perms), `locataires` (0), `super_admins` (18).

**Permissões efetivas** = grupo ∪ individuais (`User_Permissions`), **zeradas se inativo**. Forçado no banco por `user_effective_permission_ids(uuid)` e `has_permission(uuid, text)` (SECURITY DEFINER). Use `current_user_has_permission(key)` para gating server-side.

**Modelo membro vs personnalisé (UI):** ao editar um usuário, se as checkboxes == perms do grupo → fica membro (`group_id` setado, individuais limpas). Se divergir → vira "Personnalisé" (`group_id=null`, set gravado em `User_Permissions`). Isso permite remover uma permissão de UM usuário sem deny-table, pois a união só usa uma fonte por vez.

**RLS:** writes em User_Groups/User_Group_Permissions/User_Permissions e UPDATE de Users_Client exigem `is_super_admin()`. A policy `users_client_super_admin_update` foi adicionada porque antes só existia `id=auth.uid()` — toggleActive/updateUserType de OUTROS usuários falhavam silenciosamente.

Datasource: `UserManagementDatasource` (listGroups, setGroupPermissions, setUserGroup, effectivePermissionIds). Ver [[user-language]].

**Gating de UI (2026-06-10):** `PermissionsService` (singleton, [lib/data/permissions/permissions_service.dart](lib/data/permissions/permissions_service.dart)) carrega as keys efetivas no login (`load()` em my_app.dart `onAuthStateChange`; `clear()` no logout) e expõe `can(key)` + constantes `Perm.*`. Widget `PermissionGate(permission/anyOf, child, fallback)` ([lib/presentation/widgets/permission_gate.dart](lib/presentation/widgets/permission_gate.dart)) esconde botões e reage via `revision` ValueNotifier. Gating aplicado (1ª passada — seções principais): immeubles (create/edit), chambres (create/edit), factures (create/edit), EDL (create/avenant/finaliser/delete/accepter). Falta 2ª passada: pieces, inventaire, visites, fournisseurs, demandes + edit/delete restantes.

**Avenant do locataire:** é o mecanismo de *additions* reaproveitado, exposto na aba **Parties communes** do `EdlIndividuelMeubleePage` (`_buildCommuneAvenantSection`). Locataire com `edl.avenant`, dentro da janela de 30 dias pós-finalização (`_additionsOpen`), adiciona avenant a uma pièce commune → `_addAddition(comodos: _communeComodos)` grava como addition no **privatif** (não no collectif) e notifica o proprietário. RLS já cobre via `locataire_insere_additions`.

**Gating 2ª passada (feito):** PermissionGate aplicado em immeubles (create/edit), chambres (create/edit), pieces (create/edit/delete), inventaire (create/edit/delete), visites (create/edit/delete), fournisseurs (create/edit/delete), factures (create/edit), demandes.manage (toggle contact établi), EDL (create/edit/avenant/finaliser/delete/accepter/addition). **Resta:** `locataires.invite` (botão no widget compartilhado LocataireSearchField).

**Enforcement no servidor (FEITO):** RLS de escrita das tabelas rental agora exige `has_permission(uid, key)` + posse. Helper `can_manage_immeuble(bigint)` = dono OU membro da empresa (`current_user_entreprise_id`). Tabelas: Immeubles, Chambres, Pieces, Inventaire (was FOR ALL→split, SELECT preservado), Factures (idem), Fournisseurs, Visites (idem). super_admin perde escrita rental (correto: não faz locação). Factures/Fournisseurs/Visites continuam owner-scoped (sem company-sharing ainda).

**etat_de_lieux (FEITO):** policy ALL do proprietário dividida em SELECT (sem perm) + INSERT(edl.create)/UPDATE(edl.edit)/DELETE(edl.delete). `locataire_update_accepte` exige edl.accepter. Simplificações: **finaliser ⊆ edl.edit** no RLS (separado só na UI); avenant-proprietário usa edl.create no RLS.

**Tabelas filhas do EDL (FEITO):** `can_write_edl` agora exige `has_permission(edl.edit)` no ramo proprietário/empresa → propaga a cles/preneurs/releves/sections/lignes. `etat_de_lieux_observations` gateado: proprietário insert/update/delete por edl.edit (additions por edl.addition); locataire/preneur additions por edl.addition; participação normal do preneur (observação não-addition no collectif) **não** gateada (inerente).

**locataires.invite (FEITO):** `LocataireSearchField.onCreateNew` agora é nullable → call sites em etat_de_lieux passam `null` se faltar `Perm.locatairesInvite`, escondendo « Enregistrer un nouveau locataire ».

**Anti-lockout reforçado:** verificado 0 usuários sem grupo nem perms individuais.

**Anti-lockout (FEITO):** trigger `trg_set_default_user_group` define group_id a partir do tipo no INSERT e quando o tipo muda (preserva « Personnalisé » = null sem mudança de tipo). Backfill aplicado. Sem isso, usuários criados pelo dialog genérico ficariam sem permissões.

**Refresh runtime (FEITO):** `my_app.dart` recarrega permissões em `AppLifecycleState.resumed` (sem realtime nessas tabelas). Telas do Super Admin continuam gateadas por **tipo** (perms `administration` existem para delegação futura, não enforced).
