-- ============================================================================
-- Semillero de escrituras · Valoración de textos en vivo
-- Esquema completo para Supabase. Pegar entero en el SQL Editor y ejecutar.
-- Idempotente: se puede volver a correr.
--
-- CONVIVE con el cotizador de contenedores en el mismo proyecto de Supabase.
-- Por eso vive en su propio esquema `semillero` y no en `public`: así ninguna
-- tabla choca con las del cotizador y se pueden borrar todas de un golpe.
--
-- Después de correr esto, en el panel de Supabase:
--   Settings -> API -> Exposed schemas: agregar `semillero`
-- Sin ese paso el cliente no ve ninguna tabla.
-- ============================================================================

create schema if not exists semillero;

-- En un esquema nuevo los permisos no vienen dados, al contrario que en public.
-- Se otorgan a los tres roles estándar del Data API para que el panel de
-- Supabase no los marque como "custom grants". Incluir a `anon` es inocuo:
-- TODAS las políticas RLS de este archivo están escritas `to authenticated`,
-- así que quien no ha iniciado sesión recibe cero filas de las ocho tablas.
grant usage on schema semillero to anon, authenticated, service_role;
grant all on all tables    in schema semillero to anon, authenticated, service_role;
grant all on all sequences in schema semillero to anon, authenticated, service_role;
grant all on all routines  in schema semillero to anon, authenticated, service_role;
alter default privileges in schema semillero
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema semillero
  grant all on routines to anon, authenticated, service_role;

-- ---------------------------------------------------------------- 1. TABLAS

create table if not exists semillero.perfiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nombre     text not null default '',
  apellido   text not null default '',
  discord    text not null default '',
  rol        text not null default 'participante'
             check (rol in ('participante','admin')),
  creado_en  timestamptz not null default now()
);
comment on table semillero.perfiles is
  'Un perfil por cuenta de Discord. Sin correo a propósito: vive en auth.users
   y no tiene por qué ser legible por los demás participantes.';

create table if not exists semillero.talleres (
  id                  uuid primary key default gen_random_uuid(),
  nombre              text not null,
  abierto_a_registro  boolean not null default true,
  sesion_en_vivo_id   uuid,          -- FK más abajo (referencia circular)
  creado_en           timestamptz not null default now()
);
comment on column semillero.talleres.abierto_a_registro is
  'Quien entra por Discord queda inscrito solo en los talleres marcados así.';
comment on column semillero.talleres.sesion_en_vivo_id is
  'Lo que reciben los celulares. Distinto de lo que el admin esté revisando.';

create table if not exists semillero.inscripciones (
  taller_id  uuid not null references semillero.talleres(id) on delete cascade,
  perfil_id  uuid not null references semillero.perfiles(id) on delete cascade,
  creado_en  timestamptz not null default now(),
  primary key (taller_id, perfil_id)
);
comment on table semillero.inscripciones is
  'Define quién califica y quién entra al denominador. El rol es otra cosa:
   un admin inscrito dirige y además califica.';

create table if not exists semillero.criterios (
  id        uuid primary key default gen_random_uuid(),
  orden     int  not null,
  nombre    text not null,
  pregunta  text not null,
  activo    boolean not null default true
);
comment on table semillero.criterios is
  'En tabla y no en el código: un puntaje guarda criterio_id, no "el segundo
   número", así renombrar o agregar un criterio no corre los votos viejos.';

create table if not exists semillero.sesiones (
  id                    uuid primary key default gen_random_uuid(),
  taller_id             uuid not null references semillero.talleres(id) on delete cascade,
  fecha                 date not null,
  nombre                text not null,
  fase                  text not null default 'en_curso'
                        check (fase in ('en_curso','cerrada')),
  texto_en_concurso_id  uuid,        -- FK más abajo (referencia circular)
  creado_en             timestamptz not null default now()
);
comment on column semillero.sesiones.texto_en_concurso_id is
  'El único texto abierto para votar ahora mismo. Null = la sala espera.';

