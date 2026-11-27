import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../../core/domain/money.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/widgets/async_panel.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/period_selector.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/timeline_chart.dart';
import '../application/treasury_providers.dart';
import '../data/supabase_treasury_repository.dart';
import '../domain/treasury.dart';
import 'new_expense_dialog.dart';

class TreasuryPage extends ConsumerStatefulWidget {
  const TreasuryPage({super.key});
  @override
  ConsumerState<TreasuryPage> createState() => _TreasuryPageState();
}

class _TreasuryPageState extends ConsumerState<TreasuryPage> {
  PeriodFilter _filter = PeriodFilter.all();

  Future<void> _addExpense() async {
    final client = ref.read(supabaseClientProvider);
    String? uploadedPath;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NewExpenseDialog(
        onSave: client == null
            ? null
            : (draft) async {
                final repository = SupabaseTreasuryRepository(client);
                if (await repository.findExpense(draft.id) != null) return;
                if (draft.photo != null && uploadedPath == null) {
                  uploadedPath = await repository.uploadReceipt(
                    draft.photo!.bytes,
                    mimeType: draft.photo!.mimeType,
                  );
                }
                await repository.createExpense(
                  id: draft.id,
                  name: draft.name,
                  date: draft.date,
                  amount: draft.amount,
                  concept: draft.description,
                  receiptPath: uploadedPath,
                );
              },
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(cashSummaryProvider);
      ref.invalidate(cashEvolutionProvider);
      ref.invalidate(treasuryMovementsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Egreso registrado correctamente.')),
      );
    }
  }

