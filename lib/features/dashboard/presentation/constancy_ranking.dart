import 'package:flutter/material.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/attendance_insights.dart';

class ConstancyRanking extends StatelessWidget {
  const ConstancyRanking({required this.people, super.key});
  final List<MemberParticipation> people;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: AppTheme.purple,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mayor constancia',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (people.isEmpty)
            const EmptyState(
              icon: Icons.people_outline,
              title: 'Aún sin resultados',
              message: 'Las presencias aparecerán al guardar asistencias.',
            ),
          for (final (index, person) in people.take(5).indexed) ...[
            if (index > 0) const Divider(height: 1, color: Color(0xFFF0EDF7)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? const Color(0xFFFFF3CF)
                          : const Color(0xFFF2EFFC),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: index == 0
                            ? const Color(0xFF8A6500)
                            : AppTheme.purple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: person.member.fullName,
                          child: Text(
                            person.member.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 7,
                              color: person.membership == null
                                  ? const Color(0xFF79718D)
                                  : AppTheme.groupColors[person
                                        .membership!
                                        .groupId
                                        .name],
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                person.membership?.groupId.groupName ??
                                    'Sin grupo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF79718D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(100 * person.rate).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppTheme.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