create table if not exists semillero.textos (
  id         uuid primary key default gen_random_uuid(),
  sesion_id  uuid not null references semillero.sesiones(id) on delete cascade,
  orden      int  not null,
  autor_id   uuid not null references semillero.perfiles(id) on delete restrict,
  titulo     text not null,
  creado_en  timestamptz not null default now()
);

create table if not exists semillero.evaluaciones (
  id            uuid primary key default gen_random_uuid(),
  texto_id      uuid not null references semillero.textos(id) on delete cascade,
  evaluador_id  uuid not null references semillero.perfiles(id) on delete cascade,
  enviada_en    timestamptz not null default now(),
  unique (texto_id, evaluador_id)          -- nadie vota dos veces el mismo texto
);

create table if not exists semillero.puntajes (
  evaluacion_id  uuid not null references semillero.evaluaciones(id) on delete cascade,
  criterio_id    uuid not null references semillero.criterios(id) on delete restrict,
  valor          smallint not null check (valor between 1 and 5),
  primary key (evaluacion_id, criterio_id)
);

-- Referencias circulares: se agregan cuando las dos tablas ya existen.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'talleres_sesion_en_vivo_fk') then
    alter table semillero.talleres
      add constraint talleres_sesion_en_vivo_fk
      foreign key (sesion_en_vivo_id) references semillero.sesiones(id) on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'sesiones_texto_concurso_fk') then
    alter table semillero.sesiones
      add constraint sesiones_texto_concurso_fk
      foreign key (texto_en_concurso_id) references semillero.textos(id) on delete set null;
  end if;
end $$;

create index if not exists idx_sesiones_taller      on semillero.sesiones(taller_id, fecha desc);
create index if not exists idx_textos_sesion        on semillero.textos(sesion_id, orden);
create index if not exists idx_eval_texto           on semillero.evaluaciones(texto_id);
create index if not exists idx_eval_evaluador       on semillero.evaluaciones(evaluador_id);
create index if not exists idx_puntajes_evaluacion  on semillero.puntajes(evaluacion_id);

-- ------------------------------------------------- 2. LOS CINCO CRITERIOS

insert into semillero.criterios (orden, nombre, pregunta)
select * from (values
  (1,'Voz narradora',      '¿La voz que cuenta resulta reconocible, consistente y adecuada para esta historia?'),
  (2,'Personajes',         '¿Los personajes tienen suficiente presencia, deseo y contradicción como para sostener la narración?'),
  (3,'Perspectiva',        '¿El texto aprovecha de manera consciente lo que el narrador puede ver, saber, ocultar o ignorar?'),
  (4,'Ritmo y estructura', '¿La distribución de escenas, pausas, aceleraciones y revelaciones mantiene el interés?'),
  (5,'Potencia literaria', '¿Hay decisiones de lenguaje, imágenes, escenas o asociaciones que produzcan un efecto memorable?')
) as v(orden, nombre, pregunta)
where not exists (select 1 from semillero.criterios);

-- ------------------------------------- 3. ALTA AUTOMÁTICA AL ENTRAR CON DISCORD

create or replace function semillero.manejar_usuario_nuevo()
returns trigger
language plpgsql
security definer set search_path = semillero, public
as $$
declare
  handle text;
begin
  -- auth.users es de TODO el proyecto de Supabase. Si algún día el cotizador
  -- (u otra cosa) crea usuarios, no pueden terminar inscritos en el taller.
  if new.raw_app_meta_data->>'provider' is distinct from 'discord' then
    return new;
  end if;

  handle := coalesce(
    new.raw_user_meta_data->>'user_name',
    new.raw_user_meta_data->>'preferred_username',
    new.raw_user_meta_data->>'name',
    ''
  );

  insert into semillero.perfiles (id, discord)
  values (new.id, handle)
  on conflict (id) do nothing;

  -- Quien llega por Discord ya está en el servidor: queda inscrito de una.
  insert into semillero.inscripciones (taller_id, perfil_id)
  select t.id, new.id from semillero.talleres t where t.abierto_a_registro
  on conflict do nothing;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function semillero.manejar_usuario_nuevo();

-- ------------------------------------------------ 4. AYUDANTES (security definer)
-- Van con security definer para no chocar contra las mismas políticas
-- que están evaluando, que es la forma clásica de provocar recursión.

