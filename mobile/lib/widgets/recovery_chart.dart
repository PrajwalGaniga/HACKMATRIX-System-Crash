import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// RecoveryChart — shows "Recovery Score" trend using fl_chart LineChart.
class RecoveryChart extends StatelessWidget {
  final List<double> scores;
  const RecoveryChart({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📈', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('Recovery Score Trend', style: TextStyle(fontSize: 11, color: Colors.grey[500], letterSpacing: 0.8, fontFamily: 'monospace')),
          const Spacer(),
          Text('${scores.isNotEmpty ? scores.last.toInt() : 0}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF68D391))),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.04), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles:  AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.white38)),
                )),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Text('D${v.toInt()+1}', style: const TextStyle(fontSize: 9, color: Colors.white38)),
                  interval: 1,
                )),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: 50, maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: scores.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                  isCurved: true,
                  curveSmoothness: 0.4,
                  color: const Color(0xFF68D391),
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [const Color(0xFF68D391).withOpacity(0.25), Colors.transparent],
                    ),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3, color: const Color(0xFF68D391), strokeWidth: 1.5, strokeColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
