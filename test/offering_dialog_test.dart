import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/money.dart';
import 'package:concilio_jni_dreamrs/features/treasury/domain/treasury.dart';
import 'package:concilio_jni_dreamrs/features/treasury/presentation/offering_dialog.dart';

Future<void> openOffering(
  WidgetTester tester,
  Future<void> Function(CivilDate, Money) save, {
  List<SaturdayOffering> offerings = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => OfferingDialog(
                offerings: offerings,
                initialDate: CivilDate(2026, 11, 28),
                onSave: save,
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
}

void main() {
  setUpAll(() => initializeDateFormatting('es_PE'));
  testWidgets('Saturday amounts save without district or fixed deductions', (
    tester,
  ) async {
    CivilDate? savedDate;
    Money? savedAmount;
    await openOffering(tester, (date, amount) async {
      savedDate = date;
      savedAmount = amount;
    });
    await tester.tap(find.text('Guardar ofrenda'));
    await tester.pumpAndSettle();
    expect(savedDate, isNull);
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Guardar ofrenda'));
    await tester.pumpAndSettle();
    expect(savedDate, isNull);
    await tester.enterText(find.byType(TextFormField), '100,00');
    await tester.pumpAndSettle();
    expect(find.textContaining('Distrito (10%)'), findsNothing);
    expect(find.textContaining('Neto de caja:'), findsNothing);
    await tester.tap(find.text('Guardar ofrenda'));
    await tester.pumpAndSettle();
    expect(savedDate, CivilDate(2026, 11, 28));
    expect(savedAmount!.cents, 10000);
    expect(find.byType(OfferingDialog), findsNothing);
  });
  testWidgets('Existing Saturday loads and corrects only its gross amount', (
    tester,
  ) async {
    final existing = SaturdayOffering.fromJson({
      'id': 'offering-1',
      'fecha': '2026-11-28',
      'monto_bruto': '100.00',
      'aporte_distrito': '10.00',
      'colaboracion_fija': '10.00',
      'monto_neto': '80.00',
    });
    Money? saved;
    await openOffering(tester, (date, amount) async {
      saved = amount;
    }, offerings: [existing]);
    expect(find.text('Corregir ofrenda sabatina'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '100.00',
    );
    await tester.enterText(find.byType(TextFormField), '5');
    await tester.pumpAndSettle();
    expect(find.textContaining('Neto de caja:'), findsNothing);
    await tester.tap(find.text('Guardar corrección'));
    await tester.pumpAndSettle();
    expect(saved!.cents, 500);
  });
}
