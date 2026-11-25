/// PEN represented in integer centavos, with exact decimal input and rounding.
final class Money implements Comparable<Money> {
  factory Money.fromCents(int cents) {
    if (cents.abs() > maxSafeCents) {
      throw RangeError('Importe fuera del rango seguro para Web.');
    }
    return Money._(cents);
  }
  const Money._(this.cents);
  static const zero = Money._(0);
  static const maxSafeCents = 9007199254740991;

  /// Accepts PostgreSQL numeric values (num or decimal string).
  /// Rounds halfway values away from zero, matching PostgreSQL numeric round.
  factory Money.parse(Object value) {
    if (value is! num && value is! String) {
      throw FormatException('Importe inválido', value);
    }
    final input = value.toString().trim();
    final match = RegExp(
      r'^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$',
    ).firstMatch(input);
    if (match == null) throw FormatException('Importe decimal inválido', input);
    final fraction = match[3] ?? '';
    final exponent = int.tryParse(match[4] ?? '0');
    if (exponent == null || exponent.abs() > 30 || input.length > 100) {
      throw FormatException('Importe fuera de rango', input);
    }
    var units = BigInt.parse('${match[2]}$fraction');
    final power = 2 + exponent - fraction.length;
    if (power >= 0) {
      units *= BigInt.from(10).pow(power);
    } else {
      final divisor = BigInt.from(10).pow(-power);
      final remainder = units.remainder(divisor);
      units = units ~/ divisor;
      if (remainder * BigInt.two >= divisor) units += BigInt.one;
    }
    if (match[1] == '-') units = -units;
    if (units.abs() > BigInt.from(maxSafeCents)) {
      throw RangeError('Importe fuera del rango seguro para Web.');
    }
    return Money.fromCents(units.toInt());
  }

  final int cents;
  bool get isNegative => cents < 0;
  String get decimal {
    final absolute = cents.abs();
    return '${cents < 0 ? '-' : ''}${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  }

  String get formatted => 'S/ $decimal';
  Money operator +(Money other) => Money.fromCents(cents + other.cents);
  Money operator -(Money other) => Money.fromCents(cents - other.cents);

  Money percentage(int percent) {
    if (percent < 0 || percent > 100) throw RangeError.range(percent, 0, 100);
    final absolute = BigInt.from(cents).abs() * BigInt.from(percent);
    var rounded = absolute ~/ BigInt.from(100);
    if (absolute.remainder(BigInt.from(100)) >= BigInt.from(50)) {
      rounded += BigInt.one;
    }
    return Money.fromCents((cents < 0 ? -rounded : rounded).toInt());
  }

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);
  @override
  bool operator ==(Object other) => other is Money && cents == other.cents;
  @override
  int get hashCode => cents.hashCode;
  @override
  String toString() => formatted;
}
