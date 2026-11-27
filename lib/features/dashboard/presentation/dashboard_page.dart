import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/council_period.dart';
import '../../../core/providers/today_provider.dart';
import '../../attendance/domain/attendance_calendar.dart';
import '../../../shared/widgets/async_panel.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/period_selector.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/timeline_chart.dart';
import '../../groups/domain/group.dart';
import '../../attendance/application/attendance_providers.dart';
import '../../attendance/data/supabase_attendance_repository.dart';
import '../application/dashboard_providers.dart';
import 'insights_panel.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  PeriodFilter _filter = PeriodFilter.all();

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final provider = attendanceSummaryProvider((
      start: _filter.dates.start,
      end: _filter.dates.end,
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6151CC), Color(0xFF8170DE)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONECTAMOS. CRECEMOS. SOÑAMOS.',
                style: TextStyle(
                  color: Color(0xFFE4DFFC),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Cada sábado cuenta.',
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cuatro grupos, un mismo propósito. Acompañemos a cada joven en el camino.',
                style: TextStyle(color: Colors.white, height: 1.6),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Noviembre 2026 — Octubre 2027',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionHeader(
          title: 'Dashboard',
          subtitle: 'La participación de nuestros grupos, sábado a sábado.',
        ),
        PeriodSelector(
          value: _filter,
          onChanged: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 24),
        AsyncPanel(
          value: ref.watch(
            dashboardInsightsProvider((
              start: _filter.dates.start,
              end: _filter.dates.end,
            )),
          ),
          onRetry: () => ref.invalidate(dashboardInsightsProvider),
          builder: (data) => InsightsPanel(insights: data),
        ),
        AsyncPanel<List<AttendancePoint>>(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (points) => LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 700
                  ? (constraints.maxWidth - 20) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: GroupId.values.map((group) {
                  final data = points
                      .where(
                        (point) =>
                            point.groupId == group &&
                            point.date >= AttendanceCalendar.start &&
                            point.date <= today,
                      )
                      .toList();
                  final color = AppTheme.groupColors[group.name]!;
                  final invited = data.fold<int>(
                    0,
                    (total, point) => total + point.invited,
                  );
                  final present = data.fold<int>(
                    0,
                    (total, point) => total + point.present,
                  );
                  return SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    group.groupName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Icon(Icons.trending_up, color: color, size: 22),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              invited == 0
                                  ? 'Participación por registrar'
                                  : '${(present * 100 / invited).toStringAsFixed(1)}% de participación',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (data.isEmpty)
                              const EmptyState(
                                icon: Icons.show_chart,
                                title: 'Aún sin asistencias',
                                message:
                                    'Los sábados registrados aparecerán aquí.',
                              )
                            else
                              TimelineChart(
                                start: _filter.dates.start,
                                end: _filter.dates.end,
                                lines: [
                                  (
                                    color: color,
                                    points: data
                                        .map(
                                          (p) => (
                                            date: p.date,
                                            value: p.present.toDouble(),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            const Text(
                              'Asistentes por sábado',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF74798C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Un sábado sin registro no se considera ausencia. La participación se calcula sobre las personas convocadas en las sesiones guardadas.',
          style: TextStyle(fontSize: 12, color: Color(0xFF74798C)),
        ),
      ],
    );
  }
}
