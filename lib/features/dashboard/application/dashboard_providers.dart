import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/providers/today_provider.dart';
import '../../../core/supabase/pagination.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../attendance/application/attendance_providers.dart';
import '../../members/application/members_providers.dart';
import '../domain/attendance_insights.dart';

final dashboardInsightsProvider = FutureProvider.autoDispose
    .family<AttendanceInsights, ({CivilDate start, CivilDate end})>((
      ref,
      dates,
    ) async {
      ref.watch(authStateProvider);
      final client = ref.watch(supabaseClientProvider);
      final membersFuture = ref.watch(memberDirectoryProvider.future);
      final pointsFuture = ref.watch(attendanceSummaryProvider(dates).future);
      final rowsFuture = client == null
          ? Future.value(<Map<String, dynamic>>[])
          : loadAllRows(
              (from, to) async => await client
                  .from('asistencia_registros')
                  .select(
                    'id,integrante_id,presente,asistencia_sesiones!inner(fecha)',
                  )
                  .gte('asistencia_sesiones.fecha', dates.start.toString())
                  .lte('asistencia_sesiones.fecha', dates.end.toString())
                  .order('id')
                  .range(from, to),
            );
      final results = await (membersFuture, pointsFuture, rowsFuture).wait;
      return AttendanceInsights(
        members: results.$1.map((e) => e.member),
        points: results.$2,
        snapshots: results.$3.map(
          (r) => AttendanceSnapshot(
            memberId: r['integrante_id'] as String,
            present: r['presente'] as bool,
            date: CivilDate.parse(
              (r['asistencia_sesiones'] as Map)['fecha'] as String,
            ),
          ),
        ),
        start: dates.start,
        end: dates.end,
        today: ref.watch(todayProvider),
      );
    });
