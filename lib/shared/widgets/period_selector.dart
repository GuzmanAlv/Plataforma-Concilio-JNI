import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/domain/civil_date.dart';
import '../../core/domain/council_period.dart';
import 'civil_date_field.dart';
import 'styled_select.dart';

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
    final months = List.generate(12, (i) => DateTime(2026, 11 + i));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E4F4)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: constraints.maxWidth < 340 ? constraints.maxWidth : 280,
              child: StyledSelect<String>(
                label: 'Periodo',
                icon: Icons.calendar_month_outlined,
                value: value.mode == PeriodFilterMode.month
                    ? '${value.dates.start.year}-${value.dates.start.month}'
                    : value.mode.name,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('Todo el periodo'),
                  ),
                  ...months.map(
                    (month) => DropdownMenuItem(
                      value: '${month.year}-${month.month}',
                      child: Text(
                        toBeginningOfSentenceCase(
                          DateFormat('MMMM yyyy', 'es_PE').format(month),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                    PeriodFilter.month(
                      int.parse(parts[0]),
                      int.parse(parts[1]),
                    ),
                  );
                },
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final dates = await showDialog<PeriodFilter>(
                  context: context,
                  builder: (_) => PeriodRangeDialog(initial: value),
                );
                if (dates != null) onChanged(dates);
              },
              icon: const Icon(Icons.date_range_outlined),
              label: const Text('Elegir rango'),
            ),
            if (value.mode == PeriodFilterMode.range)
              Text(
                '${DateFormat('d MMM', 'es_PE').format(value.dates.start.toDateTime())} – ${DateFormat('d MMM yyyy', 'es_PE').format(value.dates.end.toDateTime())}',
                style: const TextStyle(
                  color: Color(0xFF6354D9),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PeriodRangeDialog extends StatefulWidget {
  const PeriodRangeDialog({required this.initial, super.key});
  final PeriodFilter initial;
  @override
  State<PeriodRangeDialog> createState() => _PeriodRangeDialogState();
}

class _PeriodRangeDialogState extends State<PeriodRangeDialog> {
  final _form = GlobalKey<FormState>();
  final _start = TextEditingController();
  final _end = TextEditingController();
  void _set(CivilDate start, CivilDate end) {
    setState(() {
      _start.text = DateFormat('dd/MM/yyyy').format(start.toDateTime());
      _end.text = DateFormat('dd/MM/yyyy').format(end.toDateTime());
    });
  }

  @override
  void initState() {
    super.initState();
    _start.text = DateFormat(
      'dd/MM/yyyy',
    ).format(widget.initial.dates.start.toDateTime());
    _end.text = DateFormat(
      'dd/MM/yyyy',
    ).format(widget.initial.dates.end.toDateTime());
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cycle = CouncilPeriod.official;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Elegir rango'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Elige la fecha inicial y final. Se incluyen ambos días dentro del ciclo Nov 2026 – Oct 2027.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Todo el ciclo'),
                      onPressed: () => _set(cycle.start, cycle.end),
                    ),
                    ActionChip(
                      label: const Text('Mes seleccionado'),
                      onPressed: () {
                        final start = widget.initial.dates.start;
                        final month = PeriodFilter.month(
                          start.year,
                          start.month,
                        );
                        _set(month.dates.start, month.dates.end);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CivilDateField(
                  controller: _start,
                  label: 'Desde',
                  first: cycle.start,
                  last: cycle.end,
                ),
                const SizedBox(height: 20),
                CivilDateField(
                  controller: _end,
                  label: 'Hasta',
                  first: cycle.start,
                  last: cycle.end,
                  validator: (text) {
                    final end = parseDisplayDate(text ?? '');
                    final start = parseDisplayDate(_start.text);
                    if (end == null || !cycle.contains(end)) {
                      return 'Indica una fecha válida dentro del ciclo.';
                    }
                    if (start != null && end < start) {
                      return 'La fecha final debe ser igual o posterior a la inicial.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.of(context).pop(
                PeriodFilter.range(
                  parseDisplayDate(_start.text)!,
                  parseDisplayDate(_end.text)!,
                ),
              );
            }
          },
          child: const Text('Aplicar rango'),
        ),
      ],
    );
  }
}
