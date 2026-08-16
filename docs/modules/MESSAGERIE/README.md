# Messagerie — Discussions locataire ↔ propriétaire

## Overview

Sistema de comunicação entre locataire e proprietaire. **Um fil de chat por
demanda de contato** (`Demandes_Contact` → N `Messages`).

### Fluxo (modelo « messagerie », desde 2026-07)

```
Locataire abre uma annonce (chambre ou immeuble)
  ↓
"Entrer en contact" → showContactDialog (aviso de dados partilhados + 1ª mensagem)
  ↓
DemandesContactDatasource.createWithMessage()
  → cria Demandes_Contact (statut = nouveau) + envia o 1º Message
  → RPC notify_nouvelle_demande (best-effort) → notificação ao proprietaire
  ↓
💬 O fil já está aberto para os dois lados (NÃO há mais aceitação prévia)
  ↓
Proprietaire abre → statut vira `non_repondu` ; ao responder → `repondu`
```

> ⚠️ O antigo toggle « Contact établi » (`contact_etabli`) **não é mais a
> aceitação** — a coluna existe só por compatibilidade. Quem manda é `statut`.

### Rentrer en contact ≠ cul-de-sac (2026-08)

Já ter contactado **não bloqueia mais** o locataire. Na fiche de annonce
(chambre e immeuble) o botão é decidido por
`DemandesContactDatasource.existingDemandeId(...)` :

| Estado | Botão |
|---|---|
| Nenhum fil (ou só fils `ignore`) | **« Entrer en contact »** → `showContactDialog` |
| Já existe um fil ativo | **« Discuter avec le propriétaire »** → abre o fil com todo o histórico |

Abertura do fil :
- dentro do espaço locataire → **no quadro** (`ChambreDetailView.onOuvrirDiscussion`
  → `LocataireProfilPage._openDiscussion` → menu « Mes discussions » +
  `MessagerieView.initialDemandeId`) ;
- accueil público / rota `/chambre` (sem quadro) → `DiscussionPage`
  ([discussion_page.dart](../../../lib/presentation/messagerie/discussion_page.dart)),
  que carrega a demanda por id (`DemandesContactDatasource.byId`).

## Écran partagé (`lib/presentation/messagerie/`)

**Uma única implementação para os dois perfis.** O ecrã do proprietaire é a
base ; o locataire monta o mesmo widget com outra configuração de papel.

| Ficheiro | Papel |
|---|---|
| [messagerie_model.dart](../../../lib/presentation/messagerie/messagerie_model.dart) | `MessagerieRole`, `MessagerieRoleConfig` (libellés, filtros, direito de gerir), `filterDemandes` / `countByFilter` — **funções puras, testadas sem Supabase** |
| [messagerie_view.dart](../../../lib/presentation/messagerie/messagerie_view.dart) | O ecrã : barra de título + barra de ferramentas + lista + fiche de profil + fil |
| [messagerie_row.dart](../../../lib/presentation/messagerie/messagerie_row.dart) | Uma linha da lista + `DiscussionActionButton` |
| [discussion_page.dart](../../../lib/presentation/messagerie/discussion_page.dart) | Fil em página autónoma (fallback fora dos espaços com quadro) |

Pontos de entrada : `InteractionsPage` (proprietaire, título « Messages ») e
`_MesDiscussionsTab` (locataire, título « Mes discussions »). **Ambos são
wrappers de 10 linhas** — nada de lógica duplicada.

### Regras de layout

- A **barra de título nunca desaparece** (nem durante uma conversa).
- A **barra de ferramentas (busca + chips) só aparece na raiz** : não se procura
  numa lista que não se vê.
- ≥ 820 px : lista à esquerda + **fiche de profil** (360 px) à direita ; o fil
  toma o lugar da lista. < 820 px : um só painel de cada vez (lista → fiche → fil).
- O botão **« Discuter »** vive **numa coluna própria** à direita da linha (não
  por baixo do badge de estado). Abaixo de 520 px vira botão redondo com ícone
  (`chat_bubble_outline`), alvo tátil ≥ 44 px.
- No estreito, o fil tem no header um botão **« Voir le profil »** (a fiche não
  cabe ao lado).

### Filtros por papel

| Papel | Chips |
|---|---|
| Propriétaire | Tous · Nouveau · Non répondu · Répondu · Ignoré |
| Locataire | Tous · En attente · Répondu (`nouveau`/`non_repondu`/`ignore` → « En attente ») |

## Fiche de profil (`UserProfileCard`)

[user_profile_card.dart](../../../lib/presentation/widgets/user_profile_card.dart) —
widget **reutilizável** « quem é esta pessoa » (avatar, nome, sous-titre, badge,
campos, links, ações de rodapé, **botão Fermer**). Usado na messagerie dos dois
perfis e no aperçu de « Mon Profil ». Exporta também `ProfileAvatar`,
`UnreadDot` e `ProfilePill`.

