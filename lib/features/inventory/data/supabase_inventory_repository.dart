import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/pagination.dart';
import '../domain/inventory_item.dart';

final class SupabaseInventoryRepository {
  const SupabaseInventoryRepository(this._client);
  final SupabaseClient _client;

  Future<List<InventoryItem>> loadItems() async {
    final rows = await loadAllRows(
      (from, to) async => await _client
          .from('inventario_items')
          .select()
          .order('nombre')
          .order('id')
          .range(from, to),
    );
    return rows.map(InventoryItem.fromJson).toList(growable: false);
  }

  Future<void> save(InventoryItem item) async {
    final payload = item.toJson()..remove('id');
    await _client
        .from('inventario_items')
        .update(payload)
        .eq('id', item.id)
        .select('id')
        .single();
  }

  Future<InventoryItem> create({
    required String name,
    required int quantity,
    required InventoryCondition condition,
    String notes = '',
  }) async {
    final item = InventoryItem(
      id: const Uuid().v4(),
      name: name.trim(),
      quantity: quantity,
      condition: condition,
      notes: notes.trim(),
    );
    final row = await _client
        .from('inventario_items')
        .insert(item.toJson())
        .select()
        .single();
    return InventoryItem.fromJson(row);
  }
}
