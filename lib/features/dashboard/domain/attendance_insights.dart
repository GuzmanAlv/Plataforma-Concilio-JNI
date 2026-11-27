import '../../../core/domain/civil_date.dart';
import '../../attendance/domain/attendance_point.dart';
import '../../attendance/domain/attendance_calendar.dart';
import '../../members/domain/member.dart';
import '../../groups/domain/group.dart';

class AttendanceSnapshot {
  const AttendanceSnapshot({
    required this.memberId,
    required this.date,
    required this.present,
  });
  final String memberId;
  final CivilDate date;
  final bool present;
}

class MemberParticipation {
  MemberParticipation(this.member, Iterable<AttendanceSnapshot> records)
    : records = records.toList()..sort((a, b) => b.date.compareTo(a.date));
  final Member member;
  final List<AttendanceSnapshot> records;
  int get attended => records.where((r) => r.present).length;
  int get invited => records.length;
  double get rate => invited == 0 ? 0 : attended / invited;
  CivilDate? get lastPresence =>
      records.where((r) => r.present).firstOrNull?.date;
  int get recentAbsences => records.takeWhile((r) => !r.present).length;
  bool get needsFollowUp =>
      invited >= 3 &&
      (recentAbsences >= 3 ||
          records.take(3).where((r) => r.present).length <= 1);
}

class AttendanceInsights {
  AttendanceInsights({
    required Iterable<Member> members,
    required Iterable<AttendanceSnapshot> snapshots,
    required Iterable<AttendancePoint> points,
    required CivilDate start,
    required CivilDate end,
    required CivilDate today,
  }) {
    final valid = snapshots
        .where(
          (r) =>
              r.date >= start &&
              r.date >= AttendanceCalendar.start &&
              r.date <= end &&
              r.date <= today,
        )
        .toList();
    people = members
        .where((m) => m.active)
        .map(
          (m) => MemberParticipation(m, valid.where((r) => r.memberId == m.id)),
        )
        .toList();
    sessions = points
        .where(
          (p) =>
              p.date >= start &&
              p.date >= AttendanceCalendar.start &&
              p.date <= end &&
              p.date <= today,
        )
        .toList();
  }
  late final List<MemberParticipation> people;
  late final List<AttendancePoint> sessions;
  int get present => sessions.fold(0, (n, p) => n + p.present);
  int get invited => sessions.fold(0, (n, p) => n + p.invited);
  double get rate => invited == 0 ? 0 : present / invited;
  int get coveredPeople => people.where((p) => p.invited > 0).length;
  ({GroupId group, double rate, int count})? get mostActiveGroup {
    final values =
        GroupId.values
            .map((g) {
              final rows = sessions.where((p) => p.groupId == g).toList();
              final total = rows.fold<int>(0, (n, p) => n + p.invited);
              final attended = rows.fold<int>(0, (n, p) => n + p.present);
              return (
                group: g,
                rate: total == 0 ? 0.0 : attended / total,
                count: rows.length,
                invited: total,
              );
            })
            .where((g) => g.invited > 0)
            .toList()
          ..sort((a, b) {
            final rate = b.rate.compareTo(a.rate);
            return rate != 0 ? rate : b.count.compareTo(a.count);
          });
    if (values.isEmpty) return null;
    final first = values.first;
    return (group: first.group, rate: first.rate, count: first.count);
  }

  double? get lastCompleteChange {
    final dates =
        sessions
            .map((p) => p.date)
            .toSet()
            .where((d) => sessions.where((p) => p.date == d).length == 4)
            .toList()
          ..sort();
    if (dates.length < 2) return null;
    double? rate(CivilDate d) {
      final rows = sessions.where((p) => p.date == d);
      final invited = rows.fold<int>(0, (n, p) => n + p.invited);
      return invited == 0
          ? null
          : rows.fold<int>(0, (n, p) => n + p.present) / invited;
    }

    final previous = rate(dates[dates.length - 2]);
    final last = rate(dates.last);
    return previous == null || last == null ? null : (last - previous) * 100;
  }

  List<MemberParticipation> get mostRegular =>
      people.where((p) => p.attended > 0).toList()..sort((a, b) {
        final count = b.attended.compareTo(a.attended);
        return count != 0 ? count : b.rate.compareTo(a.rate);
      });
  List<MemberParticipation> get followUp =>
      people.where((p) => p.needsFollowUp).toList()
        ..sort((a, b) => a.rate.compareTo(b.rate));
  List<MemberParticipation> get leastRegular =>
      people.where((p) => p.invited >= 3).toList()
        ..sort((a, b) => a.rate.compareTo(b.rate));
  int get completeSaturdays {
    final groups = <CivilDate, int>{};
    for (final p in sessions) {
      groups[p.date] = (groups[p.date] ?? 0) + 1;
    }
    return groups.values.where((n) => n == 4).length;
  }
}
