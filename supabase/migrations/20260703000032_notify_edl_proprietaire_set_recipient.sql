-- `notify_edl_proprietaire` ne posait pas `recipient_id` (seul `proprietaire_id`
-- l'était). Or les badges/realtime et le modèle de destinataire s'appuient sur
-- `recipient_id = auth.uid()` ; sans lui, la notification « EDL accepté » du
-- propriétaire ne remontait pas de façon fiable. On aligne sur
-- `notify_edl_locataire` en posant recipient_id = propriétaire de l'EDL.

CREATE OR REPLACE FUNCTION public.notify_edl_proprietaire(p_edl_id bigint, p_type text, p_title text, p_body text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_owner uuid;
begin
  if not public.can_access_edl(p_edl_id) then
    raise exception 'not allowed';
  end if;
  select proprietaire_id into v_owner from public.etat_de_lieux where id = p_edl_id;
  if v_owner is null then
    raise exception 'edl not found';
  end if;
  insert into public."Notifications"
    (proprietaire_id, recipient_id, type, title, body, etat_de_lieux_id, locataire_id)
  values (v_owner, v_owner, p_type, p_title, p_body, p_edl_id, (select auth.uid()));
end;
$function$;
