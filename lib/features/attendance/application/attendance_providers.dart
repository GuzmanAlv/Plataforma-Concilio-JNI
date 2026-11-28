import '../../../core/providers/request_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/supabase_attendance_repository.dart';

final attendanceSummaryProvider = FutureProvider.autoDispose
    .family<List<AttendancePoint>, ({CivilDate start, CivilDate end})>((
      ref,
      dates,
    ) async {
      ref.watch(authIdentityProvider);
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return [];
      final data = await SupabaseAttendanceRepository(
        client,
      ).loadSummary(start: dates.start, end: dates.end);
      ref.cacheSuccess();
      return data;
    });