  Future<void> _showReceipt(String path) async {
    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) return;
      final url = await SupabaseTreasuryRepository(
        client,
      ).signedReceiptUrl(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar comprobante',
                    icon: const Icon(Icons.close),
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No se pudo mostrar la imagen. Vuelve a abrir el comprobante.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir el comprobante. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final evolution = cashEvolutionProvider((
      start: _filter.dates.start,
      end: _filter.dates.end,
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Tesorería',
          subtitle:
              'Administramos con claridad lo que construimos juntos. Moneda: soles peruanos (PEN).',
          trailing: FilledButton.icon(
            onPressed: _addExpense,
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Agregar egreso'),
          ),
        ),
        AsyncPanel<CashSummary>(
          value: ref.watch(cashSummaryProvider),
          onRetry: () => ref.invalidate(cashSummaryProvider),
          builder: (summary) => LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 950
                  ? 4
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - 16 * (columns - 1)) / columns;
              final values = [
                (
                  label: 'Saldo actual de caja',
                  value: summary.balance.formatted,
                  icon: Icons.account_balance_wallet_outlined,
                  primary: true,
                ),
                (
                  label: 'Saldo inicial',
                  value: summary.initialBalance.formatted,
                  icon: Icons.flag_outlined,
                  primary: false,
                ),
                (
                  label: 'Ingresos netos',
                  value: summary.netIncome.formatted,
                  icon: Icons.south_west,
                  primary: false,
                ),
                (
                  label: 'Egresos',
                  value: summary.expenses.formatted,
                  icon: Icons.north_east,
                  primary: false,
                ),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: values
                        .map(
                          (item) => SizedBox(
                            width: width,
                            child: Card(
                              color: item.primary ? AppTheme.purple : null,
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      item.icon,
                                      color: item.primary
                                          ? Colors.white
                                          : AppTheme.purple,
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        color: item.primary
                                            ? Colors.white70
                                            : const Color(0xFF74798C),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.value,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: item.primary
                                            ? Colors.white
                                            : AppTheme.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Totales del ciclo · Bruto: ${summary.grossIncome.formatted} · Distrito: ${summary.districtContributions.formatted} · Colaboraciones: ${summary.fixedContributions.formatted}',
                    style: const TextStyle(
                      color: Color(0xFF74798C),
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        PeriodSelector(
          value: _filter,
          onChanged: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evolución de caja',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Saldo de caja (morado) e ingresos netos del día (verde), en S/.',
                  style: TextStyle(color: Color(0xFF74798C), fontSize: 12),
                ),
                AsyncPanel<List<CashPoint>>(
                  value: ref.watch(evolution),
                  onRetry: () => ref.invalidate(evolution),
                  builder: (points) {
                    final recorded = points
                        .where((point) => point.date <= CivilDate.today())
                        .toList();
                    if (recorded.isEmpty) {
                      return const EmptyState(
                        icon: Icons.show_chart,
                        title: 'Una caja con historia',
                        message:
                            'El saldo y los ingresos del concilio se mostrarán aquí.',
                      );
                    }
                    return TimelineChart(
                      start: _filter.dates.start,
                      end: _filter.dates.end,
                      lines: [
                        (
                          color: AppTheme.purple,
                          points: recorded
                              .map(
                                (p) => (
                                  date: p.date,
                                  value: p.balance.cents / 100,
                                ),
                              )
                              .toList(),
                        ),
                        (
                          color: const Color(0xFF2C9B68),
                          points: recorded
                              .map(
                                (p) => (
                                  date: p.date,
                                  value: p.netIncome.cents / 100,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _OfferingCalculator(),
        const SizedBox(height: 24),
        Text(
          'Movimientos del periodo seleccionado',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        AsyncPanel(
          value: ref.watch(treasuryMovementsProvider),
          onRetry: () => ref.invalidate(treasuryMovementsProvider),
          builder: (movements) {
            final rows =
                <
                    ({
                      CivilDate date,
                      String title,
                      String detail,
                      Money amount,
                      String? receipt,
                    })
                  >[
                    ...movements.offerings
                        .where((o) => _filter.contains(o.date))
                        .map(
                          (o) => (
                            date: o.date,
                            title: 'Ofrenda del sábado',
                            amount: o.net,
                            receipt: null,
                            detail:
                                'Bruto ${o.gross.formatted} · Distrito ${o.district.formatted} · Colab. ${o.fixedContribution.formatted}',
                          ),
                        ),
                    ...movements.expenses
                        .where((e) => _filter.contains(e.date))
                        .map(
                          (e) => (
                            date: e.date,
                            title: e.name,
                            amount: Money.zero - e.amount,
                            detail: e.concept,
                            receipt: e.receiptPath,
                          ),
                        ),
                  ]
                  ..sort((a, b) => b.date.compareTo(a.date));
            return Card(
              child: rows.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Sin movimientos registrados',
                      message:
                          'Las ofrendas y los gastos aparecerán en este espacio.',
                    )
                  : Column(
                      children: rows
                          .map(
                            (row) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              title: Text(
                                '${row.title} · ${row.amount.formatted}',
                              ),
                              subtitle: Text(
                                '${DateFormat('d MMM yyyy', 'es_PE').format(row.date.toDateTime())}\n${row.detail}',
                              ),
                              trailing: row.receipt == null
                                  ? null
                                  : IconButton(
                                      onPressed: () =>
                                          _showReceipt(row.receipt!),
                                      tooltip: 'Ver comprobante',
                                      icon: const Icon(Icons.image_outlined),
                                    ),
                            ),
                          )
                          .toList(),
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _OfferingCalculator extends StatefulWidget {
  const _OfferingCalculator();
  @override
  State<_OfferingCalculator> createState() => _OfferingCalculatorState();
}

class _OfferingCalculatorState extends State<_OfferingCalculator> {
  OfferingBreakdown? _breakdown;
  String? _error;

  void _calculate(String value) {
    setState(() {
      _error = null;
      _breakdown = null;
      if (value.trim().isEmpty) return;
      try {
        final amount = Money.parse(value.trim().replaceAll(',', '.'));
        if (amount.cents <= 0) throw const FormatException();
        _breakdown = OfferingBreakdown(amount);
      } catch (_) {
        _error = 'Ingresa un monto mayor a cero, por ejemplo 100.00.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Simular una ofrenda',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Consulta el desglose antes de registrarla. Esta simulación no guarda movimientos.',
            style: TextStyle(color: Color(0xFF74798C), fontSize: 12),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: TextField(
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto bruto recogido',
                prefixText: 'S/ ',
                errorText: _error,
              ),
              onChanged: _calculate,
            ),
          ),
          if (_breakdown != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 28,
              runSpacing: 10,
              children: [
                Text('Distrito (10%): ${_breakdown!.district.formatted}'),
                Text(
                  'Colaboración: ${_breakdown!.fixedContribution.formatted}',
                ),
                Text(
                  'Neto de caja: ${_breakdown!.net.formatted}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.purple,
                  ),
                ),
              ],
            ),
            if (_breakdown!.net.isNegative)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Este monto produce un neto negativo por la colaboración fija de S/ 10.00.',
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
