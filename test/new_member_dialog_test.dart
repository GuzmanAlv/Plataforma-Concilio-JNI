import 'package:concilio_jni_dreamrs/features/members/presentation/new_member_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Validates fields and submits one member with membership', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => NewMemberDialog(
                  onSave: (name, birth, group, role, start) async {
                    calls++;
                    expect(name, 'Ana Pérez');
                    expect(birth.toString(), '2005-06-12');
                    expect(group.name, 'amarillo');
                    expect(role.name, 'integrante');
                    expect(start.toString(), '2026-11-01');
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
    await tester.tap(find.text('Guardar integrante'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Escribe el nombre completo.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Ana Pérez');
    await tester.enterText(find.byType(TextFormField).at(1), '12/06/2005');
    await tester.ensureVisible(find.text('Guardar integrante'));
    await tester.tap(find.text('Guardar integrante'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(NewMemberDialog), findsNothing);
  });
}
