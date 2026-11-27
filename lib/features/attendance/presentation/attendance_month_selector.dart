import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/attendance_calendar.dart';

class AttendanceMonthSelector extends StatelessWidget {
  const AttendanceMonthSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (i) => DateTime(2026, 11 + i));
    final index = months.indexOf(value);
    String label(DateTime month) =>
        toBeginningOfSentenceCase(DateFormat('MMMM', 'es_PE').format(month));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: Color(0xFF6354D9),
                ),
                SizedBox(width: 8),
                Text(
                  'MES DE ASISTENCIA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xFF6354D9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: Semantics(
                        label: 'Mes de asistencia',
                        child: DropdownButton<DateTime>(
                          value: value,
                          isExpanded: true,
                          itemHeight: 64,
                          menuMaxHeight: 440,
                          borderRadius: BorderRadius.circular(18),
                          dropdownColor: Colors.white,
                          icon: const Icon(
                            Icons.expand_more_rounded,
                            color: Color(0xFF6354D9),
                          ),
                          selectedItemBuilder: (context) => months
                              .map(
                                (month) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label(month),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF39314F),
                                        ),
                                      ),
                                      Text(
                                        '${month.year}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF79718D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          items: months
                              .map(
                                (month) => DropdownMenuItem(
                                  value: month,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0EDFB),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '${month.month}'.padLeft(2, '0'),
                                          style: const TextStyle(
                                            color: Color(0xFF6354D9),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '${label(month)} ${month.year}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${AttendanceCalendar.inMonth(month.year, month.month).length} sáb.',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF79718D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (month) {
                            if (month != null) onChanged(month);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Mes anterior',
                  onPressed: index > 0
                      ? () => onChanged(months[index - 1])
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Mes siguiente',
                  onPressed: index >= 0 && index < 11
                      ? () => onChanged(months[index + 1])
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${AttendanceCalendar.inMonth(value.year, value.month).length} sábados este mes · Ciclo Nov 2026 – Oct 2027',
              style: const TextStyle(fontSize: 12, color: Color(0xFF79718D)),
            ),
          ],
        ),
      ),
    );
  }
}