create or replace function semillero.es_admin()
returns boolean language sql stable
security definer set search_path = semillero, public as $$
  select exists (select 1 from semillero.perfiles p
                 where p.id = auth.uid() and p.rol = 'admin');
$$;

create or replace function semillero.esta_inscrito(p_taller uuid)
returns boolean language sql stable
security definer set search_path = semillero, public as $$
  select exists (select 1 from semillero.inscripciones i
                 where i.taller_id = p_taller and i.perfil_id = auth.uid());
$$;

-- ¿Puede esta persona votar este texto, ahora mismo?
create or replace function semillero.puede_votar(p_texto uuid)
returns boolean language sql stable
security definer set search_path = semillero, public as $$
  select exists (
    select 1
    from semillero.textos t
    join semillero.sesiones s on s.id = t.sesion_id
    where t.id = p_texto
      and s.texto_en_concurso_id = t.id      -- está en concurso ahora
      and s.fase = 'en_curso'
      and t.autor_id <> auth.uid()           -- el autor no califica lo suyo
      and semillero.esta_inscrito(s.taller_id)
  );
$$;

-- ------------------------------------------------------------------ 5. RLS

alter table semillero.perfiles      enable row level security;
alter table semillero.talleres      enable row level security;
alter table semillero.inscripciones enable row level security;
alter table semillero.criterios     enable row level security;
alter table semillero.sesiones      enable row level security;
alter table semillero.textos        enable row level security;
alter table semillero.evaluaciones  enable row level security;
alter table semillero.puntajes      enable row level security;

-- Perfiles: todos se ven entre sí (hace falta para mostrar el autor del texto).
-- Cada quien edita el suyo. Nadie se cambia el rol a sí mismo.
drop policy if exists perfiles_ver on semillero.perfiles;
create policy perfiles_ver on semillero.perfiles
  for select to authenticated using (true);

drop policy if exists perfiles_editar_el_mio on semillero.perfiles;
create policy perfiles_editar_el_mio on semillero.perfiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid()
              and rol = (select rol from semillero.perfiles p where p.id = auth.uid()));

drop policy if exists perfiles_admin on semillero.perfiles;
create policy perfiles_admin on semillero.perfiles
  for all to authenticated using (semillero.es_admin()) with check (semillero.es_admin());

