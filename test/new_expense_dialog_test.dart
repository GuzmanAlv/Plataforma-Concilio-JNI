import 'dart:convert';
import 'package:concilio_jni_dreamrs/features/treasury/presentation/new_expense_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/money.dart';
import 'package:concilio_jni_dreamrs/features/treasury/domain/treasury.dart';

Future<void> openForm(
  WidgetTester tester,
  Future<void> Function(ExpenseDraft) save, {
  Future<XFile?> Function()? picker,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => NewExpenseDialog(onSave: save, pickPhoto: picker),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> fillForm(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Materiales');
  await tester.enterText(find.byType(TextFormField).at(1), '19,50');
  await tester.enterText(find.byType(TextFormField).at(2), '26/11/2026');
  await tester.enterText(
    find.byType(TextFormField).at(3),
    'Cartulinas para la reunión',
  );
}

void main() {
  testWidgets(
    'Editing keeps the expense identity and can remove the existing receipt',
    (tester) async {
      final original = Expense(
        id: 'existing-expense',
        date: CivilDate(2026, 11, 28),
        amount: Money.parse('25'),
        name: 'Materiales',
        concept: 'Compra anterior',
        receiptPath: 'existing/boleta.png',
      );
      ExpenseDraft? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => NewExpenseDialog(
                    initialExpense: original,
                    onSave: (draft) async {
                      saved = draft;
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
      expect(find.text('Editar egreso'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '25.00',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '18.50');
      await tester.ensureVisible(find.text('Quitar boleta actual'));
      await tester.tap(find.text('Quitar boleta actual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(saved!.id, original.id);
      expect(saved!.amount.cents, 1850);
      expect(saved!.keepExistingReceipt, false);
    },
  );
  testWidgets(
    'Validates required fields, amounts and cycle; photo is optional',
    (tester) async {
      ExpenseDraft? saved;
      await openForm(tester, (draft) async {
        saved = draft;
      });
      await tester.tap(find.text('Guardar egreso'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Ingresa el nombre del gasto.'), findsOneWidget);
      await fillForm(tester);
      await tester.enterText(find.byType(TextFormField).at(1), '-1');
      await tester.enterText(find.byType(TextFormField).at(2), '01/11/2027');
      await tester.tap(find.text('Guardar egreso'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      await tester.enterText(find.byType(TextFormField).at(1), '19,50');
      await tester.enterText(find.byType(TextFormField).at(2), '26/11/2026');
      await tester.tap(find.text('Guardar egreso'));
      await tester.pumpAndSettle();
      expect(saved!.amount.cents, 1950);
      expect(saved!.date.toString(), '2026-11-26');
      expect(saved!.name, 'Materiales');
      expect(saved!.description, 'Cartulinas para la reunión');
      expect(saved!.photo, isNull);
    },
  );

  testWidgets('Photo selection passes bytes and MIME, and can be removed', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aN1cAAAAASUVORK5CYII=',
    );
    ExpenseDraft? saved;
    await openForm(
      tester,
      (draft) async {
        saved = draft;
      },
      picker: () async => XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'boleta.png',
        path: 'boleta.png',
      ),
    );
    await fillForm(tester);
    await tester.ensureVisible(find.text('Adjuntar boleta (opcional)'));
    await tester.tap(find.text('Adjuntar boleta (opcional)'));
    await tester.pumpAndSettle();
    expect(find.text('boleta.png'), findsOneWidget);
    await tester.ensureVisible(find.text('Quitar foto'));
    await tester.tap(find.text('Quitar foto'));
    await tester.pumpAndSettle();
    expect(find.text('boleta.png'), findsNothing);
    await tester.tap(find.text('Adjuntar boleta (opcional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar egreso'));
    await tester.pumpAndSettle();
    expect(saved!.photo!.mimeType, 'image/png');
    expect(saved!.photo!.bytes, bytes);
  });

  testWidgets('Uncertain saves retry the same immutable submission', (
    tester,
  ) async {
    final drafts = <ExpenseDraft>[];
    await openForm(tester, (draft) async {
      drafts.add(draft);
      if (drafts.length == 1) throw Exception('Network failure');
    });
    await fillForm(tester);
    await tester.tap(find.text('Guardar egreso'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar guardado'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
      false,
    );
    await tester.tap(find.text('Reintentar guardado'));
    await tester.pumpAndSettle();
    expect(drafts.length, 2);
    expect(drafts[0].id, drafts[1].id);
    expect(drafts[0].amount, drafts[1].amount);
    expect(find.byType(NewExpenseDialog), findsNothing);
  });
}
