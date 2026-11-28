import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/civil_date.dart';
import '../../../shared/widgets/async_panel.dart';
import '../../../shared/widgets/section_header.dart';
import '../../groups/domain/group.dart';
import '../application/attendance_providers.dart';
import '../domain/attendance_calendar.dart';
import '../domain/attendance_point.dart';
import 'attendance_editor.dart';
import 'attendance_month_selector.dart';
import 'saturday_attendance_card.dart';

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

  Future<void> _open(CivilDate date, GroupId group) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AttendanceEditor(date: date, group: group),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asistencia guardada correctamente.')),
      );
    }
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
        AttendanceMonthSelector(
          value: _month,
          onChanged: (month) => setState(() => _month = month),
        ),
        const SizedBox(height: 20),
        AsyncPanel<List<AttendancePoint>>(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (points) => Column(
            children: dates
                .map(
                  (date) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SaturdayAttendanceCard(
                      key: ValueKey(date),
                      date: date,
                      points: points.where((p) => p.date == date).toList(),
                      initiallyExpanded: dates.length == 1,
                      onOpen: (group) => _open(date, group),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
