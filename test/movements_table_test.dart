import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/council_period.dart';
import 'package:concilio_jni_dreamrs/core/domain/money.dart';
import 'package:concilio_jni_dreamrs/features/treasury/domain/treasury.dart';
import 'package:concilio_jni_dreamrs/features/treasury/presentation/movements_table.dart';

void main() {
  testWidgets('Movement table shows expense form fields and opens editing', (
    tester,
  ) async {
    final expense = Expense(
      id: 'e1',
      date: CivilDate(2026, 11, 28),
      amount: Money.parse('12.50'),
      name: 'Cartulinas',
      concept: 'Materiales para reunión',
      receiptPath: 'e1/boleta.png',
    );
    Expense? edit;
    String? receipt;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MovementsTable(
            offerings: [],
            expenses: [expense],
            filter: PeriodFilter.all(),
            onEdit: (e) => edit = e,
            onReceipt: (p) => receipt = p,
          ),
        ),
      ),
    );
    for (final name in [
      'Fecha',
      'Tipo',
      'Nombre',
      'Descripción',
      'Monto (S/)',
      'Boleta',
      'Acciones',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Cartulinas'), findsOneWidget);
    expect(find.text('S/ -12.50'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver'));
    await tester.tap(find.text('Ver'));
    await tester.pump();
    expect(receipt, expense.receiptPath);
    await tester.ensureVisible(find.text('Editar'));
    await tester.tap(find.text('Editar'));
    await tester.pump();
    expect(edit, expense);
    expect(tester.takeException(), isNull);
  });
}
