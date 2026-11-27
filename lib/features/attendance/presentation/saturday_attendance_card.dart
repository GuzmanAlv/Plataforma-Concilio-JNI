import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/civil_date.dart';
import '../../groups/domain/group.dart';
import '../domain/attendance_point.dart';

class SaturdayAttendanceCard extends StatefulWidget {
  const SaturdayAttendanceCard({
    required this.date,
    required this.points,
    required this.onOpen,
    this.initiallyExpanded = false,
    super.key,
  });
  final CivilDate date;
  final List<AttendancePoint> points;
  final ValueChanged<GroupId> onOpen;
  final bool initiallyExpanded;
  @override
  State<SaturdayAttendanceCard> createState() => _SaturdayAttendanceCardState();
}

class _SaturdayAttendanceCardState extends State<SaturdayAttendanceCard> {
  late bool _expanded;
  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final complete = points.length == 4;
    final present = points.fold<int>(0, (n, p) => n + p.present);
    final status = complete
        ? 'Registro completo'
        : points.isNotEmpty
        ? 'Registro parcial'
        : widget.date > CivilDate.today()
        ? 'Programado'
        : 'Pendiente';
    final statusColor = complete
        ? const Color(0xFF218259)
        : points.isNotEmpty
        ? const Color(0xFF926500)
        : const Color(0xFF79718D);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: _expanded ? const Color(0xFFD4CBF4) : const Color(0xFFE8EAF2),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: Container(
          width: 52,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF0EDFB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.date.day}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6354D9),
                    ),
                  ),
                  Text(
                    DateFormat(
                      'MMM',
                      'es_PE',
                    ).format(widget.date.toDateTime()).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF79718D),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        title: Text(
          'Sábado ${widget.date.day} de ${DateFormat('MMMM', 'es_PE').format(widget.date.toDateTime())}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _tag(status, statusColor),
              _tag('${points.length}/4 grupos', const Color(0xFF6354D9)),
              if (points.isNotEmpty)
                _tag('$present presentes', const Color(0xFF218259)),
            ],
          ),
        ),
        children: [
          Semantics(
            label: 'Grupos registrados',
            value: '${points.length} de 4',
            child: LinearProgressIndicator(
              value: points.length / 4,
              minHeight: 4,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: const Color(0xFFF0EDFB),
              color: const Color(0xFF6354D9),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth >= 700
                  ? (c.maxWidth - 16) / 2
                  : c.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: GroupId.values.map((group) {
                  final point = points
                      .where((p) => p.groupId == group)
                      .firstOrNull;
                  final color = AppTheme.groupColors[group.name]!;
                  final ink = group == GroupId.amarillo
                      ? const Color(0xFF846100)
                      : Color.lerp(color, Colors.black, 0.25)!;
                  return SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  group.groupName,
                                  style: TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Icon(
                                point == null
                                    ? Icons.schedule_outlined
                                    : Icons.check_circle_outline,
                                color: point == null
                                    ? const Color(0xFF9994A7)
                                    : ink,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (point == null)
                            const Text(
                              'Aún sin marcas guardadas',
                              style: TextStyle(color: Color(0xFF79718D)),
                            )
                          else
                            Wrap(
                              spacing: 18,
                              runSpacing: 8,
                              children:
                                  [
                                        (
                                          value: point.present,
                                          label: 'Presentes',
                                        ),
                                        (
                                          value: point.invited - point.present,
                                          label: 'Ausentes',
                                        ),
                                        (
                                          value: point.invited,
                                          label: 'Convocados',
                                        ),
                                      ]
                                      .map(
                                        (metric) => Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${metric.value}',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                color: ink,
                                              ),
                                            ),
                                            Text(
                                              metric.label,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF79718D),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                            ),
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: () => widget.onOpen(group),
                            icon: Icon(
                              point == null
                                  ? Icons.fact_check_outlined
                                  : Icons.edit_outlined,
                              size: 18,
                            ),
                            label: Text(
                              point == null
                                  ? 'Tomar asistencia'
                                  : 'Corregir asistencia',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
