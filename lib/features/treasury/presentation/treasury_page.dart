import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
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
import 'movements_table.dart';
import 'offering_dialog.dart';
import 'monthly_offering_dialog.dart';
import 'saturday_offerings_panel.dart';

class TreasuryPage extends ConsumerStatefulWidget {
  const TreasuryPage({super.key});
  @override
  ConsumerState<TreasuryPage> createState() => _TreasuryPageState();
}

class _TreasuryPageState extends ConsumerState<TreasuryPage> {
  PeriodFilter _filter = PeriodFilter.all();

  bool _saturdayView = false;

  Future<void> _registerSaturday([CivilDate? date]) async {
    try {
      final offerings = await ref.read(saturdayOfferingsProvider.future);
      if (!mounted) return;
      final client = ref.read(supabaseClientProvider);
      var attempted = false;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => OfferingDialog(
          offerings: offerings,
          initialDate: date,
          onSave: client == null
              ? null
              : (date, gross) async {
                  attempted = true;
                  await SupabaseTreasuryRepository(
                    client,
                  ).saveSaturdayOffering(date: date, gross: gross);
                },
        ),
      );
      if (attempted && mounted) {
        ref.invalidate(saturdayOfferingsProvider);
        ref.invalidate(offeringMonthsProvider);
      }
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ofrenda sabatina guardada. El acumulado mensual se actualizó.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron cargar las ofrendas. Actualiza los datos e intenta nuevamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmMonth([CivilDate? month]) async {
    try {
      final months = await ref.read(offeringMonthsProvider.future);
      if (!mounted) return;
      final client = ref.read(supabaseClientProvider);
      var attempted = false;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MonthlyOfferingDialog(
          months: months,
          initialMonth: month,
          onSave: client == null
              ? null
              : (month, gross, reason) async {
                  attempted = true;
                  await SupabaseTreasuryRepository(
                    client,
                  ).confirmMonth(month: month, gross: gross, reason: reason);
                },
        ),
      );
      if (attempted && mounted) {
        ref.invalidate(offeringMonthsProvider);
        ref.invalidate(cashSummaryProvider);
        ref.invalidate(cashEvolutionProvider);
        ref.invalidate(treasuryMovementsProvider);
      }
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mes confirmado. El neto mensual se actualizó en caja.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo cargar el resumen mensual. Actualiza los datos e intenta nuevamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _addExpense([Expense? initialExpense]) async {
    final client = ref.read(supabaseClientProvider);
    String? uploadedPath;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NewExpenseDialog(
        initialExpense: initialExpense,
        onSave: client == null
            ? null
            : (draft) async {
                final repository = SupabaseTreasuryRepository(client);
                if (initialExpense == null &&
                    await repository.findExpense(draft.id) != null) {
                  return;
                }
                if (draft.photo != null && uploadedPath == null) {
                  uploadedPath = await repository.uploadReceipt(
                    draft.photo!.bytes,
                    mimeType: draft.photo!.mimeType,
                  );
                }
                final receiptPath =
                    uploadedPath ??
                    (draft.keepExistingReceipt
                        ? initialExpense?.receiptPath
                        : null);
                if (initialExpense != null) {
                  await repository.updateExpense(
                    Expense(
                      id: initialExpense.id,
                      date: draft.date,
                      amount: draft.amount,
                      concept: draft.description,
                      name: draft.name,
                      receiptPath: receiptPath,
                    ),
                  );
                } else {
                  await repository.createExpense(
                    id: draft.id,
                    name: draft.name,
                    date: draft.date,
                    amount: draft.amount,
                    concept: draft.description,
                    receiptPath: receiptPath,
                  );
                }
              },
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(cashSummaryProvider);
      ref.invalidate(cashEvolutionProvider);
      ref.invalidate(treasuryMovementsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Egreso guardado correctamente.')),
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
        const SectionHeader(
          title: 'Tesorería',
          subtitle:
              'Administramos con claridad lo que construimos juntos. Moneda: soles peruanos (PEN).',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ofrendas del concilio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Acumula lo recogido cada sábado o registra el total del mes. Distrito y colaboración se descuentan al confirmar el cierre mensual.',
                  style: TextStyle(color: Color(0xFF79718D)),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _confirmMonth(),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Agregar ofrenda mensual'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _registerSaturday(),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Agregar ofrenda del sábado'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Dashboard de caja'),
              avatar: const Icon(Icons.insights_outlined, size: 18),
              selected: !_saturdayView,
              onSelected: (_) => setState(() => _saturdayView = false),
            ),
            ChoiceChip(
              label: const Text('Ofrendas por sábado'),
              avatar: const Icon(Icons.table_chart_outlined, size: 18),
              selected: _saturdayView,
              onSelected: (_) => setState(() => _saturdayView = true),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_saturdayView)
          AsyncPanel<List<OfferingMonth>>(
            value: ref.watch(offeringMonthsProvider),
            onRetry: () => ref.invalidate(offeringMonthsProvider),
            builder: (months) => AsyncPanel<List<SaturdayOffering>>(
              value: ref.watch(saturdayOfferingsProvider),
              onRetry: () => ref.invalidate(saturdayOfferingsProvider),
              builder: (offerings) => SaturdayOfferingsPanel(
                months: months,
                offerings: offerings,
                onRegister: (date) => _registerSaturday(date),
                onConfirm: (month) => _confirmMonth(month.month),
              ),
            ),
          )
        else ...[
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                    'Saldo de caja (morado) e ingresos de cierres mensuales confirmados (verde), en S/.',
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
          Center(
            child: FilledButton.icon(
              onPressed: () => _addExpense(),
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Agregar egreso'),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          'Movimientos del periodo seleccionado',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        AsyncPanel(
          value: ref.watch(treasuryMovementsProvider),
          onRetry: () => ref.invalidate(treasuryMovementsProvider),
          builder: (movements) => MovementsTable(
            offerings: movements.offerings,
            expenses: movements.expenses,
            filter: _filter,
            onEdit: (expense) => _addExpense(expense),
            onReceipt: _showReceipt,
            onEditOffering: (offering) => _confirmMonth(offering.month),
          ),
        ),
      ],
    );
  }
}
