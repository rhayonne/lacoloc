-- Suppression ATOMIQUE du collectif orphelin d'un bail individuel.
-- Contexte : le collectif (partie=commune, type_bail=individuel) est un détail
-- d'implémentation invisible dans les listes. Quand le DERNIER privatif d'un
-- contrat est supprimé, le collectif devenu orphelin doit partir avec — sinon
-- il reste invisible/indélébile et findOpenCollectif peut le ressusciter dans
-- un nouveau contrat. Fait côté DB (trigger) pour être atomique : plus de
-- fenêtre de crash/course entre « delete privatif » et « delete collectif »
-- comme dans l'ancienne implémentation client (EtatDesLieuxDatasource.delete).
-- Garde : jamais un collectif finalisé.

create or replace function public.delete_orphan_collectif()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.partie = 'privative' and old.edl_collectif_id is not null then
    delete from public.etat_de_lieux c
    where c.id = old.edl_collectif_id
      and c.partie = 'commune'
      and (c.situation is null or c.situation <> 'finalise')
      and not exists (
        select 1 from public.etat_de_lieux p
        where p.edl_collectif_id = c.id
      );
  end if;
  return old;
end;
$$;

revoke execute on function public.delete_orphan_collectif() from public, anon, authenticated;

drop trigger if exists trg_delete_orphan_collectif on public.etat_de_lieux;
create trigger trg_delete_orphan_collectif
after delete on public.etat_de_lieux
for each row execute function public.delete_orphan_collectif();
