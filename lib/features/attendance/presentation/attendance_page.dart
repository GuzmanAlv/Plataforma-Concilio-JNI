import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/civil_date.dart';
import '../../../shared/widgets/async_panel.dart';
import '../../../shared/widgets/section_header.dart';
import '../../groups/domain/group.dart';
import '../application/attendance_providers.dart';
import '../domain/attendance_calendar.dart';
import 'attendance_editor.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});
  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  late DateTime _month;
  @override
  void initState() {
    super.initState();
    final dates = AttendanceCalendar.saturdays;
    final next =
        dates.where((d) => d >= CivilDate.today()).firstOrNull ?? dates.last;
    _month = DateTime(next.year, next.month);
  }

  @override
  Widget build(BuildContext context) {
    final dates = AttendanceCalendar.inMonth(_month.year, _month.month);
    final provider = attendanceSummaryProvider((
      start: dates.first,
      end: dates.last,
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Asistencia',
          subtitle:
              'Registro y resumen por grupo, desde el sábado 28 de noviembre de 2026.',
        ),
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<DateTime>(
            isExpanded: true,
            initialValue: _month,
            decoration: const InputDecoration(
              labelText: 'Mes de asistencia',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: List.generate(12, (i) {
              final month = DateTime(2026, 11 + i);
              return DropdownMenuItem(
                value: month,
                child: Text(DateFormat('MMMM yyyy', 'es_PE').format(month)),
              );
            }),
            onChanged: (month) {
              if (month != null) setState(() => _month = month);
            },
          ),
        ),
        const SizedBox(height: 20),
        AsyncPanel(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (points) => Column(
            children: dates.map((date) {
              final saved = points.where((p) => p.date == date).toList();
              final present = saved.fold<int>(0, (n, p) => n + p.present);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  child: ExpansionTile(
                    key: ValueKey(date),
                    initiallyExpanded: dates.length == 1,
                    title: Text(
                      'Sábado ${DateFormat('d MMMM', 'es_PE').format(date.toDateTime())}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      saved.isEmpty
                          ? 'Sin registro${date > CivilDate.today() ? ' · Próximo sábado programado' : ''}'
                          : '${saved.length}/4 grupos registrados · $present presentes${saved.length < 4 ? ' · Resumen parcial' : ''}',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final width = c.maxWidth >= 700
                                ? (c.maxWidth - 16) / 2
                                : c.maxWidth;
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: GroupId.values.map((group) {
                                final point = saved
                                    .where((p) => p.groupId == group)
                                    .firstOrNull;
                                final color = AppTheme.groupColors[group.name]!;
                                return SizedBox(
                                  width: width,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      color: color.withValues(alpha: 0.04),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.groupName,
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          point == null
                                              ? 'Pendiente de registro'
                                              : '${point.present} presentes · ${point.invited - point.present} ausentes\n${point.invited} convocados',
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton.tonalIcon(
                                          icon: Icon(
                                            point == null
                                                ? Icons.fact_check_outlined
                                                : Icons.edit_outlined,
                                          ),
                                          onPressed: () async {
                                            final result =
                                                await showDialog<bool>(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (_) =>
                                                      AttendanceEditor(
                                                        date: date,
                                                        group: group,
                                                      ),
                                                );
                                            if (result == true &&
                                                context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Asistencia guardada correctamente.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          label: Text(
                                            point == null
                                                ? 'Tomar asistencia'
                                                : 'Corregir asistencia',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
