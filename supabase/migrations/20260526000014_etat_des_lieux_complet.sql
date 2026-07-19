-- ============================================================================
-- État des lieux complet — alinhado aos modelos "partie commune" e "partie privée".
--
-- Conceito:
--  • Um EDL `partie = 'commune'` (collectif) descreve as PARTIES COMMUNES do imóvel
--    (compteurs, chauffage, eau chaude, pièces communes). chambre_id é NULL.
--  • Um EDL `partie = 'privative'` (individuel) descreve a CHAMBRE de um locataire
--    e referencia o EDL commune do imóvel via `edl_collectif_id`.
--  • Immeuble bail collectif  → só existe o EDL commune.
--  • Immeuble bail individuel → cada locataire tem 1 EDL privative ligado ao
--    EDL commune compartilhado do imóvel.
-- ============================================================================

-- ── 1. Colunas adicionais em etat_de_lieux ──────────────────────────────────
alter table public.etat_de_lieux
  add column if not exists partie text not null default 'commune'
    check (partie in ('commune', 'privative'));

alter table public.etat_de_lieux
  add column if not exists edl_collectif_id bigint
    references public.etat_de_lieux(id) on delete set null;

-- BIEN / cabeçalho do documento (snapshot no momento do EDL)
alter table public.etat_de_lieux add column if not exists surface_m2 numeric;
alter table public.etat_de_lieux add column if not exists nombre_pieces_principales int;
alter table public.etat_de_lieux add column if not exists designation text;
alter table public.etat_de_lieux add column if not exists etage text;
alter table public.etat_de_lieux add column if not exists bailleur_nom text;
alter table public.etat_de_lieux add column if not exists bailleur_adresse text;
alter table public.etat_de_lieux add column if not exists nouvelle_adresse text; -- EDL de sortie
alter table public.etat_de_lieux add column if not exists lieu_redaction text;   -- "Fait à ___"
alter table public.etat_de_lieux add column if not exists nombre_exemplaires text;

create index if not exists idx_edl_collectif on public.etat_de_lieux(edl_collectif_id);

-- ── 2. Helpers de acesso (RLS) ──────────────────────────────────────────────
-- Leitura: proprietaire dono, locataire do EDL, ou super admin.
create or replace function public.can_access_edl(p_edl_id bigint)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.etat_de_lieux e
    where e.id = p_edl_id
      and (e.proprietaire_id = (select auth.uid())
        or e.locataire_id = (select auth.uid())
        or public.is_super_admin())
  );
$$;

-- Escrita: só proprietaire dono ou super admin.
create or replace function public.can_write_edl(p_edl_id bigint)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.etat_de_lieux e
    where e.id = p_edl_id
      and (e.proprietaire_id = (select auth.uid()) or public.is_super_admin())
  );
$$;

