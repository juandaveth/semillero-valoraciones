-- ============================================================================
-- El rol de Discord decide en qué taller queda cada quien, en vez de la
-- casilla "registro abierto", que obligaba a acordarse de abrirla y cerrarla.
-- ============================================================================

-- 1. El alta de quien entra por primera vez.
create or replace function semillero.manejar_usuario_nuevo()
returns trigger
language plpgsql
security definer set search_path = semillero, public
as $$
declare
  handle text;
  did    text;
  en_espejo boolean;
begin
  if new.raw_app_meta_data->>'provider' is distinct from 'discord' then
    return new;
  end if;

  did := new.raw_user_meta_data->>'provider_id';

  handle := regexp_replace(coalesce(
    new.raw_user_meta_data->>'user_name',
    new.raw_user_meta_data->>'preferred_username',
    new.raw_user_meta_data->>'name',
    ''), '#0+$', '');

  insert into semillero.perfiles (id, discord, discord_id)
  values (new.id, handle, did)
  on conflict (id) do nothing;

  select exists(select 1 from semillero.discord_miembros where discord_id = did)
    into en_espejo;

  if en_espejo then
    -- Sabemos sus roles: mandan ellos. Si no tiene ninguno de taller, no queda
    -- inscrito en nada, y eso es correcto: está en el servidor pero no en un taller.
    insert into semillero.inscripciones (taller_id, perfil_id)
    select t.id, new.id
    from   semillero.talleres t
    join   semillero.discord_miembros m on m.discord_id = did
    where  t.discord_role_id is not null
      and  t.discord_role_id = any(m.roles)
    on conflict do nothing;
  else
    -- No está en el espejo: o el bot no ha sincronizado, o no está en el
    -- servidor. Cae al comportamiento viejo para no dejar a nadie por fuera
    -- en mitad de una sesión en vivo.
    insert into semillero.inscripciones (taller_id, perfil_id)
    select t.id, new.id from semillero.talleres t where t.abierto_a_registro
    on conflict do nothing;
  end if;

  return new;
end $$;

-- 2. Poner al día a los que ya estaban. Solo agrega; nunca quita a nadie.
create or replace function semillero.inscribir_por_roles()
returns int
language plpgsql
security definer set search_path = semillero, public
as $$
declare n int;
begin
  if not semillero.es_admin() then
    raise exception 'Solo un admin puede inscribir por rol';
  end if;

  with nuevas as (
    insert into semillero.inscripciones (taller_id, perfil_id)
    select t.id, p.id
    from   semillero.perfiles p
    join   semillero.discord_miembros m on m.discord_id = p.discord_id
    join   semillero.talleres t
           on t.discord_role_id is not null and t.discord_role_id = any(m.roles)
    where  not exists (
             select 1 from semillero.inscripciones i
             where i.taller_id = t.id and i.perfil_id = p.id)
    returning 1
  )
  select count(*) into n from nuevas;

  return n;
end $$;
