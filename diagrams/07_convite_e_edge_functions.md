# Convite de Locataire & Edge Functions — La Coloc

## Edge Functions (Deno, `supabase/functions/`)

| Função | Modo | Entrada | Saída | Efeitos |
|---|---|---|---|---|
| `invite-locataire` | **create** | `fullName`, `email`, `proprietaireId`, `phone?`, `dateOfBirth?` | `{ userId, emailSent, smtpError? }` | `generateLink('invite')` → cria `auth.users`; aguarda 400 ms o trigger; grava `invited_by_proprietaire_id`; envia e-mail SMTP; marca `invitation_email_sent`/`invitation_sent_at` |
| `invite-locataire` | **resend** | `resend: true`, `userId`, `email`, `fullName`, `phone?` | `{ emailSent, smtpError? }` | `generateLink('magiclink')` → reenvia e-mail; remarca status |
| `delete-account` | — | (JWT no header) | `{ success }` ou `{ error }` | bloqueia se houver `etat_de_lieux` com `locataire_id` = usuário; senão `auth.admin.deleteUser` |
| `notify-proprietaire` | — | `fullName`, `email`, `phone?`, `note?` | best-effort | notifica admin sobre novo cadastro de propriétaire (chamada por `AuthService.notifyProprietaireRegistration`) |

> **Segredos usados pela `invite-locataire`**: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`,
> `SMTP_PASS`, `SMTP_FROM`, `APP_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
> O link de ação leva ao `APP_URL` → o app abre `/completer-inscription`.

---

## Fluxo de Convite (create)

```mermaid
sequenceDiagram
    actor PR as Propriétaire
    participant APP as Flutter App
    participant EF as Edge Fn invite-locataire
    participant AUTH as Supabase Auth (admin)
    participant TRG as Trigger on_auth_user_created
    participant UC as Users_Client
    participant SMTP as SMTP (nodemailer)
    actor LC as Locataire

    PR->>APP: "Créer un locataire" (nome, email, phone?, dob?)
    APP->>EF: invoke('invite-locataire', { create })
    EF->>AUTH: generateLink('invite', email, data:{full_name, type_code:'locataire', needs_completion, phone?, dob?})
    AUTH-->>TRG: novo auth.users
    TRG->>UC: cria linha Users_Client (lê raw_user_meta_data)
    EF->>EF: aguarda 400 ms
    EF->>UC: update invited_by_proprietaire_id = proprietaireId
    EF->>SMTP: envia e-mail com action_link
    EF->>UC: invitation_email_sent = true, invitation_sent_at = now()
    EF-->>APP: { userId, emailSent }
    APP-->>PR: chip do locataire selecionado

    LC->>SMTP: recebe e-mail
    LC->>APP: clica no link → /completer-inscription
    APP->>AUTH: define senha + completa perfil
    AUTH-->>APP: sessão ativa → AuthGate → LocataireProfil
```

---

## Fluxo de Reenvio (resend)

```mermaid
sequenceDiagram
    actor PR as Propriétaire
    participant APP as EtatDesLieuxPage (card Invités)
    participant EF as Edge Fn invite-locataire
    participant AUTH as Supabase Auth (admin)
    participant SMTP as SMTP

    PR->>APP: "Renvoyer →" num locataire invité
    APP->>EF: invoke('invite-locataire', { resend:true, userId, email, fullName })
    EF->>AUTH: generateLink('magiclink', email)
    EF->>SMTP: reenvia e-mail
    EF->>EF: remarca invitation_email_sent/sent_at
    EF-->>APP: { emailSent }
```

---

## Fluxo de Exclusão de Conta

```mermaid
sequenceDiagram
    actor U as Usuário (locataire)
    participant APP as Profil (Zone dangereuse)
    participant EF as Edge Fn delete-account
    participant DB as Supabase

    U->>APP: "Supprimer mon compte" (confirmação)
    APP->>EF: invoke('delete-account') (JWT no header)
    EF->>DB: getUser() (valida JWT)
    EF->>DB: count etat_de_lieux WHERE locataire_id = user.id
    alt count > 0
        EF-->>APP: { error: "associé à des contrats existants" } (400)
        APP-->>U: bloqueia exclusão (botão desabilitado se hasContrats)
    else
        EF->>DB: auth.admin.deleteUser(user.id)
        EF-->>APP: { success: true }
        APP->>APP: signOut → / (home)
    end
```

> No `LocataireProfil`, o botão de exclusão já é desabilitado de antemão via
> `EtatDesLieuxDatasource.hasContratsLocataire(uid)` (UX otimista), e a edge function
> reforça a regra no servidor.

---

## RPCs (PostgreSQL `SECURITY DEFINER`)

| RPC | Parâmetros | Uso |
|---|---|---|
| `search_locataires` | `search_query` | Autocomplete de locataires no formulário de EDL |
| `list_invited_locataires` | `p_proprietaire_id` | Card "Locataires invités" (filtra `invited_by_proprietaire_id`) |

Ambas são chamadas via `supabase.rpc(...)` e retornam linhas compatíveis com
`UsersClient.fromJson`.
