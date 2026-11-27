import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../groups/domain/group.dart';
import '../../members/data/supabase_members_repository.dart';
import '../data/supabase_attendance_repository.dart';

class AttendanceSheet {
  const AttendanceSheet({
    required this.roster,
    required this.present,
    required this.saved,
  });
  final List<MemberDirectoryEntry> roster;
  final Set<String> present;
  final bool saved;
}

final attendanceSheetProvider = FutureProvider.autoDispose
    .family<AttendanceSheet, ({CivilDate date, GroupId group})>((
      ref,
      key,
    ) async {
      ref.watch(authStateProvider);
      final client = ref.watch(supabaseClientProvider);
      if (client == null) {
        return const AttendanceSheet(roster: [], present: {}, saved: false);
      }
      final repository = SupabaseAttendanceRepository(client);
      final results = await (
        SupabaseMembersRepository(client).loadDirectory(onDate: key.date),
        repository.loadSession(groupId: key.group, date: key.date),
      ).wait;
      final records = results.$2 == null
          ? null
          : await repository.loadRecords(results.$2!.id);
      return AttendanceSheet(
        roster: results.$1
            .where((e) => e.membership?.groupId == key.group)
            .toList(),
        present:
            records?.where((r) => r.present).map((r) => r.memberId).toSet() ??
            {},
        saved: results.$2 != null,
      );
    });
