import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../services/cwc_live_provider.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import '../widgets/flood_gauge.dart';
import '../widgets/river_level_visualizer.dart';

class MonitorsScreen extends StatefulWidget {
  const MonitorsScreen({super.key});

  @override
  State<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends State<MonitorsScreen> {
  final RealTimeService _svc = RealTimeService();
  int _lastHash = 0;

  @override
  void initState() {
    super.initState();
    // FIX 1: Do NOT call startPolling() — HomeScreen owns polling.
    _svc.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _svc.removeListener(_onUpdate);
    super.dispose();
  }

  // FIX 4: Only rebuild when data actually changes.
  void _onUpdate() {
    final h = _svc.liveLevels.length ^
        (_svc.lastFetchTime?.millisecondsSinceEpoch ?? 0);
    if (h != _lastHash) {
      _lastHash = h;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    final cs = Theme.of(context).colorScheme;

    final levels = List<FloodData>.from(_svc.liveLevels)
      ..sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _svc.refreshData,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('River Monitors',
                          style: TextStyle(
                            color: rc.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        _svc.lastFetchTime == null
                            ? 'Waiting for first live update'
                            : 'Live at ${DateFormat('HH:mm:ss').format(_svc.lastFetchTime!.toLocal())}',
                        style: TextStyle(
                            color: rc.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (levels.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                // FIX 3: SliverList = lazy, no shrinkWrap needed.
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final item = levels[i];
                        final history = _svc.trendForCity(item.city);
                        final isDanger = item.capacityPercent >=
                            85.0;

                        Color borderColor;
                        switch (item.riskLevel) {
                          case 'CRITICAL':
                            borderColor = rc.riverCritical;
                            break;
                          case 'HIGH':
                            borderColor = rc.riverDanger;
                            break;
                          case 'MODERATE':
                            borderColor = rc.riverWarning;
                            break;
                          default:
                            borderColor = rc.riverNormal;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: rc.cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDanger
                                  ? rc.riverDanger.withOpacity(0.65)
                                  : borderColor.withOpacity(0.28),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: RiverLevelVisualizer(
                                      city: item.city,
                                      river:
                                          item.riverName ?? 'River',
                                      currentLevel: item.currentLevel,
                                      safeLevel: item.safeLevel,
                                      warningLevel: item.warningLevel,
                                      dangerLevel: item.dangerLevel,
                                      trend: item.status,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 100,
                                    child: FloodGauge(
                                      capacity: item.capacityPercent,
                                      riskLevel: item.riskLevel,
                                      size: 100,
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
                                    color: rc.riverDanger,
                                  ),
                                  _ChipLabel(
                                    icon: Icons.timeline,
                                    text:
                                        'Warning: ${item.warningLevel.toStringAsFixed(1)} m',
                                    color: rc.riverWarning,
                                  ),
                                  if (item.expectedPeakLevel != null)
                                    _ChipLabel(
                                      icon: Icons.show_chart,
                                      text:
                                          'Peak ${item.expectedPeakLevel!.toStringAsFixed(1)} m',
                                      color: rc.riverNormal,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 60,
                                child: _Sparkline(
                                  history: history,
                                  dangerLevel: item.dangerLevel,
                                  warningLevel: item.warningLevel,
                                  lineColor: rc.sparklineColor,
                                ),
                              ),
                              if (isDanger)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                          Icons.notification_important,
                                          color: rc.riverDanger,
                                          size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Critical threshold breached',
                                        style: TextStyle(
                                          color: rc.riverDanger,
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
                      },
                      childCount: levels.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _ChipLabel(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: rc.chipBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(text,
              style:
                  TextStyle(color: rc.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<RiverLevelSnapshot> history;
  final double warningLevel;
  final double dangerLevel;
  final Color lineColor;
  const _Sparkline({
    required this.history,
    required this.warningLevel,
    required this.dangerLevel,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final pts = List<RiverLevelSnapshot>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (pts.length < 2) {
      return Center(
        child: Text('Sparkline appears after more live points',
            style: TextStyle(
                color: RiverColors.of(context).textSecondary,
                fontSize: 11)),
      );
    }
    final clipped =
        pts.length > 24 ? pts.sublist(pts.length - 24) : pts;
    final spots = List.generate(
        clipped.length,
        (i) => FlSpot(i.toDouble(), clipped[i].level));
    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(
            show: true,
            border: Border.all(color: lineColor.withOpacity(0.12))),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 2,
            color: lineColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true, color: lineColor.withOpacity(0.18)),
          ),
        ],
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
              y: warningLevel,
              color: const Color(0xFFF59E0B),
              strokeWidth: 1,
              dashArray: [4, 4]),
          HorizontalLine(
              y: dangerLevel,
              color: const Color(0xFFEF4444),
              strokeWidth: 1.1,
              dashArray: [5, 4]),
        ]),
      ),
    );
  }
}
