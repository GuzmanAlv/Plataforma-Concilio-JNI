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

class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});
  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  String _search = '';
  GroupId? _group;

  Future<void> _add() async {
    final client = ref.read(supabaseClientProvider);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NewMemberDialog(
        onSave: client == null
            ? null
            : (name, birth, group, role, start) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Integrante registrado correctamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(
        title: 'Integrantes',
        subtitle: 'Cada nombre es parte de nuestra historia.',
        trailing:
            ref.watch(supabaseClientProvider) == null ||
                [
                  'admin',
                  'secretaria',
                ].contains(ref.watch(profileProvider).asData?.value?['rol'])
            ? FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Nuevo integrante'),
              )
            : null,
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
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<GroupId?>(
              isExpanded: true,
              initialValue: null,
              decoration: const InputDecoration(labelText: 'Grupo'),
              items: [
                const DropdownMenuItem<GroupId?>(
                  value: null,
                  child: Text('Todos los grupos'),
                ),
                ...GroupId.values.map(
                  (group) => DropdownMenuItem(
                    value: group,
                    child: Text(group.groupName),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _group = value),
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
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
                        children: filtered.map((entry) {
                          final group = entry.membership?.groupId;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: group == null
                                  ? const Color(0xFFF0EEFC)
                                  : AppTheme.groupColors[group.name]!
                                        .withValues(alpha: 0.12),
                              child: Text(
                                entry.member.fullName
                                    .substring(0, 1)
                                    .toUpperCase(),
                              ),
                            ),
                            title: Text(entry.member.fullName),
                            subtitle: Text(
                              '${entry.member.ageOn(today)} años · ${entry.membership?.role.label ?? 'Sin asignación'}',
                            ),
                            trailing: group == null
                                ? null
                                : Text(
                                    group.label,
                                    style: TextStyle(
                                      color: AppTheme.groupColors[group.name],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          );
                        }).toList(),
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
