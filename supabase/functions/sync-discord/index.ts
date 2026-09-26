// Trae la lista de miembros del servidor de Discord y la guarda en
// semillero.discord_miembros. Solo la puede llamar un admin del taller.
//
// Variables que necesita (Edge Functions -> Secrets):
//   DISCORD_BOT_TOKEN   el token del bot
//   DISCORD_GUILD_ID    el id del servidor
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY las inyecta Supabase sola.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = Deno.env.get("SUPABASE_URL")!;
  const auth = req.headers.get("Authorization") ?? "";

  // 1. ¿Quién llama? Con SU token, para que la RLS diga la verdad.
  const comoUsuario = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
    db: { schema: "semillero" },
  });
  const { data: { user } } = await comoUsuario.auth.getUser();
  if (!user) return json({ error: "Hay que iniciar sesión" }, 401);

  const { data: perfil } = await comoUsuario
    .from("perfiles").select("rol").eq("id", user.id).single();
  if (perfil?.rol !== "admin") {
    return json({ error: "Solo un admin del taller puede sincronizar" }, 403);
  }

  // 2. Traer los miembros. Discord pagina de 1000 en 1000.
  const token = Deno.env.get("DISCORD_BOT_TOKEN");
  const guild = Deno.env.get("DISCORD_GUILD_ID");
  if (!token || !guild) {
    return json({ error: "Faltan DISCORD_BOT_TOKEN o DISCORD_GUILD_ID" }, 500);
  }

  const miembros: any[] = [];
  let despues = "0";
  for (let vuelta = 0; vuelta < 20; vuelta++) {
    const r = await fetch(
      `https://discord.com/api/v10/guilds/${guild}/members?limit=1000&after=${despues}`,
      { headers: { Authorization: `Bot ${token}` } },
    );
    if (!r.ok) {
      const detalle = await r.text();

      // 404 "Unknown Guild" es ambiguo: o el bot no está en ese servidor, o el
      // id es de otra cosa. Le preguntamos al bot dónde SÍ está, y así el id
      // correcto queda a la vista en vez de adivinarlo.
      if (r.status === 404) {
        const g = await fetch("https://discord.com/api/v10/users/@me/guilds", {
          headers: { Authorization: `Bot ${token}` },
        });
        if (g.ok) {
          const suyos = await g.json();
          const lista = suyos.map((x: any) => `${x.name} = ${x.id}`).join(" · ");
          return json({
            error: `El id ${guild} no es de ningún servidor donde esté el bot`,
            detalle: suyos.length
              ? `El bot está en: ${lista}`
              : "El bot no está en ningún servidor todavía",
          }, 502);
        }
      }

      // 403 casi siempre significa que falta el permiso de leer miembros.
      return json({ error: `Discord respondió ${r.status}`, detalle }, 502);
    }
    const lote = await r.json();
    miembros.push(...lote);
    if (lote.length < 1000) break;
    despues = lote[lote.length - 1].user.id;
  }

  // 3. Guardar el espejo.
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    db: { schema: "semillero" },
  });

  const filas = miembros.map((m) => ({
    discord_id: m.user.id,
    username: (m.user.username ?? "").replace(/#0+$/, ""),
    display_name: m.nick ?? m.user.global_name ?? m.user.username ?? "",
    roles: m.roles ?? [],
    es_bot: !!m.user.bot,
    sincronizado_en: new Date().toISOString(),
  }));

  const { error } = await admin
    .from("discord_miembros").upsert(filas, { onConflict: "discord_id" });
  if (error) return json({ error: error.message }, 500);

  // Quien ya no está en el servidor se va del espejo.
  const ids = filas.map((f) => f.discord_id);
  if (ids.length) {
    await admin.from("discord_miembros").delete().not(
      "discord_id", "in", `(${ids.map((i) => `"${i}"`).join(",")})`,
    );
  }

  // Los roles del servidor, para poder escogerlos en el panel.
  let roles = 0;
  const rr = await fetch(`https://discord.com/api/v10/guilds/${guild}/roles`, {
    headers: { Authorization: `Bot ${token}` },
  });
  if (rr.ok) {
    const lista = await rr.json();
    const filasRol = lista
      .filter((x: any) => x.name !== "@everyone" && !x.managed)
      .map((x: any) => ({
        role_id: x.id,
        nombre: x.name,
        posicion: x.position ?? 0,
        sincronizado_en: new Date().toISOString(),
      }));
    if (filasRol.length) {
      await admin.from("discord_roles").upsert(filasRol, { onConflict: "role_id" });
      const ids = filasRol.map((f: any) => f.role_id);
      await admin.from("discord_roles").delete().not(
        "role_id", "in", `(${ids.map((i: string) => `"${i}"`).join(",")})`,
      );
      roles = filasRol.length;
    }
  }

  return json({ ok: true, miembros: filas.length, roles });
});
