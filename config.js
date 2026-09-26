// Credenciales públicas del proyecto de Supabase.
// La anon key va en el navegador a propósito: cualquiera que abra la app la ve.
// Lo que protege los datos son las políticas RLS del esquema `semillero`,
// no el secreto de esta llave.
window.SUPABASE_CONFIG = {
  url: 'https://sosqjpjwcqyzjfypuobn.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvc3FqcGp3Y3F5empmeXB1b2JuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5MTEyMTQsImV4cCI6MjEwMzQ4NzIxNH0.MTmjxvBNcxbZsNkdiCuBurn082WZiAEW3qwgp46aF0A',
  schema: 'semillero'
};
