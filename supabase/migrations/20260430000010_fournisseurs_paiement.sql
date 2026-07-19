-- Tabela de referência dos tipos de pagamento utilizados em França.
-- =============================================================================

create table if not exists public."Payment_Types_Reference" (
  id          bigint generated always as identity primary key,
  code        text not null unique,
  label       text not null,
  description text
);

alter table public."Payment_Types_Reference" enable row level security;

create policy "payment_types_select_all" on public."Payment_Types_Reference"
  for select to anon, authenticated
  using (true);

create policy "payment_types_write_admin" on public."Payment_Types_Reference"
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

insert into public."Payment_Types_Reference" (code, label, description) values
  ('virement',        'Virement bancaire',      'Virement SEPA classique'),
  ('prelevement',     'Prélèvement SEPA',       'Débit automatique autorisé'),
  ('cheque',          'Chèque',                 'Chèque bancaire'),
  ('carte',           'Carte bancaire',         'Paiement par carte CB / Visa / Mastercard'),
  ('especes',         'Espèces',                'Paiement en liquide'),
  ('wero',            'Wero',                   'Virement instantané Wero (ex-Lydia / ex-PayLib)'),
  ('paypal',          'PayPal',                 'Paiement via PayPal'),
  ('titre_service',   'Titre-service / CESU',   'Chèque emploi-service universel'),
  ('autre',           'Autre',                  'Autre moyen de paiement')
on conflict (code) do update
  set label       = excluded.label,
      description = excluded.description;

-- =============================================================================
-- Nouvelles colonnes sur Fournisseurs
-- =============================================================================

alter table public."Fournisseurs"
  add column if not exists iban            text,
  add column if not exists bic             text,
  add column if not exists titulaire_compte text,
  add column if not exists types_paiement  text[] not null default '{}';
