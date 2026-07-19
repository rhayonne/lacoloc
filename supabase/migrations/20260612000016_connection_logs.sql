-- Logs de connexion : enregistre chaque connexion réussie (IP, user agent,
-- appareil, navigateur, fuseau horaire). Lecture réservée au super_admin ;
-- insertion uniquement via la edge function log-connection (service role).

create table public.connection_logs (
  id            bigserial primary key,
  user_id       uuid references auth.users(id) on delete set null,
  user_email    text,
  user_name     text,
  user_type     text,          -- locataire / proprietaire / super_admin / …
  ip_address    text,
  user_agent    text,
  device        text,          -- Windows / Mac / iPhone / Android / Linux / …
  browser       text,          -- Chrome / Firefox / Safari / Edge / …
  timezone      text,
  created_at    timestamptz default now() not null
);

alter table public.connection_logs enable row level security;

-- Seul le super_admin peut lire les logs.
create policy "super_admin_select_connection_logs"
  on public.connection_logs for select
  to authenticated
  using (
    exists (
      select 1
      from public."Users_Client" uc
      join public."User_Types_Reference" utr on utr.id = uc.type_user_id
      where uc.id = auth.uid() and utr.code = 'super_admin'
    )
  );

-- Aucune politique INSERT/UPDATE/DELETE pour les utilisateurs :
-- les insertions se font exclusivement via la edge function (service role).

create index idx_connection_logs_created_at on public.connection_logs(created_at desc);
create index idx_connection_logs_user_id    on public.connection_logs(user_id);
create index idx_connection_logs_user_type  on public.connection_logs(user_type);
