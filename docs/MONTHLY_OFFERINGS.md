# Ofrendas por sábado y cierre mensual

## Uso

1. En Tesorería, `Agregar ofrenda del sábado` registra fecha y monto bruto. Corregir una fecha actualiza el mismo registro.
2. Los importes se acumulan por mes. No se descuenta nada por sábado y estos importes pendientes no se suman a caja.
3. `Agregar ofrenda mensual` permite seleccionar un mes. Precarga la suma registrada, o permite ingresar directamente el total del mes si no se llevaron registros sabatinos.
4. Antes de confirmar se muestran: bruto, distrito (10%), colaboración (S/ 10.00 por mes) y neto. Si el bruto difiere del acumulado de sábados, se requiere explicar el ajuste. El bruto debe ser positivo, con hasta dos decimales.
5. Al confirmar se crea o corrige un único cierre por mes. Solo su neto entra a caja; no se suman además los sábados. No se confirman meses futuros.
6. Si cambia un sábado después del cierre, el mes indica que requiere revisión. La caja conserva el último neto confirmado hasta que se revise y reconfirme.

Ejemplo: cuatro sábados de S/ 100.00 → bruto mensual S/ 400.00 → distrito S/ 40.00 → colaboración S/ 10.00 → neto S/ 350.00.

La contribución se redondea sobre el bruto **mensual**, no sumando redondeos semanales. Un mes de bruto pequeño puede tener neto negativo; no se trunca a cero.

## Interfaz y consultas

- Los dos botones de alta aparecen encima del dashboard.
- El selector `Dashboard de caja / Ofrendas por sábado` reemplaza únicamente la sección principal. El listado de movimientos confirmados permanece debajo.
- La tabla de sábados tiene filtro mensual, fechas registradas y pendientes, acumulado, estimaciones y estado del cierre. En móvil se desplaza horizontalmente; como máximo contiene cinco filas.
- El formulario mensual usa un selector de mes, sin pedir una fecha de sábado.
- El gráfico y los movimientos financieros muestran cierres confirmados. Su fecha contable se asigna automáticamente al último día del mes, o al día de confirmación si se cierra el mes actual antes de terminar. Corregir un cierre conserva esa fecha.
- Las consultas de acumulados y registros sabatinos se cargan cuando se usan y se conservan cinco minutos. Alternar vistas no precarga gráficos ocultos.
- Guardar un sábado invalida únicamente registros y acumulados. Confirmar un mes actualiza acumulados, saldo, gráfico y movimientos.

## Supabase

Migración aplicada: `20261128154955_monthly_offering_settlements.sql`.

- `ofrendas_sabatinas`: fecha única y monto bruto; se renombró la tabla anterior conservando sus datos, autores y políticas. Los antiguos campos de deducción semanal se retiraron.
- `ofrendas_mensuales`: mes único, bruto confirmado, deducciones generadas por PostgreSQL, neto, motivo, versión y huella de los sábados revisados.
- `resumen_ofrendas_mensuales`: doce meses del ciclo con suma, cantidad de sábados y estado de revisión. Es una vista con `security_invoker`.
- `confirmar_ofrenda_mensual`: operación transaccional con `security_invoker`, control de versión y revisión de la fuente. Rechaza datos obsoletos. Un reintento idéntico devuelve el cierre existente sin duplicarlo.
- Los cambios sabatinos y las confirmaciones del mismo mes se serializan con el mismo bloqueo transaccional. Las reglas de revisión de la fuente también se validan mediante trigger para las escrituras directas.
- `resumen_caja` y `evolucion_caja` consumen exclusivamente cierres mensuales confirmados y egresos. El saldo inicial y los gastos existentes se conservan.
- Las tablas tienen RLS. Las nuevas tablas, vistas y RPC están restringidas a cuentas autenticadas según el modo de acceso vigente.

Los sábados previos a esta migración se conservan como pendientes; la migración no confirma importes automáticamente.

## Verificación

`supabase/monthly_offerings_test.sql` ejecuta pruebas en una transacción y revierte todos sus cambios. Cubre cuatro sábados, deducción única, caja pendiente, confirmación, reintentos, correcciones posteriores, fuentes/versiones obsoletas, ajustes sin motivo, coincidencia de gráfico y saldo y redondeo mensual. Requiere una cuenta Auth existente y fechas de muestra sin registros previos; no se usa como dato inicial.

Las pruebas Flutter cubren montos sabatinos sin deducciones, suma y confirmación mensual en móvil, ajuste con motivo, tabla mensual y cálculo exacto en centavos.
