import '../../../core/domain/json_fields.dart';

enum InventoryCondition {
  bueno('Bueno'),
  regular('Regular'),
  malo('Malo'),
  baja('De baja');

  const InventoryCondition(this.label);
  final String label;
  static InventoryCondition parse(String value) => values.firstWhere(
    (condition) => condition.name == value,
    orElse: () =>
        throw FormatException('Estado de inventario desconocido: $value'),
  );
}

final class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.condition,
    this.notes = '',
  }) {
    requireNonEmpty(id, 'El identificador');
    requireNonEmpty(name, 'El nombre');
    if (quantity < 0) throw ArgumentError('La cantidad no puede ser negativa.');
  }
  factory InventoryItem.fromJson(JsonMap json) => InventoryItem(
    id: jsonString(json, 'id'),
    name: jsonString(json, 'nombre'),
    quantity: jsonInt(json, 'cantidad'),
    condition: InventoryCondition.parse(jsonString(json, 'estado')),
    notes: jsonString(json, 'observaciones'),
  );
  final String id;
  final String name;
  final int quantity;
  final InventoryCondition condition;
  final String notes;
  JsonMap toJson() => {
    'id': id,
    'nombre': name,
    'cantidad': quantity,
    'estado': condition.name,
    'observaciones': notes,
  };
}
