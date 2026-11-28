import 'package:flutter_test/flutter_test.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/features/attendance/domain/attendance_calendar.dart';
import 'package:concilio_jni_dreamrs/features/attendance/domain/attendance_point.dart';
import 'package:concilio_jni_dreamrs/features/dashboard/domain/attendance_insights.dart';
import 'package:concilio_jni_dreamrs/features/groups/domain/group.dart';
import 'package:concilio_jni_dreamrs/features/members/domain/member.dart';

Member member(String id, {bool active = true}) => Member(
  id: id,
  fullName: id,
  birthDate: CivilDate(2000, 1, 1),
  active: active,
);
AttendanceSnapshot mark(String id, int offset, bool present) =>
    AttendanceSnapshot(
      memberId: id,
      date: AttendanceCalendar.start.addDays(offset * 7),
      present: present,
    );
void main() {
  test(
    'Constancy ranks members before leaders, then percentage and attendance',
    () {
      final stats = AttendanceInsights(
        members: [member('Líder'), member('Ana'), member('Luis')],
        memberships: {
          for (final name in ['Líder', 'Ana', 'Luis'])
            name: GroupMembership(
              id: name,
              memberId: name,
              groupId: GroupId.verde,
              role: name == 'Líder' ? MemberRole.lider : MemberRole.integrante,
              startDate: AttendanceCalendar.start,
            ),
        },
        snapshots: [
          ...List.generate(3, (i) => mark('Líder', i, true)),
          mark('Ana', 0, true),
          mark('Ana', 1, false),
          mark('Ana', 2, true),
          mark('Luis', 0, true),
        ],
        points: [],
        start: AttendanceCalendar.start,
        end: CivilDate(2027, 10, 31),
        today: CivilDate(2026, 12, 12),
      );
      expect(stats.mostRegular.map((p) => p.member.id), [
        'Luis',
        'Ana',
        'Líder',
      ]);
      expect(stats.mostRegular.first.membership!.groupId, GroupId.verde);
    },
  );
  test(
    'Operational calendar starts Nov 28 and separates months through Oct 2027',
    () {
      expect(AttendanceCalendar.saturdays.length, 49);
      expect(AttendanceCalendar.saturdays.first, CivilDate(2026, 11, 28));
      expect(AttendanceCalendar.saturdays.last, CivilDate(2027, 10, 30));
      expect(AttendanceCalendar.inMonth(2026, 11).length, 1);
      expect(AttendanceCalendar.inMonth(2026, 12).map((d) => d.day), [
        5,
        12,
        19,
        26,
      ]);
    },
  );
  test(
    'Follow-up needs recorded convocations, ignores future and archived people',
    () {
      final stats = AttendanceInsights(
        members: [
          member('Ana'),
          member('Luis'),
          member('Nuevo'),
          member('Baja', active: false),
        ],
        snapshots: [
          mark('Ana', 0, false),
          mark('Ana', 1, false),
          mark('Ana', 2, false),
          mark('Ana', 3, true),
          mark('Luis', 0, false),
          mark('Luis', 2, true),
          mark('Baja', 0, false),
        ],
        points: [],
        start: CivilDate(2026, 11, 1),
        end: CivilDate(2027, 10, 31),
        today: CivilDate(2026, 12, 12),
      );
      expect(stats.people.length, 3);
      expect(stats.followUp.map((p) => p.member.id), ['Ana']);
      expect(stats.people.first.recentAbsences, 3);
      expect(stats.people.first.invited, 3);
      expect(stats.people.first.lastPresence, isNull);
      expect(stats.people[1].invited, 2); // missing Dec 5 is not an absence
      expect(stats.coveredPeople, 2);
      expect(stats.mostRegular.first.member.id, 'Luis');
    },
  );
  test('Complete-week trend and active group use rates, not group size', () {
    final points = <AttendancePoint>[
      for (final group in GroupId.values) ...[
        AttendancePoint(
          date: CivilDate(2026, 11, 28),
          groupId: group,
          present: 1,
          invited: 2,
        ),
        AttendancePoint(
          date: CivilDate(2026, 12, 5),
          groupId: group,
          present: 2,
          invited: 2,
        ),
      ],
      AttendancePoint(
        date: CivilDate(2026, 12, 12),
        groupId: GroupId.amarillo,
        present: 0,
        invited: 20,
      ),
    ];
    final stats = AttendanceInsights(
      members: [],
      snapshots: [],
      points: points,
      start: AttendanceCalendar.start,
      end: CivilDate(2027, 10, 31),
      today: CivilDate(2026, 12, 12),
    );
    expect(stats.completeSaturdays, 2);
    expect(stats.lastCompleteChange, 50);
    expect(stats.mostActiveGroup!.group, isNot(GroupId.amarillo));
    expect(stats.mostActiveGroup!.rate, 0.75);
    expect(stats.present, 12);
    expect(stats.invited, 36);
  });
}
