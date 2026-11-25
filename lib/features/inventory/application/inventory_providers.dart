import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/supabase_inventory_repository.dart';
import '../domain/inventory_item.dart';

final inventoryItemsProvider = FutureProvider.autoDispose<List<InventoryItem>>((
  ref,
) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return [];
  return SupabaseInventoryRepository(client).loadItems();
});
