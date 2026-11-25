import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/domain/civil_date.dart';
import '../../core/domain/council_period.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final PeriodFilter value;
  final ValueChanged<PeriodFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final period = CouncilPeriod.official;
    final months = List.generate(12, (index) => DateTime(2026, 11 + index));
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 230,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey(
              '${value.mode}-${value.dates.start}-${value.dates.end}',
            ),
            initialValue: value.mode == PeriodFilterMode.month
                ? '${value.dates.start.year}-${value.dates.start.month}'
                : value.mode.name,
            decoration: const InputDecoration(
              labelText: 'Periodo',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('Todo el periodo'),
              ),
              ...months.map(
                (month) => DropdownMenuItem(
                  value: '${month.year}-${month.month}',
                  child: Text(DateFormat('MMMM yyyy', 'es_PE').format(month)),
                ),
              ),
              if (value.mode == PeriodFilterMode.range)
                const DropdownMenuItem(
                  value: 'range',
                  child: Text('Rango personalizado'),
                ),
            ],
            onChanged: (selection) {
              if (selection == 'all') {
                onChanged(PeriodFilter.all());
                return;
              }
              if (selection == null || selection == 'range') return;
              final parts = selection.split('-');
              onChanged(
                PeriodFilter.month(int.parse(parts[0]), int.parse(parts[1])),
              );
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final dates = await showDateRangePicker(
              context: context,
              firstDate: period.start.toDateTime(),
              lastDate: period.end.toDateTime(),
              initialDateRange: DateTimeRange(
                start: value.dates.start.toDateTime(),
                end: value.dates.end.toDateTime(),
              ),
              helpText: 'Selecciona fechas del concilio',
            );
            if (dates != null) {
              onChanged(
                PeriodFilter.range(
                  CivilDate.fromDateTime(dates.start),
                  CivilDate.fromDateTime(dates.end),
                ),
              );
            }
          },
          icon: const Icon(Icons.date_range_outlined),
          label: const Text('Elegir rango'),
        ),
        if (value.mode == PeriodFilterMode.range)
          Text(
            '${DateFormat('d MMM').format(value.dates.start.toDateTime())} – ${DateFormat('d MMM yyyy').format(value.dates.end.toDateTime())}',
          ),
      ],
    );
  }
}
