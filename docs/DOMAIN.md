# Modelos de dominio

Los modelos son Dart puro, inmutables y sin dependencia de Flutter, Supabase o generación de código. Los nombres de clase están en inglés y los mapas JSON usan exactamente los nombres SQL en español. El frontend no recalcula ni sobrescribe columnas generadas de PostgreSQL.

| Archivo | Tipos principales |
| --- | --- |
| `lib/core/domain/civil_date.dart` | `CivilDate`: fecha civil estricta `YYYY-MM-DD`, comparación, edad, cumpleaños |
| `lib/core/domain/council_period.dart` | `CouncilPeriod.official`, `CivilDateRange`, `PeriodFilter` por todo el ciclo, mes o rango inclusivo |
| `lib/core/domain/money.dart` | `Money`: PEN en centavos enteros, lectura decimal exacta y redondeo |
| `lib/features/groups/domain/group.dart` | `GroupId`, `Group` |
| `lib/features/members/domain/member.dart` | `Member`, `MemberRole`, `GroupMembership` |
| `lib/features/attendance/domain/attendance.dart` | `AttendanceSession`, `AttendanceRecord`, `AttendanceSubmission` |
| `lib/features/treasury/domain/treasury.dart` | `Offering`, `OfferingBreakdown`, `Expense`, `CashSettings` |
| `lib/features/inventory/domain/inventory_item.dart` | `InventoryItem`, `InventoryCondition` |
| `lib/features/updates/domain/app_version_config.dart` | `AppVersionConfig` |

## Fechas y periodo

El ciclo oficial es **2026-11-01 a 2027-10-31**, ambos inclusive. Tiene 52 sábados, desde el 7 de noviembre de 2026 hasta el 30 de octubre de 2027. Asistencia y ofrendas exigen sábado; los egresos admiten cualquier día del ciclo.

`CivilDate` no convierte fechas a UTC ni interpreta timestamps como fechas. SQL `date` se intercambia siempre como `YYYY-MM-DD`. `CivilDate.today()` usa el calendario local mostrado por el dispositivo. Para informes reproducibles, se pasa explícitamente una fecha de referencia a `ageOn` y `nextBirthdayOnOrAfter`; la interfaz usa formato peruano `es_PE`.

Para nacidos el **29 de febrero**, la política del producto calcula cumpleaños y cambio de edad el **28 de febrero** en años no bisiestos. Esto es una regla de presentación y cálculo del sistema.

`GroupMembership` usa intervalos **[fecha_inicio, fecha_fin)**. Un traslado efectivo el 9 de enero cierra la membresía anterior antes de ese día y abre la siguiente ese mismo día. El rol pertenece a la membresía histórica, no se guarda como un valor mutable en el integrante.

## Dinero

`Money.cents` evita sumas y porcentajes con coma flotante. `Money.parse` acepta `numeric` de Supabase como número o texto decimal; procesa el decimal y exponentes con enteros exactos. Las mitades se redondean alejándose de cero, igual que `round(numeric, 2)` en PostgreSQL. `Money.decimal` produce texto como `100.00` para enviar al backend. `Money.formatted` incluye `S/`.

El desglose por sábado es `distrito = round(bruto × 10%, 2)`, colaboración fija `S/ 10.00` y `neto = bruto − distrito − colaboración`. Se acepta un neto negativo cuando la ofrenda bruta no cubre ambas salidas. Por ejemplo, `S/ 10.00` produce neto `S/ -1.00`. El saldo usa exclusivamente **saldo inicial + netos − egresos**. El servidor sigue siendo la autoridad sobre los montos guardados.

`Offering.toWriteJson()` excluye `aporte_distrito`, `colaboracion_fija` y `monto_neto`, porque PostgreSQL los genera. `Offering.toJson()` serializa el detalle completo para lectura o caché; no debe pasarse como payload de escritura de la tabla. Los otros `toJson()` incluyen el identificador; al crear filas el repositorio decide si lo genera o lo deja al valor por defecto SQL.

## Asistencia y comprobantes

La ausencia de sesión o registro significa **sin toma de asistencia**, no una falta. `AttendanceSubmission.toRpcParams()` prepara el payload de `guardar_asistencia` y elimina identificadores repetidos. La validación de pertenencia histórica y el guardado sin duplicados se resuelven en una sola transacción en Supabase.

`Expense.receiptPath` guarda una ruta de Storage privado; la URL firmada se solicita al visualizar. Los bytes de las fotos y la lógica de carga pertenecen a la capa de datos. `AppVersionConfig` compara números de compilación enteros y exige HTTPS para el APK; no usa comparación lexicográfica de versiones.

## Repositorios Supabase

Cada módulo dispone de un `Supabase…Repository` en su carpeta `data`. Reciben un `SupabaseClient` explícito para facilitar inyección y pruebas. Miembros y asistencia usan RPCs para operaciones que deben ser atómicas. El archivo `lib/core/supabase/pagination.dart` recupera todas las páginas con orden estable y no asume que una respuesta menor a 500 filas sea la última; esto evita truncar directorios, asistencias y movimientos al superar los límites habituales de la API. Las lecturas paginadas reflejan el estado del servidor durante la consulta, no una transacción de snapshot entre solicitudes HTTP.

En inventario, `create` inserta un UUID nuevo y `save` actualiza un ítem existente sin enviar su `id` en las columnas modificables. Esto respeta los permisos SQL por columna y evita modificar identidades. Las actualizaciones solicitan la fila resultante para detectar filas ausentes o escrituras filtradas por permisos.

`SupabaseTreasuryRepository` lee las vistas `resumen_caja` y `evolucion_caja`; en esta última, `CashPoint.netIncome` corresponde al ingreso neto **de ese día**, mientras que `CashPoint.balance` conserva el saldo acumulado desde el inicio, incluso al filtrar un rango posterior. La inserción de ofrenda usa `upsert` por `fecha` para corregir el mismo sábado.

Para egresos con foto, `createExpense` recibe `Uint8List` y tipo MIME. Se puede obtener el contenido con `XFile.readAsBytes()` tanto en Web como en Android. Valida JPEG, PNG, WEBP, HEIC o HEIF y hasta 10 MiB; guarda un nombre UUID en el bucket privado y solicita enlaces de 60 segundos con `signedReceiptUrl`. Si falla la inserción del egreso, conserva la imagen para reconciliación: un timeout puede ocurrir antes o después de confirmar la transacción y una consulta inmediata tampoco demuestra que haya terminado. La limpieza de archivos huérfanos se debe realizar tras resolver las escrituras pendientes. El formulario futuro debe retener un identificador de envío para reconciliar resultados inciertos antes de permitir reintentos. La visualización de HEIC/HEIF depende del soporte del navegador; la captura y conversión a JPEG puede incorporarse al formulario futuro.

## Verificación

Los egresos incorporan `Expense.name` (`egresos.nombre`) para el nombre del gasto; `concept` mantiene su descripción. El formulario admite boleta opcional. Al guardar conserva un UUID por envío, congela los datos durante los reintentos y reutiliza la ruta de la foto ya subida. El repositorio recupera un registro existente por ese UUID y reconcilia conflictos de clave primaria; un timeout después del commit no genera un segundo gasto. Guardar correctamente invalida saldo, evolución y movimientos en Riverpod.

Ejecutar `flutter test test/domain`. Las pruebas cubren precisión monetaria y redondeo, netos negativos, fechas inválidas, sábados y límites de periodo, edad/cumpleaños, traslado con fin exclusivo, contratos JSON y payloads de asistencia.
