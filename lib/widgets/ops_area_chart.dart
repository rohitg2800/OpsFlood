// lib/widgets/ops_area_chart.dart
// OpsFlood — OpsAreaChart widget v1
// Replaces gauge / sparklines with a clean fl_chart AreaChart.
// Shows up to 24 data points (hourly or 5-min intervals).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class OpsAreaChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color        lineColor;
  final double?      warningY;
  final double?      dangerY;
  final String       yUnit;
  final double       minY;
  final double?      maxY;
  final double       height;

  const OpsAreaChart({
    super.key,
    required this.values,
    this.labels    = const [],
    this.lineColor = AppPalette.cyan,
    this.warningY,
    this.dangerY,
    this.yUnit     = '',
    this.minY      = 0,
    this.maxY,
    this.height    = 140,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No data',
              style: TextStyle(color: AppPalette.textGrey, fontSize: 12)),
        ),
      );
    }

    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final computedMax = maxY ??
        (values.reduce((a, b) => a > b ? a : b) * 1.15).clamp(minY + 1, double.infinity);
    final dangerLine  = dangerY;
    final warnLine    = warningY;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: minY,
          maxY: computedMax,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (computedMax - minY) / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: AppPalette.abyssStroke.withValues(alpha: 0.8),
              strokeWidth: 0.5,
              dashArray: [4, 6],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: (computedMax - minY) / 3,
                getTitlesWidget: (v, _) => Text(
                  '${v.toStringAsFixed(v < 10 ? 1 : 0)}$yUnit',
                  style: const TextStyle(
                    fontSize: 9, color: AppPalette.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: labels.isNotEmpty,
                reservedSize: 22,
                interval: (values.length / 5).clamp(1, double.infinity),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= labels.length) return const SizedBox.shrink();
                  return Text(
                    labels[i],
                    style: const TextStyle(
                      fontSize: 8, color: AppPalette.textGrey,
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (warnLine != null)
                HorizontalLine(
                  y: warnLine,
                  color: AppPalette.amber.withValues(alpha: 0.6),
                  strokeWidth: 1.2,
                  dashArray: [5, 5],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(
                      fontSize: 8, color: AppPalette.amber,
                      fontWeight: FontWeight.w700,
                    ),
                    labelResolver: (_) => 'WARN',
                  ),
                ),
              if (dangerLine != null)
                HorizontalLine(
                  y: dangerLine,
                  color: AppPalette.critical.withValues(alpha: 0.6),
                  strokeWidth: 1.2,
                  dashArray: [5, 5],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(
                      fontSize: 8, color: AppPalette.critical,
                      fontWeight: FontWeight.w700,
                    ),
                    labelResolver: (_) => 'DANGER',
                  ),
                ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: lineColor,
              barWidth: 2.2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: values.length <= 10,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: lineColor,
                  strokeColor: AppPalette.abyss0,
                  strokeWidth: 1.5,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withValues(alpha: 0.22),
                    lineColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppPalette.abyss3,
              // tooltipRoundedRadius removed — not in fl_chart 1.2.0
              getTooltipItems: (touchedSpots) => touchedSpots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(2)}$yUnit',
                        TextStyle(
                          color: lineColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ),
    );
  }
}
