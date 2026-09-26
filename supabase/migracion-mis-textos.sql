-- ============================================================================
-- El autor deja de depender de que su sesión esté en vivo para ver lo suyo.
-- Un texto "está listo" cuando ya no es el que está en concurso: desde ese
-- momento su autor puede ver el promedio y los comentarios, aunque la sesión
-- siga abierta y aunque no esté en el aire.
-- ============================================================================

create or replace function semillero.mis_textos()
returns table (
  texto_id  uuid,
  titulo    text,
  sesion    text,
  fecha     date,
  n         bigint,
  promedio  numeric,
  listo     boolean
)
language sql stable
security definer set search_path = semillero, public
as $$
  select t.id, t.titulo, s.nombre, s.fecha,
         count(distinct e.id),
         case when s.texto_en_concurso_id is distinct from t.id
              then round(avg(pu.valor)::numeric, 2) end,
         (s.texto_en_concurso_id is distinct from t.id)
  from   semillero.textos t
  join   semillero.sesiones s on s.id = t.sesion_id
  left   join semillero.evaluaciones e on e.texto_id = t.id
  left   join semillero.puntajes pu on pu.evaluacion_id = e.id
  where  t.autor_id = auth.uid()
  group  by t.id, t.titulo, s.nombre, s.fecha, s.texto_en_concurso_id
  order  by s.fecha desc, t.orden;
$$;

create or replace function semillero.mis_comentarios()
returns table (texto_id uuid, comentario text)
language sql stable
security definer set search_path = semillero, public
as $$
  select e.texto_id, e.comentario
  from   semillero.evaluaciones e
  join   semillero.textos t on t.id = e.texto_id
  join   semillero.sesiones s on s.id = t.sesion_id
  where  t.autor_id = auth.uid()
    and  e.comentario is not null
    and  s.texto_en_concurso_id is distinct from t.id
  -- Al azar: el orden de llegada delata quién escribió primero.
  order  by md5(e.id::text);
$$;

-- Y los comentarios de una sesión también se sueltan en cuanto el texto sale
-- de concurso, sin esperar a que se cierre la sesión entera.
create or replace function semillero.comentarios_de_sesion(p_sesion uuid)
returns table (texto_id uuid, comentario text)
language plpgsql
security definer set search_path = semillero, public
as $$
begin
  if not (
    semillero.es_admin()
    or exists (
      select 1 from semillero.textos t
      join semillero.sesiones s on s.id = t.sesion_id
      where s.id = p_sesion and t.autor_id = auth.uid()
        and s.texto_en_concurso_id is distinct from t.id)
  ) then
    raise exception 'Los comentarios no están disponibles para ti todavía';
  end if;

  return query
  select e.texto_id, e.comentario
  from   semillero.evaluaciones e
  join   semillero.textos t on t.id = e.texto_id
  join   semillero.sesiones s on s.id = t.sesion_id
  where  t.sesion_id = p_sesion
    and  e.comentario is not null
    and  s.texto_en_concurso_id is distinct from t.id
    and  (semillero.es_admin() or t.autor_id = auth.uid())
  order  by md5(e.id::text || p_sesion::text);
end $$;
