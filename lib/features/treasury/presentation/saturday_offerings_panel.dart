import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../../shared/widgets/styled_select.dart';
import '../domain/treasury.dart';

class SaturdayOfferingsPanel extends StatefulWidget {
  const SaturdayOfferingsPanel({
    required this.months,
    required this.offerings,
    required this.onRegister,
    required this.onConfirm,
    super.key,
  });
  final List<OfferingMonth> months;
  final List<SaturdayOffering> offerings;
  final void Function(CivilDate date) onRegister;
  final ValueChanged<OfferingMonth> onConfirm;
  @override
  State<SaturdayOfferingsPanel> createState() => _SaturdayOfferingsPanelState();
}

class _SaturdayOfferingsPanelState extends State<SaturdayOfferingsPanel> {
  late CivilDate _month;
  @override
  void initState() {
    super.initState();
    final today = CivilDate.today();
    _month =
        widget.months
            .where(
              (m) => m.month.year == today.year && m.month.month == today.month,
            )
            .firstOrNull
            ?.month ??
        widget.months.first.month;
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.months.firstWhere((m) => m.month == _month);
    final byDate = {for (final o in widget.offerings) o.date: o};
    final dates = CouncilPeriod.official.saturdays
        .where((d) => d.year == _month.year && d.month == _month.month)
        .toList();
    final estimate = summary.saturdayTotal.cents > 0
        ? OfferingBreakdown(summary.saturdayTotal)
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ofrendas de cada sábado',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'El registro sabatino alimenta el acumulado mensual. Las deducciones se aplican una sola vez al confirmar el mes.',
              style: TextStyle(color: Color(0xFF79718D)),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: StyledSelect<CivilDate>(
                label: 'Mes de las ofrendas',
                value: _month,
                icon: Icons.calendar_month_outlined,
                items: widget.months
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.month,
                        child: Text(
                          toBeginningOfSentenceCase(
                            DateFormat(
                              'MMMM yyyy',
                              'es_PE',
                            ).format(m.month.toDateTime()),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (month) {
                  if (month != null) setState(() => _month = month);
                },
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF2EFFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Acumulado: ${summary.saturdayTotal.formatted}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6354D9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${summary.saturdayCount}/${dates.length} sábados registrados',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Distrito estimado: ${estimate?.district.formatted ?? '—'}',
                      ),
                      const Text('Colaboración mensual: S/ 10.00'),
                      Text('Neto estimado: ${estimate?.net.formatted ?? '—'}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    summary.confirmed == null
                        ? 'Pendiente de confirmar · El acumulado aún no entra a caja.'
                        : summary.needsReview
                        ? 'Cambios pendientes de revisión · La caja conserva el último cierre confirmado.'
                        : 'Mes confirmado · Neto en caja: ${summary.confirmed!.net.formatted}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF7F5FD),
                ),
                columns: const [
                  DataColumn(label: Text('Sábado')),
                  DataColumn(label: Text('Monto recogido'), numeric: true),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: dates.map((date) {
                  final offering = byDate[date];
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          DateFormat('dd/MM/yyyy').format(date.toDateTime()),
                        ),
                      ),
                      DataCell(
                        Text(
                          offering?.gross.formatted ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Text(offering == null ? 'Sin registrar' : 'Guardado'),
                      ),
                      DataCell(
                        TextButton.icon(
                          onPressed: () => widget.onRegister(date),
                          icon: Icon(
                            offering == null
                                ? Icons.add_rounded
                                : Icons.edit_outlined,
                            size: 18,
                          ),
                          label: Text(offering == null ? 'Agregar' : 'Editar'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'En móvil, desliza la tabla para ver todas las columnas.',
              style: TextStyle(fontSize: 12, color: Color(0xFF79718D)),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: () => widget.onConfirm(summary),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Revisar y confirmar mes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
