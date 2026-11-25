# Supabase: esquema y reglas de negocio

La migración `supabase/migrations/202611250001_initial_schema.sql` crea la base del ciclo **1 de noviembre de 2026–31 de octubre de 2027**. No contiene jóvenes ficticios ni credenciales. Requiere un proyecto Supabase con PostgreSQL 15 o posterior por las vistas `security_invoker`.

## Instalación

1. Crea un proyecto Supabase y conserva su URL y su clave publicable/anon para el frontend. La clave `service_role` nunca se incorpora a Flutter, Render, APK ni repositorio.
2. Ejecuta la migración completa en SQL Editor como `postgres`, o vincula Supabase CLI y ejecuta `supabase db push`. La migración es de instalación, no un script para repetir sobre tablas existentes. Las actualizaciones posteriores se añaden como nuevas migraciones.
3. En Authentication crea al administrador e identifica su UUID. Asigna el primer perfil desde SQL Editor:

```sql
insert into public.perfiles(user_id,nombre,rol)
values ('UUID-REAL-DEL-USUARIO','Administrador','admin');
```

4. Desactiva el registro público si solamente habrá acceso por invitación. Un usuario creado en Auth sin fila en `perfiles` no puede leer datos del concilio.
5. Configura las URLs permitidas de Auth con la URL web definitiva de Render y las URLs locales que utilices. La base usa inicio por correo/contraseña; si añades OAuth o enlaces mágicos, configura también sus enlaces de retorno.
6. Comprueba los roles antes de introducir datos reales. No asignes `admin` desde metadatos enviados por el cliente.

## Tablas y relaciones

| Tabla | Función |
| --- | --- |
| `perfiles` | Usuarios autorizados y rol de acceso |
| `grupos` | Cuatro filas fijas: amarillo, verde, rojo y celeste |
| `integrantes` | Nombre, fecha de nacimiento y estado activo; la edad se calcula |
| `membresias_grupo` | Historial de grupo y rol, con intervalo `[fecha_inicio, fecha_fin)` |
| `asistencia_sesiones` | Único registro por grupo y sábado |
| `asistencia_registros` | Snapshot de convocados con presencia o ausencia explícita |
| `ofrendas` | Un ingreso bruto por sábado y desglose generado en PostgreSQL |
| `egresos` | Monto, fecha, concepto y ruta privada del comprobante |
| `configuracion_caja` | Una sola fila con el saldo inicial editable del ciclo |
| `auditoria_caja` | Registro inmutable para clientes de los cambios de saldo inicial |
| `configuracion_app` | `version_actual`, `build_actual` y `url_apk` HTTPS |
| `inventario_items` | Nombre, cantidad, estado y observaciones |

Todos los montos son `numeric`, en soles, con dos decimales. No se guardan edades ni saldos actuales duplicados. Los estados de inventario son `bueno`, `regular`, `malo` y `baja`.

## Directorio e historial

Usa estas RPC para mantener atómicos los cambios de historial:

```sql
select public.crear_integrante(
  p_nombre_completo => 'Nombre real',
  p_fecha_nacimiento => date '2005-06-12',
  p_grupo_id => 'amarillo',
  p_rol => 'integrante',
  p_fecha_inicio => date '2026-11-01'
);

select public.cambiar_grupo(
  p_integrante_id => 'UUID-INTEGRANTE',
  p_grupo_id => 'verde',
  p_rol => 'integrante',
  p_fecha => date '2026-11-25'
);

select public.archivar_integrante(
  p_integrante_id => 'UUID-INTEGRANTE',
  p_fecha => date '2026-11-25'
);
```

`crear_integrante` retorna el UUID del joven. `cambiar_grupo` retorna el UUID de la nueva membresía; enviar el mismo grupo y rol conserva la asignación vigente. Cambiar solo el rol también genera historial. La fecha nueva debe ser posterior al inicio vigente y no puede estar en el futuro. Los rangos de un mismo joven nunca se superponen. El día efectivo del cambio pertenece al nuevo grupo. Si una baja o un cambio invalidaría un registro de asistencia existente, la transacción se rechaza: debe elegirse una fecha posterior a esos registros.

La eliminación se implementa como **baja lógica** mediante `archivar_integrante`: cierra su membresía y marca `activo=false`, conservando asistencia y pertenencia histórica. No hay borrado físico de jóvenes desde el cliente. Nombre y nacimiento pueden editarse directamente; el cliente solo tiene permisos sobre esas dos columnas.

Los cuatro grupos comienzan con `activo=false` para cargar personas reales sin inventar líderes. Tras registrar al menos dos líderes vigentes, activa cada grupo con `update grupos set activo=true where id='amarillo'`. Un trigger diferido rechaza activar un grupo o modificar sus asignaciones dejando menos de dos líderes actuales. Los cambios futuros de grupo y bajas se rechazan para que una asignación programada no evada este mínimo con el paso del tiempo. El indicador `activo` es un estado de preparación; los cuatro grupos permanecen visibles.

## Asistencia corregible

```sql
select public.guardar_asistencia(
  p_grupo_id => 'amarillo',
  p_fecha => date '2026-11-07',
  p_presentes => array['UUID-PRESENTE-1','UUID-PRESENTE-2']::uuid[]
);
```

La RPC calcula la lista de integrantes según su pertenencia **en ese sábado**, incluye a los ausentes y devuelve el UUID de sesión. Una lista vacía (`array[]::uuid[]`) significa que no asistió ninguno. Repetir grupo/fecha corrige la sesión existente mediante `upsert`, sin duplicarla. Las escrituras directas a sesiones, registros e historial están revocadas para clientes. Las correcciones quedan identificadas por `updated_at` y `updated_by`.

