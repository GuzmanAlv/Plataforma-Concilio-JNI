import '../../../core/providers/request_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/supabase_treasury_repository.dart';
import '../domain/treasury.dart';

final cashSummaryProvider = FutureProvider.autoDispose<CashSummary>((
  ref,
) async {
  ref.watch(authIdentityProvider);
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const CashSummary.zero();
  final data = await SupabaseTreasuryRepository(client).loadSummary();
  ref.cacheSuccess();
  return data;
});

final cashEvolutionProvider = FutureProvider.autoDispose
    .family<List<CashPoint>, ({CivilDate start, CivilDate end})>((
      ref,
      dates,
    ) async {
      ref.watch(authIdentityProvider);
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return [];
      final data = await SupabaseTreasuryRepository(
        client,
      ).loadEvolution(start: dates.start, end: dates.end);
      ref.cacheSuccess();
      return data;
    });

final treasuryMovementsProvider =
    FutureProvider.autoDispose<
      ({List<Offering> offerings, List<Expense> expenses})
    >((ref) async {
      ref.watch(authIdentityProvider);
      final client = ref.watch(supabaseClientProvider);
      if (client == null) {
        return (offerings: <Offering>[], expenses: <Expense>[]);
      }
      final repository = SupabaseTreasuryRepository(client);
      final results = await (
        repository.loadOfferings(),
        repository.loadExpenses(),
      ).wait;
      ref.cacheSuccess();
      return (offerings: results.$1, expenses: results.$2);
    });
