ALTER TABLE public."Immeubles" ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
ALTER TABLE public."Chambres"  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
