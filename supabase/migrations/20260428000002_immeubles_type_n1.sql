-- Corrige a relação Immeubles -> Immeuble_Types_Reference de N-N para N-1.
-- Remove a tabela de junção e adiciona type_id diretamente em Immeubles.

-- Remove a tabela de junção (cascade apaga índices e policies ligadas).
drop table if exists public."Immeubles_Types" cascade;

-- Adiciona type_id como FK direta (N-1).
alter table public."Immeubles"
  add column if not exists type_id bigint
    references public."Immeuble_Types_Reference" (id) on delete set null;

-- Índice para joins e filtros por tipo.
create index if not exists "Immeubles_type_id_idx"
  on public."Immeubles" (type_id);
