-- Tabela de referência de tipos de utilizador.
-- Substitui o check-constraint inline em Users_Client.type_client.

-- =============================================================================
-- 1. Criar tabela de referência
-- =============================================================================
create table if not exists public."User_Types_Reference" (
  id          bigint generated always as identity primary key,
  code        text not null unique,   -- chave programática: 'locataire', 'proprietaire', 'super_admin'
  label       text not null,          -- rótulo legível: 'Locataire', 'Propriétaire', 'Super Admin'
  description text
);

-- Leitura pública; escrita só super_admin (mesma política das outras referências).
alter table public."User_Types_Reference" enable row level security;

create policy "user_types_select_all" on public."User_Types_Reference"
  for select to anon, authenticated
  using (true);

create policy "user_types_write_admin" on public."User_Types_Reference"
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- =============================================================================
-- 2. Seed dos tipos
-- =============================================================================
insert into public."User_Types_Reference" (code, label, description) values
  ('locataire',    'Locataire',    'Inquilino que aluga um quarto na plataforma'),
  ('proprietaire', 'Propriétaire', 'Dono de imóveis que anuncia quartos'),
  ('super_admin',  'Super Admin',  'Administrador da plataforma com acesso total')
on conflict (code) do update
  set label       = excluded.label,
      description = excluded.description;

-- =============================================================================
-- 3. Adicionar coluna FK em Users_Client
-- =============================================================================
-- Passo 1: adiciona coluna nullable (sem FK ainda) e preenche com base no text
alter table public."Users_Client"
  add column if not exists type_user_id bigint;

update public."Users_Client" uc
set type_user_id = (
  select utr.id
  from public."User_Types_Reference" utr
  where utr.code = uc.type_client
)
where type_user_id is null;

-- Passo 2: aplica FK e índice
alter table public."Users_Client"
  add constraint fk_users_client_type_user
  foreign key (type_user_id)
  references public."User_Types_Reference"(id)
  on delete restrict;

create index if not exists "Users_Client_type_user_id_idx"
  on public."Users_Client" (type_user_id);

-- =============================================================================
-- 4. Atualizar a função current_user_role() para usar ambas as colunas
--    (mantém compatibilidade: ainda devolve o code text)
-- =============================================================================
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select utr.code
     from public."Users_Client" uc
     join public."User_Types_Reference" utr on utr.id = uc.type_user_id
     where uc.id = (select auth.uid())),
    (select type_client from public."Users_Client" where id = (select auth.uid()))
  )
$$;
