import 'civil_date.dart';
import 'money.dart';

typedef JsonMap = Map<String, dynamic>;

String jsonString(JsonMap json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('El campo $key debe ser texto.');
  return value;
}

String? jsonNullableString(JsonMap json, String key) {
  if (json[key] == null) return null;
  return jsonString(json, key);
}

bool jsonBool(JsonMap json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('El campo $key debe ser booleano.');
  return value;
}

int jsonInt(JsonMap json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('El campo $key debe ser entero.');
  return value;
}

CivilDate jsonDate(JsonMap json, String key) =>
    CivilDate.parse(jsonString(json, key));
CivilDate? jsonNullableDate(JsonMap json, String key) =>
    json[key] == null ? null : jsonDate(json, key);
Money jsonMoney(JsonMap json, String key) {
  final value = json[key];
  if (value == null) throw FormatException('Falta el campo monetario $key.');
  return Money.parse(value);
}

void requireNonEmpty(String value, String label) {
  if (value.trim().isEmpty) throw ArgumentError('$label es obligatorio.');
}
