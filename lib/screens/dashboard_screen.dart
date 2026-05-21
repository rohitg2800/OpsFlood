import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../services/real_time_service.dart';
import '../widgets/animated_alert_badge.dart';
import '../widgets/flood_gauge.dart';
import '../widgets/premium_stat_card.dart';
import '../widgets/risk_heatmap.dart';
import '../widgets/river_level_visualizer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final RealTimeService _service = RealTimeService();
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _service.startPolling();
    if (_selectedCity == null && _service.liveLevels.isNotEmpty) {
      _selectedCity = _service.liveLevels.first.city;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05141E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF08344B),
              Color(0xFF05141E),
              Color(0xFF02080E),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _service,
            builder: (context, _) {
              final levels = List<FloodData>.from(_service.liveLevels)
                ..sort(
                    (a, b) => b.capacityPercent.compareTo(a.capacityPercent));

              if (levels.isNotEmpty &&
                  (_selectedCity == null ||
                      levels.every((entry) => entry.city != _selectedCity))) {
                _selectedCity = levels.first.city;
              }

              final primary = levels.isNotEmpty ? levels.first : null;
              final selected = levels.firstWhere(
                (entry) => entry.city == _selectedCity,
                orElse: () =>
                    primary ??
                    FloodData.fromMonitoredCity(
                        AppConstants.monitoredCities.first),
              );

              final monitoringData = _service.monitoringData;

              return RefreshIndicator(
                onRefresh: _service.refreshData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.water_drop, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          'OpsFlood Command',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _service.refreshData,
                          icon:
                              const Icon(Icons.refresh, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _service.lastFetchTime == null
                          ? 'Awaiting first live poll'
                          : 'Updated ${DateFormat('dd MMM, HH:mm:ss').format(_service.lastFetchTime!.toLocal())}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    if (_service.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.orange.withOpacity(0.17),
                          border: Border.all(
                              color: Colors.orangeAccent.withOpacity(0.5)),
                        ),
                        child: Text(
                          _service.error!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    AnimatedAlertBadge(
                      count: _service.activeCriticalAlerts.length,
                      isCritical: _service.activeCriticalAlerts.isNotEmpty,
                      label: _service.activeCriticalAlerts.isNotEmpty
                          ? 'Critical Alerts'
                          : 'Live Alerts',
                    ),
                    const SizedBox(height: 16),
                    if (primary != null)
                      Center(
                        child: FloodGauge(
                          capacity: primary.capacityPercent,
                          riskLevel: primary.riskLevel,
                          label:
                              '${primary.city} | ${primary.riverName ?? 'River'}',
                          size: 240,
                        ),
                      )
                    else
                      const SizedBox(
                        height: 240,
                        child: Center(
                          child:
                              CircularProgressIndicator(color: Colors.white70),
                        ),
                      ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 122,
                      child: Row(
                        children: [
                          Expanded(
                            child: PremiumStatCard(
                              icon: Icons.warning_amber,
                              title: 'Critical',
                              value: '${monitoringData.criticalCount}',
                              subtitle: 'threshold breaches',
                              accent: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PremiumStatCard(
                              icon: Icons.ssid_chart,
                              title: 'High Risk',
                              value: '${monitoringData.highRiskCount}',
                              subtitle: 'active locations',
                              accent: const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PremiumStatCard(
                              icon: _service.isOnline
                                  ? Icons.wifi
                                  : Icons.wifi_off,
                              title: _service.isOnline ? 'Online' : 'Offline',
                              value: _service.queuedOfflineCycles > 0
                                  ? '${_service.queuedOfflineCycles}'
                                  : 'Live',
                              subtitle: _service.isUsingCache
                                  ? 'cache mode'
                                  : 'real-time feed',
                              accent: _service.isOnline
                                  ? const Color(0xFF34C759)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'River Monitoring',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      itemCount: levels.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        mainAxisSpacing: 10,
                        childAspectRatio: 3.0,
                      ),
                      itemBuilder: (context, index) {
                        final item = levels[index];
                        return RiverLevelVisualizer(
                          city: item.city,
                          river: item.riverName ?? 'River',
                          currentLevel: item.currentLevel,
                          safeLevel: item.safeLevel,
                          warningLevel: item.warningLevel,
                          dangerLevel: item.dangerLevel,
                          trend: item.status,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: levels.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final city = levels[index].city;
                          final selectedChip = city == _selectedCity;
                          return ChoiceChip(
                            selected: selectedChip,
                            onSelected: (_) =>
                                setState(() => _selectedCity = city),
                            selectedColor: const Color(0xFF0DA7C2),
                            backgroundColor: Colors.white.withOpacity(0.12),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.25)),
                            label: Text(
                              city,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _TrendCard(
                      city: selected.city,
                      history: _service.trendForCity(selected.city),
                      dangerLevel: selected.dangerLevel,
                      warningLevel: selected.warningLevel,
                    ),
                    const SizedBox(height: 14),
                    RiskHeatmap(stateRisks: _stateRiskMap(levels)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Map<String, String>> _stateRiskMap(List<FloodData> levels) {
    final rank = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1};
    final map = <String, String>{};

    for (final item in levels) {
      final existing = map[item.state];
      if (existing == null ||
          (rank[item.riskLevel] ?? 0) > (rank[existing] ?? 0)) {
        map[item.state] = item.riskLevel;
      }
    }

    return map.entries
        .map((e) => {'state': e.key, 'risk': e.value})
        .toList(growable: false);
  }
}

class _TrendCard extends StatelessWidget {
  final String city;
  final List<RiverLevelSnapshot> history;
  final double warningLevel;
  final double dangerLevel;

  const _TrendCard({
    required this.city,
    required this.history,
    required this.warningLevel,
    required this.dangerLevel,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<RiverLevelSnapshot>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final points =
        sorted.length > 24 ? sorted.sublist(sorted.length - 24) : sorted;

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].level));
    }

    return Container(
      height: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$city: 24h River Trend',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: spots.length < 2
                ? const Center(
                    child: Text(
                      'Waiting for live history points...',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 0.5,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.white.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, _) => Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 10),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              if (value == 0)
                                return const Text('Start',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 10));
                              if (value ==
                                  ((spots.length - 1) / 2).roundToDouble()) {
                                return const Text('Mid',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 10));
                              }
                              if (value == (spots.length - 1).toDouble()) {
                                return const Text('Now',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 10));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF24C9E8),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF24C9E8).withOpacity(0.35),
                                const Color(0xFF24C9E8).withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ],
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: warningLevel,
                            color: const Color(0xFFF59E0B),
                            strokeWidth: 1.3,
                            dashArray: [4, 4],
                          ),
                          HorizontalLine(
                            y: dangerLevel,
                            color: const Color(0xFFEF4444),
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
