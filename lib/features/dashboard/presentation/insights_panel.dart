import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/attendance_insights.dart';
import 'constancy_ranking.dart';

class InsightsPanel extends StatelessWidget {
  const InsightsPanel({required this.insights, super.key});
  final AttendanceInsights insights;
  Widget _ranking(
    BuildContext context,
    String title,
    List<MemberParticipation> people,
    String empty,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (people.isEmpty)
            EmptyState(
              icon: Icons.people_outline,
              title: 'Aún sin resultados',
              message: empty,
            ),
          ...people
              .take(5)
              .map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.member.fullName),
                  subtitle: Text(
                    '${p.attended}/${p.invited} convocatorias · ${(100 * p.rate).toStringAsFixed(0)}%\n'
                    '${p.recentAbsences} ausencias consecutivas · Última presencia: ${p.lastPresence == null ? 'Sin presencias registradas' : DateFormat('d MMM yyyy', 'es_PE').format(p.lastPresence!.toDateTime())}',
                  ),
                  isThreeLine: true,
                ),
              ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 950
              ? 4
              : c.maxWidth >= 600
              ? 2
              : 1;
          final width = (c.maxWidth - 16 * (columns - 1)) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children:
                [
                      (
                        label: 'Integrantes activos',
                        value: '${insights.people.length}',
                        icon: Icons.groups_outlined,
                      ),
                      (
                        label: 'Participación registrada',
                        value: insights.invited == 0
                            ? 'Sin datos'
                            : '${(100 * insights.rate).toStringAsFixed(1)}%',
                        icon: Icons.insights_outlined,
                      ),
                      (
                        label: 'Requieren seguimiento',
                        value: '${insights.followUp.length}',
                        icon: Icons.favorite_outline,
                      ),
                      (
                        label: 'Sábados completos',
                        value: '${insights.completeSaturdays}',
                        icon: Icons.event_available_outlined,
                      ),
                    ]
                    .map(
                      (m) => SizedBox(
                        width: width,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  m.icon,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  m.value,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                Text(m.label),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          );
        },
      ),
      const SizedBox(height: 12),
      Text(
        '${insights.present} presencias · ${insights.coveredPeople} integrantes con convocatorias · '
        '${insights.people.length - insights.coveredPeople} sin tomas registradas en el rango.',
        style: const TextStyle(color: Color(0xFF74798C)),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insights.mostActiveGroup == null
                    ? 'Grupo más activo: pendiente de datos'
                    : 'Mayor actividad: ${insights.mostActiveGroup!.group.groupName} · ${(insights.mostActiveGroup!.rate * 100).toStringAsFixed(1)}% · ${insights.mostActiveGroup!.count} sesiones',
              ),
              const SizedBox(height: 8),
              Text(
                insights.lastCompleteChange == null
                    ? 'Tendencia: requiere dos sábados completos con convocados'
                    : 'Últimos dos sábados completos: ${insights.lastCompleteChange! >= 0 ? '+' : ''}${insights.lastCompleteChange!.toStringAsFixed(1)} puntos de participación',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 1100
              ? 3
              : c.maxWidth >= 700
              ? 2
              : 1;
          final width = (c.maxWidth - 16 * (columns - 1)) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: width,
                child: ConstancyRanking(people: insights.mostRegular),
              ),
              SizedBox(
                width: width,
                child: _ranking(
                  context,
                  'Seguimiento prioritario',
                  insights.followUp,
                  'Se necesitan al menos tres convocatorias por persona para identificar un seguimiento.',
                ),
              ),
              SizedBox(
                width: width,
                child: _ranking(
                  context,
                  'Menor participación',
                  insights.leastRegular,
                  'La comparación empieza con tres convocatorias registradas.',
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
    ],
  );
}
