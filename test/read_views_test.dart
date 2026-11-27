import 'package:concilio_jni_dreamrs/app/app.dart';
import 'package:concilio_jni_dreamrs/app/router/app_router.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/council_period.dart';
import 'package:concilio_jni_dreamrs/features/attendance/application/attendance_providers.dart';
import 'package:concilio_jni_dreamrs/features/attendance/data/supabase_attendance_repository.dart';
import 'package:concilio_jni_dreamrs/features/groups/domain/group.dart';
import 'package:concilio_jni_dreamrs/features/members/application/members_providers.dart';
import 'package:concilio_jni_dreamrs/features/members/data/supabase_members_repository.dart';
import 'package:concilio_jni_dreamrs/features/members/domain/member.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_PE'));

  testWidgets(
    'New member button is centered below the directory card on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(375, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ConcilioApp(),
        ),
      );
      container.read(appRouterProvider).go('/integrantes');
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Nuevo integrante');
      expect(tester.getCenter(button).dx, closeTo(187.5, 1));
      expect(
        tester.getTopLeft(button).dy,
        greaterThan(tester.getBottomLeft(find.byType(Card).first).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saved sessions render four dated charts with weighted participation',
    (tester) async {
      tester.view.physicalSize = const Size(1050, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final period = CouncilPeriod.official;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceSummaryProvider((
              start: period.start,
              end: period.end,
            )).overrideWith(
              (ref) async => [
                for (final group in GroupId.values) ...[
                  AttendancePoint(
                    date: CivilDate(2026, 11, 7),
                    groupId: group,
                    present: 2,
                    invited: 2,
                  ),
                  AttendancePoint(
                    date: CivilDate(2026, 11, 14),
                    groupId: group,
                    present: 1,
                    invited: 2,
                  ),
                ],
              ],
            ),
          ],
          child: const ConcilioApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsNWidgets(4));
      expect(find.text('75.0% de participación'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Archived members stay out of directory and upcoming birthdays', (
    tester,
  ) async {
    final today = CivilDate.today();
    final container = ProviderContainer(
      overrides: [
        memberDirectoryProvider.overrideWith(
          (ref) async => [
            MemberDirectoryEntry(
              member: Member(
                id: 'active',
                fullName: 'Joven vigente',
                birthDate: CivilDate(2000, today.month, today.day),
                active: true,
              ),
            ),
            MemberDirectoryEntry(
              member: Member(
                id: 'archived',
                fullName: 'Joven archivado',
                birthDate: CivilDate(2000, today.month, today.day),
                active: false,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ConcilioApp(),
      ),
    );
    container.read(appRouterProvider).go('/integrantes');
    await tester.pumpAndSettle();
    expect(find.text('Joven vigente'), findsNWidgets(2));
    expect(find.text('Joven archivado'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
