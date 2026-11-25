import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/council_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fecha civil estricta sin normalización silenciosa ni hora UTC', () {
    expect(CivilDate.parse('2026-11-07').toString(), '2026-11-07');
    expect(CivilDate.parse('2026-11-07').isSaturday, isTrue);
    expect(() => CivilDate.parse('2026-02-29'), throwsFormatException);
    expect(() => CivilDate.parse('2026-13-01'), throwsFormatException);
    expect(
      () => CivilDate.parse('2026-11-07T00:00:00Z'),
      throwsFormatException,
    );
    expect(
      CivilDate.fromDateTime(DateTime.utc(2026, 11, 7)).toString(),
      '2026-11-07',
    );
    expect(CivilDate(2026, 12, 31).addDays(1), CivilDate(2027, 1, 1));
  });

  test(
    'edad y próximo cumpleaños respetan cumpleaños del día y cambio de año',
    () {
      final birth = CivilDate(2006, 11, 25);
      expect(birth.ageOn(CivilDate(2026, 11, 24)), 19);
      expect(birth.ageOn(CivilDate(2026, 11, 25)), 20);
      expect(
        birth.nextBirthdayOnOrAfter(CivilDate(2026, 11, 25)),
        CivilDate(2026, 11, 25),
      );
      expect(
        birth.nextBirthdayOnOrAfter(CivilDate(2026, 11, 26)),
        CivilDate(2027, 11, 25),
      );
      expect(() => birth.ageOn(CivilDate(2005, 1, 1)), throwsArgumentError);
    },
  );

  test('29 de febrero cumple el 28 en años no bisiestos', () {
    final birth = CivilDate(2008, 2, 29);
    expect(birth.ageOn(CivilDate(2027, 2, 27)), 18);
    expect(birth.ageOn(CivilDate(2027, 2, 28)), 19);
    expect(
      birth.nextBirthdayOnOrAfter(CivilDate(2028, 2, 28)),
      CivilDate(2028, 2, 29),
    );
  });

  test('el ciclo oficial contiene exactamente sus 52 sábados', () {
    final period = CouncilPeriod.official;
    expect(period.saturdays.length, 52);
    expect(period.saturdays.first, CivilDate(2026, 11, 7));
    expect(period.saturdays.last, CivilDate(2027, 10, 30));
    expect(period.contains(CivilDate(2026, 11, 1)), isTrue);
    expect(period.contains(CivilDate(2027, 10, 31)), isTrue);
    expect(period.contains(CivilDate(2027, 11, 1)), isFalse);
    expect(
      () => period.requireDate(CivilDate(2026, 11, 8), saturday: true),
      throwsArgumentError,
    );
  });

  test('filtros inclusivos de mes y rango permanecen dentro del ciclo', () {
    final november = PeriodFilter.month(2026, 11);
    expect(november.saturdays.map((date) => date.day), [7, 14, 21, 28]);
    expect(
      PeriodFilter.range(
        CivilDate(2026, 11, 14),
        CivilDate(2026, 11, 21),
      ).saturdays.length,
      2,
    );
    expect(() => PeriodFilter.month(2026, 10), throwsArgumentError);
    expect(
      () => PeriodFilter.range(CivilDate(2027, 1, 2), CivilDate(2026, 11, 7)),
      throwsArgumentError,
    );
    expect(PeriodFilter.all().saturdays.length, 52);
  });
}
