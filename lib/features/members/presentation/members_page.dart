import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/civil_date.dart';
import '../../../shared/widgets/async_panel.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../groups/domain/group.dart';
import '../application/members_providers.dart';
import '../data/supabase_members_repository.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'new_member_dialog.dart';
import 'member_directory_row.dart';
import '../../../shared/widgets/styled_select.dart';
import '../../attendance/application/attendance_sheet_provider.dart';
import '../../attendance/application/attendance_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';

class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});
  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  String _search = '';
  GroupId? _group;
  int _page = 0;
  static const _pageSize = 30;

  Future<void> _add([MemberDirectoryEntry? entry]) async {
    final client = ref.read(supabaseClientProvider);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NewMemberDialog(
        initialEntry: entry,
        onSave: client == null
            ? null
            : (name, birth, group, role, start) async {
                if (entry != null) {
                  await SupabaseMembersRepository(client).edit(
                    memberId: entry.member.id,
                    fullName: name,
                    birthDate: birth,
                    groupId: group,
                    role: role,
                    effectiveDate: start,
                  );
                  return;
                }
                await SupabaseMembersRepository(client).create(
                  fullName: name,
                  birthDate: birth,
                  groupId: group,
                  role: role,
                  startDate: start,
                );
              },
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(memberDirectoryProvider);
      ref.invalidate(attendanceRosterProvider);
      ref.invalidate(attendanceSheetProvider);
      ref.invalidate(attendanceSummaryProvider);
      ref.invalidate(dashboardInsightsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            entry == null
                ? 'Integrante registrado correctamente.'
                : 'Datos actualizados correctamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        title: 'Integrantes',
        subtitle: 'Cada nombre es parte de nuestra historia.',
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() {
                _search = value.trim().toLowerCase();
                _page = 0;
              }),
            ),
          ),
          SizedBox(
            width: 220,
            child: StyledSelect<GroupId?>(
              value: _group,
              label: 'Filtrar por grupo',
              icon: Icons.groups_outlined,
              items: [
                const DropdownMenuItem<GroupId?>(
                  value: null,
                  child: Text('Todos los grupos'),
                ),
                ...GroupId.values.map(
                  (group) => DropdownMenuItem(
                    value: group,
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: AppTheme.groupColors[group.name],
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(group.groupName)),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() {
                _group = value;
                _page = 0;
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      AsyncPanel<List<MemberDirectoryEntry>>(
        value: ref.watch(memberDirectoryProvider),
        onRetry: () => ref.invalidate(memberDirectoryProvider),
        builder: (entries) {
          final today = CivilDate.today();
          final filtered = entries
              .where(
                (entry) =>
                    entry.member.active &&
                    entry.member.fullName.toLowerCase().contains(_search) &&
                    (_group == null || entry.membership?.groupId == _group),
              )
              .toList();
          final birthdays =
              entries
                  .where(
                    (entry) =>
                        entry.member.active &&
                        today.daysUntil(
                              entry.member.nextBirthdayOnOrAfter(today),
                            ) <=
                            30,
                  )
                  .toList()
                ..sort(
                  (a, b) => a.member
                      .nextBirthdayOnOrAfter(today)
                      .compareTo(b.member.nextBirthdayOnOrAfter(today)),
                );
          final pageCount = (filtered.length / _pageSize).ceil().clamp(
            1,
            1000000,
          );
          final page = _page.clamp(0, pageCount - 1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: entries.isEmpty
                            ? 'Nuestro directorio empieza aquí'
                            : 'Sin coincidencias',
                        message: entries.isEmpty
                            ? 'Los jóvenes registrados aparecerán en esta lista.'
                            : 'Prueba con otro nombre o grupo.',
                      )
                    : Column(
                        children: filtered
                            .skip(page * _pageSize)
                            .take(_pageSize)
                            .map((entry) {
                              return MemberDirectoryRow(
                                entry: entry,
                                today: today,
                                onEdit: () => _add(entry),
                              );
                            })
                            .toList(),
                      ),
              ),
              if (pageCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      IconButton(
                        tooltip: 'Integrantes anteriores',
                        onPressed: page == 0
                            ? null
                            : () => setState(() => _page = page - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '${filtered.length} integrantes · Página ${page + 1} de $pageCount',
                      ),
                      IconButton(
                        tooltip: 'Integrantes siguientes',
                        onPressed: page + 1 == pageCount
                            ? null
                            : () => setState(() => _page = page + 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Nuevo integrante'),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Próximos cumpleaños',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Celebremos juntos los próximos 30 días.',
                        style: TextStyle(color: Color(0xFF74798C)),
                      ),
                      if (birthdays.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text(
                            'No hay cumpleaños próximos registrados.',
                          ),
                        ),
                      ...birthdays.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.cake_outlined,
                            color: AppTheme.purple,
                          ),
                          title: Text(entry.member.fullName),
                          subtitle: Text(
                            DateFormat('d MMMM', 'es_PE').format(
                              entry.member
                                  .nextBirthdayOnOrAfter(today)
                                  .toDateTime(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}
