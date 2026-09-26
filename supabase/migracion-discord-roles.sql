-- Los roles del servidor, para escogerlos de una lista en vez de pegar ids.
-- Pegar un id a mano fue justo lo que costó una hora con el guild equivocado.
create table if not exists semillero.discord_roles (
  role_id         text primary key,
  nombre          text not null default '',
  posicion        int  not null default 0,
  sincronizado_en timestamptz not null default now()
);

alter table semillero.discord_roles enable row level security;

drop policy if exists roles_admin_ve on semillero.discord_roles;
create policy roles_admin_ve on semillero.discord_roles
  for select to authenticated using (semillero.es_admin());

grant select on semillero.discord_roles to authenticated;
grant all    on semillero.discord_roles to service_role;
