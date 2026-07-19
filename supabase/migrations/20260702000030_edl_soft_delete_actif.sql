-- Soft-delete des états des lieux : `actif=false` = désactivé par le super admin.
-- Les EDL inactifs disparaissent pour proprietaire/locataire (filtré côté
-- datasource) mais restent visibles/réactivables dans le menu super admin.
-- Appliqué directement sur Supabase via MCP (le DB est la source de vérité).
alter table public.etat_de_lieux
  add column if not exists actif boolean not null default true;

create index if not exists idx_etat_de_lieux_actif on public.etat_de_lieux(actif);
