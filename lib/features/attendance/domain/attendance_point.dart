import '../../../core/domain/civil_date.dart';
import '../../../core/domain/json_fields.dart';
import '../../groups/domain/group.dart';

final class AttendancePoint {
  const AttendancePoint({
    required this.date,
    required this.groupId,
    required this.present,
    required this.invited,
  });
  factory AttendancePoint.fromJson(JsonMap json) => AttendancePoint(
    date: jsonDate(json, 'fecha'),
    groupId: GroupId.parse(jsonString(json, 'grupo_id')),
    present: jsonInt(json, 'total_presentes'),
    invited: jsonInt(json, 'total_convocados'),
  );
  final CivilDate date;
  final GroupId groupId;
  final int present;
  final int invited;
  double get participationRate => invited == 0 ? 0 : present / invited;
}
