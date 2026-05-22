import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../providers/flood_providers.dart';
import '../services/api_service.dart';
import '../services/real_time_service.dart'; // CwcStationData lives here
import '../screens/river_monitor_screen.dart';
import '../theme/river_theme.dart';
import '../widgets/animated_alert_badge.dart';
import '../widgets/flood_gauge.dart';
import '../widgets/premium_stat_card.dart';
import '../widgets/risk_heatmap.dart';
import '../widgets/river_level_visualizer.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedCity;

  Map<String, dynamic>? _modelMetrics;
  bool _metricsLoading = true;
  bool _showDebug = false;

  List<FloodData> _cachedSortedLevels = <FloodData>[];
  int _cachedHash = -1;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(_pulseCtrl);
    _fetchModelMetrics();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchModelMetrics() async {
    try {
      final res = await ApiService().getModelMetrics();
      if (mounted)
        setState(() {
          _modelMetrics = res;
          _metricsLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _metricsLoading = false);
    }
  }

  Future<void> _onRefresh() => ref.read(realTimeProvider).refreshData();

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    final cs = Theme.of(context).colorScheme;

    final svc          = ref.read(realTimeProvider);
    final liveLevels   = ref.watch(liveLevelsProvider);
    final isUsingFallback  = ref.watch(isUsingFallbackProvider);
    final isWakingUp       = ref.watch(isWakingUpProvider);
    final lastFetchTime    = ref.watch(lastFetchTimeProvider);
    final isOffline        = ref.watch(isOfflineProvider); // isOnlineProvider doesn't exist
    final isOnline         = !isOffline;
    final errorMsg         = ref.watch(errorMessageProvider);
    final monData          = ref.watch(monitoringDataProvider);

    final cwcStations  = svc.cwcStations;
    final hasCwcLive   = svc.hasCwcLiveData;

    final newHash = liveLevels.length ^
        (lastFetchTime?.millisecondsSinceEpoch ?? 0);
    if (newHash != _cachedHash) {
      _cachedHash = newHash;
      _cachedSortedLevels = List<FloodData>.from(liveLevels)
        ..sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));
    }
    final levels = _cachedSortedLevels;

    if (levels.isNotEmpty &&
        (_selectedCity == null ||
            levels.every((e) => e.city != _selectedCity))) {
      _selectedCity = levels.first.city;
    }

    final primary = levels.isNotEmpty ? levels.first : null;
    final selected = levels.isEmpty
        ? null
        : levels.firstWhere((e) => e.city == _selectedCity,
            orElse: () => primary!);

    final bool isBackendLive = lastFetchTime != null &&
        !isUsingFallback &&
        !isWakingUp;
    final bool isConnecting  = isWakingUp;
    final bool showLive      = isBackendLive && !hasCwcLive;
    final bool showCwcLive   = hasCwcLive;
    final bool showConnecting = isConnecting && !hasCwcLive;

    final timestampLabel = isBackendLive
        ? 'Updated ${DateFormat("dd MMM, HH:mm:ss").format(lastFetchTime!.toLocal())}'
        : cwcStations.isNotEmpty
            ? 'CWC data: ${DateFormat("HH:mm:ss").format(DateTime.now())} \u00b7 Backend proxied'
            : isConnecting
                ? 'Connecting to live feed\u2026'
                : 'Waiting for live data\u2026';

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: kDebugMode
          ? FloatingActionButton.small(
              heroTag: 'dbg',
              backgroundColor: Colors.deepPurple,
              onPressed: () => setState(() => _showDebug = !_showDebug),
              child: Icon(
                  _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
                  color: Colors.white,
                  size: 18),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        Icon(Icons.water_drop, color: rc.riverNormal, size: 22),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('OpsFlood Command',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: rc.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 21,
                              )),
                        ),
                        const Spacer(),
                        _StatusPill(
                          isLive: showLive,
                          isCwcLive: showCwcLive,
                          isConnecting: showConnecting,
                          isOffline: isOffline,
                          pulseAnim: _pulseAnim,
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: _onRefresh,
                          icon: Icon(Icons.refresh,
                              color: rc.textSecondary, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    showConnecting
                        ? AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) => Text(
                              'Waking up backend \u2014 CWC feed via proxy ~5 s',
                              style: TextStyle(
                                  color: Colors.orange
                                      .withValues(alpha: _pulseAnim.value),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic),
                            ),
                          )
                        : Text(timestampLabel,
                            style: TextStyle(
                                color: rc.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),

                    if (kDebugMode && _showDebug)
                      _DebugPanel(service: svc),

                    if (hasCwcLive)
                      _CwcLiveBanner(stationCount: cwcStations.length)
                    else if (isUsingFallback && !hasCwcLive)
                      _WakingBanner(
                        message: cwcStations.isEmpty
                            ? 'Connecting to CWC flood telemetry\u2026'
                            : 'CWC data unavailable \u2014 estimated levels shown.',
                      )
                    else if (isOffline)
                      _OfflineBanner(),

                    if (errorMsg != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.orange.withValues(alpha: 0.12),
                          border: Border.all(
                              color: Colors.orangeAccent.withValues(alpha: 0.5)),
                        ),
                        child: Text(errorMsg,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),

                    AnimatedAlertBadge(
                      count: svc.activeCriticalAlerts.length,
                      isCritical: svc.activeCriticalAlerts.isNotEmpty,
                      label: svc.activeCriticalAlerts.isNotEmpty
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
                              '${primary.city} | ${primary.riverName ?? "River"}',
                          size: 200,
                        ),
                      )
                    else
                      const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator())),
                    const SizedBox(height: 16),

                    if (cwcStations.isNotEmpty) ...[
                      _CwcStationStrip(stations: cwcStations.take(8).toList()),
                      const SizedBox(height: 16),
                      _CwcLiveSummaryCard(
                        station: cwcStations.first,
                        stationCount: cwcStations.length,
                      ),
                      const SizedBox(height: 16),
                    ],

                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: PremiumStatCard(
                              icon: Icons.warning_amber,
                              title: 'Critical',
                              value: '${monData.criticalCount}',
                              subtitle: 'threshold breaches',
                              accent: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PremiumStatCard(
                              icon: Icons.ssid_chart,
                              title: 'High Risk',
                              value: '${monData.highRiskCount}',
                              subtitle: 'active locations',
                              accent: const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PremiumStatCard(
                              icon: hasCwcLive
                                  ? Icons.sensors
                                  : isOnline
                                      ? Icons.wifi
                                      : Icons.wifi_off,
                              title: hasCwcLive
                                  ? 'CWC'
                                  : isOnline
                                      ? 'Online'
                                      : 'Offline',
                              value: hasCwcLive
                                  ? '${cwcStations.length}'
                                  : isConnecting
                                      ? 'Waking'
                                      : svc.queuedOfflineCycles > 0
                                          ? '${svc.queuedOfflineCycles}'
                                          : 'Live',
                              subtitle: hasCwcLive
                                  ? 'stations above warning'
                                  : svc.isUsingCache
                                      ? 'cache mode'
                                      : isConnecting
                                          ? 'backend waking'
                                          : 'real-time feed',
                              accent: hasCwcLive
                                  ? const Color(0xFF34C759)
                                  : isUsingFallback
                                      ? const Color(0xFFF59E0B)
                                      : isOnline
                                          ? const Color(0xFF34C759)
                                          : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _ModelMetricsCard(
                        loading: _metricsLoading, metrics: _modelMetrics),
                    const SizedBox(height: 16),

                    if (levels.isNotEmpty) ...[
                      Text('River Monitoring',
                          style: TextStyle(
                            color: rc.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          )),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: levels.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final city = levels[i].city;
                            final sel = city == _selectedCity;
                            return ChoiceChip(
                              selected: sel,
                              onSelected: (_) =>
                                  setState(() => _selectedCity = city),
                              selectedColor: rc.riverNormal,
                              backgroundColor: rc.chipBg,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              label: Text(city,
                                  style: TextStyle(
                                      color:
                                          sel ? Colors.white : rc.textSecondary,
                                      fontSize: 12)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (selected != null)
                      RepaintBoundary(
                        child: _TrendCard(
                          city: selected.city,
                          history: svc.trendForCity(selected.city),
                          dangerLevel: selected.dangerLevel,
                          warningLevel: selected.warningLevel,
                          isLiveData: isBackendLive || hasCwcLive,
                        ),
                      ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final item = levels[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                sliver: SliverToBoxAdapter(
                  child: RiskHeatmap(stateRisks: _stateRiskMap(levels)),
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

// ── Debug Panel ─────────────────────────────────────────────────────────────────
class _DebugPanel extends StatelessWidget {
  final dynamic service;
  const _DebugPanel({required this.service});

  String _fmt(Map<String, dynamic> m) {
    try {
      final enc = const JsonEncoder.withIndent('  ').convert(m);
      return enc.length > 800 ? '${enc.substring(0, 800)}\n...truncated' : enc;
    } catch (_) {
      return m.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\uD83D\uDD0E API Debug Panel',
              style: TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(height: 8),
          _row('isWakingUp', '${service.isWakingUp}'),
          _row('hasCwcLiveData', '${service.hasCwcLiveData}'),
          _row('cwcStations', '${service.cwcStations.length}'),
          _row('isUsingFallback', '${service.isUsingFallback}'),
          _row('isUsingCache', '${service.isUsingCache}'),
          _row('retryCount', '${service.debugRetryCount}'),
          _row('wakeAttempts', '${service.debugWakeAttempts}'),
          _row('error', service.error ?? 'none'),
          const Divider(color: Colors.white12, height: 16),
          const Text('live-levels response:',
              style: TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 4),
          _codeBlock(_fmt(service.debugLevelsRaw)),
          const SizedBox(height: 8),
          const Text('CWC FFS telemetry response:',
              style: TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 4),
          _codeBlock(_fmt(service.debugCwcRaw)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
                width: 130,
                child: Text(label,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
      );

  Widget _codeBlock(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 9,
                fontFamily: 'monospace')),
      );
}

// ── Status pill ───────────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final bool isLive, isCwcLive, isConnecting, isOffline;
  final Animation<double> pulseAnim;
  const _StatusPill({
    required this.isLive,
    required this.isCwcLive,
    required this.isConnecting,
    required this.isOffline,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isLive || isCwcLive
        ? const Color(0xFF34C759)
        : isConnecting
            ? Colors.orange
            : isOffline
                ? Colors.redAccent
                : Colors.grey;
    final String label = isLive
        ? 'LIVE'
        : isCwcLive
            ? 'CWC LIVE'
            : isConnecting
                ? 'CONNECTING'
                : isOffline
                    ? 'OFFLINE'
                    : 'STANDBY';
    final bool pulsing = isConnecting || isCwcLive;

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color.withValues(alpha: pulsing ? pulseAnim.value : 1.0),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 5)
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ── CWC Live Banner ───────────────────────────────────────────────────────────────────
class _CwcLiveBanner extends StatelessWidget {
  final int stationCount;
  const _CwcLiveBanner({required this.stationCount});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF34C759).withValues(alpha: 0.10),
          border: Border.all(
              color: const Color(0xFF34C759).withValues(alpha: 0.40)),
        ),
        child: Row(
          children: [
            const Icon(Icons.sensors, color: Color(0xFF34C759), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('\uD83D\uDFE2  CWC Live Telemetry Active',
                      style: TextStyle(
                          color: Color(0xFF34C759),
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(
                      '$stationCount stations above warning level \u00b7 via backend proxy',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Waking Banner ───────────────────────────────────────────────────────────────────
class _WakingBanner extends StatelessWidget {
  final String message;
  const _WakingBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
          border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.40)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded,
                color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('\u23f3  Connecting to Live Feed',
                      style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(message,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Offline Banner ───────────────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.redAccent.withValues(alpha: 0.10),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.40)),
        ),
        child: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\uD83D\uDD34  No Internet Connection',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  SizedBox(height: 3),
                  Text('Cached data shown. Reconnect to restore live feed.',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── CWC Station Strip ───────────────────────────────────────────────────────────────────
class _CwcStationStrip extends StatelessWidget {
  final List<CwcStationData> stations;
  const _CwcStationStrip({required this.stations});

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('\u26a0 CWC Stations Above Warning Level',
            style: TextStyle(
                color: rc.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(height: 8),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final s = stations[i];
              final color = s.status == 'CRITICAL'
                  ? const Color(0xFFEF4444)
                  : s.status == 'WARNING'
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF34C759);
              final displayName = s.stationName.isNotEmpty
                  ? s.stationName
                  : s.riverName.isNotEmpty
                      ? s.riverName
                      : 'Station ${i + 1}';
              final dangerStr = s.dangerLevel > 0
                  ? 'DL: ${s.dangerLevel.toStringAsFixed(1)} m'
                  : 'WL: ${s.warningLevel.toStringAsFixed(1)} m';
              return Container(
                width: 164,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: rc.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: rc.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(s.stateName.isNotEmpty ? s.stateName : 'India',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: rc.textSecondary, fontSize: 11)),
                    if (s.riverName.isNotEmpty)
                      Text(s.riverName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: rc.textSecondary.withValues(alpha: 0.75),
                              fontSize: 10)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text('${s.riverLevel.toStringAsFixed(2)} m',
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                        const SizedBox(width: 4),
                        Icon(
                            s.trend == 'RISING'
                                ? Icons.trending_up
                                : s.trend == 'FALLING'
                                    ? Icons.trending_down
                                    : Icons.trending_flat,
                            color: color,
                            size: 15),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(dangerStr,
                        style:
                            TextStyle(color: rc.textSecondary, fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── CWC Live Summary Card ───────────────────────────────────────────────────────────────────
class _CwcLiveSummaryCard extends StatelessWidget {
  final CwcStationData station;
  final int stationCount;
  const _CwcLiveSummaryCard({
    required this.station,
    required this.stationCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = station.status == 'CRITICAL'
        ? const Color(0xFFEF4444)
        : station.status == 'WARNING'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF34C759);
    final dangerStr = station.dangerLevel > 0
        ? 'DL ${station.dangerLevel.toStringAsFixed(1)} m'
        : 'WL ${station.warningLevel.toStringAsFixed(1)} m';
    final updated = station.lastUpdate.toLocal();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1724),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.sensors, size: 18, color: Colors.white70),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Live CWC river feed',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(station.status,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(station.stationName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
              '${station.riverName.isNotEmpty ? '${station.riverName} \u00b7 ' : ''}${station.stateName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 12),
          Row(children: [
            Text('${station.riverLevel.toStringAsFixed(2)} m',
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            Text(dangerStr,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const Spacer(),
            Text('Updated ${DateFormat('HH:mm').format(updated)}',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Text('Source: ${station.source}',
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RiverMonitorScreen(),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('View $stationCount live stations'),
            ),
          ])
        ],
      ),
    );
  }
}

// ── Model metrics card ───────────────────────────────────────────────────────────────────
class _ModelMetricsCard extends StatelessWidget {
  final bool loading;
  final Map<String, dynamic>? metrics;
  const _ModelMetricsCard({required this.loading, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    if (loading) {
      return Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
            color: rc.cardBg, borderRadius: BorderRadius.circular(12)),
        child: const Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final m = metrics?['metrics'] as Map<String, dynamic>? ?? {};
    final status = metrics?['status']?.toString() ?? 'unavailable';
    final algo = metrics?['algorithm']?.toString() ?? 'Model';
    if (status == 'unavailable' || m.isEmpty) return const SizedBox.shrink();

    double pct(String key) => ((m[key] as num?)?.toDouble() ?? 0.0) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rc.riverNormal.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_alt, color: rc.riverNormal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(algo,
                    style: TextStyle(
                        color: rc.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  'F1 ${pct("f1_score").toStringAsFixed(1)}%  '
                  'Acc ${pct("accuracy").toStringAsFixed(1)}%  '
                  'P ${pct("precision").toStringAsFixed(1)}%  '
                  'R ${pct("recall").toStringAsFixed(1)}%',
                  style: TextStyle(color: rc.textSecondary, fontSize: 11),
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

// ── Trend chart ───────────────────────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  final String city;
  final List<RiverLevelSnapshot> history;
  final double warningLevel;
  final double dangerLevel;
  final bool isLiveData;
  const _TrendCard({
    required this.city,
    required this.history,
    required this.warningLevel,
    required this.dangerLevel,
    required this.isLiveData,
  });

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    final sorted = List<RiverLevelSnapshot>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final pts =
        sorted.length > 24 ? sorted.sublist(sorted.length - 24) : sorted;
    final spots =
        List.generate(pts.length, (i) => FlSpot(i.toDouble(), pts[i].level));

    return Container(
      height: 230,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: rc.riverNormal.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$city: 24h River Trend',
                  style: TextStyle(
                      color: rc.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isLiveData ? const Color(0xFF34C759) : Colors.orange)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          (isLiveData ? const Color(0xFF34C759) : Colors.orange)
                              .withValues(alpha: 0.5)),
                ),
                child: Text(
                  isLiveData ? '\u25cf LIVE' : '\u26a0 EST',
                  style: TextStyle(
                      color:
                          isLiveData ? const Color(0xFF34C759) : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: spots.length < 2
                ? Center(
                    child: Text(
                    isLiveData
                        ? 'Waiting for live history points\u2026'
                        : 'History will populate once live feed starts',
                    style: TextStyle(color: rc.textSecondary),
                    textAlign: TextAlign.center,
                  ))
                : LineChart(LineChartData(
                    minY: 0,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 0.5,
                      getDrawingHorizontalLine: (_) => FlLine(
                          color: rc.riverNormal.withValues(alpha: 0.1),
                          strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1),
                            style: TextStyle(
                                color: rc.textSecondary, fontSize: 10)),
                      )),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          if (v == 0)
                            return Text('Start',
                                style: TextStyle(
                                    color: rc.textSecondary, fontSize: 10));
                          if (v == ((spots.length - 1) / 2).roundToDouble())
                            return Text('Mid',
                                style: TextStyle(
                                    color: rc.textSecondary, fontSize: 10));
                          if (v == (spots.length - 1).toDouble())
                            return Text('Now',
                                style: TextStyle(
                                    color: rc.textSecondary, fontSize: 10));
                          return const SizedBox.shrink();
                        },
                      )),
                    ),
                    borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                            color: rc.riverNormal.withValues(alpha: 0.15))),
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
                              rc.sparklineColor.withValues(alpha: 0.35),
                              rc.sparklineColor.withValues(alpha: 0.02),
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
                            dashArray: [4, 4]),
                        HorizontalLine(
                            y: dangerLevel,
                            color: const Color(0xFFEF4444),
                            strokeWidth: 1.5,
                            dashArray: [6, 4]),
                      ],
                    ),
                  )),
          ),
        ],
      ),
    );
  }
}
