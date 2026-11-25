import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/supabase_treasury_repository.dart';
import '../domain/treasury.dart';

final cashSummaryProvider = FutureProvider.autoDispose<CashSummary>((
  ref,
) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const CashSummary.zero();
  return SupabaseTreasuryRepository(client).loadSummary();
});

final cashEvolutionProvider = FutureProvider.autoDispose
    .family<List<CashPoint>, ({CivilDate start, CivilDate end})>((
      ref,
      dates,
    ) async {
      ref.watch(authStateProvider);
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return [];
      return SupabaseTreasuryRepository(
        client,
      ).loadEvolution(start: dates.start, end: dates.end);
    });

final treasuryMovementsProvider =
    FutureProvider.autoDispose<
      ({List<Offering> offerings, List<Expense> expenses})
    >((ref) async {
      ref.watch(authStateProvider);
      final client = ref.watch(supabaseClientProvider);
      if (client == null) {
        return (offerings: <Offering>[], expenses: <Expense>[]);
      }
      final repository = SupabaseTreasuryRepository(client);
      final results = await (
        repository.loadOfferings(),
        repository.loadExpenses(),
      ).wait;
      return (offerings: results.$1, expenses: results.$2);
    });
