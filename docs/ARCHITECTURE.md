# Arquitectura de Concilio JNI Dreamrs

Esta primera entrega establece el proyecto Flutter para Web y Android, la navegación, los modelos, la conexión de lectura y el contrato de Supabase. Las pantallas se completan por módulo sobre esa base. El periodo oficial es **1 de noviembre de 2026 a 31 de octubre de 2027**; la moneda es **PEN, S/**.

## Estructura de carpetas

```text
lib/
  main.dart                       # Configuración y arranque de Supabase
  app/
    app.dart                      # MaterialApp, locale es_PE y router
    router/                       # Rutas y navegación con GoRouter
    shell/                        # Navbar, Drawer y marco responsivo
    theme/                        # Material 3 y colores de los cuatro grupos
  core/
    config/                       # Variables públicas de compilación
    domain/                       # CivilDate, Money, periodo y filtros
    supabase/                     # Cliente inyectado, sesión y perfil
  shared/
    widgets/                      # Estados vacío, error, carga y encabezados
  features/
    auth/presentation/            # Inicio de sesión y control de acceso
    groups/domain/                # Los cuatro grupos y sus identificadores
    members/
      domain/                     # Joven, rol e historial de pertenencia
      data/                       # Repositorio Supabase del directorio
      presentation/               # Directorio y filtros
    attendance/
      domain/                     # Sesión, registro y envío de asistencia
      data/                       # Lectura agregada y contrato de asistencia
      presentation/               # Dashboard, gráficas y filtro de periodo
    treasury/
      domain/                     # Ofrenda, desglose, egreso y caja
      data/                       # Consulta de caja y movimientos
      presentation/               # Resumen financiero
    inventory/
      domain/                     # Ítem, cantidad y estado
      data/                       # Consulta de inventario
      presentation/               # Listado base ampliable
    updates/domain/               # Versión publicada, build y URL de APK
test/
  domain/                         # Reglas y contratos de los modelos
supabase/
  migrations/                     # SQL versionado y ordenado por fecha
  tests/                          # Verificación transaccional del esquema
web/                              # Entrada HTML y manifest del sitio
android/                          # Plataforma nativa y firma del APK
scripts/                          # Compilación reproducible para Render
.github/workflows/                # Análisis, pruebas y builds de CI
render.yaml                       # Static Site y rewrite SPA
docs/                             # Arquitectura, dominio, Supabase y despliegue
```

La estructura es **por funcionalidad**. `domain` contiene las reglas y tipos de cada módulo; `data` traduce consultas y respuestas de Supabase; `presentation` organiza widgets y estado de pantalla. Los módulos solo agregan capas cuando las necesitan: autenticación no requiere hoy un dominio propio y el control de versiones todavía no tiene pantalla. Esto evita llenar el proyecto con clases sin una responsabilidad concreta.

## Flujo y responsabilidades

`main.dart` lee las variables de compilación, inicializa el cliente y lo inyecta mediante Riverpod. `ConcilioApp` aplica tema, idioma y GoRouter. Cada pantalla obtiene datos a través de sus proveedores y repositorios; los modelos de dominio no importan Flutter ni Supabase.

Riverpod administra dependencias y respuestas asíncronas, incluidos estados de carga, error y vacío. La sesión y el perfil autorizado forman parte de las dependencias de acceso. La caché de datos debe invalidarse al cambiar de sesión y, cuando se incorporen formularios, después de cada mutación exitosa.

GoRouter define `/asistencia`, `/integrantes`, `/tesoreria` y `/inventario`. El `ShellRoute` comparte el marco visual. `ResponsiveShell` muestra navegación superior en pantallas amplias y Drawer en las estrechas; sus destinos comparten los mismos paths. La estrategia Web usa paths legibles y Render devuelve `index.html` al recargar una ruta interna.

El cliente muestra los datos y anticipa errores de formulario. **PostgreSQL es la autoridad** sobre pertenencias históricas, unicidad de asistencia, fechas, permisos y montos guardados. Las operaciones de varias tablas se exponen como RPC transaccionales. El detalle se encuentra en [SUPABASE.md](SUPABASE.md).

## Decisiones de dominio

| Decisión | Implementación y motivo |
| --- | --- |
| Fechas civiles | `CivilDate` intercambia `YYYY-MM-DD` con columnas SQL `date`, sin convertir cumpleaños o sábados a otro huso horario. |
| Ciclo único | `CouncilPeriod.official` concentra los límites; `PeriodFilter` representa todo el ciclo, un mes o un rango inclusivo. SQL valida el mismo periodo. |
| Dinero exacto | `Money` usa centavos enteros; PostgreSQL almacena `numeric(12,2)`. El desglose definitivo lo generan las columnas SQL. |
| Edad calculada | Se deriva del nacimiento y de una fecha de referencia; no se persiste un valor que quede obsoleto. |
| Historial de grupo | Las membresías usan intervalos `[inicio, fin)`. Traslados y cambios de rol conservan las asignaciones anteriores. |
| Baja de integrantes | La baja lógica preserva historial y asistencias; evita romper reportes anteriores. |
| Cuatro grupos | Identificadores fijos `amarillo`, `verde`, `rojo`, `celeste`, con acentos visuales consistentes. |
| Líderes | Los grupos se preparan inicialmente inactivos y se activan con al menos dos líderes. SQL protege ese mínimo. |
| Asistencia corregible | Una sesión por grupo y sábado; guardar otra vez corrige la sesión, con snapshot de convocados. |
| Caja | Saldo inicial editable + ingresos netos − egresos. El 10% y los S/ 10.00 quedan en el detalle y no se suman a caja. |
| Comprobantes | Ruta privada de Storage en el egreso, bytes en Web/Android y URL firmada al consultar. El flujo de formulario se completa después. |
| Actualizaciones APK | Versión informativa y número de build entero. La URL HTTPS y los datos se publican en `configuracion_app`. |

Las reglas de redondeo, cumpleaños del 29 de febrero y contratos JSON se documentan en [DOMAIN.md](DOMAIN.md).

## Acceso y propiedad de los datos

Las personas del directorio y las cuentas de acceso son conceptos distintos. Registrar a un joven no crea una cuenta de usuario. Nombrarlo líder tampoco le otorga permisos para entrar o administrar la aplicación.

| Concepto | Dónde se registra | Alcance |
| --- | --- | --- |
| Identidad de acceso | Supabase Auth | Correo, contraseña y sesión de un operador. |
| Rol de aplicación | `perfiles.rol` | `admin`, `secretaria`, `tesoreria` o `consulta`; determina permisos mediante RLS y RPC. |
| Rol juvenil | `membresias_grupo.rol` | `lider` o `integrante`; representa su función en un grupo y conserva historial. |
| Integrante | `integrantes` | Nombre, nacimiento y estado de una persona del concilio. |

Los datos pertenecen a un único concilio para el ciclo configurado. No hay aislamiento por iglesia, organización o múltiples concilios en esta entrega; añadirlo requeriría una clave de organización y políticas en todas las tablas. Las operaciones se autorizan por el perfil asignado por administración. El cliente no puede otorgarse permisos ni introducir una clave privilegiada.

El bucket de comprobantes es privado. La fila pública de versión del APK contiene únicamente metadatos de distribución. El esquema no publica nombres, nacimientos, asistencias ni finanzas a usuarios anónimos. La matriz de permisos está en [SUPABASE.md](SUPABASE.md).

## Criterios previstos para los insights

Esta entrega prepara datos y gráficas de consulta; los rankings y alertas siguientes se implementan en una fase posterior. Se aplicarán a sesiones guardadas dentro del filtro y con fecha hasta la fecha de referencia, nunca a sábados futuros.

- **Grupo más activo:** `sum(presentes) / sum(convocados)` en el rango. Se mostrará el número de sesiones y convocatorias junto al porcentaje. Si el denominador es cero no existe una tasa comparable. Los empates se muestran como tales.
- **Constancia individual:** presencias divididas entre convocatorias registradas del integrante. Se respeta el snapshot histórico, incluso si cambió de grupo. El resultado incluye ambas cantidades para que una única convocatoria no aparente la misma evidencia que veinte.
- **Ausencias recientes:** señalar a un integrante activo cuando tenga al menos **tres ausencias consecutivas** en sus últimas convocatorias de sesiones guardadas. Cada sesión se considera cerrada al guardar la toma. La lista recorre sus convocatorias reales a través de los grupos, hasta hoy, y muestra las fechas que sustentan el resultado.
- **Participación general:** total de presencias y convocatorias, tasa, sesiones registradas y cobertura del periodo seleccionado. Un sábado sin toma de asistencia permanece como **sin registro**, no se convierte en cero ni en ausencia.

Sin convocatorias suficientes no se etiqueta a una persona como ausente reiterada. Sin registros comparables no se designa un grupo más activo. Las alertas describen la asistencia registrada y no afirman que una persona abandonó el concilio.

## Alcance de esta primera entrega y continuidad

La base incluye navegación responsiva, autenticación por correo/contraseña cuando Supabase está configurado, modelos inmutables y consultas iniciales para las pantallas. La UI de módulos es de lectura, con filtros del dashboard, estados vacíos y sin datos ficticios. Los modelos, tablas, políticas y RPC preparan las operaciones de escritura.

Los siguientes incrementos incorporan formularios de alta/edición/baja y traslado de integrantes, toma y corrección de asistencia, saldo inicial, ofrendas y egresos con comprobantes, y los insights definidos arriba. Después se amplía inventario y se añade el aviso de actualización Android. Cada incremento debe conectar el repositorio, invalidar los proveedores afectados y probar sus reglas y permisos antes de presentarlo como disponible.

El esquema se aplica a un proyecto Supabase real antes de probar la integración. El despliegue Web y el APK firmado se preparan con [DEPLOYMENT.md](DEPLOYMENT.md); crear los servicios, publicar un release o aplicar una migración remota son pasos de instalación separados de tener estos archivos listos.
