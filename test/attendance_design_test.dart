import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:concilio_jni_dreamrs/app/theme/app_theme.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/features/attendance/domain/attendance_point.dart';
import 'package:concilio_jni_dreamrs/features/attendance/presentation/attendance_month_selector.dart';
import 'package:concilio_jni_dreamrs/features/attendance/presentation/saturday_attendance_card.dart';
import 'package:concilio_jni_dreamrs/features/groups/domain/group.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_PE'));
  testWidgets('Saturday date badge fits with enlarged text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: SingleChildScrollView(
              child: SaturdayAttendanceCard(
                date: CivilDate(2026, 11, 28),
                points: const [],
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Month navigation controls stay within the cycle and update the selected month',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var month = DateTime(2026, 11);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: const EdgeInsets.all(16),
                child: AttendanceMonthSelector(
                  value: month,
                  onChanged: (next) => setState(() => month = next),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(month, DateTime(2026, 12));
      expect(find.text('Diciembre'), findsOneWidget);
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      expect(month, DateTime(2026, 11));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Saturday cards distinguish pending groups from recorded absences on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      GroupId? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SaturdayAttendanceCard(
                  date: CivilDate(2026, 11, 28),
                  initiallyExpanded: true,
                  points: [
                    AttendancePoint(
                      date: CivilDate(2026, 11, 28),
                      groupId: GroupId.amarillo,
                      present: 3,
                      invited: 4,
                    ),
                  ],
                  onOpen: (group) => selected = group,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Registro parcial'), findsOneWidget);
      expect(find.text('1/4 grupos'), findsOneWidget);
      expect(find.text('Aún sin marcas guardadas'), findsNWidgets(3));
      final edit = find.widgetWithText(FilledButton, 'Corregir asistencia');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pump();
      expect(selected, GroupId.amarillo);
      expect(tester.takeException(), isNull);
    },
  );
}
