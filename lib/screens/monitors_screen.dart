import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../services/real_time_service.dart';
import '../widgets/flood_gauge.dart';
import '../widgets/river_level_visualizer.dart';

class MonitorsScreen extends StatefulWidget {
  const MonitorsScreen({super.key});

  @override
  State<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends State<MonitorsScreen> {
  final RealTimeService _service = RealTimeService();

  @override
  void initState() {
    super.initState();
    _service.startPolling();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF051017),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C2C3E), Color(0xFF051017), Color(0xFF01070B)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _service,
            builder: (context, _) {
              final levels = List<FloodData>.from(_service.liveLevels)
                ..sort(
                    (a, b) => b.capacityPercent.compareTo(a.capacityPercent));

              return RefreshIndicator(
                onRefresh: _service.refreshData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    const Text(
                      'River Monitors',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _service.lastFetchTime == null
                          ? 'Waiting for first live update'
                          : 'Live at ${DateFormat('HH:mm:ss').format(_service.lastFetchTime!.toLocal())}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    if (levels.isEmpty)
                      const SizedBox(
                        height: 260,
                        child: Center(
                          child:
                              CircularProgressIndicator(color: Colors.white70),
                        ),
                      )
                    else
                      ...levels.map((item) {
                        final history = _service.trendForCity(item.city);
                        final monitoring =
                            RiverMonitoring.fromFloodData(item, history);
                        final isDanger = monitoring.isDangerZone;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDanger
                                  ? const Color(0xFFEF4444).withOpacity(0.65)
                                  : Colors.white.withOpacity(0.16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: RiverLevelVisualizer(
                                      city: item.city,
                                      river: item.riverName ?? 'River',
                                      currentLevel: item.currentLevel,
                                      safeLevel: item.safeLevel,
                                      warningLevel: item.warningLevel,
                                      dangerLevel: item.dangerLevel,
                                      trend: item.status,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 110,
                                    child: FloodGauge(
                                      capacity: item.capacityPercent,
                                      riskLevel: item.riskLevel,
                                      size: 110,
                                      label: item.state,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ChipLabel(
                                    icon: Icons.warning_amber,
                                    text:
                                        'Danger: ${item.dangerLevel.toStringAsFixed(1)} m',
                                  ),
                                  _ChipLabel(
                                    icon: Icons.timeline,
                                    text:
                                        'Warning: ${item.warningLevel.toStringAsFixed(1)} m',
                                  ),
                                  if (item.expectedPeakLevel != null)
                                    _ChipLabel(
                                      icon: Icons.show_chart,
                                      text:
                                          'Expected peak ${item.expectedPeakLevel!.toStringAsFixed(1)} m',
                                    ),
                                  if (item.expectedPeakTime != null)
                                    _ChipLabel(
                                      icon: Icons.schedule,
                                      text: DateFormat('dd MMM HH:mm').format(
                                          item.expectedPeakTime!.toLocal()),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 64,
                                child: _Sparkline(
                                  history: history,
                                  dangerLevel: item.dangerLevel,
                                  warningLevel: item.warningLevel,
                                ),
                              ),
                              if (isDanger)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.notification_important,
                                          color: Color(0xFFEF4444), size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Critical threshold breached',
                                        style: TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ChipLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.11),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<RiverLevelSnapshot> history;
  final double warningLevel;
  final double dangerLevel;

  const _Sparkline({
    required this.history,
    required this.warningLevel,
    required this.dangerLevel,
  });

  @override
  Widget build(BuildContext context) {
    final points = List<RiverLevelSnapshot>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (points.length < 2) {
      return const Center(
        child: Text(
          'Sparkline will appear after more live points',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      );
    }

    final clipped =
        points.length > 24 ? points.sublist(points.length - 24) : points;
    final spots = <FlSpot>[];
    for (var i = 0; i < clipped.length; i++) {
      spots.add(FlSpot(i.toDouble(), clipped[i].level));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 2,
            color: const Color(0xFF24C9E8),
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF24C9E8).withOpacity(0.2),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: warningLevel,
            color: const Color(0xFFF59E0B),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
          HorizontalLine(
            y: dangerLevel,
            color: const Color(0xFFEF4444),
            strokeWidth: 1.1,
            dashArray: [5, 4],
          ),
        ]),
      ),
    );
  }
}
