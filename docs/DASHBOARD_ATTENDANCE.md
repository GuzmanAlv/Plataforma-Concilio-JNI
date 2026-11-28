# Dashboard, asistencia y movimientos

## Navegación

Dashboard es la pantalla inicial (`/dashboard`) y el primer destino de Navbar/Drawer. Asistencia tiene una pantalla independiente (`/asistencia`), seguida de Integrantes, Tesorería e Inventario.

## Registro sabatino

El calendario operativo empieza el **28 de noviembre de 2026** y termina el **30 de octubre de 2027**: 49 sábados, agrupados en los meses del ciclo oficial noviembre 2026–octubre 2027. Seleccionar un mes muestra sus sábados; abrir un sábado muestra el resumen de los cuatro grupos.

Cada grupo informa presentes, ausentes y convocados cuando existe una sesión guardada. Si falta una sesión se muestra «Pendiente de registro», sin inventar ausencias. El resumen indica si están registrados los cuatro grupos o si aún es parcial.

«Tomar asistencia» carga las personas que pertenecían al grupo en la fecha elegida. «Corregir asistencia» abre las marcas guardadas. La RPC `guardar_asistencia` conserva la misma sesión al guardar nuevamente el mismo grupo y sábado. Se recargan los resúmenes y el Dashboard después de guardar. Se pueden preparar fechas futuras, pero estas no intervienen en los indicadores de constancia ni en las alertas hasta que llegue su fecha.

## Indicadores

Los filtros de mes, rango o ciclo afectan los indicadores y gráficos. El análisis incluye únicamente fechas desde el 28 de noviembre que ya han llegado y sesiones registradas; se basa en los convocados históricos, incluso al cambiar de grupo.

- Integrantes activos, personas con convocatorias y personas sin registros en el rango.
- Participación ponderada: presencias / convocatorias guardadas, sin promediar porcentajes de grupos de distinto tamaño.
- Mayor constancia: primero integrantes y después líderes, según su asignación actual. Dentro de cada categoría se ordena por porcentaje descendente; en empate, por presencias y luego por nombre. El ranking compacto muestra hasta cinco posiciones numeradas, nombre, grupo actual y porcentaje del periodo, sin ausencias ni fechas adicionales. Reutiliza el directorio ya cargado, sin consultas nuevas.
- Menor participación: tasa ascendente, con al menos tres convocatorias para comparar.
- Seguimiento: tres ausencias consecutivas o como máximo una presencia en las últimas tres convocatorias registradas. No se etiqueta a personas con menos de tres convocatorias.
- Grupo más activo por tasa de participación, mostrando su número de sesiones.
- Sábados con los cuatro grupos registrados y cambio de participación entre los dos últimos sábados completos con convocados.
- Cuatro gráficos de líneas con el color de cada grupo.

Una fecha sin sesión no equivale a una falta. Las personas dadas de baja se excluyen de las listas de seguimiento, conservando los totales históricos de sus sesiones.

## Tabla de tesorería y edición

El botón «Agregar egreso» está centrado debajo del gráfico de caja. Los movimientos se presentan en una tabla desplazable con Fecha, Tipo, Nombre, Descripción, Monto, Boleta y Acciones. Se puede ordenar por fecha, nombre o monto; el filtro de periodo se mantiene.

La tabla ocupa como mínimo el ancho de su tarjeta, con bordes redondeados recortados y separaciones de columnas compactas. Cuando el ancho disponible no alcanza, permite desplazamiento horizontal con barra visible. Los títulos y descripciones largos conservan el texto completo en una ayuda emergente. Se mantienen veinte movimientos por página.

«Editar» abre el formulario del egreso con sus datos actuales. Se pueden cambiar nombre, descripción, fecha y monto, conservar la boleta, reemplazarla o quitar su asociación. La actualización conserva el UUID y modifica el movimiento existente; no agrega otro egreso. Saldo, evolución y movimientos se recargan después de guardar. Los archivos reemplazados se conservan para evitar pérdidas por respuestas de red inciertas; pueden reconciliarse posteriormente como objetos sin referencias.

Las filas de ofrendas muestran el desglose mensual y su ingreso neto confirmado. Su acción de edición permite revisar y confirmar el mes. Ver `MONTHLY_OFFERINGS.md`.

## Directorio compacto

Las filas distribuyen nombre a la izquierda, fecha de nacimiento y edad al centro, y grupo con cargo a la derecha, junto al botón de edición. En móvil se usan el nombre corto del grupo y tamaños compactos para conservar esa distribución. Los nombres largos tienen un máximo de dos líneas con ayuda emergente; se mantienen la edición al tocar y la paginación de treinta integrantes.

## Validación

Pruebas de calendario, métricas con fechas futuras y sin registro, navegación responsiva, marcas de asistencia, tabla, edición y conservación/remoción de boleta. También se verificaron en Supabase las correcciones de asistencia sin duplicados y el cambio de saldo al editar un egreso, dentro de una transacción revertida sin alterar los datos reales.
