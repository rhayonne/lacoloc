-- Notifier le proprietaire d'une nouvelle demande de contact.
--
-- Contexte : le tableau de bord (Vue générale) unifie désormais tout ce qui
-- doit être notifié au propriétaire dans une seule section « Notifications »
-- (table `Notifications`) — l'ancien bloc ad-hoc « Nouvelles demandes
-- d'interactions » (qui lisait `Demandes_Contact` directement) est retiré.
-- Sans cette RPC, une nouvelle demande de contact ne générait **aucune**
-- ligne dans `Notifications` et disparaissait donc du tableau de bord.
--
-- SECURITY DEFINER (comme notify_edl_proprietaire) : le locataire n'a pas le
-- droit d'INSERT direct dans Notifications (RLS réservée aux RPC). Le
-- destinataire (owner_id de l'immeuble) est dérivé côté serveur, non
-- falsifiable ; on vérifie seulement que l'appelant est bien le locataire de
-- la demande.
create or replace function public.notify_nouvelle_demande(p_demande_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_locataire uuid;
  v_chambre text;
  v_immeuble text;
  v_body text;
begin
  select i.owner_id, d.locataire_id, c.room_name, i.name
    into v_owner, v_locataire, v_chambre, v_immeuble
    from "Demandes_Contact" d
    left join "Immeubles" i on i.id = d.immeuble_id
    left join "Chambres" c on c.id = d.chambre_id
   where d.id = p_demande_id;

  if v_owner is null then
    raise exception 'demande not found';
  end if;
  if v_locataire is distinct from auth.uid() then
    raise exception 'not allowed';
  end if;

  v_body := coalesce(
    nullif(concat_ws(' — ', v_chambre, v_immeuble), ''),
    'Un locataire souhaite entrer en contact.'
  );

  insert into public."Notifications"
    (proprietaire_id, recipient_id, type, title, body, locataire_id)
  values
    (v_owner, v_owner, 'nouvelle_demande', 'Nouvelle demande de contact', v_body, v_locataire);
end;
$$;

revoke execute on function public.notify_nouvelle_demande(bigint) from public, anon;
grant execute on function public.notify_nouvelle_demande(bigint) to authenticated;
