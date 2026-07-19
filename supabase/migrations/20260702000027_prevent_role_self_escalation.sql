-- =============================================================================
-- Correction de sécurité (CRITIQUE) : escalade de privilèges via self-update.
-- =============================================================================
-- La policy `users_client_update` autorise (id = auth.uid()) sans restreindre
-- les colonnes → n'importe quel utilisateur authentifié pouvait changer son
-- propre `type_user_id` en super_admin (is_super_admin()/current_user_role()
-- dérivent le rôle de cette colonne) et prendre le contrôle total.
--
-- Ce trigger BEFORE UPDATE verrouille tout changement de `type_user_id` sauf :
--   - contexte service role / interne (auth.uid() null) — de confiance ;
--   - super_admin (peut tout changer, cf. users_client_super_admin_update) ;
--   - admin_groupe modifiant un AUTRE utilisateur (déjà borné par la RLS
--     with_check à proprietaire/locataire + même entreprise).
-- =============================================================================
create or replace function public.prevent_role_self_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.type_user_id is distinct from old.type_user_id then
    if (select auth.uid()) is null or public.is_super_admin() then
      return new;
    elsif public.current_user_role() = 'admin_groupe'
          and new.id <> (select auth.uid()) then
      return new; -- borné par la RLS (proprietaire/locataire, même entreprise)
    else
      raise exception 'Modification du type d''utilisateur interdite.'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_role_self_escalation on public."Users_Client";
create trigger trg_prevent_role_self_escalation
  before update on public."Users_Client"
  for each row execute function public.prevent_role_self_escalation();
