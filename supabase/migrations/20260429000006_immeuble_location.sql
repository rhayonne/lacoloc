-- Campos de localização para permitir filtros por cidade, região e departamento.
ALTER TABLE public."Immeubles"
  ADD COLUMN IF NOT EXISTS city       text,
  ADD COLUMN IF NOT EXISTS region     text,
  ADD COLUMN IF NOT EXISTS department text;
