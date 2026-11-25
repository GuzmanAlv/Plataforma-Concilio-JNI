import '../../../core/domain/json_fields.dart';

enum GroupId {
  amarillo('Amarillo', 0xFFF5B800),
  verde('Verde', 0xFF2E9E5B),
  rojo('Rojo', 0xFFE5484D),
  celeste('Celeste', 0xFF2FA8E0);

  const GroupId(this.label, this.colorValue);
  final String label;
  final int colorValue;
  String get groupName => 'Grupo $label';

  static GroupId parse(String value) => GroupId.values.firstWhere(
    (id) => id.name == value,
    orElse: () => throw FormatException('Grupo desconocido: $value'),
  );
}

final class Group {
  const Group({required this.id, required this.active});
  factory Group.fromJson(JsonMap json) => Group(
    id: GroupId.parse(jsonString(json, 'id')),
    active: jsonBool(json, 'activo'),
  );

  final GroupId id;
  final bool active;
  String get name => id.groupName;
  JsonMap toJson() => {'id': id.name, 'nombre': name, 'activo': active};
}
