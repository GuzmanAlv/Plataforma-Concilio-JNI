import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:concilio_jni_dreamrs/app/theme/app_theme.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/council_period.dart';
import 'package:concilio_jni_dreamrs/features/groups/domain/group.dart';
import 'package:concilio_jni_dreamrs/features/members/domain/member.dart';
import 'package:concilio_jni_dreamrs/features/members/data/supabase_members_repository.dart';
import 'package:concilio_jni_dreamrs/features/members/presentation/new_member_dialog.dart';
import 'package:concilio_jni_dreamrs/shared/widgets/period_selector.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_PE'));
  testWidgets(
    'Mobile editing preloads personal data and preserves assignment',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saved = false;
      final entry = MemberDirectoryEntry(
        member: Member(
          id: 'member',
          fullName: 'Ana Pérez',
          birthDate: CivilDate(2005, 6, 12),
          active: true,
        ),
        membership: GroupMembership(
          id: 'membership',
          memberId: 'member',
          groupId: GroupId.verde,
          role: MemberRole.lider,
          startDate: CivilDate(2026, 11, 1),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => NewMemberDialog(
                    initialEntry: entry,
                    onSave: (name, birth, group, role, start) async {
                      expect(name, 'Ana Actualizada');
                      expect(birth, CivilDate(2004, 2, 29));
                      expect(group, GroupId.verde);
                      expect(role, MemberRole.lider);
                      saved = true;
                    },
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('12/06/2005'), findsOneWidget);
      expect(find.text('Fecha efectiva del cambio'), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ana Actualizada',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '29/02/2004');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(saved, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Range form rejects reversed dates and returns an inclusive range',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PeriodFilter? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showDialog<PeriodFilter>(
                  context: context,
                  builder: (_) =>
                      PeriodRangeDialog(initial: PeriodFilter.all()),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '28/11/2026');
      await tester.enterText(find.byType(TextFormField).at(1), '01/11/2026');
      await tester.tap(find.text('Aplicar rango'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        find.text('La fecha final debe ser igual o posterior a la inicial.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).at(1), '05/12/2026');
      await tester.tap(find.text('Aplicar rango'));
      await tester.pumpAndSettle();
      expect(result!.dates.start, CivilDate(2026, 11, 28));
      expect(result!.dates.end, CivilDate(2026, 12, 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Birthday calendar opens at year selection on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const NewMemberDialog(),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    final calendar = find.byTooltip('Elegir Fecha de nacimiento');
    await tester.ensureVisible(calendar);
    await tester.tap(calendar);
    await tester.pumpAndSettle();
    expect(find.byType(YearPicker), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
