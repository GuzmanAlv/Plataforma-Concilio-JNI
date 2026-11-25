import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/domain/civil_date.dart';

class TimelineChart extends StatelessWidget {
  const TimelineChart({
    required this.start,
    required this.end,
    required this.lines,
    super.key,
  });
  final CivilDate start;
  final CivilDate end;
  final List<({Color color, List<({CivilDate date, double value})> points})>
  lines;

  @override
  Widget build(BuildContext context) {
    final span = start.daysUntil(end).clamp(1, 366).toDouble();
    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, right: 12),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: span,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 48),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: (span / 3).ceilToDouble(),
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      DateFormat(
                        'd MMM',
                        'es_PE',
                      ).format(start.addDays(value.round()).toDateTime()),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
            ),
            lineBarsData: lines
                .map(
                  (line) => LineChartBarData(
                    spots: line.points
                        .map(
                          (point) => FlSpot(
                            start.daysUntil(point.date).toDouble(),
                            point.value,
                          ),
                        )
                        .toList(),
                    color: line.color,
                    barWidth: 3,
                    dotData: FlDotData(show: line.points.length < 15),
                    belowBarData: BarAreaData(
                      show: true,
                      color: line.color.withValues(alpha: 0.05),
                    ),
                  ),
                )
                .toList(),
          ),
          duration: Duration.zero,
        ),
      ),
    );
  }
}
