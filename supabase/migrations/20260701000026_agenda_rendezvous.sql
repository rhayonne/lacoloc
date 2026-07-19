-- ─────────────────────────────────────────────────────────────────────────────
-- Agenda / Rendez-vous — refonte de la table Visites + plages d'ouverture.
--
-- La table `Visites` ne stockait qu'une *date* (`date_visite`). L'agenda type
-- Doctolib a besoin d'un créneau horaire (début/fin), d'un contact invité
-- (locataire existant OU e-mail « invité » hors système), d'un lieu (immeuble)
-- et de notes. On ajoute aussi une table `Plages_Ouverture` : les plages de
-- disponibilité du propriétaire par jour de semaine (avec un type ouverture /
-- pause déjeuner) qui pilotent l'affichage du calendrier (blanc = dispo,
-- jaune = pause, hachuré = hors plage).
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Visites : nouvelles colonnes (idempotent) ────────────────────────────
alter table public."Visites"
  add column if not exists heure_debut  timestamptz,
  add column if not exists heure_fin    timestamptz,
  add column if not exists invite_email text,
  add column if not exists invite_nom   text,
  add column if not exists locataire_id uuid references public."Users_Client"(id) on delete set null,
  add column if not exists immeuble_id  bigint references public."Immeubles"(id) on delete set null,
  add column if not exists notes        text,
  add column if not exists notified_at  timestamptz;

-- `date_visite` reste renseignée (dérivée de heure_debut côté app) pour la
-- compatibilité avec l'ancien code. On la rend nullable au cas où.
alter table public."Visites"
  alter column date_visite drop not null;

create index if not exists visites_owner_debut_idx
  on public."Visites" (owner_id, heure_debut);

-- Rétro-remplissage : pour les anciennes visites sans créneau, on pose un
-- créneau 09:00–10:00 sur leur date, afin qu'elles restent visibles.
update public."Visites"
   set heure_debut = (date_visite::timestamp + interval '9 hour'),
       heure_fin   = (date_visite::timestamp + interval '10 hour')
 where heure_debut is null
   and date_visite is not null;

-- ── 2. Plages d'ouverture (disponibilités du propriétaire) ──────────────────
create table if not exists public."Plages_Ouverture" (
  id           bigint generated always as identity primary key,
  owner_id     uuid not null references public."Users_Client"(id) on delete cascade,
  jour_semaine smallint not null check (jour_semaine between 1 and 7), -- 1=lundi … 7=dimanche
  heure_debut  time not null,
  heure_fin    time not null,
  type         text not null default 'ouverture' check (type in ('ouverture', 'pause')),
  created_at   timestamptz not null default now(),
  check (heure_fin > heure_debut)
);

create index if not exists plages_owner_jour_idx
  on public."Plages_Ouverture" (owner_id, jour_semaine);

alter table public."Plages_Ouverture" enable row level security;

-- Le propriétaire gère uniquement ses propres plages.
drop policy if exists plages_select_own on public."Plages_Ouverture";
create policy plages_select_own on public."Plages_Ouverture"
  for select using (owner_id = auth.uid());

drop policy if exists plages_insert_own on public."Plages_Ouverture";
create policy plages_insert_own on public."Plages_Ouverture"
  for insert with check (owner_id = auth.uid());

drop policy if exists plages_update_own on public."Plages_Ouverture";
create policy plages_update_own on public."Plages_Ouverture"
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists plages_delete_own on public."Plages_Ouverture";
create policy plages_delete_own on public."Plages_Ouverture"
  for delete using (owner_id = auth.uid());
