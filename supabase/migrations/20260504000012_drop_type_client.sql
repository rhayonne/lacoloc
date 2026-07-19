-- Remove a coluna legada type_client de Users_Client.
-- O tipo de utilizador passa a ser gerido exclusivamente via type_user_id (FK para User_Types_Reference).

-- =============================================================================
-- 1. Trigger: usa type_code da metadata para lookup em User_Types_Reference
-- =============================================================================
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public."Users_Client" (id, email, full_name, type_user_id)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    coalesce(
      (select id from public."User_Types_Reference"
       where code = coalesce(new.raw_user_meta_data ->> 'type_code', 'locataire')),
      (select id from public."User_Types_Reference" where code = 'locataire')
    )
  )
  on conflict (id) do update set
    email     = excluded.email,
    full_name = coalesce(excluded.full_name, public."Users_Client".full_name);
  return new;
end;
$$;

-- =============================================================================
-- 2. is_super_admin() — apenas type_user_id
-- =============================================================================
create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select utr.code = 'super_admin'
     from public."Users_Client" uc
     join public."User_Types_Reference" utr on utr.id = uc.type_user_id
     where uc.id = (select auth.uid())),
    false
  )
$$;

-- =============================================================================
-- 3. current_user_role() — apenas type_user_id
-- =============================================================================
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select utr.code
  from public."Users_Client" uc
  join public."User_Types_Reference" utr on utr.id = uc.type_user_id
  where uc.id = (select auth.uid())
$$;

-- =============================================================================
-- 4. NOT NULL em type_user_id
-- =============================================================================
update public."Users_Client"
set type_user_id = (select id from public."User_Types_Reference" where code = 'locataire')
where type_user_id is null;

alter table public."Users_Client"
  alter column type_user_id set not null;

-- =============================================================================
-- 5. Remover índice e coluna type_client
-- =============================================================================
drop index if exists public."Users_Client_type_client_idx";

alter table public."Users_Client"
  drop column if exists type_client;