-- Catálogos y estructura: todos leen, solo el admin escribe.
do $$
declare t text;
begin
  foreach t in array array['talleres','inscripciones','criterios','sesiones','textos'] loop
    execute format('drop policy if exists %I_ver on semillero.%I', t, t);
    execute format('create policy %I_ver on semillero.%I for select to authenticated using (true)', t, t);
    execute format('drop policy if exists %I_admin on semillero.%I', t, t);
    execute format('create policy %I_admin on semillero.%I for all to authenticated
                    using (semillero.es_admin()) with check (semillero.es_admin())', t, t);
  end loop;
end $$;

-- ---- Evaluaciones y puntajes: aquí vive el anonimato ----
-- Cada quien lee SOLO lo suyo. El autor no puede consultar quién le puso qué,
-- ni desde la app ni abriendo la pestaña de red.

drop policy if exists eval_ver_las_mias on semillero.evaluaciones;
create policy eval_ver_las_mias on semillero.evaluaciones
  for select to authenticated
  using (evaluador_id = auth.uid() or semillero.es_admin());

drop policy if exists eval_insertar on semillero.evaluaciones;
create policy eval_insertar on semillero.evaluaciones
  for insert to authenticated
  with check (evaluador_id = auth.uid() and semillero.puede_votar(texto_id));

drop policy if exists puntajes_ver_los_mios on semillero.puntajes;
create policy puntajes_ver_los_mios on semillero.puntajes
  for select to authenticated
  using (semillero.es_admin() or exists (
    select 1 from semillero.evaluaciones e
    where e.id = evaluacion_id and e.evaluador_id = auth.uid()));

drop policy if exists puntajes_insertar on semillero.puntajes;
create policy puntajes_insertar on semillero.puntajes
  for insert to authenticated
  with check (exists (
    select 1 from semillero.evaluaciones e
    where e.id = evaluacion_id and e.evaluador_id = auth.uid()));

-- Un voto es definitivo: no hay update ni delete para nadie salvo el admin.
drop policy if exists eval_admin_borrar on semillero.evaluaciones;
create policy eval_admin_borrar on semillero.evaluaciones
  for delete to authenticated using (semillero.es_admin());

-- ------------------------------------------- 6. ESCRIBIR EL VOTO DE UNA SOLA VEZ
-- Seis viajes desde un celular con mala señal es una fila a medio guardar.
-- Esto entra completo o no entra.

create or replace function semillero.enviar_valoracion(p_texto uuid, p_puntajes jsonb)
returns uuid
language plpgsql
security invoker set search_path = semillero, public
as $$
declare
  v_eval uuid;
  v_esperados int;
  v_recibidos int;
begin
  if not semillero.puede_votar(p_texto) then
    raise exception 'Ese texto no está en concurso, o no te corresponde calificarlo';
  end if;

  select count(*) into v_esperados from semillero.criterios where activo;
  select count(*) into v_recibidos from jsonb_object_keys(p_puntajes);
  if v_recibidos <> v_esperados then
    raise exception 'Faltan criterios: llegaron % de %', v_recibidos, v_esperados;
  end if;

  insert into semillero.evaluaciones (texto_id, evaluador_id)
  values (p_texto, auth.uid())
  returning id into v_eval;

  insert into semillero.puntajes (evaluacion_id, criterio_id, valor)
  select v_eval, key::uuid, value::smallint
  from jsonb_each_text(p_puntajes);

  return v_eval;
end $$;

-- --------------------------------------------------- 7. PROMEDIOS SIN FILAS
-- Devuelve agregados y nunca filas individuales. Es la única puerta por donde
-- salen los resultados: sin esto, el anonimato sería una promesa de la interfaz.

create or replace function semillero.resultados_de_sesion(p_sesion uuid)
returns table (
  texto_id     uuid,
  titulo       text,
  orden        int,
  criterio_id  uuid,
  criterio     text,
  promedio     numeric,
  n            bigint
)
language plpgsql
security definer set search_path = semillero, public
as $$
begin
  if not (
    semillero.es_admin()
    or exists (                       -- el autor, solo con la sesión ya cerrada
      select 1 from semillero.textos t
      join semillero.sesiones s on s.id = t.sesion_id
      where s.id = p_sesion and t.autor_id = auth.uid() and s.fase = 'cerrada')
  ) then
    raise exception 'Los resultados no están disponibles para ti todavía';
  end if;

  return query
  select t.id, t.titulo, t.orden, c.id, c.nombre,
         round(avg(pu.valor)::numeric, 2), count(distinct e.id)
  from semillero.textos t
  cross join semillero.criterios c
  left join semillero.evaluaciones e on e.texto_id = t.id
  left join semillero.puntajes pu on pu.evaluacion_id = e.id and pu.criterio_id = c.id
  where t.sesion_id = p_sesion and c.activo
    -- Un participante solo ve su propio texto; el admin los ve todos.
    and (semillero.es_admin() or t.autor_id = auth.uid())
  group by t.id, t.titulo, t.orden, c.id, c.nombre, c.orden
  order by t.orden, c.orden;
end $$;

-- ---------------------------------------------------------- 8. TIEMPO REAL
-- Los celulares se suscriben a la fila de su sesión: cuando cambia
-- texto_en_concurso_id, la pantalla salta sola. Reemplaza el sondeo de 1,2 s.

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

do $$
declare t text;
begin
  foreach t in array array['sesiones','talleres','evaluaciones'] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime'
                     and schemaname = 'semillero' and tablename = t) then
      execute format('alter publication supabase_realtime add table semillero.%I', t);
    end if;
  end loop;
end $$;

-- Los grants de arriba corrieron antes de que existieran las tablas.
-- Se repiten al final para que alcancen a todo lo creado en este archivo.
grant all on all tables    in schema semillero to anon, authenticated, service_role;
grant all on all sequences in schema semillero to anon, authenticated, service_role;
grant all on all routines  in schema semillero to anon, authenticated, service_role;
