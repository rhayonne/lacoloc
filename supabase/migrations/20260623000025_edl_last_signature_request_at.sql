-- Horodatage de la dernière « demande de signature » envoyée au locataire pour
-- un EDL finalisé non signé (anti-spam : 1 demande / 5 jours, contrôlé côté app).
alter table public."etat_de_lieux"
  add column if not exists last_signature_request_at timestamptz;
