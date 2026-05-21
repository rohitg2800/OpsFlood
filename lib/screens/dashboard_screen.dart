import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../services/api_service.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
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

  Map<String, dynamic>? _modelMetrics;
  bool _metricsLoading = true;

  int _lastLevelHash = 0;

  List<FloodData> _cachedSortedLevels = <FloodData>[];
  int _cachedHash = -1;

  @override
  void initState() {
    super.initState();
    _fetchModelMetrics();
    _service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    final newHash = _service.liveLevels.length ^
        (_service.lastFetchTime?.millisecondsSinceEpoch ?? 0);
    if (newHash != _lastLevelHash) {
      _lastLevelHash = newHash;
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchModelMetrics() async {
    try {
      final res = await ApiService().getModelMetrics();
      if (mounted) setState(() { _modelMetrics = res; _metricsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _metricsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    final cs = Theme.of(context).colorScheme;

    final newHash = _service.liveLevels.length ^
        (_service.lastFetchTime?.millisecondsSinceEpoch ?? 0);
    if (newHash != _cachedHash) {
      _cachedHash = newHash;
      _cachedSortedLevels = List<FloodData>.from(_service.liveLevels)
        ..sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));
    }
    final levels = _cachedSortedLevels;

    if (levels.isNotEmpty &&
        (_selectedCity == null ||
            levels.every((e) => e.city != _selectedCity))) {
      _selectedCity = levels.first.city;
    }

    final primary  = levels.isNotEmpty ? levels.first : null;
    final selected = levels.isEmpty
        ? null
        : levels.firstWhere(
            (e) => e.city == _selectedCity,
            orElse: () => primary!,
          );

    final timestampLabel = _service.lastFetchTime == null
        ? 'Awaiting first live poll'
        : 'Updated ${DateFormat("dd MMM, HH:mm:ss").format(_service.lastFetchTime!.toLocal())}';

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _service.refreshData,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Header ──────────────────────────────────────────────
                    Row(
                      children: [
                        Icon(Icons.water_drop, color: rc.riverNormal),
                        const SizedBox(width: 8),
                        Text('OpsFlood Command',
                            style: TextStyle(
                              color: rc.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            )),
                        const Spacer(),
                        IconButton(
                          onPressed: _service.refreshData,
                          icon: Icon(Icons.refresh, color: rc.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(timestampLabel,
                        style: TextStyle(
                            color: rc.textSecondary, fontSize: 12)),
                    const SizedBox(height: 10),

                    // ── Simulated-data banner (shown when backend is offline) ──
                    if (_service.isUsingFallback)
                      const _SimulatedDataBanner(),

                    // ── Error banner ─────────────────────────────────────────
                    if (_service.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.orange.withOpacity(0.15),
                          border: Border.all(
                              color: Colors.orangeAccent.withOpacity(0.5)),
                        ),
                        child: Text(_service.error!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),

                    // ── Alert badge ──────────────────────────────────────────
                    AnimatedAlertBadge(
                      count: _service.activeCriticalAlerts.length,
                      isCritical: _service.activeCriticalAlerts.isNotEmpty,
                      label: _service.activeCriticalAlerts.isNotEmpty
                          ? 'Critical Alerts'
                          : 'Live Alerts',
                    ),
                    const SizedBox(height: 14),

                    // ── Gauge — top-risk city ────────────────────────────────
                    if (primary != null)
                      Center(
                        child: FloodGauge(
                          capacity: primary.capacityPercent,
                          riskLevel: primary.riskLevel,
                          label:
                              '${primary.city} | ${primary.riverName ?? "River"}',
                          size: 200,
                        ),
                      )
                    else
                      const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: 14),

                    // ── Stat cards ───────────────────────────────────────────
                    SizedBox(
                      height: 110,
                      child: Row(
                        children: [
                          Expanded(
                            child: PremiumStatCard(
                              icon: Icons.warning_amber,
                              title: 'Critical',
                              value:
                                  '${_service.monitoringData.criticalCount}',
                              subtitle: 'threshold breaches',
                              accent: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PremiumStatCard(
                              icon: Icons.ssid_chart,
                              title: 'High Risk',
                              value:
                                  '${_service.monitoringData.highRiskCount}',
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
                                  : _service.isUsingFallback ? 'Simulated' : 'Live',
                              subtitle: _service.isUsingCache
                                  ? 'cache mode'
                                  : _service.isUsingFallback
                                      ? 'backend offline'
                                      : 'real-time feed',
                              accent: _service.isUsingFallback
                                  ? const Color(0xFFF59E0B)
                                  : _service.isOnline
                                      ? const Color(0xFF34C759)
                                      : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Model metrics ────────────────────────────────────────
                    _ModelMetricsCard(
                        loading: _metricsLoading, metrics: _modelMetrics),
                    const SizedBox(height: 16),

                    // ── City selector chips ──────────────────────────────────
                    if (levels.isNotEmpty) ...[
                      Text('River Monitoring',
                          style: TextStyle(
                            color: rc.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          )),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: levels.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final city = levels[i].city;
                            final sel = city == _selectedCity;
                            return ChoiceChip(
                              selected: sel,
                              onSelected: (_) =>
                                  setState(() => _selectedCity = city),
                              selectedColor: rc.riverNormal,
                              backgroundColor: rc.chipBg,
                              label: Text(city,
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : rc.textSecondary,
                                      fontSize: 12)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── Trend chart for selected city ────────────────────────
                    if (selected != null)
                      RepaintBoundary(
                        child: _TrendCard(
                          city: selected.city,
                          history: _service.trendForCity(selected.city),
                          dangerLevel: selected.dangerLevel,
                          warningLevel: selected.warningLevel,
                        ),
                      ),
                    const SizedBox(height: 14),
                  ]),
                ),
              ),

              // ── River cards (lazy) ───────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final item = levels[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RiverLevelVisualizer(
                          city: item.city,
                          river: item.riverName ?? 'River',
                          currentLevel: item.currentLevel,
                          safeLevel: item.safeLevel,
                          warningLevel: item.warningLevel,
                          dangerLevel: item.dangerLevel,
                          trend: item.status,
                        ),
                      );
                    },
                    childCount: levels.length,
                  ),
                ),
              ),

              // ── Risk heatmap ─────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: RiskHeatmap(
                      stateRisks: _stateRiskMap(levels)),
                ),
              ),
            ],
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

// ── Simulated Data Banner ───────────────────────────────────────────────────
class _SimulatedDataBanner extends StatelessWidget {
  const _SimulatedDataBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFF59E0B).withOpacity(0.12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.45),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️  Simulated Data',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Backend is offline or starting up. River levels shown are estimated, not live.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Model metrics card ──────────────────────────────────────────────────────
class _ModelMetricsCard extends StatelessWidget {
  final bool loading;
  final Map<String, dynamic>? metrics;
  const _ModelMetricsCard({required this.loading, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    if (loading) {
      return Container(
        height: 52,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: rc.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final m      = metrics?['metrics'] as Map<String, dynamic>? ?? {};
    final status = metrics?['status']?.toString() ?? 'unavailable';
    final algo   = metrics?['algorithm']?.toString() ?? 'Model';
    if (status == 'unavailable' || m.isEmpty) return const SizedBox.shrink();

    double pct(String key) => ((m[key] as num?)?.toDouble() ?? 0.0) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rc.riverNormal.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_alt, color: rc.riverNormal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(algo,
                    style: TextStyle(
                        color: rc.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  'F1 ${pct("f1_score").toStringAsFixed(1)}%  '
                  'Acc ${pct("accuracy").toStringAsFixed(1)}%  '
                  'P ${pct("precision").toStringAsFixed(1)}%  '
                  'R ${pct("recall").toStringAsFixed(1)}%',
                  style:
                      TextStyle(color: rc.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (m['training_samples'] != null)
            Text('${m["training_samples"]}\nsamples',
                textAlign: TextAlign.right,
                style: TextStyle(color: rc.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Trend chart ─────────────────────────────────────────────────────────────
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
    final rc = RiverColors.of(context);
    final sorted = List<RiverLevelSnapshot>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final pts = sorted.length > 24 ? sorted.sublist(sorted.length - 24) : sorted;
    final spots = List.generate(
        pts.length, (i) => FlSpot(i.toDouble(), pts[i].level));

    return Container(
      height: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: rc.riverNormal.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$city: 24h River Trend',
              style: TextStyle(
                  color: rc.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: spots.length < 2
                ? Center(
                    child: Text('Waiting for live history points…',
                        style:
                            TextStyle(color: rc.textSecondary)))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 0.5,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: rc.riverNormal.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(1),
                              style: TextStyle(
                                  color: rc.textSecondary,
                                  fontSize: 10),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              if (v == 0)
                                return Text('Start',
                                    style: TextStyle(
                                        color: rc.textSecondary,
                                        fontSize: 10));
                              if (v ==
                                  ((spots.length - 1) / 2)
                                      .roundToDouble())
                                return Text('Mid',
                                    style: TextStyle(
                                        color: rc.textSecondary,
                                        fontSize: 10));
                              if (v == (spots.length - 1).toDouble())
                                return Text('Now',
                                    style: TextStyle(
                                        color: rc.textSecondary,
                                        fontSize: 10));
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                            color:
                                rc.riverNormal.withOpacity(0.15)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: rc.sparklineColor,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                rc.sparklineColor.withOpacity(0.35),
                                rc.sparklineColor.withOpacity(0.02),
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
