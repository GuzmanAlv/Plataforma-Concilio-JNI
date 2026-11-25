import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/supabase_attendance_repository.dart';

final attendanceSummaryProvider = FutureProvider.autoDispose
    .family<List<AttendancePoint>, ({CivilDate start, CivilDate end})>((
      ref,
      dates,
    ) async {
      ref.watch(authStateProvider);
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return [];
      return SupabaseAttendanceRepository(
        client,
      ).loadSummary(start: dates.start, end: dates.end);
    });
