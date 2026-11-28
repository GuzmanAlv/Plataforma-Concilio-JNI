import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../../core/domain/json_fields.dart';
import '../../../core/domain/money.dart';
import '../../../core/supabase/pagination.dart';
import '../domain/treasury.dart';

final class CashSummary {
  const CashSummary.zero()
    : initialBalance = Money.zero,
      grossIncome = Money.zero,
      districtContributions = Money.zero,
      fixedContributions = Money.zero,
      netIncome = Money.zero,
      expenses = Money.zero,
      balance = Money.zero;
  const CashSummary({
    required this.initialBalance,
    required this.grossIncome,
    required this.districtContributions,
    required this.fixedContributions,
    required this.netIncome,
    required this.expenses,
    required this.balance,
  });
  factory CashSummary.fromJson(JsonMap json) => CashSummary(
    initialBalance: jsonMoney(json, 'saldo_inicial'),
    grossIncome: jsonMoney(json, 'ingresos_brutos'),
    districtContributions: jsonMoney(json, 'aportes_distrito'),
    fixedContributions: jsonMoney(json, 'colaboraciones'),
    netIncome: jsonMoney(json, 'ingresos_netos'),
    expenses: jsonMoney(json, 'egresos'),
    balance: jsonMoney(json, 'saldo_actual'),
  );
  final Money initialBalance;
  final Money grossIncome;
  final Money districtContributions;
  final Money fixedContributions;
  final Money netIncome;
  final Money expenses;
  final Money balance;
}

final class CashPoint {
  const CashPoint({
    required this.date,
    required this.netIncome,
    required this.expenses,
    required this.balance,
  });
  factory CashPoint.fromJson(JsonMap json) => CashPoint(
    date: jsonDate(json, 'fecha'),
    netIncome: jsonMoney(json, 'ingresos_netos'),
    expenses: jsonMoney(json, 'egresos'),
    balance: jsonMoney(json, 'saldo_caja'),
  );
  final CivilDate date;

  /// Net income for this calendar day, not cumulative income.
  final Money netIncome;
  final Money expenses;
  final Money balance;
}

