import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../../core/domain/json_fields.dart';
import '../../groups/domain/group.dart';

final class AttendanceSession {
  AttendanceSession({
    required this.id,
    required this.groupId,
    required this.date,
  }) {
    requireNonEmpty(id, 'El identificador');
    CouncilPeriod.official.requireDate(date, saturday: true);
  }
  factory AttendanceSession.fromJson(JsonMap json) => AttendanceSession(
    id: jsonString(json, 'id'),
    groupId: GroupId.parse(jsonString(json, 'grupo_id')),
    date: jsonDate(json, 'fecha'),
  );
  final String id;
  final GroupId groupId;
  final CivilDate date;
  JsonMap toJson() => {
    'id': id,
    'grupo_id': groupId.name,
    'fecha': date.toString(),
  };
}

/// A missing record/session means attendance has not been taken, not absence.
final class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.memberId,
    required this.present,
  }) {
    requireNonEmpty(id, 'El identificador');
    requireNonEmpty(sessionId, 'La sesión');
    requireNonEmpty(memberId, 'El integrante');
  }
  factory AttendanceRecord.fromJson(JsonMap json) => AttendanceRecord(
    id: jsonString(json, 'id'),
    sessionId: jsonString(json, 'sesion_id'),
    memberId: jsonString(json, 'integrante_id'),
    present: jsonBool(json, 'presente'),
  );
  final String id;
  final String sessionId;
  final String memberId;
  final bool present;
  JsonMap toJson() => {
    'id': id,
    'sesion_id': sessionId,
    'integrante_id': memberId,
    'presente': present,
  };
}

/// RPC payload: saving again replaces marks for the same group and Saturday.
final class AttendanceSubmission {
  AttendanceSubmission({
    required this.groupId,
    required this.date,
    required Iterable<String> presentMemberIds,
  }) : presentMemberIds = Set<String>.unmodifiable(presentMemberIds) {
    CouncilPeriod.official.requireDate(date, saturday: true);
    for (final id in this.presentMemberIds) {
      requireNonEmpty(id, 'El integrante');
    }
  }
  final GroupId groupId;
  final CivilDate date;
  final Set<String> presentMemberIds;
  JsonMap toRpcParams() => {
    'p_grupo_id': groupId.name,
    'p_fecha': date.toString(),
    'p_presentes': presentMemberIds.toList(growable: false),
  };
}
