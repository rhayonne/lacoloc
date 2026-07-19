-- Généralise les notifications à un destinataire quelconque (propriétaire OU
-- locataire) via `recipient_id`, ajoute les policies RLS par destinataire et la
-- RPC `notify_edl_locataire` (symétrique de `notify_edl_proprietaire`).
-- But UX : le locataire reçoit un fil « Messages » (ex. EDL à signer) et la
-- pastille du menu correspondante.

-- 1) Colonne destinataire effectif (legacy = proprietaire_id).
alter table public."Notifications"
  add column if not exists recipient_id uuid references auth.users(id) on delete cascade;

update public."Notifications"
  set recipient_id = proprietaire_id
  where recipient_id is null;

create index if not exists notifications_recipient_idx
  on public."Notifications" (recipient_id, is_read);

-- 2) RLS additive : le destinataire lit / met à jour / supprime ses notifications.
--    (Permissif → s'ajoute aux policies propriétaire existantes ; comme
--     recipient_id = proprietaire_id sur l'existant, rien ne casse.)
drop policy if exists "recipient_select_notifications" on public."Notifications";
create policy "recipient_select_notifications"
  on public."Notifications" for select
  to authenticated
  using (recipient_id = auth.uid());

drop policy if exists "recipient_update_notifications" on public."Notifications";
create policy "recipient_update_notifications"
  on public."Notifications" for update
  to authenticated
  using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

drop policy if exists "recipient_delete_notifications" on public."Notifications";
create policy "recipient_delete_notifications"
  on public."Notifications" for delete
  to authenticated
  using (recipient_id = auth.uid());

-- 3) RPC : crée une notification pour le(s) locataire(s) d'un EDL.
--    SECURITY DEFINER : le destinataire est dérivé de l'EDL (non falsifiable).
create or replace function public.notify_edl_locataire(
  p_edl_id integer,
  p_type   text,
  p_title  text,
  p_body   text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_edl    record;
  v_uid    uuid;
begin
  if not public.can_access_edl(p_edl_id) then
    raise exception 'accès refusé à l''EDL %', p_edl_id;
  end if;

  select id, proprietaire_id, locataire_id, partie
    into v_edl
    from public."etat_de_lieux"
    where id = p_edl_id;

  if v_edl.id is null then
    return;
  end if;

  if v_edl.partie = 'commune' then
    -- Une notification par preneur du collectif.
    for v_uid in
      select distinct locataire_id
        from public."etat_de_lieux_preneurs"
        where etat_de_lieux_id = p_edl_id and locataire_id is not null
    loop
      insert into public."Notifications"
        (proprietaire_id, recipient_id, type, title, body, etat_de_lieux_id, locataire_id, is_read)
      values
        (v_edl.proprietaire_id, v_uid, p_type, p_title, p_body, p_edl_id, v_uid, false);
    end loop;
  elsif v_edl.locataire_id is not null then
    insert into public."Notifications"
      (proprietaire_id, recipient_id, type, title, body, etat_de_lieux_id, locataire_id, is_read)
    values
      (v_edl.proprietaire_id, v_edl.locataire_id, p_type, p_title, p_body, p_edl_id, v_edl.locataire_id, false);
  end if;
end;
$$;

revoke all on function public.notify_edl_locataire(integer, text, text, text) from anon;
grant execute on function public.notify_edl_locataire(integer, text, text, text) to authenticated;
