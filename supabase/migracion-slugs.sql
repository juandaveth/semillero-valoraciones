-- Un nombre corto por taller, para que cada uno tenga su propia ruta:
-- /#/panel/invisibles y /#/panel/fertiles
alter table semillero.talleres add column if not exists slug text;

update semillero.talleres set slug = 'invisibles'
where slug is null and nombre = 'Narradores Invisibles';

update semillero.talleres set slug = 'fertiles'
where slug is null and nombre = 'Error Fértil';

-- Por si queda alguno sin nombrar: uno derivado del nombre, sin tildes.
update semillero.talleres
set    slug = regexp_replace(
         lower(translate(nombre, 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN')),
         '[^a-z0-9]+', '-', 'g')
where  slug is null;

create unique index if not exists idx_talleres_slug on semillero.talleres(slug);
