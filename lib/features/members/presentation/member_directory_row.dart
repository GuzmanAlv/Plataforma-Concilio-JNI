import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/civil_date.dart';
import '../data/supabase_members_repository.dart';

class MemberDirectoryRow extends StatelessWidget {
  const MemberDirectoryRow({
    required this.entry,
    required this.today,
    required this.onEdit,
    super.key,
  });
  final MemberDirectoryEntry entry;
  final CivilDate today;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final group = entry.membership?.groupId;
    final color = group == null
        ? const Color(0xFF79718D)
        : AppTheme.groupColors[group.name]!;
    final ink = group?.name == 'amarillo' ? const Color(0xFF846100) : color;
    final birth = DateFormat(
      'dd/MM/yyyy',
    ).format(entry.member.birthDate.toDateTime());
    final name = Tooltip(
      message: entry.member.fullName,
      child: Text(
        entry.member.fullName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
    final birthday = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          birth,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Text(
          '${entry.member.ageOn(today)} años',
          style: const TextStyle(fontSize: 11, color: Color(0xFF79718D)),
        ),
      ],
    );
    final assignment = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          group?.label ?? 'Sin grupo',
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          entry.membership?.role.label ?? 'Sin asignación',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 11, color: Color(0xFF79718D)),
        ),
      ],
    );
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 620;
            final edit = IconButton(
              tooltip: 'Editar integrante',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppTheme.purple,
              ),
            );
            if (wide) {
              return Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: color.withValues(alpha: .12),
                          child: Text(
                            entry.member.fullName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: name),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Center(
                      child: Tooltip(
                        message: 'Fecha de nacimiento',
                        child: birthday,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(child: assignment),
                        const SizedBox(width: 8),
                        edit,
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: name),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: Tooltip(
                      message: 'Fecha de nacimiento',
                      child: birthday,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: assignment),
                      const SizedBox(width: 4),
                      edit,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
