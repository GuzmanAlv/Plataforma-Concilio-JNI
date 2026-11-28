import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/domain/civil_date.dart';

CivilDate? parseDisplayDate(String value) {
  try {
    return CivilDate.fromDateTime(
      DateFormat('dd/MM/yyyy').parseStrict(value.trim()),
    );
  } catch (_) {
    return null;
  }
}

class CivilDateField extends StatelessWidget {
  const CivilDateField({
    required this.controller,
    required this.label,
    required this.first,
    required this.last,
    this.enabled = true,
    this.yearFirst = false,
    this.helper,
    this.onChanged,
    this.validator,
    super.key,
  });
  final TextEditingController controller;
  final String label;
  final CivilDate first;
  final CivilDate last;
  final bool enabled;
  final bool yearFirst;
  final String? helper;
  final VoidCallback? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.datetime,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'dd/mm/aaaa',
      helperText: helper ?? 'Escribe la fecha o abre el calendario.',
      helperMaxLines: 3,
      prefixIcon: Icon(yearFirst ? Icons.cake_outlined : Icons.event_outlined),
      suffixIcon: IconButton(
        tooltip: 'Elegir $label',
        icon: const Icon(Icons.calendar_month_outlined),
        onPressed: !enabled
            ? null
            : () async {
                var initial =
                    parseDisplayDate(controller.text) ??
                    (yearFirst ? CivilDate(2005, 1, 1) : first);
                if (initial < first) initial = first;
                if (initial > last) initial = last;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial.toDateTime(),
                  firstDate: first.toDateTime(),
                  lastDate: last.toDateTime(),
                  initialDatePickerMode: yearFirst
                      ? DatePickerMode.year
                      : DatePickerMode.day,
                  helpText: label,
                  fieldHintText: 'dd/mm/aaaa',
                  confirmText: 'Usar fecha',
                  cancelText: 'Cancelar',
                  switchToInputEntryModeIcon: const Icon(
                    Icons.edit_calendar_outlined,
                  ),
                );
                if (picked != null && context.mounted) {
                  controller.text = DateFormat('dd/MM/yyyy').format(picked);
                  onChanged?.call();
                }
              },
      ),
    ),
    onChanged: (_) => onChanged?.call(),
    validator:
        validator ??
        (value) {
          final date = parseDisplayDate(value ?? '');
          if (date == null || date < first || date > last) {
            return 'Ingresa una fecha válida dentro del intervalo permitido.';
          }
          return null;
        },
  );
}
