-- Trigger que cria um Users_Client automaticamente ao registrar via auth.signUp,
-- usando os metadados (full_name, type_client) passados no signUp.
-- Mantém AuthService.signUp simples (a inserção dupla na tabela vira opcional).

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public."Users_Client" (id, email, full_name, type_client)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    coalesce(new.raw_user_meta_data ->> 'type_client', 'locataire')
  )
  on conflict (id) do update set
    email     = excluded.email,
    full_name = coalesce(excluded.full_name, public."Users_Client".full_name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
