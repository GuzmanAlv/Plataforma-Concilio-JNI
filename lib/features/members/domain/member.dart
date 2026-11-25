import '../../../core/domain/civil_date.dart';
import '../../../core/domain/json_fields.dart';
import '../../groups/domain/group.dart';

enum MemberRole {
  lider('Líder'),
  integrante('Integrante');

  const MemberRole(this.label);
  final String label;
  static MemberRole parse(String value) => values.firstWhere(
    (role) => role.name == value,
    orElse: () => throw FormatException('Rol desconocido: $value'),
  );
}

final class Member {
  Member({
    required this.id,
    required this.fullName,
    required this.birthDate,
    required this.active,
  }) {
    requireNonEmpty(id, 'El identificador');
    requireNonEmpty(fullName, 'El nombre completo');
  }

  factory Member.fromJson(JsonMap json) => Member(
    id: jsonString(json, 'id'),
    fullName: jsonString(json, 'nombre_completo'),
    birthDate: jsonDate(json, 'fecha_nacimiento'),
    active: jsonBool(json, 'activo'),
  );

  final String id;
  final String fullName;
  final CivilDate birthDate;
  final bool active;
  int ageOn(CivilDate date) => birthDate.ageOn(date);
  CivilDate nextBirthdayOnOrAfter(CivilDate date) =>
      birthDate.nextBirthdayOnOrAfter(date);

  JsonMap toJson() => {
    'id': id,
    'nombre_completo': fullName,
    'fecha_nacimiento': birthDate.toString(),
    'activo': active,
  };

  Member copyWith({String? fullName, CivilDate? birthDate, bool? active}) =>
      Member(
        id: id,
        fullName: fullName ?? this.fullName,
        birthDate: birthDate ?? this.birthDate,
        active: active ?? this.active,
      );
}

/// Membership history uses [startDate, endDate): endDate is exclusive.
final class GroupMembership {
  GroupMembership({
    required this.id,
    required this.memberId,
    required this.groupId,
    required this.role,
    required this.startDate,
    this.endDate,
  }) {
    requireNonEmpty(id, 'El identificador');
    requireNonEmpty(memberId, 'El integrante');
    if (endDate != null && endDate! <= startDate) {
      throw ArgumentError('El intervalo de membresía debe ser positivo.');
    }
  }

  factory GroupMembership.fromJson(JsonMap json) => GroupMembership(
    id: jsonString(json, 'id'),
    memberId: jsonString(json, 'integrante_id'),
    groupId: GroupId.parse(jsonString(json, 'grupo_id')),
    role: MemberRole.parse(jsonString(json, 'rol')),
    startDate: jsonDate(json, 'fecha_inicio'),
    endDate: jsonNullableDate(json, 'fecha_fin'),
  );

  final String id;
  final String memberId;
  final GroupId groupId;
  final MemberRole role;
  final CivilDate startDate;
  final CivilDate? endDate;
  bool get isCurrent => endDate == null;
  bool contains(CivilDate date) =>
      date >= startDate && (endDate == null || date < endDate!);

  JsonMap toJson() => {
    'id': id,
    'integrante_id': memberId,
    'grupo_id': groupId.name,
    'rol': role.name,
    'fecha_inicio': startDate.toString(),
    'fecha_fin': endDate?.toString(),
  };
}
