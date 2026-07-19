-- Migration inicial do domínio "Room Rental" do La Coloc / Super Coloc.
-- Cria tabelas, índices, RLS e seeds das tabelas de referência.
-- Os identificadores ficam entre aspas porque seguimos o naming PascalCase do
-- CLAUDE.md (Immeubles, Chambres etc.). Em projetos novos, prefira snake_case.

-- =============================================================================
-- 1. Users_Client : perfis estendidos do auth.users
-- =============================================================================
create table if not exists public."Users_Client" (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text not null,
  full_name   text,
  type_client text not null check (type_client in ('locataire', 'proprietaire', 'super_admin')),
  created_at  timestamptz not null default now()
);

-- Filtros frequentes por tipo (ex: dashboards de admin).
create index if not exists "Users_Client_type_client_idx"
  on public."Users_Client" (type_client);

-- =============================================================================
-- 2. Tabelas de referência (editáveis apenas pelo Super Admin)
-- =============================================================================
create table if not exists public."Immeuble_Types_Reference" (
  id   bigint generated always as identity primary key,
  name text not null unique
);

create table if not exists public."Options_Reference" (
  id   bigint generated always as identity primary key,
  name text not null unique
);

-- =============================================================================
-- 3. Immeubles : container do quarto (apartamento, casa, etc.)
-- =============================================================================
create table if not exists public."Immeubles" (
  id            bigint generated always as identity primary key,
  owner_id      uuid not null references public."Users_Client" (id) on delete cascade,
  name          text not null,
  address       text,
  total_m2      numeric(8, 2),
  description   text,
  common_photos text[] not null default '{}',
  created_at    timestamptz not null default now()
);

-- Postgres não cria índices automáticos para FKs: necessários para joins/cascade.
create index if not exists "Immeubles_owner_id_idx"
  on public."Immeubles" (owner_id);

-- =============================================================================
-- 3.1 Junção N-N: Immeubles <-> Immeuble_Types_Reference
-- Um imóvel pode ter vários tipos (ex: Appartement + Loft).
-- =============================================================================
create table if not exists public."Immeubles_Types" (
  immeuble_id bigint not null references public."Immeubles" (id) on delete cascade,
  type_id     bigint not null references public."Immeuble_Types_Reference" (id) on delete restrict,
  primary key (immeuble_id, type_id)
);

-- A PK já cobre lookups por immeuble_id; criamos o índice "reverso" para
-- consultas tipo "todos os imóveis do tipo X".
create index if not exists "Immeubles_Types_type_id_idx"
  on public."Immeubles_Types" (type_id);

-- =============================================================================
-- 4. Chambres : o "produto" alugado, vinculado a um imóvel
-- =============================================================================
create table if not exists public."Chambres" (
  id               bigint generated always as identity primary key,
  immeuble_id      bigint not null references public."Immeubles" (id) on delete cascade,
  room_name        text not null,
  m2               numeric(6, 2),
  description      text,
  room_photos      text[] not null default '{}',
  selected_options bigint[] not null default '{}',
  created_at       timestamptz not null default now()
);

create index if not exists "Chambres_immeuble_id_idx"
  on public."Chambres" (immeuble_id);
-- GIN p/ buscas sobre o array de opcionais (ex: "tem Wifi e Bureau").
create index if not exists "Chambres_selected_options_gin_idx"
  on public."Chambres" using gin (selected_options);

-- =============================================================================
-- 5. Helper: papel do usuário corrente (cacheável dentro de policies)
-- SECURITY DEFINER permite ler Users_Client mesmo sob RLS.
-- =============================================================================
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select type_client from public."Users_Client" where id = (select auth.uid())
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select type_client from public."Users_Client" where id = (select auth.uid())) = 'super_admin',
    false
  )
$$;

-- =============================================================================
-- 6. Row Level Security
-- =============================================================================
alter table public."Users_Client"             enable row level security;
alter table public."Immeuble_Types_Reference" enable row level security;
alter table public."Options_Reference"        enable row level security;
alter table public."Immeubles"                enable row level security;
alter table public."Immeubles_Types"          enable row level security;
alter table public."Chambres"                 enable row level security;

-- ---- Users_Client ----------------------------------------------------------
-- Cada usuário só vê/edita seu próprio perfil. Super admin enxerga tudo.
drop policy if exists users_client_select_self on public."Users_Client";
create policy users_client_select_self on public."Users_Client"
  for select to authenticated
  using (id = (select auth.uid()) or public.is_super_admin());

drop policy if exists users_client_insert_self on public."Users_Client";
create policy users_client_insert_self on public."Users_Client"
  for insert to authenticated
  with check (id = (select auth.uid()));

