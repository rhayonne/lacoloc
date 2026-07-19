-- Deux signatures possibles par utilisateur : une « draw » (gestuelle) et une
-- « image » (fichier importé), avec une marquée « principale ».
-- (Appliquée en prod via MCP le 2026-07-19.)
alter table public.user_signatures
  add column if not exists kind text not null default 'draw',
  add column if not exists is_principal boolean not null default false;

-- Les lignes existantes (une seule par user) deviennent la signature principale.
update public.user_signatures set is_principal = true where is_principal = false;

-- kind ∈ {draw, image}
alter table public.user_signatures drop constraint if exists user_signatures_kind_check;
alter table public.user_signatures
  add constraint user_signatures_kind_check check (kind in ('draw','image'));

-- Une seule signature par (utilisateur, type) — remplace l'unicité sur user_id.
alter table public.user_signatures drop constraint if exists uq_user_signatures_user;
alter table public.user_signatures drop constraint if exists uq_user_signatures_user_kind;
alter table public.user_signatures
  add constraint uq_user_signatures_user_kind unique (user_id, kind);

-- Au plus UNE principale par utilisateur.
drop index if exists uq_user_sig_principal;
create unique index uq_user_sig_principal
  on public.user_signatures(user_id) where is_principal;
