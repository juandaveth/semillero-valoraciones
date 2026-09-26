-- El autor se escribe a mano. Si el nombre coincide con alguien registrado,
-- además queda enlazado, y solo entonces el sistema sabe que el texto es suyo.
alter table semillero.textos alter column autor_id drop not null;
alter table semillero.textos add column if not exists autor_nombre text;

-- puede_votar tiene que aguantar un autor sin cuenta:
-- si no está enlazado, nadie queda excluido de calificarlo.
create or replace function semillero.puede_votar(p_texto uuid)
returns boolean language sql stable
security definer set search_path = semillero, public as $$
  select exists (
    select 1
    from semillero.textos t
    join semillero.sesiones s on s.id = t.sesion_id
    where t.id = p_texto
      and s.texto_en_concurso_id = t.id
      and s.fase = 'en_curso'
      and (t.autor_id is null or t.autor_id <> auth.uid())
      and semillero.esta_inscrito(s.taller_id)
  );
$$;
