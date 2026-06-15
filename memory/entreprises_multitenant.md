---
name: entreprises-multitenant
description: Multi-tenancy de empresas, tipo admin_groupe e escopo de imóveis por empresa
metadata:
  type: project
---

Multi-tenant de **empresas** (Fase 1 — fundação + Super Admin), 2026-06-10. Decisões: usuários criados pelo adminGroupe são sempre **propriétaires**; **todos da empresa veem todos** os imóveis da empresa.

**Schema:** tabela `Entreprises` (name, domain, active, created_by). `Users_Client.entreprise_id` + `Immeubles.entreprise_id` (FKs). Novo tipo `admin_groupe` (id 5) em User_Types_Reference. Função `current_user_entreprise_id()`. Trigger `trg_set_immeuble_entreprise` herda a empresa do owner no INSERT do imóvel (multi-tenant automático).

**RLS:** Entreprises — super admin total; membro lê a própria; **domínio só super admin altera** (writes=is_super_admin). Immeubles update/delete liberados também para membros da mesma empresa (`entreprise_id = current_user_entreprise_id()`); insert aceita role admin_groupe.

**Permissões/grupos (refinados):** super_admins=só categoria `administration` (users.manage, permissions.manage, entreprises.manage, reference.manage); proprietaires=rental (sem admin/entreprise); admin_groupe (novo grupo)=rental + `entreprise.comptes`; locataires=edl.avenant/addition/accepter. Categorias novas: `administration`, `entreprise`. Ver [[permissions-groups]].

**Dart:** `Entreprise` model, `EntreprisesDatasource` (listAll/create/update/listMembers/createAdminGroupe/createProprietaire). `UserType.adminGroupe`. Super Admin → menu **Comptes Entreprises** ([comptes_entreprises_page.dart](lib/presentation/users/admin/comptes_entreprises_page.dart)): criar empresa+domínio, criar adminGroupe. AuthGate roteia admin_groupe → ProprietaireProfilPage.

**Fase 2 (FEITO):** `ImmeublesDatasource.listByOwner` agora é company-aware (cache `_entrepriseIdOf`; se o user tem empresa → lista por entreprise_id; limpa no logout). RLS: adminGroupe (role admin_groupe) lê/atualiza usuários da própria empresa (`users_client_admin_groupe_select/update`), com WITH CHECK impedindo escalonamento (só proprietaire/locataire na própria empresa). Dashboard adminGroupe (ProprietaireProfil) tem botão de footer **« Configuration entreprise »** → `EntrepriseConfigPage` (aba **Comptes**): lista membros + cria propriétaires com email `local@domínio` (domínio fixo/read-only, só `local` editável). `EntreprisesDatasource.byId/createProprietaire`.

**Company-sharing completo (FEITO):** `entreprise_id` adicionado a Factures/Fournisseurs/Visites/etat_de_lieux (+ triggers `set_entreprise_from_owner`/`set_edl_entreprise` herdando do owner/proprietaire + backfill). RLS dessas tabelas e `can_access_edl`/`can_write_edl` agora incluem o ramo `entreprise_id = current_user_entreprise_id()`. Datasources company-aware via **`SessionScope.currentEntrepriseId()`** ([session_scope.dart](lib/data/datasources/session_scope.dart), cache, limpo no logout): factures/fournisseurs/edl filtram por entreprise_id quando há empresa; visites já dependia do RLS. Imóveis via `ImmeublesDatasource` (cache próprio). **Demandes_Contact** continua owner-scoped (não compartilhado).

**Nota:** company-sharing só "ativa" quando existe empresa; sem empresa, entreprise_id é null em tudo → comportamento idêntico ao owner-scoped (sem regressão).

**Reset de senha + desativação (FEITO):** `EntreprisesDatasource.resetPassword(userId,email)` delega a `resendInvitation` (nova senha temp + link de ativação, sem senha anterior; dev → ADDR_MAIL_CONFIRMATION). Botão « Réinitialiser le mot de passe » por membro na aba Comptes do **admin de groupe** (não para si) e no super admin. **Super admin** (ComptesEntreprises): Switch de ativo por membro (`setMemberActive`) + Switch de ativo da **empresa** (`update active`). Desativar a empresa **zera as permissões de todos os membros**: `user_effective_permission_ids` agora exige `u.active AND (entreprise_id IS NULL OR Entreprises.active)`. Não há "sub-grupos" no modelo — a empresa é o agrupamento. Reset depende de SMTP configurado nos secrets da Edge Function.
