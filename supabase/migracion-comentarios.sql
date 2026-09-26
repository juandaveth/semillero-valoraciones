-- ============================================================================
-- Un comentario por evaluación, hasta 1000 caracteres, opcional.
-- El autor del texto los lee; nunca sabe quién escribió cuál.
-- ============================================================================

alter table semillero.evaluaciones
  add column if not exists comentario text;

alter table semillero.evaluaciones
  drop constraint if exists comentario_cabe;
alter table semillero.evaluaciones
  add constraint comentario_cabe check (comentario is null or length(comentario) <= 1000);

-- El voto sigue entrando completo o no entrando, ahora con el comentario dentro.
create or replace function semillero.enviar_valoracion(
  p_texto uuid, p_puntajes jsonb, p_comentario text default null)
returns uuid
language plpgsql
security invoker set search_path = semillero, public
as $$
declare
  v_eval uuid;
  v_esperados int;
  v_recibidos int;
  v_texto text;
begin
  if not semillero.puede_votar(p_texto) then
    raise exception 'Ese texto no está en concurso, o no te corresponde calificarlo';
  end if;

  select count(*) into v_esperados from semillero.criterios where activo;
  select count(*) into v_recibidos from jsonb_object_keys(p_puntajes);
  if v_recibidos <> v_esperados then
    raise exception 'Faltan criterios: llegaron % de %', v_recibidos, v_esperados;
  end if;

  v_texto := nullif(btrim(coalesce(p_comentario, '')), '');
  if length(v_texto) > 1000 then
    raise exception 'El comentario no puede pasar de 1000 caracteres';
  end if;

  insert into semillero.evaluaciones (texto_id, evaluador_id, comentario)
  values (p_texto, auth.uid(), v_texto)
  returning id into v_eval;

  insert into semillero.puntajes (evaluacion_id, criterio_id, valor)
  select v_eval, key::uuid, value::smallint
  from   jsonb_each_text(p_puntajes);

  return v_eval;
end $$;

-- Los comentarios de una sesión, sin decir quién escribió cada uno.
-- El autor solo ve los de SU texto, y solo con la sesión cerrada.
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
      where s.id = p_sesion and t.autor_id = auth.uid() and s.fase = 'cerrada')
  ) then
    raise exception 'Los comentarios no están disponibles para ti todavía';
  end if;

  return query
  select e.texto_id, e.comentario
  from   semillero.evaluaciones e
  join   semillero.textos t on t.id = e.texto_id
  where  t.sesion_id = p_sesion
    and  e.comentario is not null
    and  (semillero.es_admin() or t.autor_id = auth.uid())
  -- Al azar: el orden de llegada delata quién escribió primero.
  order  by md5(e.id::text || p_sesion::text);
end $$;
