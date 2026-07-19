ALTER TABLE public."Chambres"  ADD COLUMN IF NOT EXISTS main_photo text;
ALTER TABLE public."Immeubles" ADD COLUMN IF NOT EXISTS main_photo text;
