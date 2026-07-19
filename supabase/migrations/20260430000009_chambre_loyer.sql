-- Adiciona preço de aluguel e indicador de ocupação à tabela Chambres.
ALTER TABLE public."Chambres"
  ADD COLUMN IF NOT EXISTS prix_loyer numeric(10, 2),
  ADD COLUMN IF NOT EXISTS est_loue   boolean NOT NULL DEFAULT false;
