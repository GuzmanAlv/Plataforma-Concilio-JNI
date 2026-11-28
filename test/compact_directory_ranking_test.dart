import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concilio_jni_dreamrs/app/theme/app_theme.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/features/members/domain/member.dart';
import 'package:concilio_jni_dreamrs/features/members/data/supabase_members_repository.dart';
import 'package:concilio_jni_dreamrs/features/members/presentation/member_directory_row.dart';
import 'package:concilio_jni_dreamrs/features/groups/domain/group.dart';
import 'package:concilio_jni_dreamrs/features/dashboard/domain/attendance_insights.dart';
import 'package:concilio_jni_dreamrs/features/dashboard/presentation/constancy_ranking.dart';

MemberDirectoryEntry entry(String name) => MemberDirectoryEntry(
  member: Member(
    id: name,
    fullName: name,
    birthDate: CivilDate(2005, 6, 12),
    active: true,
  ),
  membership: GroupMembership(
    id: name,
    memberId: name,
    groupId: GroupId.verde,
    role: MemberRole.integrante,
    startDate: CivilDate(2026, 11, 1),
  ),
);

void main() {
  testWidgets(
    'Directory centers birthday and keeps group/role right in compact desktop and phone rows',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 1100.0]) {
        tester.view.physicalSize = Size(width, 800);
        var edits = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MemberDirectoryRow(
                  entry: entry('Ana Pérez Rodríguez'),
                  today: CivilDate(2026, 11, 28),
                  onEdit: () => edits++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byType(MemberDirectoryRow);
        expect(
          tester.getCenter(find.text('12/06/2005')).dx,
          closeTo(width / 2, 2),
        );
        expect(tester.getCenter(find.text('Verde')).dx, greaterThan(width / 2));
        expect(tester.getSize(row).height, lessThan(110));
        await tester.tap(find.byTooltip('Editar integrante'));
        expect(edits, 1);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'Constancy ranking shows only numbered names, groups and percentages',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final people = ['Ana', 'Luis'].map((name) {
        final e = entry(name);
        return MemberParticipation(e.member, [
          AttendanceSnapshot(
            memberId: name,
            date: CivilDate(2026, 11, 28),
            present: true,
          ),
        ], membership: e.membership);
      }).toList();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConstancyRanking(people: people),
            ),
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('100%'), findsNWidgets(2));
      expect(find.text('Grupo Verde'), findsNWidgets(2));
      expect(find.textContaining('ausencias'), findsNothing);
      expect(find.textContaining('convocatorias'), findsNothing);
      expect(find.textContaining('Última presencia'), findsNothing);
      expect(
        tester.getSize(find.byType(ConstancyRanking)).height,
        lessThan(240),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
