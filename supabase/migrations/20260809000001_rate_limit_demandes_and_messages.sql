-- Rate-limiting anti-spam sur Demandes_Contact et Messages.
--
-- Contexte (audit sécurité 2026-08-09) : la migration 20260723000001 a retiré
-- l'exigence d'acceptation préalable avant l'envoi de messages (« messagerie
-- ouverte ») — dès qu'une demande existe, les deux parties peuvent s'écrire
-- sans limite. Sans garde-fou, un compte compromis/malveillant pourrait :
--   (1) créer un grand nombre de Demandes_Contact (spam de propriétaires) ;
--   (2) envoyer un flot de messages dans un fil existant.
--
-- Ces triggers ajoutent une limite raisonnable, non-intrusive pour l'usage
-- normal, appliquée **à l'INSERT uniquement** (coût négligeable, comme les
-- autres vérifications lourdes du module messagerie — cf. can_access_demande).
--
-- Idempotent : réexécutable sans dommage.

-- ── 1. Demandes_Contact : max 20 nouvelles demandes / locataire / heure ──────
create or replace function public.demandes_contact_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  select count(*) into v_count
    from public."Demandes_Contact"
   where locataire_id = new.locataire_id
     and created_at > now() - interval '1 hour';

  if v_count >= 20 then
    raise exception 'Trop de demandes de contact créées récemment. Merci de réessayer plus tard.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

revoke execute on function public.demandes_contact_rate_limit() from public, anon, authenticated;

drop trigger if exists trg_demandes_contact_rate_limit on public."Demandes_Contact";
create trigger trg_demandes_contact_rate_limit
  before insert on public."Demandes_Contact"
  for each row execute function public.demandes_contact_rate_limit();

-- ── 2. Messages : max 60 messages / expéditeur / 10 minutes ─────────────────
create or replace function public.messages_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  select count(*) into v_count
    from public."Messages"
   where sender_id = new.sender_id
     and created_at > now() - interval '10 minutes';

  if v_count >= 60 then
    raise exception 'Trop de messages envoyés récemment. Merci de réessayer dans quelques minutes.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

revoke execute on function public.messages_rate_limit() from public, anon, authenticated;

drop trigger if exists trg_messages_rate_limit on public."Messages";
create trigger trg_messages_rate_limit
  before insert on public."Messages"
  for each row execute function public.messages_rate_limit();

-- Index au service des deux triggers (comptage par fenêtre glissante).
-- Remplace messages_sender_idx (sender_id) par une variante composite : les
-- requêtes existantes filtrant seulement sur sender_id restent couvertes
-- (préfixe de l'index), et le trigger gagne l'accès à created_at sans scan.
drop index if exists public.messages_sender_idx;
create index if not exists messages_sender_created_idx
  on public."Messages" (sender_id, created_at);

create index if not exists demandes_contact_locataire_created_idx
  on public."Demandes_Contact" (locataire_id, created_at);
