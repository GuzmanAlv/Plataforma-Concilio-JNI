import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/async_panel.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_item.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        title: 'Inventario',
        subtitle: 'Cuidamos los recursos que nos ayudan a servir.',
      ),
      AsyncPanel<List<InventoryItem>>(
        value: ref.watch(inventoryItemsProvider),
        onRetry: () => ref.invalidate(inventoryItemsProvider),
        builder: (items) => Card(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Un lugar para cada recurso',
                  message:
                      'Aquí encontrarás los artículos, sus cantidades, estado y observaciones.',
                )
              : Column(
                  children: items
                      .map(
                        (item) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.condition.label}${item.notes.isEmpty ? '' : '\n${item.notes}'}',
                          ),
                          trailing: Text(
                            '× ${item.quantity}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ),
    ],
  );
}
