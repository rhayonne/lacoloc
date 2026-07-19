-- Adiciona campo active a Users_Client.
-- Locataire: active = true (auto-ativado).
-- Proprietaire: active = false (aguarda ativação manual pelo admin).

alter table public."Users_Client"
  add column if not exists active boolean not null default true;

-- Atualizar trigger: define active com base no type_code da metadata
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type_code text;
  v_type_id   bigint;
  v_active    boolean;
begin
  v_type_code := coalesce(new.raw_user_meta_data ->> 'type_code', 'locataire');

  select id into v_type_id
  from public."User_Types_Reference"
  where code = v_type_code;

  if v_type_id is null then
    select id into v_type_id
    from public."User_Types_Reference"
    where code = 'locataire';
    v_type_code := 'locataire';
  end if;

  -- Proprietaire aguarda ativação; os demais são ativos imediatamente.
  v_active := (v_type_code <> 'proprietaire');

  insert into public."Users_Client" (id, email, full_name, type_user_id, active)
  values (new.id, new.email, new.raw_user_meta_data ->> 'full_name', v_type_id, v_active)
  on conflict (id) do update set
    email     = excluded.email,
    full_name = coalesce(excluded.full_name, public."Users_Client".full_name);

  return new;
end;
$$;
