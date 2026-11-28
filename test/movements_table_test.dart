import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/council_period.dart';
import 'package:concilio_jni_dreamrs/core/domain/money.dart';
import 'package:concilio_jni_dreamrs/features/treasury/domain/treasury.dart';
import 'package:concilio_jni_dreamrs/features/treasury/presentation/movements_table.dart';

void main() {
  testWidgets(
    'Large movement lists render only one page and retain access to all rows',
    (tester) async {
      final expenses = List.generate(
        45,
        (i) => Expense(
          id: 'e$i',
          date: CivilDate(2026, 11, 1).addDays(i),
          amount: Money.parse('10'),
          name: 'Gasto $i',
          concept: 'Materiales',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MovementsTable(
                offerings: const [],
                expenses: expenses,
                filter: PeriodFilter.all(),
                onEdit: (_) {},
                onReceipt: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 20);
      expect(find.text('Gasto 44'), findsOneWidget);
      expect(find.text('Gasto 0'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Movimientos siguientes'));
      await tester.tap(find.byTooltip('Movimientos siguientes'));
      await tester.pumpAndSettle();
      expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 20);
      await tester.ensureVisible(find.byTooltip('Movimientos siguientes'));
      await tester.tap(find.byTooltip('Movimientos siguientes'));
      await tester.pumpAndSettle();
      expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 5);
      expect(find.text('Gasto 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
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
