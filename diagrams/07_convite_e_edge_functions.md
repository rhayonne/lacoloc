# Convite de Locataire & Edge Functions — Super Loc

## Edge Functions (Deno, `supabase/functions/`)

| Função | Modo | Entrada | Saída | Efeitos |
|---|---|---|---|---|
| `invite-locataire` | **create** | `fullName`, `email`, `proprietaireId`, `phone?`, `dateOfBirth?`, `redirectTo?`, `mailTo?` | `{ userId, emailSent, smtpError? }` | `admin.createUser` com **senha temp aleatória** + `email_confirm:true` + `needs_completion:true`; grava `invited_by_proprietaire_id`; envia e-mail SMTP com a senha temp + link `…/?email&temp`; marca `invitation_email_sent` |
| `invite-locataire` | **resend** | `resend: true`, `userId`, `email`, `fullName?`, `phone?`, `redirectTo?`, `mailTo?` | `{ emailSent, smtpError? }` | `admin.updateUserById` define **nova** senha temp (+ `needs_completion:true`); reenvia o link |
| `invite-locataire` | **test** | `test: true`, `email`, `emailType?` (super_admin) | `{ ok, …, smtpError? }` | só envia e-mail de diagnóstico SMTP (não cria conta) |
| `notify-edl` | — | `edlId`, `event` (`accepte`/`addition`/`a_signer`), `locataireNom?`, `comodo?`, `texte?`, `mailTo?` | `{ sent, smtpError? }` | e-mail SMTP sobre um EDL; destinatário resolvido server-side; campos de texto com escape HTML |
| `delete-account` | — | (JWT no header) | `{ success }` ou `{ error }` | bloqueia se houver `etat_de_lieux` com `locataire_id` = usuário; senão `auth.admin.deleteUser` |
| `notify-proprietaire` | — | `fullName`, `email`, `phone?`, `note?` | best-effort | notifica admin sobre novo cadastro de propriétaire (chamada por `AuthService.notifyProprietaireRegistration`) |

> **🔒 Autenticação/autorização (correções de segurança):**
> - `invite-locataire` **create/resend**: validam o JWT do chamador (`requireManager` → `getUser` + `code`) e exigem `proprietaire`/`admin_groupe`/`super_admin` (401/403). Antes eram abertos → permitiam criar contas ou redefinir a senha de qualquer utilizador (via `userId`) e desviar o link.
> - `invite-locataire` **test**: reservado a `super_admin` (`verify_jwt: true`).
> - `notify-edl`: valida o JWT **e lê o EDL com o cliente do chamador (RLS)** → 403 se não tem acesso; impede disparar e-mails enumerando `edlId`. Campos `locataireNom`/`comodo`/`texte` (+ nomes) passam por escape HTML.
> - `notify_edl_proprietaire` / `notify_edl_locataire`, `search_locataires`, `list_invited_locataires`: `EXECUTE` revogado de `anon`/`PUBLIC` (só `authenticated`).

> **Segredos usados pela `invite-locataire`**: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`,
> `SMTP_PASS`, `SMTP_FROM`, `APP_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
>
> **`redirectTo`** (novo): o cliente passa a URL da página de criação de senha no body
> da chamada. A edge function usa `redirectTo ?? APP_URL` no `generateLink`. O valor vem
> do `.env` do ambiente selecionado (`EtatDesLieuxDatasource._confirmationUrl`):
> `URL_EMAIL_CONFIRMATION_PROD` quando `EnvConfig.isProd`, senão `URL_EMAIL_CONFIRMATION_DEV`.
> O link de ação leva à verificação Supabase → redireciona para a URL (`/confirmation-locataire`);
> o listener em `my_app.dart` detecta `needs_completion` e abre `/completer-inscription`.
>
> **`mailTo`** (override de dev): em **dev**, `inviteLocataire` envia `mailTo =`
> `ADDR_MAIL_CONFIRMATION` (`.env.dev`) como **destinatário do e-mail** — o compte é sempre
> criado com o e-mail real. **Gate de segurança:** nos modos `create`/`resend` o override só
> é honrado se o secret de servidor **`ALLOW_CLIENT_MAIL_OVERRIDE=true`** estiver definido;
> caso contrário (prod, ou projeto único sem o secret) o link de ativação vai **sempre** ao
> e-mail real — impede desviar o link (com a senha temp) para um endereço arbitrário.

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

    PR->>APP: "Enregistrer un nouveau locataire" (nome, email, phone?)
    APP->>EF: invoke('invite-locataire', { create, redirectTo, mailTo? })
    EF->>EF: gera senha temp aleatória
    EF->>AUTH: admin.createUser(email, password:temp, email_confirm:true,\ndata:{full_name, type_code:'locataire', needs_completion:true, phone?, dob?})
    AUTH-->>TRG: novo auth.users (e-mail já confirmado)
    TRG->>UC: cria linha Users_Client (lê raw_user_meta_data)
    EF->>EF: aguarda 400 ms
    EF->>UC: update invited_by_proprietaire_id = proprietaireId
    EF->>SMTP: e-mail com senha temp + link …/?email&temp
    EF->>UC: invitation_email_sent = true
    EF-->>APP: { userId, emailSent }
    APP-->>PR: locataire adicionado como preneur

    LC->>SMTP: recebe e-mail (senha temp + link)
    LC->>APP: clica no link (raiz + ?email&temp)
    APP->>AUTH: signInWithPassword(email, temp) automático
    AUTH-->>APP: signedIn (needs_completion) → /completer-inscription
    LC->>APP: define NOVA senha
    APP->>AUTH: updateUser(password, needs_completion:false)
    AUTH-->>APP: conta ativada → /profile
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
