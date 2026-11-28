import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../../core/domain/json_fields.dart';
import '../../../core/supabase/pagination.dart';
import '../../groups/domain/group.dart';
import '../domain/member.dart';

final class MemberDirectoryEntry {
  const MemberDirectoryEntry({required this.member, this.membership});
  final Member member;
  final GroupMembership? membership;
}

final class SupabaseMembersRepository {
  const SupabaseMembersRepository(this._client);
  final SupabaseClient _client;

  Future<List<Group>> loadGroups() async {
    final rows = await _client.from('grupos').select().order('id');
    return rows.map(Group.fromJson).toList(growable: false);
  }

  Future<List<MemberDirectoryEntry>> loadDirectory({CivilDate? onDate}) async {
    final date = (onDate ?? CivilDate.today()).toString();
    final results = await Future.wait([
      loadAllRows(
        (from, to) async => await _client
            .from('integrantes')
            .select()
            .order('id')
            .range(from, to),
      ),
      loadAllRows(
        (from, to) async => await _client
            .from('membresias_grupo')
            .select()
            .lte('fecha_inicio', date)
            .or('fecha_fin.is.null,fecha_fin.gt.$date')
            .order('id')
            .range(from, to),
      ),
    ]);
    final memberships = <String, GroupMembership>{
      for (final json in results[1])
        jsonString(json, 'integrante_id'): GroupMembership.fromJson(json),
    };
    final entries = results[0].map((json) {
      final member = Member.fromJson(json);
      return MemberDirectoryEntry(
        member: member,
        membership: memberships[member.id],
      );
    }).toList();
    entries.sort(
      (a, b) => a.member.fullName.toLowerCase().compareTo(
        b.member.fullName.toLowerCase(),
      ),
    );
    return List.unmodifiable(entries);
  }

  Future<List<GroupMembership>> loadHistory(String memberId) async {
    requireNonEmpty(memberId, 'El integrante');
    final rows = await loadAllRows(
      (from, to) async => await _client
          .from('membresias_grupo')
          .select()
          .eq('integrante_id', memberId)
          .order('fecha_inicio')
          .order('id')
          .range(from, to),
    );
    return rows.map(GroupMembership.fromJson).toList(growable: false);
  }

  Future<String> create({
    required String fullName,
    required CivilDate birthDate,
    required GroupId groupId,
    MemberRole role = MemberRole.integrante,
    CivilDate? startDate,
  }) async {
    requireNonEmpty(fullName, 'El nombre completo');
    if (birthDate > CivilDate.today()) {
      throw ArgumentError('La fecha de nacimiento no puede ser futura.');
    }
    if (startDate != null) CouncilPeriod.official.requireDate(startDate);
    final result = await _client.rpc(
      'crear_integrante',
      params: {
        'p_nombre_completo': fullName.trim(),
        'p_fecha_nacimiento': birthDate.toString(),
        'p_grupo_id': groupId.name,
        'p_rol': role.name,
        if (startDate != null) 'p_fecha_inicio': startDate.toString(),
      },
    );
    return result as String;
  }

  Future<void> updateMember(Member member) async {
    if (member.birthDate > CivilDate.today()) {
      throw ArgumentError('La fecha de nacimiento no puede ser futura.');
    }
    await _client
        .from('integrantes')
        .update({
          'nombre_completo': member.fullName.trim(),
          'fecha_nacimiento': member.birthDate.toString(),
        })
        .eq('id', member.id)
        .select('id')
        .single();
  }

  Future<void> edit({
    required String memberId,
    required String fullName,
    required CivilDate birthDate,
    required GroupId groupId,
    required MemberRole role,
    required CivilDate effectiveDate,
  }) async {
    requireNonEmpty(fullName, 'El nombre completo');
    CouncilPeriod.official.requireDate(effectiveDate);
    if (birthDate > CivilDate.today()) {
      throw ArgumentError('La fecha de nacimiento no puede ser futura.');
    }
    await _client.rpc(
      'editar_integrante',
      params: {
        'p_integrante_id': memberId,
        'p_nombre_completo': fullName.trim(),
        'p_fecha_nacimiento': birthDate.toString(),
        'p_grupo_id': groupId.name,
        'p_rol': role.name,
        'p_fecha': effectiveDate.toString(),
      },
    );
  }

  Future<String> changeGroup({
    required String memberId,
    required GroupId groupId,
    required MemberRole role,
    required CivilDate date,
  }) async {
    requireNonEmpty(memberId, 'El integrante');
    CouncilPeriod.official.requireDate(date);
    final result = await _client.rpc(
      'cambiar_grupo',
      params: {
        'p_integrante_id': memberId,
        'p_grupo_id': groupId.name,
        'p_rol': role.name,
        'p_fecha': date.toString(),
      },
    );
    return result as String;
  }

  Future<void> archive({
    required String memberId,
    required CivilDate date,
  }) async {
    requireNonEmpty(memberId, 'El integrante');
    CouncilPeriod.official.requireDate(date);
    await _client.rpc(
      'archivar_integrante',
      params: {'p_integrante_id': memberId, 'p_fecha': date.toString()},
    );
  }
}
