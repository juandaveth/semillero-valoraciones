-- ============================================================================
-- Espejo del servidor de Discord dentro de la base.
-- Permite responder en el panel: quién está en el servidor, quién tiene el rol
-- de cada taller, y quién está inscrito. Las tres cosas son distintas.
-- ============================================================================

-- 1. El id de Discord como llave estable. El nombre de usuario cambia; el id no.
alter table semillero.perfiles add column if not exists discord_id text;

-- Rellena el id de quienes ya entraron, leyéndolo de auth.
update semillero.perfiles p
set    discord_id = u.raw_user_meta_data->>'provider_id'
from   auth.users u
where  u.id = p.id and p.discord_id is null;

-- El sufijo "#0" es el discriminador viejo de Discord, no es parte del handle.
update semillero.perfiles set discord = regexp_replace(discord, '#0+$', '')
where  discord ~ '#0+$';

create index if not exists idx_perfiles_discord_id on semillero.perfiles(discord_id);

-- 2. Qué rol del servidor corresponde a cada taller.
alter table semillero.talleres add column if not exists discord_role_id text;

-- 3. El espejo. Lo escribe solo el bot, a través de la función de borde.
create table if not exists semillero.discord_miembros (
  discord_id      text primary key,
  username        text not null default '',
  display_name    text not null default '',
  roles           text[] not null default '{}',
  es_bot          boolean not null default false,
  sincronizado_en timestamptz not null default now()
);
comment on table semillero.discord_miembros is
  'Copia de los miembros del servidor. No es fuente de verdad de nada: sirve
   para comparar contra los inscritos y ver quién falta o quién sobra.';

alter table semillero.discord_miembros enable row level security;

-- Solo los admin la leen. Nadie la escribe desde el navegador: la llena el
-- service_role desde la función de borde, que se salta la RLS.
drop policy if exists miembros_admin_ve on semillero.discord_miembros;
create policy miembros_admin_ve on semillero.discord_miembros
  for select to authenticated using (semillero.es_admin());

grant select on semillero.discord_miembros to authenticated;
grant all    on semillero.discord_miembros to service_role;

-- 4. El trigger de alta ahora guarda también el id de Discord y limpia el "#0".
create or replace function semillero.manejar_usuario_nuevo()
returns trigger
language plpgsql
security definer set search_path = semillero, public
as $$
declare
  handle text;
begin
  if new.raw_app_meta_data->>'provider' is distinct from 'discord' then
    return new;
  end if;

  handle := regexp_replace(coalesce(
    new.raw_user_meta_data->>'user_name',
    new.raw_user_meta_data->>'preferred_username',
    new.raw_user_meta_data->>'name',
    ''), '#0+$', '');

  insert into semillero.perfiles (id, discord, discord_id)
  values (new.id, handle, new.raw_user_meta_data->>'provider_id')
  on conflict (id) do nothing;

  insert into semillero.inscripciones (taller_id, perfil_id)
  select t.id, new.id from semillero.talleres t where t.abierto_a_registro
  on conflict do nothing;

  return new;
end $$;
