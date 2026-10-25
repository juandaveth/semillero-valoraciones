# Valoración de textos · Narradores Invisibles

Producción: https://narradores-invisibles.vercel.app
Desplegar con `./deploy.sh` (nunca `vercel --prod` solo: no mueve el alias).

## Estado: en pausa desde el 25 de octubre de 2026

El taller terminó. La app queda en el aire tal como está: los participantes ven
el "Acumulado del taller" (textos seleccionados para los fanzines, solo los que
tienen 10 valoraciones o más) y cada autor ve lo suyo en su perfil.

Nada de lo de abajo se construye mientras no haya un taller nuevo que lo use.
Si vuelve, se empieza por "Antes de reabrir", en ese orden.

## Antes de reabrir

1. **Comprobar por consola que un participante no lee votos ajenos.** Nunca se
   hizo (pendiente desde el 11 de septiembre). La interfaz no puede demostrarlo.
   Se hace solo, bajándose de admin un momento:
   1. SQL Editor: `update semillero.perfiles set rol = 'participante' where
      id = (select id from auth.users where email = 'jd.reyespaez@gmail.com');`
      y anotar `select count(*) from semillero.evaluaciones e join auth.users u
      on u.id = e.evaluador_id where u.email = 'jd.reyespaez@gmail.com';`
   2. En Chrome, recargar la app (ya no sale "Panel"), `Cmd + Option + J` y
      correr `(await sb.from('evaluaciones').select('*')).data.length`
      (si no deja pegar, escribir `allow pasting`).
   3. Mismo número que el paso 1 = anonimato real. Más = cualquiera ve quién
      votó qué: parar todo.
   4. Volver a admin: el mismo `update` con `rol = 'admin'`.
2. **Riesgo heredado: la `service_role` del cotizador.** La base la comparte con
   el cotizador de contenedores, que usa esa llave desde Vercel. Se salta toda
   la RLS: quien la tenga puede leer quién votó qué. Sacar el semillero a su
   propio proyecto de Supabase o quitarle la llave al cotizador.
3. **Probar en teléfono lo que salió sin probar:**
   - El commit 1e78fbe (3 de octubre): el autor no se atasca en su propio
     texto, un envío fallido no borra nada, errores junto al botón.
   - El acumulado visto con una cuenta de participante (solo se probó como admin).
   - En iPhone real, si la barra fija tapa el comentario con el teclado abierto.
   - Con más de dos teléfonos, en la red del lugar.
4. **Limpiar los datos de prueba** de la base (acordado desde el 12 de
   septiembre, nunca hecho).

## Deuda en el código

- [ ] **Enlaces de Discord escritos en el código y buscados por título**
      (`discordLinks` en `cargarRankingData`). Si alguien cambia un título, el
      texto pierde su enlace sin error. Lo bien hecho: columna opcional
      `textos.discord_url` que el equipo pega en el panel, y que sirva también
      para mostrar "Leer el texto en Discord" en la pantalla de calificación.
- [ ] **Copy del modelo viejo** que sigue en pantalla: "No recargues",
      "Espera al siguiente texto", "Al final vas a ver los promedios".
- [ ] **Leyenda fija de la escala** al calificar (1 todavía no funciona ·
      5 punto fuerte).
- [ ] `generarRankingModal` ya no se usa: borrarla.
- [ ] `cargarRankingData` trae las sesiones de todos los talleres y llama una
      función por sesión. Con un solo taller no importa; con varios, filtrar
      por el taller del participante.
- [ ] Detonantes y fanzines del perfil van a mano en `documentosSesion`, uno
      por sesión.

## Lo que se notaría en el salón (si hay otro taller presencial)

- [ ] **Saber quién falta por enviar, no solo cuántos.**
- [ ] **Los ausentes rompen el contador.** Posible arreglo: marcar presentes al
      empezar y que el denominador sean los presentes.
- [ ] **Qué pasa si alguien pierde señal al enviar.** El voto es atómico, pero
      el aviso de error es discreto.

## Decisiones aplazadas

- **El autor enlazado o no.** El bloqueo de "no califiques tu texto" solo actúa
  si el nombre coincide exacto con un perfil. Se dejó así a propósito.
- **Promedio por participante** (quién califica duro y quién suave). Juanda lo
  descartó para el acumulado; sigue siendo el insumo si algún día se corrige.
- **Editar los criterios desde la app.** Están en tabla para eso; hoy, por SQL.

## Hecho (para no volver a discutirlo)

- Acumulado del taller (16 sep): promedio simple, sin corrección por severidad.
- Calificación secuencial, sesión abierta hasta el martes (3 oct).
- Acumulado visible para participantes, mínimo de 10 valoraciones, enlaces de
  Discord de los 8 textos y "En el aire" renombrado a "Desde el cielo" (24 oct).
