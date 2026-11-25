/// A calendar date, without a time zone or an implicit UTC conversion.
final class CivilDate implements Comparable<CivilDate> {
  factory CivilDate(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);
    if (year < 1 ||
        year > 9999 ||
        normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError('Fecha de calendario inválida: $year-$month-$day');
    }
    return CivilDate._(year, month, day);
  }

  const CivilDate._(this.year, this.month, this.day);

  factory CivilDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) throw FormatException('Se esperaba YYYY-MM-DD', value);
    try {
      return CivilDate(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
    } on ArgumentError {
      throw FormatException('Fecha de calendario inválida', value);
    }
  }

  /// Uses the date shown by the device, without converting it to UTC.
  factory CivilDate.fromDateTime(DateTime value) =>
      CivilDate(value.year, value.month, value.day);

  factory CivilDate.today() => CivilDate.fromDateTime(DateTime.now());

  final int year;
  final int month;
  final int day;

  DateTime toDateTime() => DateTime(year, month, day);
  DateTime get _utc => DateTime.utc(year, month, day);
  int get weekday => _utc.weekday;
  bool get isSaturday => weekday == DateTime.saturday;

  CivilDate addDays(int days) =>
      CivilDate.fromDateTime(_utc.add(Duration(days: days)));
  int daysUntil(CivilDate other) => other._utc.difference(_utc).inDays;

  /// Feb 29 birthdays are celebrated on Feb 28 in non-leap years.
  CivilDate anniversaryIn(int targetYear) {
    final leap =
        targetYear % 4 == 0 && (targetYear % 100 != 0 || targetYear % 400 == 0);
    return CivilDate(
      targetYear,
      month,
      month == 2 && day == 29 && !leap ? 28 : day,
    );
  }

  int ageOn(CivilDate today) {
    if (today < this) throw ArgumentError('El nacimiento no puede ser futuro.');
    return today.year - year - (today < anniversaryIn(today.year) ? 1 : 0);
  }

  CivilDate nextBirthdayOnOrAfter(CivilDate today) {
    if (today < this) throw ArgumentError('El nacimiento no puede ser futuro.');
    final thisYear = anniversaryIn(today.year);
    return thisYear < today ? anniversaryIn(today.year + 1) : thisYear;
  }

  @override
  int compareTo(CivilDate other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    final byMonth = month.compareTo(other.month);
    return byMonth != 0 ? byMonth : day.compareTo(other.day);
  }

  bool operator <(CivilDate other) => compareTo(other) < 0;
  bool operator <=(CivilDate other) => compareTo(other) <= 0;
  bool operator >(CivilDate other) => compareTo(other) > 0;
  bool operator >=(CivilDate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
