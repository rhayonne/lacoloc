-- Historique des messages diffusés par le super admin + média (image/YouTube).
create table if not exists public."Admin_Messages" (
  id               bigserial primary key,
  sender_id        uuid not null references auth.users(id) on delete cascade,
  title            text not null,
  body             text,
  media_type       text check (media_type in ('image','youtube')),
  media_url        text,
  audience         text,
  recipients_count integer not null default 0,
  created_at       timestamptz not null default now()
);

alter table public."Admin_Messages" enable row level security;

drop policy if exists "admin_messages_super_admin_select" on public."Admin_Messages";
create policy "admin_messages_super_admin_select"
  on public."Admin_Messages" for select to authenticated
  using (public.is_super_admin());

grant select on public."Admin_Messages" to authenticated;
grant usage, select on sequence "Admin_Messages_id_seq" to authenticated;

-- Notifications : média + lien vers le message diffusé.
alter table public."Notifications"
  add column if not exists media_type text,
  add column if not exists media_url text,
  add column if not exists admin_message_id bigint references public."Admin_Messages"(id) on delete set null;

-- RPC mise à jour : enregistre le message dans l'historique + diffuse.
drop function if exists public.admin_broadcast_notification(uuid[], text, text, text);
create or replace function public.admin_broadcast_notification(
  p_recipient_ids uuid[],
  p_type       text,
  p_title      text,
  p_body       text default null,
  p_media_type text default null,
  p_media_url  text default null,
  p_audience   text default null
) returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid;
  v_count  integer := 0;
  v_msg_id bigint;
begin
  if not public.is_super_admin() then
    raise exception 'accès refusé : super admin requis';
  end if;
  if p_title is null or length(btrim(p_title)) = 0 then
    raise exception 'titre requis';
  end if;
  if p_media_type is not null and p_media_type not in ('image','youtube') then
    raise exception 'type de média invalide';
  end if;

  v_count := coalesce(array_length(p_recipient_ids, 1), 0);

  insert into public."Admin_Messages"
    (sender_id, title, body, media_type, media_url, audience, recipients_count)
  values
    (auth.uid(), p_title, p_body, p_media_type, p_media_url, p_audience, v_count)
  returning id into v_msg_id;

  foreach v_uid in array coalesce(p_recipient_ids, array[]::uuid[])
  loop
    insert into public."Notifications"
      (proprietaire_id, recipient_id, type, title, body, media_type, media_url, admin_message_id, is_read)
    values
      (v_uid, v_uid, coalesce(p_type, 'admin_message'), p_title, p_body, p_media_type, p_media_url, v_msg_id, false);
  end loop;

  return v_msg_id;
end;
$$;

revoke all on function public.admin_broadcast_notification(uuid[], text, text, text, text, text, text) from anon, public;
grant execute on function public.admin_broadcast_notification(uuid[], text, text, text, text, text, text) to authenticated;
