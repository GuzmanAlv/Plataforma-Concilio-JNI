import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../../core/domain/json_fields.dart';
import '../../../core/supabase/pagination.dart';
import '../../groups/domain/group.dart';
import '../domain/attendance.dart';

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

final class SupabaseAttendanceRepository {
  const SupabaseAttendanceRepository(this._client);
  final SupabaseClient _client;

  Future<List<AttendancePoint>> loadSummary({
    required CivilDate start,
    required CivilDate end,
  }) async {
    PeriodFilter.range(start, end);
    final rows = await loadAllRows(
      (from, to) async => await _client
          .from('asistencia_por_sabado')
          .select()
          .gte('fecha', start.toString())
          .lte('fecha', end.toString())
          .order('fecha')
          .order('grupo_id')
          .range(from, to),
    );
    return rows.map(AttendancePoint.fromJson).toList(growable: false);
  }

  Future<AttendanceSession?> loadSession({
    required GroupId groupId,
    required CivilDate date,
  }) async {
    CouncilPeriod.official.requireDate(date, saturday: true);
    final row = await _client
        .from('asistencia_sesiones')
        .select()
        .eq('grupo_id', groupId.name)
        .eq('fecha', date.toString())
        .maybeSingle();
    return row == null ? null : AttendanceSession.fromJson(row);
  }

  Future<List<AttendanceRecord>> loadRecords(String sessionId) async {
    requireNonEmpty(sessionId, 'La sesión');
    final rows = await loadAllRows(
      (from, to) async => await _client
          .from('asistencia_registros')
          .select()
          .eq('sesion_id', sessionId)
          .order('id')
          .range(from, to),
    );
    return rows.map(AttendanceRecord.fromJson).toList(growable: false);
  }

  Future<String> save(AttendanceSubmission submission) async =>
      await _client.rpc('guardar_asistencia', params: submission.toRpcParams())
          as String;
}
