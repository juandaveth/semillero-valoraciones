-- ============================================================================
-- El voto, alineado con el modelo secuencial (sin "texto en concurso").
--
-- La versión que corría en la base (escrita a mano, nunca guardada en el repo)
-- tenía dos fallas:
--   1. Rechazaba con "El texto no existe" todo texto sin autor enlazado
--      (autor_id null), es decir, los marcados "(sin cuenta)".
--   2. No validaba nada de la sesión: con la consola, cualquier persona con
--      cuenta podía votar textos de sesiones cerradas, vencidas o de otro taller.
-- Además convivía con la versión vieja de dos argumentos.
--
-- Un texto movido a otra sesión vota según la sesión donde está AHORA. Sus votos
-- viejos se quedan con él, y el unique (texto_id, evaluador_id) impide repetir.
-- ============================================================================

drop function if exists semillero.enviar_valoracion(uuid, jsonb);

-- ¿Puede esta persona votar este texto, ahora mismo?
-- Sin "en concurso": basta con que la sesión esté abierta y dentro del plazo.
-- La usa también la política de insert de evaluaciones.
create or replace function semillero.puede_votar(p_texto uuid)
returns boolean language sql stable
security definer set search_path = semillero, public as $$
  select exists (
    select 1
    from semillero.textos t
    join semillero.sesiones s on s.id = t.sesion_id
    where t.id = p_texto
      and s.fase = 'en_curso'
      and (s.deadline is null or now() < s.deadline::timestamptz)
      and (t.autor_id is null or t.autor_id <> auth.uid())
      and semillero.esta_inscrito(s.taller_id)
  );
$$;

-- El voto entra completo (cinco puntajes y el comentario) o no entra.
create or replace function semillero.enviar_valoracion(
  p_texto uuid, p_puntajes jsonb, p_comentario text default null)
returns void
language plpgsql
security definer set search_path = semillero, public
as $$
declare
  v_eval uuid;
  v_esperados int;
  v_recibidos int;
begin
  if auth.uid() is null then
    raise exception 'Tienes que entrar con tu cuenta para calificar';
  end if;

  if not exists (select 1 from semillero.textos where id = p_texto) then
    raise exception 'El texto no existe';
  end if;

  if not semillero.puede_votar(p_texto) then
    raise exception 'Este texto ya no recibe valoraciones, o no te corresponde calificarlo';
  end if;

  select count(*) into v_esperados from semillero.criterios where activo;
  select count(*) into v_recibidos from jsonb_object_keys(p_puntajes);
  if v_recibidos <> v_esperados then
    raise exception 'Faltan criterios: llegaron % de %', v_recibidos, v_esperados;
  end if;

  begin
    insert into semillero.evaluaciones (texto_id, evaluador_id, comentario)
    values (p_texto, auth.uid(), nullif(btrim(p_comentario), ''))
    returning id into v_eval;
  exception when unique_violation then
    raise exception 'Ya calificaste este texto';
  end;

  insert into semillero.puntajes (evaluacion_id, criterio_id, valor)
  select v_eval, key::uuid, value::smallint
  from jsonb_each_text(p_puntajes);
end $$;

grant execute on function semillero.enviar_valoracion(uuid, jsonb, text) to authenticated;
