import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';

abstract final class AttendanceCalendar {
  static final start = CivilDate(2026, 11, 28);
  static List<CivilDate> get saturdays =>
      CouncilPeriod.official.saturdays.where((d) => d >= start).toList();
  static List<CivilDate> inMonth(int year, int month) =>
      saturdays.where((d) => d.year == year && d.month == month).toList();
}
