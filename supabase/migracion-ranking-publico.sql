-- Con la sesión cerrada, cualquier inscrito ve los promedios de TODOS los textos,
-- no solo del suyo. Sigue devolviendo agregados y nunca filas: quién votó qué
-- no sale de aquí. Lo que se abre es el resultado, no la autoría del voto.
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
    or exists (                      -- inscrito del taller, con la sesión ya cerrada
      select 1
      from semillero.sesiones s
      join semillero.inscripciones i
        on i.taller_id = s.taller_id and i.perfil_id = auth.uid()
      where s.id = p_sesion and s.fase = 'cerrada')
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
  group by t.id, t.titulo, t.orden, c.id, c.nombre, c.orden
  order by t.orden, c.orden;
end $$;