Os dados vêm de `DemandeContactModel.profilInterlocuteur(uid)` → `ProfileCardData`
— o **mesmo** método para os dois lados (o locataire vê o proprietaire, o
proprietaire vê o locataire).

## Préférences d'affichage du profil

`Users_Client.profile_visibility` (JSONB, migration
`20260815174659_users_client_profile_visibility`, **aplicada em prod via MCP em
15/08/2026** — não há ficheiro `.sql` no repo, o histórico está no Supabase) :
chaves `age`, `phone`, `email` (booleanos ; chave ausente = visível). Editado em **Mon Profil → « Ma
fiche de profil »** ([profile_visibility_section.dart](../../../lib/presentation/widgets/profile_visibility_section.dart))
com um **interrupteur por campo** + um **aperçu ao vivo** do próprio
`UserProfileCard`. O **nome completo é sempre visível** (bloqueado) — sem ele
não se sabe a quem se escreve.

O filtro é feito em `ProfileCardData` : um campo mascarado **nunca chega à
camada UI**.

### Defaults assimétricos (RGPD)

`ProfileVisibility.defaultsFor(isLocataire:)` — uma chave ausente **não** quer
dizer « visível » para toda a gente :

| Papel | Default | Porquê |
|---|---|---|
| Locataire | tudo visível (`consentiDefaults`) | o pop-up « Entrer en contact » enumera o que vai ser transmitido e ele valida ao enviar → consentimento informado |
| Proprietaire / admin entreprise / super admin | nada visível (`minimalDefaults`) | ninguém lhe pediu autorização para difundir os contactos → **nada sai por omissão** (minimização, art. 5.1.c ; proteção por defeito, art. 25.2) |

Sem embed de `User_Types_Reference`, assume-se o default **mais protetor**.
Nenhuma migração de dados foi necessária : `{}` continua a significar « nunca
escolhi », só mudou a leitura.

### O masquage é aplicado no SERVIDOR (2026-08-15)

A política `users_client_select_demande_counterpart` — que abria a **linha
inteira** da contraparte — foi **apagada** (assim como `shares_demande_with`).
A identidade da outra parte passa agora só pela RPC :

```
demande_counterpart_profiles(p_demande_ids bigint[])  -- SECURITY DEFINER
  → demande_id, user_id, full_name, age, phone, email
```

- Só responde às **duas partes** da demanda (um terceiro recebe zero linhas).
- Devolve **sempre** o nome (sem ele não se sabe a quem se escreve) e **só** os
  campos que a pessoa aceita mostrar — defaults assimétricos calculados em SQL,
  espelho de `ProfileVisibility.defaultsFor`.
- Um campo mascarado **não é transmitido** : não está na resposta HTTP. Abrir o
  DevTools ou chamar a API à mão não dá nada de mais.

**Fim do harvesting** : criar uma demanda em qualquer anúncio já não dá acesso à
ficha do proprietário. Antes, uma conta criada só para isso colhia telefone +
e-mail a 20/hora (o limite do `trg_demandes_contact_rate_limit`).

**Por que não `revoke select (phone, email)`** : o revoke é por *role* e atinge
toda a tabela — quebraria 6 datasources (incl. telas de admin) e impediria cada
um de ler a **própria** linha. O corte cirúrgico tira só o acesso injustificado
(uma simples demanda) e deixa intactos os legítimos, que têm políticas próprias :
`users_client_select` (a própria linha), `proprietaire_can_read_linked_locataires`
(**contrato real** via `etat_de_lieux`), `users_client_admin_groupe_select`,
`is_super_admin()`.

**No cliente** : `_select` de `Demandes_Contact` não embarca nenhum
`Users_Client` ; `DemandeContactModel` não carrega dado pessoal nenhum (só ids +
o bien) ; a ficha vem de `counterpartProfiles(ids)` e é passada explicitamente a
`MessagerieRow`, `UserProfileCard` e `ConversationView(interlocuteur:)`.
`MessagesDatasource` deixou de embarcar o nome do remetente.

### Tabelas

- **Demandes_Contact** : `statut` (`nouveau`/`non_repondu`/`repondu`/`ignore`)
- **Messages** : `demande_id`, `sender_id`, `recipient_id`, `body`, `read_at`
- **Users_Client** : `profile_visibility` (JSONB)

### RLS

- Locataire lê as suas demandas ; proprietaire as das suas propriedades.
- `Messages` SELECT = `auth.uid() IN (sender_id, recipient_id)` — **desnormalizado
  de propósito** (o `realtime.list_changes` avalia esta política a cada evento).
- INSERT em `Messages` : verificações pesadas (`can_access_demande`) só aqui.
- UPDATE em `Messages` : só `read_at` (trigger `trg_messages_only_read_at`).
- DELETE só do próprio `sender_id`.

---

## 🔗 Relacionados

- DATASOURCES.md — MessagesDatasource, DemandesContactDatasource
- DATA_MODEL.md — Tabelas
- RLS.md — Políticas
- NOTIFICATIONS.md — Evento `nouvelle_demande`

**Ver também** : CLAUDE.md seção « Messagerie »
