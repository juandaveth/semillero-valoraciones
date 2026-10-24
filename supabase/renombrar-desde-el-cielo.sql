-- 24 oct 2026: el texto de Carlos Mario Calle (Sesión 6) se llama "Desde el cielo", no "En el aire".
update semillero.textos
set    titulo = 'Desde el cielo'
where  titulo = 'En el aire'
returning id, titulo, autor_nombre;
