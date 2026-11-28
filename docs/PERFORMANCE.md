# Rendimiento y navegación

## Cambios

- Las respuestas exitosas de directorio, resúmenes de asistencia, indicadores, caja, evolución, movimientos e inventario se conservan en memoria cinco minutos. Los errores no se retienen. No se escriben datos personales en una caché de disco adicional.
- El tiempo se cuenta desde que termina la consulta. Al vencer, Riverpod puede liberar el proveedor si no tiene consumidores; al salir y regresar después del vencimiento se consulta nuevamente. No hay sondeos periódicos ni precargas de todos los módulos.
- Cambiar de cuenta o cerrar sesión invalida las dependencias de datos. Renovar el token de la misma cuenta no vuelve a consultar todos los módulos ni reconstruye el shell por ese evento.
- Guardar integrantes invalida directorio, listas históricas, asistencia e indicadores; guardar asistencia invalida sesiones, resúmenes e indicadores; guardar tesorería invalida saldo, evolución y movimientos.
- `Actualizar datos` limpia las cachés. Permite consultar cambios de otros usuarios antes de su vencimiento. Las cachés no son sincronización en tiempo real.
- Los cuatro grupos de un mismo sábado comparten la carga del directorio histórico. Las marcas y la sesión se consultan nuevamente cada vez que se abre el editor; un fallo al guardar invalida la lista histórica para reconciliar cambios de grupo externos.
- La navegación entre módulos no anima transiciones de página ni vuelve a navegar al módulo que ya está seleccionado.
- El cálculo de constancia agrupa registros por integrante en una pasada, en vez de recorrer todas las asistencias por cada persona. Las clasificaciones calculadas se reutilizan en su objeto de indicadores.
- El directorio dibuja hasta 30 integrantes por página y la tabla financiera hasta 20 movimientos. Los filtros y totales siguen considerando todos los registros cargados. Esto limita los widgets creados; las consultas siguen paginándose con orden estable y sin truncar datos.
- El formulario de asistencia muestra directamente su lista, sin buscador interno.

## Verificación reproducible

`flutter test test/navigation_cache_test.dart` comprueba las solicitudes HTTP con el cliente Supabase y transporte simulado:

| Caso de prueba | Solicitudes |
| --- | --- |
| Primera visita a Integrantes y Tesorería, respuestas vacías | 6 |
| Regreso a esos mismos proveedores dentro de la caché | 0 adicionales |
| Directorio al abrir los cuatro grupos de un sábado | 2 en total: integrantes y membresías |
| Sesiones al abrir los cuatro grupos | 4; se consulta una vez por apertura |

La prueba también cubre cambio de cuenta, invalidación explícita, renovación de token y vencimiento. Las pruebas de tabla verifican que los 45 movimientos de una muestra se pueden consultar en tres páginas, sin dibujarlos todos juntos.

Estas cifras validan consultas evitadas, no una estimación de latencia de producción. La primera carga sigue dependiendo de la red, Supabase y el dispositivo.

## Probar rendimiento local

El modo de desarrollo mantiene herramientas y comprobaciones adicionales. Para comparar navegación con una compilación optimizada, detén la ejecución anterior y usa:

```powershell
flutter run -d chrome --profile --dart-define-from-file=config/local.json
```

Render compila Web en `release`. El archivo local de configuración continúa excluido de Git.
