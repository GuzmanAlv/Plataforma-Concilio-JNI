# Concilio JNI Dreamrs

**Acceso actual:** los roles de acceso están desactivados temporalmente. Todas las cuentas que inician sesión con correo y contraseña tienen los mismos permisos, sin requerir una fila en `perfiles`. Los roles juveniles Líder/Integrante permanecen. Consulta [el estado de conexión](docs/CONNECTION.md).

Base modular en Flutter para **Web responsiva y Android**, con Supabase y despliegue como Static Site en Render. Ciclo oficial: **noviembre de 2026 a octubre de 2027**. Moneda: **PEN (S/)**.

## Primera entrega

- Navegación superior desde 1050 px y menú hamburguesa en móviles: Asistencia & Dashboard, Integrantes, Tesorería e Inventario.
- Modelos inmutables, fechas civiles, edad y cumpleaños, historial de grupos, filtros del ciclo y dinero en centavos.
- Dashboard con cuatro gráficos de asistencia y filtros por mes/rango/ciclo. Directorio con búsqueda y cumpleaños. Resumen, movimientos y gráfico de caja; simulador de ofrendas e inventario base.
- Conexión de lectura mediante Riverpod y repositorios Supabase. Acceso con correo/contraseña y perfiles autorizados.
- Migración SQL con RLS, Storage privado, RPC transaccionales, caja auditada y configuración de versiones del APK.
- Proyecto Android, configuración de firma, Render SPA y CI para análisis, pruebas y builds Web/APK debug.

**Alcance actual:** con Supabase configurado se pueden registrar integrantes, tomar y corregir asistencias, guardar y corregir ofrendas, y registrar y editar egresos con comprobantes opcionales. El Dashboard incluye constancia y seguimiento. Sin configuración, la aplicación muestra una vista previa sin guardado. Quedan pendientes las interfaces de edición/baja y traslado de integrantes, y la comprobación de actualizaciones de APK.

## Ejecutar

**Ofrendas:** `Tesorería → Registrar ofrenda` permite elegir un sábado del ciclo e ingresar el monto bruto. El formulario muestra el 10% para el distrito, S/ 10.00 de colaboración y el neto que ingresa a caja. Supabase calcula y guarda ese desglose. Cada fecha tiene un único registro: seleccionar una fecha existente o usar su botón de edición permite corregirla. Tras guardar se actualizan saldo, gráfico y movimientos.

**Diseño de asistencia:** el selector de mes incluye navegación anterior/siguiente, año y cantidad de sábados. Las tarjetas de cada sábado muestran estado de registro, avance de los cuatro grupos y presentes, ausentes y convocados por grupo al desplegarlas. Un grupo pendiente no se cuenta como ausente.

**Navegación y seguimiento:** Dashboard y Asistencia están separados, con Dashboard primero. El registro sabatino empieza el 28/11/2026 y se organiza por meses, con resúmenes por grupo y correcciones. El Dashboard incluye constancia y seguimiento. Tesorería muestra una tabla con edición de egresos; su botón de alta está centrado bajo el gráfico. Ver [detalle y reglas de indicadores](docs/DASHBOARD_ATTENDANCE.md).

**Egresos:** `Tesorería → Agregar egreso` registra nombre, monto en soles, fecha del ciclo y descripción, con foto de boleta opcional (máximo 10 MiB). Los comprobantes van al Storage privado. El saldo, el gráfico y los movimientos se recargan tras guardar. Cada envío conserva su UUID para reconciliar reintentos sin duplicar gastos. La migración `20261127035725_expense_name.sql` añade el nombre del gasto y está aplicada en Supabase.

El botón `Nuevo integrante` está centrado debajo del recuadro/listado del directorio.

**Actualización — registro de integrantes:** disponible en `Integrantes → Nuevo integrante` para perfiles `admin` y `secretaria`. Incluye nombre, nacimiento, edad automática, grupo, rol y fecha de ingreso. Guarda mediante la RPC `crear_integrante` y actualiza el directorio. Sin Supabase se puede abrir el formulario en vista previa, con guardado deshabilitado. Las pantallas de edición/baja y traslado siguen pendientes.

Requiere **Flutter 3.44.4 / Dart 3.12.2**, fijados en CI y Render. El lockfile está versionado.

```powershell
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Para conectar datos, aplica primero la [guía de Supabase](docs/SUPABASE.md), crea la cuenta de acceso y asígnale un perfil desde SQL. Copia `config/example.json` a `config/local.json` y completa la URL y **clave pública** del proyecto:

```powershell
Copy-Item config/example.json config/local.json
flutter run -d chrome --dart-define-from-file=config/local.json
```

El archivo local está ignorado por Git. La clave pública se incluye en Web/APK; las políticas RLS protegen los datos. La aplicación y el script de Render rechazan claves secretas o JWT con rol `service_role`.

```powershell
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/local.json
flutter build apk --debug --dart-define-from-file=config/local.json
```

El APK debug sirve para pruebas; la distribución requiere firma release. La Web se puede abrir desde Safari en iPhone; el APK corresponde a Android. Consulta los pasos de [despliegue y firma](docs/DEPLOYMENT.md).

## Documentación

| Entrega | Ubicación |
| --- | --- |
| Arquitectura de carpetas y decisiones | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| SQL completo | [supabase/migrations/20261125164602_concilio_initial_schema.sql](supabase/migrations/20261125164602_concilio_initial_schema.sql) |
| Puesta en marcha, permisos y RPC | [docs/SUPABASE.md](docs/SUPABASE.md) |
| Modelos y contratos de datos | [docs/DOMAIN.md](docs/DOMAIN.md) |
| Web/Render y APK Android | [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) |
| Pruebas de integridad y acceso SQL | [supabase/tests/001_business_rules.sql](supabase/tests/001_business_rules.sql) |

No se crean jóvenes, líderes ni movimientos financieros ficticios. Los cuatro grupos se crean inactivos para permitir registrar sus líderes; al activarlos se exige el mínimo de dos. Las bajas preservan los datos históricos. Una ofrenda pequeña puede tener neto negativo: se mantiene la fórmula solicitada sin truncar el resultado.