-- ── 3. Preneurs (colocataires listados no EDL commune; 1 no privative) ───────
create table if not exists public.etat_de_lieux_preneurs (
  id            bigint generated always as identity primary key,
  etat_de_lieux_id bigint not null references public.etat_de_lieux(id) on delete cascade,
  locataire_id  uuid references public."Users_Client"(id) on delete set null,
  nom           text,
  adresse       text,
  ordre         int not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists idx_edl_preneurs_edl on public.etat_de_lieux_preneurs(etat_de_lieux_id);

-- ── 4. Relevés techniques (compteurs eau/gaz/élec, chauffage, eau chaude) ────
create table if not exists public.etat_de_lieux_releves (
  id            bigint generated always as identity primary key,
  etat_de_lieux_id bigint not null references public.etat_de_lieux(id) on delete cascade,
  categorie     text not null
    check (categorie in ('eau_gaz', 'electrique', 'chauffage', 'eau_chaude')),
  type          text,           -- ex: "Collectif gaz de ville", "Ballon d'eau chaude"
  numero_serie  text,
  valeur_index  numeric,        -- M3 (eau/gaz) ou KW (électrique)
  unite         text,           -- 'M3' | 'KW' | null
  etat_usure    text,           -- N | B | U | M
  fonctionnement text,          -- ex: "OK"
  observations  text,
  ordre         int not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists idx_edl_releves_edl on public.etat_de_lieux_releves(etat_de_lieux_id);

-- ── 5. Remise des clés (EDL privative) ──────────────────────────────────────
create table if not exists public.etat_de_lieux_cles (
  id            bigint generated always as identity primary key,
  etat_de_lieux_id bigint not null references public.etat_de_lieux(id) on delete cascade,
  type_cle      text not null,  -- ex: "Badge accès batiment", "Clé chambre 1"
  nombre        int,
  remise_ce_jour boolean not null default false,
  date_remise   date,
  commentaire   text,
  ordre         int not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists idx_edl_cles_edl on public.etat_de_lieux_cles(etat_de_lieux_id);

-- ── 6. Sections (pièces do documento) + lignes (linhas de equipamento) ───────
create table if not exists public.etat_de_lieux_sections (
  id            bigint generated always as identity primary key,
  etat_de_lieux_id bigint not null references public.etat_de_lieux(id) on delete cascade,
  nom           text not null,  -- ex: "ENTREE et PLACARD", "SEJOUR", "CHAMBRE N°…"
  ordre         int not null default 0,
  commentaire_global text,
  created_at    timestamptz not null default now()
);
create index if not exists idx_edl_sections_edl on public.etat_de_lieux_sections(etat_de_lieux_id);

create table if not exists public.etat_de_lieux_lignes (
  id            bigint generated always as identity primary key,
  section_id    bigint not null references public.etat_de_lieux_sections(id) on delete cascade,
  equipement    text not null,  -- ex: "PORTE PALIERE", "SOL", "MUR A", "TV"
  nature_nombre text,           -- ex: "1", "2"
  etat_usure    text,           -- N | B | U | M
  fonctionnement text,          -- ex: "OK"
  commentaires  text,
  ordre         int not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists idx_edl_lignes_section on public.etat_de_lieux_lignes(section_id);

-- ── 7. RLS ───────────────────────────────────────────────────────────────────
alter table public.etat_de_lieux_preneurs enable row level security;
alter table public.etat_de_lieux_releves  enable row level security;
alter table public.etat_de_lieux_cles     enable row level security;
alter table public.etat_de_lieux_sections enable row level security;
alter table public.etat_de_lieux_lignes   enable row level security;

-- preneurs
drop policy if exists edl_preneurs_select on public.etat_de_lieux_preneurs;
create policy edl_preneurs_select on public.etat_de_lieux_preneurs
  for select to authenticated using (public.can_access_edl(etat_de_lieux_id));
drop policy if exists edl_preneurs_write on public.etat_de_lieux_preneurs;
create policy edl_preneurs_write on public.etat_de_lieux_preneurs
  for all to authenticated
  using (public.can_write_edl(etat_de_lieux_id))
  with check (public.can_write_edl(etat_de_lieux_id));

-- releves
drop policy if exists edl_releves_select on public.etat_de_lieux_releves;
create policy edl_releves_select on public.etat_de_lieux_releves
  for select to authenticated using (public.can_access_edl(etat_de_lieux_id));
drop policy if exists edl_releves_write on public.etat_de_lieux_releves;
create policy edl_releves_write on public.etat_de_lieux_releves
  for all to authenticated
  using (public.can_write_edl(etat_de_lieux_id))
  with check (public.can_write_edl(etat_de_lieux_id));

-- cles
drop policy if exists edl_cles_select on public.etat_de_lieux_cles;
create policy edl_cles_select on public.etat_de_lieux_cles
  for select to authenticated using (public.can_access_edl(etat_de_lieux_id));
drop policy if exists edl_cles_write on public.etat_de_lieux_cles;
create policy edl_cles_write on public.etat_de_lieux_cles
  for all to authenticated
  using (public.can_write_edl(etat_de_lieux_id))
  with check (public.can_write_edl(etat_de_lieux_id));

-- sections
drop policy if exists edl_sections_select on public.etat_de_lieux_sections;
create policy edl_sections_select on public.etat_de_lieux_sections
  for select to authenticated using (public.can_access_edl(etat_de_lieux_id));
drop policy if exists edl_sections_write on public.etat_de_lieux_sections;
create policy edl_sections_write on public.etat_de_lieux_sections
  for all to authenticated
  using (public.can_write_edl(etat_de_lieux_id))
  with check (public.can_write_edl(etat_de_lieux_id));

-- lignes (acesso resolvido via section → edl)
drop policy if exists edl_lignes_select on public.etat_de_lieux_lignes;
create policy edl_lignes_select on public.etat_de_lieux_lignes
  for select to authenticated using (
    exists (
      select 1 from public.etat_de_lieux_sections s
      where s.id = section_id and public.can_access_edl(s.etat_de_lieux_id)
    )
  );
drop policy if exists edl_lignes_write on public.etat_de_lieux_lignes;
create policy edl_lignes_write on public.etat_de_lieux_lignes
  for all to authenticated
  using (
    exists (
      select 1 from public.etat_de_lieux_sections s
      where s.id = section_id and public.can_write_edl(s.etat_de_lieux_id)
    )
  )
  with check (
    exists (
      select 1 from public.etat_de_lieux_sections s
      where s.id = section_id and public.can_write_edl(s.etat_de_lieux_id)
    )
  );
