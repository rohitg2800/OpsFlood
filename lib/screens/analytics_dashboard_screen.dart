// lib/screens/analytics_dashboard_screen.dart
// OpsFlood — Module 14: Analytics Dashboard
//
// Full-screen analytics view with:
//  • 7-day station water-level sparklines (fl_chart)
//  • District-wise alert frequency bar chart
//  • Risk score trend line chart
//  • Summary stat cards (total alerts, stations above danger, avg level)
//  • Date-range picker to zoom history
//  • Export to CSV (excel_export_service)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Mock data models (replace with real providers)
// ---------------------------------------------------------------------------

class _DailyPoint {
  final DateTime date;
  final double value;
  const _DailyPoint(this.date, this.value);
}

class _DistrictAlerts {
  final String district;
  final int count;
  const _DistrictAlerts(this.district, this.count);
}

// ---------------------------------------------------------------------------
// Providers (wire to real data in production)
// ---------------------------------------------------------------------------

final _dateRangeProvider =
    StateProvider<DateTimeRange>((_) => DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 6)),
          end: DateTime.now(),
        ));

final _waterLevelDataProvider =
    Provider.family<List<_DailyPoint>, String>((_, stationId) {
  // Sample 7-day data — replace with Firestore/CWC query
  final now = DateTime.now();
  final rand = [8.2, 8.9, 9.4, 10.1, 9.8, 10.6, 11.2];
  return List.generate(
      7, (i) => _DailyPoint(now.subtract(Duration(days: 6 - i)), rand[i]));
});

final _districtAlertsProvider = Provider<List<_DistrictAlerts>>(
  (_) => const [
    _DistrictAlerts('Darbhanga', 14),
    _DistrictAlerts('Muzaffarpur', 11),
    _DistrictAlerts('Sitamarhi', 9),
    _DistrictAlerts('Supaul', 8),
    _DistrictAlerts('Patna', 6),
    _DistrictAlerts('Bhagalpur', 5),
  ],
);

// ---------------------------------------------------------------------------
// AnalyticsDashboardScreen
// ---------------------------------------------------------------------------

class AnalyticsDashboardScreen extends ConsumerWidget {
  static const String route = '/analytics';
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Select date range',
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialDateRange: ref.read(_dateRangeProvider),
              );
              if (range != null) {
                ref.read(_dateRangeProvider.notifier).state = range;
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting analytics CSV…')),
              );
              // TODO: ExcelExportService.exportAnalytics(ref.read(...))
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SummaryRow(),
          SizedBox(height: 16),
          _SectionHeader('Water Level Trend (7 days)'),
          _WaterLevelChart(),
          SizedBox(height: 16),
          _SectionHeader('Alerts by District'),
          _DistrictBarChart(),
          SizedBox(height: 16),
          _SectionHeader('Risk Score Trend'),
          _RiskScoreChart(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  const _SummaryRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Total Alerts', value: '53',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFEF4444)),
        const SizedBox(width: 10),
        _StatCard(label: 'Above Danger', value: '8',
            icon: Icons.water_damage_outlined,
            color: const Color(0xFFFF6B35)),
        const SizedBox(width: 10),
        _StatCard(label: 'Avg Level (m)', value: '9.8',
            icon: Icons.show_chart,
            color: const Color(0xFF0D47A1)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 6, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF0D47A1))),
      );
}

// ---------------------------------------------------------------------------
// Water level line chart
// ---------------------------------------------------------------------------

class _WaterLevelChart extends ConsumerWidget {
  const _WaterLevelChart();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_waterLevelDataProvider('PATNA-CWC'));
    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    return _ChartCard(
      child: LineChart(
        LineChartData(
          minY: 6,
          maxY: 13,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx >= 0 && idx < data.length) {
                    return Text(
                      DateFormat('d/M').format(data[idx].date),
                      style: const TextStyle(fontSize: 9),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawHorizontalLine: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF0D47A1),
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF0D47A1).withOpacity(0.12),
              ),
            ),
            // Danger line
            LineChartBarData(
              spots: List.generate(
                  7, (i) => FlSpot(i.toDouble(), 10.5)),
              color: const Color(0xFFEF4444),
              barWidth: 1.5,
              dashArray: [4, 4],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// District bar chart
// ---------------------------------------------------------------------------

class _DistrictBarChart extends ConsumerWidget {
  const _DistrictBarChart();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_districtAlertsProvider);
    return _ChartCard(
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx >= 0 && idx < data.length) {
                    return Transform.rotate(
                      angle: -0.5,
                      child: Text(
                        data[idx].district.substring(0, 4),
                        style: const TextStyle(fontSize: 9),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(fontSize: 10))),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawHorizontalLine: true,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          barGroups: data.asMap().entries.map((e) {
            final hue = 220.0 - e.key * 15;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.count.toDouble(),
                  color: HSLColor.fromAHSL(
                          1, hue, 0.7, 0.45)
                      .toColor(),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Risk score trend
// ---------------------------------------------------------------------------

class _RiskScoreChart extends StatelessWidget {
  const _RiskScoreChart();
  static const _scores = [0.38, 0.45, 0.52, 0.68, 0.61, 0.74, 0.81];
  @override
  Widget build(BuildContext context) {
    final spots = _scores
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    return _ChartCard(
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 1,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  '${(v * 100).toInt()}%',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawHorizontalLine: true,
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(colors: [
                Color(0xFF4CAF50),
                Color(0xFFFF9800),
                Color(0xFFFF1744),
              ]),
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4CAF50).withOpacity(0.2),
                    const Color(0xFFFF1744).withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared chart card container
// ---------------------------------------------------------------------------

class _ChartCard extends StatelessWidget {
  final Widget child;
  const _ChartCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}
