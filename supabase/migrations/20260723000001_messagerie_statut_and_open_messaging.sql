-- Refonte « Demandes de contact » → messagerie ouverte.
--
-- Deux changements, appliqués en prod le 2026-07-23 (via MCP) et consignés ici
-- pour qu'un `db reset` reconstruise le schéma courant :
--
--   1. Nouvelle colonne `Demandes_Contact.statut` — remplace le booléen
--      d'acceptation `contact_etabli` (conservé pour compat/historique). Le
--      statut est géré par le propriétaire : nouveau → non_repondu → repondu,
--      ou ignore. Voir `StatutDemande` (Dart).
--   2. **Plus d'acceptation préalable** : dès qu'une demande existe, les deux
--      parties peuvent s'écrire. On retire donc `demande_est_acceptee` de la
--      politique d'INSERT de `Messages` (il ne reste que `can_access_demande`).
--
-- Idempotent : réexécutable sans dommage.

-- ── 1. Colonne statut ────────────────────────────────────────────────────────
alter table public."Demandes_Contact"
  add column if not exists statut text not null default 'nouveau';

-- Valeurs autorisées (aligné sur l'enum Dart StatutDemande).
alter table public."Demandes_Contact"
  drop constraint if exists demandes_contact_statut_check;
alter table public."Demandes_Contact"
  add constraint demandes_contact_statut_check
  check (statut in ('nouveau', 'non_repondu', 'repondu', 'ignore'));

-- Le propriétaire de l'immeuble peut mettre à jour le statut de la demande.
drop policy if exists proprietaire_update_demande on public."Demandes_Contact";
create policy proprietaire_update_demande on public."Demandes_Contact"
  for update to authenticated
  using (
    immeuble_id in (
      select id from public."Immeubles" where owner_id = (select auth.uid())
    )
  )
  with check (
    immeuble_id in (
      select id from public."Immeubles" where owner_id = (select auth.uid())
    )
  );

-- ── 2. Messagerie ouverte : INSERT sans exigence d'acceptation ────────────────
drop policy if exists participant_insert_messages on public."Messages";
create policy participant_insert_messages on public."Messages"
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and recipient_id <> auth.uid()
    and public.can_access_demande(demande_id)
  );

-- `demande_est_acceptee` n'est plus utilisée par aucune politique ; on la laisse
-- en place (inoffensive) pour ne pas casser d'éventuels appels historiques.
