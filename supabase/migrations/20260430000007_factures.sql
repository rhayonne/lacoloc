-- Tabela de faturas do proprietário.
-- Cobre todos os tipos comuns: Eau, Électricité, Gaz, Téléphone, Internet,
-- Box TV+Internet, Assurance, Charges de copropriété, Taxe foncière, Divers.

create table if not exists public."Factures" (
  id              bigint generated always as identity primary key,
  owner_id        uuid references auth.users(id) on delete cascade not null,
  immeuble_id     bigint references public."Immeubles"(id) on delete set null,
  code_facture    text,
  fournisseur     text not null,
  type_facture    text not null,           -- 'Eau', 'Électricité', 'Gaz', etc.
  periode_debut   date,
  periode_fin     date,
  date_emission   date,
  date_echeance   date,
  montant_ht      numeric(12,2),
  taux_tva        numeric(5,2) default 20, -- % (ex: 20, 10, 5.5, 0)
  montant_ttc     numeric(12,2),
  statut          text not null default 'Non payée', -- 'Non payée' | 'Payée' | 'En litige'
  notes           text,
  created_at      timestamptz default now() not null
);

-- Accès propriétaire uniquement (RLS)
alter table public."Factures" enable row level security;

create policy "Propriétaire voit ses propres factures"
  on public."Factures"
  for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Index utile pour les listes filtrées par propriétaire
create index if not exists factures_owner_idx on public."Factures"(owner_id);
create index if not exists factures_immeuble_idx on public."Factures"(immeuble_id);
