-- Communication super admin : diffuser une notification in-app à un ensemble
-- d'utilisateurs (apparaît dans leur tableau de bord + menu « Messages »).
--
-- L'audience (tous / par type / par groupe / utilisateurs spécifiques) est
-- résolue côté application, qui passe ici la liste explicite des destinataires.
-- La RPC est SECURITY DEFINER et n'accepte que le super admin (les INSERT
-- directs dans Notifications restent réservés aux RPC).
create or replace function public.admin_broadcast_notification(
  p_recipient_ids uuid[],
  p_type  text,
  p_title text,
  p_body  text default null
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid;
  v_count integer := 0;
begin
  -- Seul le super admin peut diffuser.
  if not public.is_super_admin() then
    raise exception 'accès refusé : super admin requis';
  end if;

  if p_title is null or length(btrim(p_title)) = 0 then
    raise exception 'titre requis';
  end if;

  foreach v_uid in array coalesce(p_recipient_ids, array[]::uuid[])
  loop
    -- proprietaire_id = recipient_id : la notification reste visible uniquement
    -- par son destinataire (RLS par recipient_id ; pas de fuite via la policy
    -- héritée par proprietaire_id).
    insert into public."Notifications"
      (proprietaire_id, recipient_id, type, title, body, is_read)
    values
      (v_uid, v_uid, coalesce(p_type, 'admin_message'), p_title, p_body, false);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.admin_broadcast_notification(uuid[], text, text, text) from anon, public;
grant execute on function public.admin_broadcast_notification(uuid[], text, text, text) to authenticated;