final class SupabaseTreasuryRepository {
  const SupabaseTreasuryRepository(this._client);
  final SupabaseClient _client;
  static const receiptBucket = 'comprobantes';
  static const maxReceiptBytes = 10 * 1024 * 1024;
  static const _extensions = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/heic': 'heic',
    'image/heif': 'heif',
  };

  Future<CashSummary> loadSummary() async => CashSummary.fromJson(
    await _client.from('resumen_caja').select().single(),
  );

  Future<List<CashPoint>> loadEvolution({
    required CivilDate start,
    required CivilDate end,
  }) async {
    PeriodFilter.range(start, end);
    final rows = await loadAllRows(
      (from, to) async => await _client
          .from('evolucion_caja')
          .select()
          .gte('fecha', start.toString())
          .lte('fecha', end.toString())
          .order('fecha')
          .range(from, to),
    );
    return rows.map(CashPoint.fromJson).toList(growable: false);
  }

  Future<List<Offering>> loadOfferings() async {
    final rows = await loadAllRows(
      (from, to) async => await _client
          .from('ofrendas_mensuales')
          .select()
          .order('mes', ascending: false)
          .order('id')
          .range(from, to),
    );
    return rows.map(Offering.fromJson).toList(growable: false);
  }

  Future<List<Expense>> loadExpenses() async {
    final rows = await loadAllRows(
      (from, to) async => await _client
          .from('egresos')
          .select()
          .order('fecha', ascending: false)
          .order('id')
          .range(from, to),
    );
    return rows.map(Expense.fromJson).toList(growable: false);
  }

  Future<void> updateInitialBalance(Money amount) async {
    await _client
        .from('configuracion_caja')
        .update({'saldo_inicial': amount.decimal})
        .eq('id', 1)
        .select('id')
        .single();
  }

  Future<List<OfferingMonth>> loadOfferingMonths() async {
    final rows = await _client
        .from('resumen_ofrendas_mensuales')
        .select()
        .order('mes');
    return rows.map(OfferingMonth.fromJson).toList(growable: false);
  }

  Future<List<SaturdayOffering>> loadSaturdayOfferings() async {
    final rows = await loadAllRows(
      (from, to) async => await _client
          .from('ofrendas_sabatinas')
          .select('id,fecha,monto_bruto')
          .order('fecha')
          .range(from, to),
    );
    return rows.map(SaturdayOffering.fromJson).toList(growable: false);
  }

  Future<void> confirmMonth({
    required OfferingMonth month,
    required Money gross,
    required String reason,
  }) async {
    OfferingBreakdown(gross);
    await _client.rpc(
      'confirmar_ofrenda_mensual',
      params: {
        'p_mes': month.month.toString(),
        'p_monto_bruto': gross.decimal,
        'p_fuente_revision': month.sourceRevision,
        'p_version': month.version,
        'p_ajuste_razon': reason.trim(),
      },
    );
  }

  Future<SaturdayOffering> saveSaturdayOffering({
    required CivilDate date,
    required Money gross,
  }) async {
    CouncilPeriod.official.requireDate(date, saturday: true);
    if (gross.cents <= 0) {
      throw ArgumentError('El monto debe ser mayor a cero.');
    }
    final row = await _client
        .from('ofrendas_sabatinas')
        .upsert({
          'fecha': date.toString(),
          'monto_bruto': gross.decimal,
        }, onConflict: 'fecha')
        .select()
        .single();
    return SaturdayOffering.fromJson(row);
  }

  /// Works with XFile.readAsBytes() on Web and Android; never requires dart:io.
  Future<String> uploadReceipt(
    Uint8List bytes, {
    required String mimeType,
  }) async {
    final extension = _extensions[mimeType];
    if (extension == null) {
      throw ArgumentError(
        'El comprobante debe ser una imagen JPEG, PNG, WEBP, HEIC o HEIF.',
      );
    }
    if (bytes.isEmpty || bytes.length > maxReceiptBytes) {
      throw ArgumentError(
        'La imagen debe contener datos y pesar como máximo 10 MiB.',
      );
    }
    final path = '${const Uuid().v4()}/comprobante.$extension';
    await _client.storage
        .from(receiptBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    return path;
  }

  Future<String> signedReceiptUrl(String path) async {
    requireNonEmpty(path, 'La ruta del comprobante');
    return _client.storage.from(receiptBucket).createSignedUrl(path, 60);
  }

  Future<Expense> createExpense({
    String? id,
    String name = 'Gasto',
    required CivilDate date,
    required Money amount,
    required String concept,
    Uint8List? receiptBytes,
    String? receiptMimeType,
    String? receiptPath,
  }) async {
    CouncilPeriod.official.requireDate(date);
    requireNonEmpty(concept, 'El concepto');
    requireNonEmpty(name, 'El nombre del gasto');
    if (receiptBytes != null && receiptPath != null) {
      throw ArgumentError('Envía una imagen o una ruta existente.');
    }
    if (amount.cents <= 0) {
      throw ArgumentError('El egreso debe ser mayor a cero.');
    }
    if (receiptBytes != null && receiptMimeType == null) {
      throw ArgumentError('Falta el tipo MIME de la imagen.');
    }
    final expenseId = id ?? const Uuid().v4();
    final existing = await findExpense(expenseId);
    if (existing != null) return existing;
    String? path = receiptPath;
    if (receiptBytes != null) {
      path = await uploadReceipt(receiptBytes, mimeType: receiptMimeType!);
    }
    // Never delete the uploaded object on an ambiguous network failure: an
    // INSERT may still commit after another request reports the row absent.
    // Reconcile orphaned files separately, after pending writes have settled.
    try {
      final row = await _client
          .from('egresos')
          .insert({
            'id': expenseId,
            'fecha': date.toString(),
            'monto': amount.decimal,
            'concepto': concept.trim(),
            'nombre': name.trim(),
            'comprobante_path': path,
          })
          .select()
          .single();
      return Expense.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        final saved = await findExpense(expenseId);
        if (saved != null) return saved;
      }
      rethrow;
    }
  }

  Future<Expense?> findExpense(String id) async {
    final row = await _client
        .from('egresos')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Expense.fromJson(row);
  }

  Future<Expense> updateExpense(Expense expense) async {
    final row = await _client
        .from('egresos')
        .update({
          'nombre': expense.name.trim(),
          'concepto': expense.concept.trim(),
          'fecha': expense.date.toString(),
          'monto': expense.amount.decimal,
          'comprobante_path': expense.receiptPath,
        })
        .eq('id', expense.id)
        .select()
        .single();
    return Expense.fromJson(row);
  }
}
