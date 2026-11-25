import 'civil_date.dart';

final class CivilDateRange {
  CivilDateRange(this.start, this.end) {
    if (end < start) {
      throw ArgumentError('La fecha final debe ser posterior a la inicial.');
    }
  }

  final CivilDate start;
  final CivilDate end;
  bool contains(CivilDate date) => date >= start && date <= end;
}

final class CouncilPeriod {
  CouncilPeriod._();
  static final official = CouncilPeriod._();
  final start = CivilDate(2026, 11, 1);
  final end = CivilDate(2027, 10, 31);
  static const label = 'Nov 2026 – Oct 2027';

  bool contains(CivilDate date) => date >= start && date <= end;
  CivilDateRange get range => CivilDateRange(start, end);

  void requireDate(CivilDate date, {bool saturday = false}) {
    if (!contains(date)) {
      throw ArgumentError('La fecha debe estar entre $start y $end.');
    }
    if (saturday && !date.isSaturday) {
      throw ArgumentError('La fecha debe ser sábado.');
    }
  }

  List<CivilDate> get saturdays {
    var date = start.addDays((DateTime.saturday - start.weekday + 7) % 7);
    final result = <CivilDate>[];
    while (date <= end) {
      result.add(date);
      date = date.addDays(7);
    }
    return List.unmodifiable(result);
  }
}

enum PeriodFilterMode { all, month, range }

final class PeriodFilter {
  PeriodFilter._(this.mode, this.dates);
  factory PeriodFilter.all() =>
      PeriodFilter._(PeriodFilterMode.all, CouncilPeriod.official.range);

  factory PeriodFilter.month(int year, int month) {
    final start = CivilDate(year, month, 1);
    final end = CivilDate.fromDateTime(DateTime.utc(year, month + 1, 0));
    CouncilPeriod.official.requireDate(start);
    CouncilPeriod.official.requireDate(end);
    return PeriodFilter._(PeriodFilterMode.month, CivilDateRange(start, end));
  }

  factory PeriodFilter.range(CivilDate start, CivilDate end) {
    CouncilPeriod.official.requireDate(start);
    CouncilPeriod.official.requireDate(end);
    return PeriodFilter._(PeriodFilterMode.range, CivilDateRange(start, end));
  }

  final PeriodFilterMode mode;
  final CivilDateRange dates;
  bool contains(CivilDate date) => dates.contains(date);
  List<CivilDate> get saturdays =>
      CouncilPeriod.official.saturdays.where(contains).toList(growable: false);
}
