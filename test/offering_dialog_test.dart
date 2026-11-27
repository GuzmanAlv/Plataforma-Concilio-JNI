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
  List<Offering> offerings = const [],
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
  testWidgets(
    'Validates amount and saves a Saturday with the exact displayed breakdown',
    (tester) async {
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
      expect(find.text('Distrito (10%): S/ 10.00'), findsOneWidget);
      expect(find.text('Neto de caja: S/ 80.00'), findsOneWidget);
      await tester.tap(find.text('Guardar ofrenda'));
      await tester.pumpAndSettle();
      expect(savedDate, CivilDate(2026, 11, 28));
      expect(savedAmount!.cents, 10000);
      expect(find.byType(OfferingDialog), findsNothing);
    },
  );
  testWidgets(
    'Existing Saturday loads its offering for correction; low gross keeps negative net',
    (tester) async {
      final existing = Offering.fromJson({
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
      expect(find.text('Corregir ofrenda'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '100.00',
      );
      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pumpAndSettle();
      expect(find.text('Neto de caja: S/ -5.50'), findsOneWidget);
      await tester.tap(find.text('Guardar corrección'));
      await tester.pumpAndSettle();
      expect(saved!.cents, 500);
    },
  );
}
