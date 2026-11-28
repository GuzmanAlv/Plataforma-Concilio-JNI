import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../../core/domain/json_fields.dart';
import '../../../core/domain/money.dart';

final class OfferingBreakdown {
  OfferingBreakdown(Money gross) : gross = gross {
    if (gross.cents <= 0) {
      throw ArgumentError('La ofrenda bruta debe ser mayor a cero.');
    }
  }
  final Money gross;
  Money get district => gross.percentage(10);
  Money get fixedContribution => Money.fromCents(1000);
  Money get net => gross - district - fixedContribution;
}

final class Offering {
  Offering({
    required this.id,
    required this.date,
    required this.month,
    required this.gross,
    required this.district,
    required this.fixedContribution,
    required this.net,
  }) {
    requireNonEmpty(id, 'El identificador');
    CouncilPeriod.official.requireDate(date);
    CouncilPeriod.official.requireDate(month);
    if (month.day != 1 ||
        month.year != date.year ||
        month.month != date.month) {
      throw ArgumentError('El cierre debe corresponder al mes de caja.');
    }
    final expected = OfferingBreakdown(gross);
    if (district != expected.district ||
        fixedContribution != expected.fixedContribution ||
        net != expected.net) {
      throw ArgumentError(
        'El desglose de la ofrenda no coincide con las reglas de caja.',
      );
    }
  }

  factory Offering.fromJson(JsonMap json) => Offering(
    id: jsonString(json, 'id'),
    date: jsonDate(json, 'fecha_caja'),
    month: jsonDate(json, 'mes'),
    gross: jsonMoney(json, 'monto_bruto'),
    district: jsonMoney(json, 'aporte_distrito'),
    fixedContribution: jsonMoney(json, 'colaboracion_fija'),
    net: jsonMoney(json, 'monto_neto'),
  );
  final String id;
  final CivilDate date;
  final CivilDate month;
  final Money gross;
  final Money district;
  final Money fixedContribution;
  final Money net;

  JsonMap toJson() => {
    'id': id,
    'mes': month.toString(),
    'fecha_caja': date.toString(),
    'monto_bruto': gross.decimal,
    'aporte_distrito': district.decimal,
    'colaboracion_fija': fixedContribution.decimal,
    'monto_neto': net.decimal,
  };
}

final class SaturdayOffering {
  SaturdayOffering({
    required this.id,
    required this.date,
    required this.gross,
  }) {
    CouncilPeriod.official.requireDate(date, saturday: true);
    if (gross.cents <= 0) {
      throw ArgumentError('El monto debe ser mayor a cero.');
    }
  }
  factory SaturdayOffering.fromJson(JsonMap json) => SaturdayOffering(
    id: jsonString(json, 'id'),
    date: jsonDate(json, 'fecha'),
    gross: jsonMoney(json, 'monto_bruto'),
  );
  final String id;
  final CivilDate date;
  final Money gross;
}

final class OfferingMonth {
  const OfferingMonth({
    required this.month,
    required this.saturdayTotal,
    required this.saturdayCount,
    required this.sourceRevision,
    required this.version,
    required this.needsReview,
    this.confirmed,
    this.reason = '',
  });
  factory OfferingMonth.fromJson(JsonMap json) => OfferingMonth(
    month: jsonDate(json, 'mes'),
    saturdayTotal: jsonMoney(json, 'total_sabatino'),
    saturdayCount: jsonInt(json, 'sabados_registrados'),
    sourceRevision: jsonString(json, 'fuente_revision'),
    version: jsonInt(json, 'version'),
    needsReview: jsonBool(json, 'requiere_revision'),
    reason: json['ajuste_razon'] as String? ?? '',
    confirmed: json['cierre_id'] == null
        ? null
        : Offering.fromJson({...json, 'id': json['cierre_id']}),
  );
  final CivilDate month;
  final Money saturdayTotal;
  final int saturdayCount;
  final String sourceRevision;
  final int version;
  final bool needsReview;
  final Offering? confirmed;
  final String reason;
  static List<OfferingMonth> emptyCycle() => List.generate(
    12,
    (i) => OfferingMonth(
      month: CivilDate.fromDateTime(DateTime(2026, 11 + i)),
      saturdayTotal: Money.zero,
      saturdayCount: 0,
      sourceRevision: '',
      version: 0,
      needsReview: false,
    ),
  );
}

final class Expense {
  Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.concept,
    this.name = 'Gasto',
    this.receiptPath,
  }) {
    requireNonEmpty(id, 'El identificador');
    requireNonEmpty(concept, 'El concepto');
    requireNonEmpty(name, 'El nombre del gasto');
    CouncilPeriod.official.requireDate(date);
    if (amount.cents <= 0) {
      throw ArgumentError('El egreso debe ser mayor a cero.');
    }
    if (receiptPath != null) {
      requireNonEmpty(receiptPath!, 'La ruta del comprobante');
    }
  }
  factory Expense.fromJson(JsonMap json) => Expense(
    id: jsonString(json, 'id'),
    date: jsonDate(json, 'fecha'),
    amount: jsonMoney(json, 'monto'),
    concept: jsonString(json, 'concepto'),
    name: json['nombre'] == null ? 'Gasto' : jsonString(json, 'nombre'),
    receiptPath: jsonNullableString(json, 'comprobante_path'),
  );
  final String id;
  final CivilDate date;
  final Money amount;
  final String concept;
  final String name;

  /// Private Storage path; request a signed URL when viewing the receipt.
  final String? receiptPath;
  JsonMap toJson() => {
    'id': id,
    'fecha': date.toString(),
    'monto': amount.decimal,
    'concepto': concept,
    'nombre': name,
    'comprobante_path': receiptPath,
  };
}

final class CashSettings {
  const CashSettings({required this.initialBalance});
  factory CashSettings.fromJson(JsonMap json) {
    if (jsonInt(json, 'id') != 1) {
      throw FormatException('Configuración de caja inválida.');
    }
    return CashSettings(initialBalance: jsonMoney(json, 'saldo_inicial'));
  }
  final Money initialBalance;
  JsonMap toJson() => {'id': 1, 'saldo_inicial': initialBalance.decimal};

  Money balance({
    required Iterable<Offering> offerings,
    required Iterable<Expense> expenses,
  }) =>
      offerings.fold(initialBalance, (sum, offering) => sum + offering.net) -
      expenses.fold(Money.zero, (sum, expense) => sum + expense.amount);
}