drop policy if exists users_client_update_self on public."Users_Client";
create policy users_client_update_self on public."Users_Client"
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ---- Tabelas de referência -------------------------------------------------
-- Leitura pública (anon + authenticated). Escrita só super_admin.
drop policy if exists types_select_all on public."Immeuble_Types_Reference";
create policy types_select_all on public."Immeuble_Types_Reference"
  for select to anon, authenticated
  using (true);

drop policy if exists types_write_admin on public."Immeuble_Types_Reference";
create policy types_write_admin on public."Immeuble_Types_Reference"
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists options_select_all on public."Options_Reference";
create policy options_select_all on public."Options_Reference"
  for select to anon, authenticated
  using (true);

drop policy if exists options_write_admin on public."Options_Reference";
create policy options_write_admin on public."Options_Reference"
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ---- Immeubles -------------------------------------------------------------
-- Lista pública. Escrita só pelo dono (proprietaire) ou super_admin.
drop policy if exists immeubles_select_all on public."Immeubles";
create policy immeubles_select_all on public."Immeubles"
  for select to anon, authenticated
  using (true);

drop policy if exists immeubles_insert_owner on public."Immeubles";
create policy immeubles_insert_owner on public."Immeubles"
  for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and (public.current_user_role() in ('proprietaire', 'super_admin'))
  );

drop policy if exists immeubles_update_owner on public."Immeubles";
create policy immeubles_update_owner on public."Immeubles"
  for update to authenticated
  using (owner_id = (select auth.uid()) or public.is_super_admin())
  with check (owner_id = (select auth.uid()) or public.is_super_admin());

drop policy if exists immeubles_delete_owner on public."Immeubles";
create policy immeubles_delete_owner on public."Immeubles"
  for delete to authenticated
  using (owner_id = (select auth.uid()) or public.is_super_admin());

-- ---- Immeubles_Types (junção) ---------------------------------------------
-- Lista pública. Escrita só pelo dono do imóvel.
drop policy if exists immeubles_types_select_all on public."Immeubles_Types";
create policy immeubles_types_select_all on public."Immeubles_Types"
  for select to anon, authenticated
  using (true);

drop policy if exists immeubles_types_write_owner on public."Immeubles_Types";
create policy immeubles_types_write_owner on public."Immeubles_Types"
  for all to authenticated
  using (
    exists (
      select 1 from public."Immeubles" i
      where i.id = immeuble_id
        and (i.owner_id = (select auth.uid()) or public.is_super_admin())
    )
  )
  with check (
    exists (
      select 1 from public."Immeubles" i
      where i.id = immeuble_id
        and (i.owner_id = (select auth.uid()) or public.is_super_admin())
    )
  );

-- ---- Chambres --------------------------------------------------------------
-- Lista pública. Escrita só pelo dono do imóvel pai.
drop policy if exists chambres_select_all on public."Chambres";
create policy chambres_select_all on public."Chambres"
  for select to anon, authenticated
  using (true);

drop policy if exists chambres_insert_owner on public."Chambres";
create policy chambres_insert_owner on public."Chambres"
  for insert to authenticated
  with check (
    exists (
      select 1 from public."Immeubles" i
      where i.id = immeuble_id
        and (i.owner_id = (select auth.uid()) or public.is_super_admin())
    )
  );

drop policy if exists chambres_update_owner on public."Chambres";
create policy chambres_update_owner on public."Chambres"
  for update to authenticated
  using (
    exists (
      select 1 from public."Immeubles" i
      where i.id = immeuble_id
        and (i.owner_id = (select auth.uid()) or public.is_super_admin())
    )
  )
  with check (
    exists (
      select 1 from public."Immeubles" i
      where i.id = immeuble_id
        and (i.owner_id = (select auth.uid()) or public.is_super_admin())
    )
  );

drop policy if exists chambres_delete_owner on public."Chambres";
create policy chambres_delete_owner on public."Chambres"
  for delete to authenticated
  using (
    exists (
      select 1 from public."Immeubles" i
      where i.id = immeuble_id
        and (i.owner_id = (select auth.uid()) or public.is_super_admin())
    )
  );

-- =============================================================================
-- 7. Seeds das tabelas de referência (idempotente via ON CONFLICT)
-- =============================================================================
insert into public."Immeuble_Types_Reference" (name) values
  ('Appartement'),
  ('Maison'),
  ('Studio'),
  ('Loft'),
  ('Duplex')
on conflict (name) do nothing;

insert into public."Options_Reference" (name) values
  ('Lit simple'),
  ('Lit double'),
  ('Douche'),
  ('Salle de bain privée'),
  ('Armoire'),
  ('Bureau'),
  ('Wifi'),
  ('Climatisation'),
  ('Chauffage'),
  ('Balcon'),
  ('Fenêtre'),
  ('Prise réseau')
on conflict (name) do nothing;