La vista `asistencia_por_sabado` devuelve `fecha`, `grupo_id`, `total_convocados` y `total_presentes`. Un sábado sin sesión es **sin registro**, no una ausencia ni un cero automático. Los gráficos y rankings deben mostrar este estado y usar únicamente sesiones registradas. Para constancia, dividir presencias entre convocatorias registradas; para ausencias recientes, considerar las últimas sesiones registradas de cada integrante, respetando cambios de grupo y excluyendo fechas futuras. El grupo más activo se puede comparar por tasa de participación; debe mostrarse también el número de sesiones para interpretar la comparación. Esos criterios quedan para la siguiente pantalla de dashboard.

## Caja y ofrendas

Al insertar una ofrenda solo envía `fecha` y `monto_bruto`. PostgreSQL genera:

- `aporte_distrito = round(monto_bruto × 0.10, 2)`.
- `colaboracion_fija = S/ 10.00`.
- `monto_neto = monto_bruto − aporte_distrito − colaboracion_fija`.

Ejemplo: bruto S/ 100.00 → distrito S/ 10.00, colaboración S/ 10.00, neto S/ 80.00. Una ofrenda de S/ 5.00 produce neto **−S/ 5.50** conforme a la fórmula solicitada; no se altera silenciosamente a cero. La interfaz debe mostrar ese resultado antes de guardar. Un sábado admite una sola ofrenda: para corregirla se actualiza la existente.

La vista `resumen_caja` devuelve el saldo inicial, ingresos brutos, aportes al distrito, colaboraciones, ingresos netos, egresos y saldo actual. El saldo inicial es editable por `admin` y `tesoreria`, y cada cambio genera auditoría.

`evolucion_caja` devuelve una fila por día del ciclo con `fecha`, `ingresos_netos` **del día**, `egresos` del día y `saldo_caja` acumulado desde noviembre. Al filtrar meses o rangos, conserva el saldo de arrastre calculado desde el inicio. El gráfico de ingresos debe etiquetar si representa ingresos diarios o un agregado semanal; no mezclarlo con acumulados sin explicarlo.

## Acceso

| Acción | admin | secretaria | tesoreria | consulta |
| --- | --- | --- | --- | --- |
| Leer directorio, asistencia, caja e inventario | Sí | Sí | Sí | Sí |
| Crear/editar/baja de jóvenes y tomar asistencia | Sí | Sí | No | No |
| Activar grupos y editar inventario | Sí | Sí | No | No |
| Ofrendas, egresos, saldo inicial, comprobantes | Sí | No | Sí | No |
| Leer auditoría de saldo inicial | Sí | No | Sí | No |
| Gestionar perfiles y versión APK | Sí | No | No | No |

`configuracion_app` puede leerse sin sesión para comprobar actualizaciones; no contiene datos personales ni secretos. Todas las demás tablas tienen RLS. Las vistas operan con `security_invoker=true`. Las RPC privilegiadas verifican el perfil y fijan `search_path=''`. Los usuarios no pueden otorgarse roles a sí mismos.

## Comprobantes en Web y Android

La migración crea el bucket privado `comprobantes`, limitado a **10 MiB** y MIME `image/jpeg`, `image/png`, `image/webp`, `image/heic`, `image/heif`. La selección/subida se hace con bytes para funcionar sin `dart:io` en navegador. Usa una ruta única, por ejemplo `egresos/<uuid>/<uuid>.jpg`. Guarda esa ruta relativa en `egresos.comprobante_path`; no guardes la URL firmada ni una ruta local del dispositivo.

Para visualizar, solicita una URL firmada con una duración corta; el repositorio usa 60 segundos. Solo usuarios autorizados pueden descargar; solamente administración/tesorería pueden subir, reemplazar y eliminar. Si falla guardar el egreso después de la subida, el repositorio conserva la imagen: un timeout puede ocurrir mientras el INSERT todavía se está confirmando. Una consulta inmediata sin resultados tampoco garantiza que esa transacción haya terminado. Los archivos huérfanos se deben reconciliar después de que las escrituras pendientes hayan concluido. Al reemplazar un comprobante, primero guarda la nueva ruta y después elimina el anterior. Storage y PostgreSQL no comparten una transacción.

HEIC/HEIF pueden almacenarse, pero no todos los navegadores los muestran. Una pantalla de producción debe convertir a JPEG/PNG o informar que el archivo requiere descarga. Esta entrega prepara la estructura de datos; el formulario y la conversión se completan después.

## Pruebas y referencias

`supabase/tests/001_business_rules.sql` es una prueba transaccional para ejecutar en una base de pruebas después de migrar; termina con `ROLLBACK`, sin dejar personas ni movimientos ficticios. Se ejecuta como `postgres` porque prepara usuarios temporales y luego cambia al rol `authenticated` para probar restricciones reales de cliente. No la ejecutes como una llamada RPC ni desde Flutter.

La migración y esta prueba se ejecutaron correctamente con PostgreSQL 18.6 local y tablas/roles mínimos que simulan Auth y Storage. Se comprobaron permisos por rol, políticas de objetos privados, fechas del ciclo, historial, mínimo de líderes, correcciones de asistencia, redondeo, rechazo de `NaN`, desglose, saldo, arrastre y auditoría. Esto valida SQL y RLS; la subida real de imágenes, las URLs firmadas y la integración con Auth requieren comprobarse en el proyecto Supabase de destino.

Referencias oficiales: [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [funciones y seguridad](https://supabase.com/docs/guides/database/functions), [Storage y políticas](https://supabase.com/docs/guides/storage/security/access-control), [triggers de PostgreSQL](https://www.postgresql.org/docs/current/sql-createtrigger.html).
