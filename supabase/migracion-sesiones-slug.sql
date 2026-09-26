-- Agregar slug a sesiones
alter table semillero.sesiones add column if not exists slug text unique;

-- Generar slugs iniciales basados en ID
update semillero.sesiones
set slug = 'sesion-' || id::text
where slug is null;
