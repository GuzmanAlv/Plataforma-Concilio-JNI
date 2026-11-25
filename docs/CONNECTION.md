# Conexión con Supabase

Proyecto vinculado: **GuzmanAlv's Project** (`qxiirhtpwxqkcepuhokn`).
URL pública: `https://qxiirhtpwxqkcepuhokn.supabase.co`.

La migración `20261125164602_concilio_initial_schema.sql` está aplicada en el proyecto remoto. Su versión local coincide con el historial remoto para evitar volver a ejecutar la instalación. Las 12 tablas tienen RLS, los cuatro grupos están creados y el bucket `comprobantes` es privado. No se han cargado integrantes ficticios.

`config/local.json` contiene la URL y la clave publicable y permanece excluido de Git. Para iniciar la aplicación conectada desde la raíz del repositorio:

```powershell
flutter run -d chrome --dart-define-from-file=config/local.json
```

## Primera cuenta administradora

Correo indicado por el propietario: `ansleyalvarado15@gmail.com`.

Primero crear el usuario en Authentication → Users del proyecto, eligiendo su contraseña. Después asignar el perfil desde SQL Editor o mediante la integración autorizada:

```sql
do $$
declare usuario uuid;
begin
  select id into strict usuario from auth.users
  where lower(email) = 'ansleyalvarado15@gmail.com'
    and email_confirmed_at is not null;
  insert into public.perfiles(user_id, nombre, rol)
  values (usuario, 'Administrador', 'admin')
  on conflict (user_id) do update set rol = 'admin';
end;
$$;
```

La asignación exige una cuenta confirmada. Crear una cuenta Auth no otorga permisos de administración automáticamente. El perfil debe asignarlo el propietario o un administrador autorizado.

## Verificación realizada

- La API REST devuelve la versión pública `0.1.0`, build `1`.
- La API rechaza la lectura anónima de integrantes con HTTP 401.
- Authentication tiene habilitado el acceso por correo.
- Aún falta crear la cuenta administradora y verificar un alta desde Flutter con esa sesión.

Los asesores de Supabase señalan las cuatro RPC con `SECURITY DEFINER`: es una exposición intencional, limitada a usuarios autenticados y protegida dentro de cada función mediante el rol de `perfiles`; `anon` no tiene ejecución. [Detalle del asesor](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

Como mejoras posteriores de rendimiento quedan [índices de claves foráneas de auditoría](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys) y [consolidación de políticas permisivas](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies). Los índices todavía sin uso corresponden a una base recién creada.
