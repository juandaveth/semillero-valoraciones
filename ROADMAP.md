# Valoración de textos · Narradores Invisibles

Producción: https://narradores-invisibles.vercel.app
Desplegar con `./deploy.sh` (nunca `vercel --prod` solo: no mueve el alias).

## Antes de usarlo en serio

- [x] **Correr `supabase/migracion-ranking-publico.sql`.** Hecho el 11 de
      septiembre de 2026. Ojo: que corriera no prueba que funcione. El mensaje de
      rechazo es el mismo en la versión vieja y la nueva, así que desde fuera no
      se distinguen: lo confirma la prueba de abajo y ninguna otra cosa.
- [x] **Probar la ruta del participante con una cuenta sin rol admin.** Hecho el
      12 de septiembre de 2026, en vivo con Camilo, calificando dos textos.
      Queda pendiente solo la comprobación por consola de que no puede leer
      votos ajenos.
- [ ] **Comprobar por consola que un participante no lee votos ajenos.** Siendo
      participante: `(await sb.from('evaluaciones').select('*')).data.length`
      debe devolver solo los propios. La interfaz no puede demostrarlo.
- [ ] **Probar con más de dos teléfonos**, en la red del lugar donde va a ser.

## Prometido en el copy y no construido

- [x] **Acumulación entre sesiones.** Hecha el 16 de septiembre de 2026:
      tarjeta "Acumulado del taller" en el panel, con todos los textos de las
      sesiones cerradas ordenados por promedio, más la media de cada sesión.
      **Decisión: promedio simple.** Se construyó también una corrección por la
      severidad de cada evaluador y Juanda la descartó: el promedio es el de
      quienes estuvieron en esa clase, sin ajustes. Vale recordar que con los
      datos del 12 los tres textos quedaron dentro de 0.13 puntos, así que el
      orden es más ruido que señal: sirve para conversar, no para coronar.

## Lo que se va a notar en el salón

- [ ] **Saber quién falta por enviar, no solo cuántos.** Hoy el panel dice
      "12 de 17". En vivo la pregunta real es "¿a quién esperamos?".
- [ ] **Los ausentes rompen el contador.** Si tres personas no vinieron, nunca
      llega a 17 y el panel parece incompleto toda la sesión. Posible arreglo:
      marcar presentes al empezar, y que el denominador sean los presentes.
- [ ] **Qué pasa si alguien pierde señal al enviar.** El voto es atómico en la
      base (entra completo o no entra), pero el aviso de error en la interfaz es
      discreto y nadie lo va a ver en un teléfono.

## Decisiones aplazadas

- [ ] **Limpiar los datos de prueba** de la base. Acordado: después de la clase
      del 12 de septiembre de 2026.
- [ ] **El autor enlazado o no.** Hoy el bloqueo de "no califiques tu texto"
      solo actúa si el nombre escrito coincide exacto con un perfil registrado.
      Se dejó así a propósito. Alternativas: quitar el bloqueo del todo, u
      obligar a enlazar todo texto a un perfil.
- [ ] **Promedio por participante** (quién califica duro y quién suave). Se
      propuso y Juanda escogió otra cosa. Sigue siendo el insumo natural para
      corregir la acumulación.
- [ ] **Editar los criterios desde la app.** Están en tabla justamente para eso,
      pero hoy se cambian con SQL.

## Riesgo heredado

La base la comparte con el cotizador de contenedores, que usa la `service_role`
key desde Vercel. Esa llave se salta toda la RLS en cualquier esquema: quien la
tenga puede leer quién votó qué.
