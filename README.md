# Ocre · CRM

Sistema de gestión de Ocre (reservas, clientes, proveedores, cobros, leads y egresos).

- **App:** `index.html`. Es un solo archivo, publicado con GitHub Pages.
- **Datos:** Supabase, proyecto «AL OESTE» (el nombre del proyecto en Supabase). Cada sección del CRM es una tabla `crm_*` con `id` y `data` (jsonb).
- **Acceso:** usuarios de Supabase Auth que estén cargados en `crm_usuarios`. Las políticas de seguridad (RLS) bloquean todo lo demás.
- **Esquema:** `supabase_schema.sql`. Se puede volver a correr sin romper nada.

La clave que figura en `index.html` es la clave **pública** de Supabase, pensada para ir en el navegador. Nunca subir acá la clave secreta (service_role).

## Habilitar un usuario

1. Supabase → Authentication → Users → Add user (con «Auto Confirm User»).
2. SQL Editor:

```sql
insert into public.crm_usuarios (user_id, email, nombre)
select id, email, 'Nombre' from auth.users where email = 'email@ejemplo.com';
```
