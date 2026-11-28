import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:concilio_jni_dreamrs/app/theme/app_theme.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/money.dart';
import 'package:concilio_jni_dreamrs/features/treasury/domain/treasury.dart';
import 'package:concilio_jni_dreamrs/features/treasury/presentation/monthly_offering_dialog.dart';
import 'package:concilio_jni_dreamrs/features/treasury/presentation/saturday_offerings_panel.dart';

OfferingMonth month({Offering? confirmed, bool review = false}) =>
    OfferingMonth(
      month: CivilDate(2026, 11, 1),
      saturdayTotal: Money.parse('400'),
      saturdayCount: 4,
      sourceRevision: 'source-version',
      version: confirmed == null ? 0 : 1,
      needsReview: review,
      confirmed: confirmed,
    );

void main() {
  setUpAll(() => initializeDateFormatting('es_PE'));
  testWidgets(
    'Monthly form preloads the sum and deducts fixed contribution once on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Money? saved;
      String? savedReason;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MonthlyOfferingDialog(
                    months: [month()],
                    initialMonth: CivilDate(2026, 11, 1),
                    onSave: (source, gross, reason) async {
                      expect(source.sourceRevision, 'source-version');
                      saved = gross;
                      savedReason = reason;
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
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '400.00',
      );
      expect(find.text('Distrito (10%): S/ 40.00'), findsOneWidget);
      expect(find.text('Neto de caja: S/ 350.00'), findsOneWidget);
      await tester.tap(find.text('Confirmar mes'));
      await tester.pumpAndSettle();
      expect(saved, Money.parse('400'));
      expect(savedReason, '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Manual adjustment requires a reason and recalculates the monthly breakdown',
    (tester) async {
      Money? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MonthlyOfferingDialog(
                    months: [month()],
                    onSave: (_, gross, reason) async {
                      saved = gross;
                      expect(reason, 'Corrección de conteo');
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
      await tester.enterText(find.byType(TextFormField).first, '450,00');
      await tester.tap(find.text('Confirmar mes'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(
        find.text('Explica la diferencia respecto al acumulado.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Corrección de conteo',
      );
      expect(find.text('Neto de caja: S/ 395.00'), findsOneWidget);
      await tester.tap(find.text('Confirmar mes'));
      await tester.pumpAndSettle();
      expect(saved, Money.parse('450'));
    },
  );

  testWidgets(
    'Monthly Saturday table keeps pending entries outside confirmed cash',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final offering = Offering(
        id: 'closed',
        month: CivilDate(2026, 11, 1),
        date: CivilDate(2026, 11, 28),
        gross: Money.parse('350'),
        district: Money.parse('35'),
        fixedContribution: Money.parse('10'),
        net: Money.parse('305'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SaturdayOfferingsPanel(
                months: [month(confirmed: offering, review: true)],
                offerings: [7, 14, 21, 28]
                    .map(
                      (d) => SaturdayOffering(
                        id: '$d',
                        date: CivilDate(2026, 11, d),
                        gross: Money.parse('100'),
                      ),
                    )
                    .toList(),
                onRegister: (_) {},
                onConfirm: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Acumulado: S/ 400.00'), findsOneWidget);
      expect(find.text('Neto estimado: S/ 350.00'), findsOneWidget);
      expect(
        find.textContaining('La caja conserva el último cierre confirmado.'),
        findsOneWidget,
      );
      expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 4);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Monthly round uses the total, rather than summing rounded Saturday deductions',
    () {
      final total = List.generate(
        4,
        (_) => Money.parse('0.05'),
      ).fold(Money.zero, (sum, value) => sum + value);
      final breakdown = OfferingBreakdown(total);
      expect(breakdown.district, Money.parse('0.02'));
      expect(breakdown.net, Money.parse('-9.82'));
    },
  );
}
