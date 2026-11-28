import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/features/attendance/application/attendance_sheet_provider.dart';
import 'package:concilio_jni_dreamrs/features/attendance/presentation/attendance_editor.dart';
import 'package:concilio_jni_dreamrs/features/groups/domain/group.dart';
import 'package:concilio_jni_dreamrs/features/members/domain/member.dart';
import 'package:concilio_jni_dreamrs/features/members/data/supabase_members_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_PE'));
  testWidgets('Loads saved marks and corrects the same group and Saturday', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    final date = CivilDate(2026, 11, 28);
    final roster = ['Ana', 'Luis']
        .map(
          (name) => MemberDirectoryEntry(
            member: Member(
              id: name,
              fullName: name,
              birthDate: CivilDate(2000, 1, 1),
              active: true,
            ),
            membership: GroupMembership(
              id: name,
              memberId: name,
              groupId: GroupId.amarillo,
              role: MemberRole.integrante,
              startDate: CivilDate(2026, 11, 1),
            ),
          ),
        )
        .toList();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceSheetProvider((
            date: date,
            group: GroupId.amarillo,
          )).overrideWith(
            (ref) async =>
                AttendanceSheet(roster: roster, present: {'Ana'}, saved: true),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AttendanceEditor(
                    date: date,
                    group: GroupId.amarillo,
                    onSave: (submission) async {
                      submitted = submission.toRpcParams();
                    },
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar integrante'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Ana'),
          )
          .value,
      true,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Guardar asistencia'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.widgetWithText(CheckboxListTile, 'Luis'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Luis'));
    await tester.pump();
    await tester.tap(find.text('Guardar asistencia'));
    await tester.pumpAndSettle();
    expect(submitted!['p_fecha'], '2026-11-28');
    expect(submitted!['p_grupo_id'], 'amarillo');
    expect(submitted!['p_presentes'], unorderedEquals(['Ana', 'Luis']));
    expect(find.byType(AttendanceEditor), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
