# Edge Functions - Deno

## Funções

1. **invite-locataire**: Criar/reenviar convite, test email
2. **notify-edl**: Email de EDL (accepte, addition, a_signer)
3. **notify-rendezvous**: Convites de rendez-vous
4. **manage-user-auth**: ban/unban/set_password
5. **delete-account**: Soft-delete

**Location**: `supabase/functions/<name>/`

**Segurança**: JWT validation obrigatória (exceto test mode em dev)
