-- Enlaza textos con su autor registrado cuando uno de los dos nombres empieza
-- por el otro: sirve para "Beatriz Montañez Mallarino" contra el perfil
-- "Beatriz Montañez", y para "Fernando" contra "Fernando Restrepo".
--
-- Solo actúa cuando hay UN candidato. Si dos perfiles encajan, lo deja quieto
-- y lo saca en la consulta de abajo: mejor sin enlazar que mal enlazado.
with candidatos as (
  select t.id  as texto_id,
         p.id  as perfil_id,
         count(*) over (partition by t.id) as cuantos
  from   semillero.textos t
  join   semillero.perfiles p
         on  p.nombre <> ''
         and (
              lower(btrim(t.autor_nombre)) like lower(btrim(p.nombre || ' ' || p.apellido)) || '%'
           or lower(btrim(p.nombre || ' ' || p.apellido)) like lower(btrim(t.autor_nombre)) || '%'
         )
  where  t.autor_id is null
)
update semillero.textos t
set    autor_id = c.perfil_id
from   candidatos c
where  t.id = c.texto_id and c.cuantos = 1;

-- Lo que sigue sin enlazar, con quién se parece.
select t.titulo,
       t.autor_nombre as autor_escrito,
       coalesce(string_agg(p.nombre || ' ' || p.apellido, ' / '), 'nadie se parece') as candidatos
from   semillero.textos t
left   join semillero.perfiles p
       on p.nombre <> '' and (
            t.autor_nombre ilike '%' || p.nombre || '%'
         or t.autor_nombre ilike '%' || p.apellido || '%')
where  t.autor_id is null
group  by t.id, t.titulo, t.autor_nombre
order  by t.titulo;
