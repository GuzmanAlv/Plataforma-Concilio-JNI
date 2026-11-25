import 'package:concilio_jni_dreamrs/core/domain/money.dart';
import 'package:concilio_jni_dreamrs/features/treasury/domain/treasury.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PEN decimal exacto', () {
    test('convierte numeric de PostgreSQL sin operaciones con double', () {
      expect(Money.parse('1234.56').cents, 123456);
      expect(Money.parse(12.3).cents, 1230);
      expect(Money.parse(0).decimal, '0.00');
      expect(Money.parse('-0.01').decimal, '-0.01');
      expect(Money.parse('1e2').cents, 10000);
      expect(Money.parse('5e-3').cents, 1);
    });

    test('redondea mitades alejándose de cero, igual que numeric round', () {
      expect(Money.parse('1.005').decimal, '1.01');
      expect(Money.parse('-1.005').decimal, '-1.01');
      expect(Money.parse('1.0049').decimal, '1.00');
      expect(Money.parse('-0.0049').decimal, '0.00');
      expect(Money.parse('0.05').percentage(10).decimal, '0.01');
      expect(Money.parse('-0.05').percentage(10).decimal, '-0.01');
    });

    test('rechaza entradas malformadas y fuera del entero seguro de Web', () {
      for (final invalid in ['S/ 10.00', '1,25', 'NaN', '', '1e100']) {
        expect(() => Money.parse(invalid), throwsFormatException);
      }
      expect(() => Money.fromCents(Money.maxSafeCents + 1), throwsRangeError);
    });

    test(
      'desglosa ofrendas y conserva el neto negativo de ofrendas pequeñas',
      () {
        final normal = OfferingBreakdown(Money.parse('100.00'));
        expect(normal.district.decimal, '10.00');
        expect(normal.fixedContribution.decimal, '10.00');
        expect(normal.net.decimal, '80.00');
        expect(OfferingBreakdown(Money.parse('10.00')).net.decimal, '-1.00');
        expect(OfferingBreakdown(Money.parse('11.11')).net.decimal, '0.00');
        expect(
          () => OfferingBreakdown(Money.parse('-0.01')),
          throwsArgumentError,
        );
        expect(() => OfferingBreakdown(Money.zero), throwsArgumentError);
      },
    );
  });
}
