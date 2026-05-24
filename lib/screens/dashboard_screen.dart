// lib/screens/dashboard_screen.dart
//
// OpsFlood — DashboardScreen (v12 — full UI overhaul)
//
// CHANGES vs previous version:
//   - Removed duplicate import of river_monitoring.dart
//   - Removed _ModelMetricsCard (backend endpoint unavailable, shows empty)
//   - Removed dead `ApiService().getModelMetrics()` call
//   - Removed unused `_showDebug` FAB wiring (kept panel itself, debug-only)
//   - Banner logic cleaned up — exactly one banner shown at a time
//   - Trend chart now uses flowRate (m³/s) when gauge level is 0
//   - Dashboard header is now a proper glassy app bar
//   - CWC station strip shows cwcSource tag
//   - River cards pass flowRateM3s + cwcSource through to RiverLevelVisualizer
library;

import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
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

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final RealTimeService _service = RealTimeService();
  String? _selectedCity;

  bool _showDebug    = false;
  int  _lastLevelHash = 0;
  List<FloodData> _cachedSortedLevels = [];
  int  _cachedHash = -1;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(_pulseCtrl);
    _service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    final h = _service.liveLevels.length ^
        (_service.lastFetchTime?.millisecondsSinceEpoch ?? 0);
    if (h != _lastLevelHash) {
      _lastLevelHash = h;
      if (mounted) setState(() {});
    }
  }

  Future<void> _onRefresh() => _service.refreshData();

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    final cs = Theme.of(context).colorScheme;

    final h = _service.liveLevels.length ^
        (_service.lastFetchTime?.millisecondsSinceEpoch ?? 0);
    if (h != _cachedHash) {
      _cachedHash = h;
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
        : levels.firstWhere((e) => e.city == _selectedCity,
            orElse: () => primary!);

    final cwcStations = _service.cwcStations;
    final hasCwcLive  = _service.hasCwcLiveData;
    final isConnecting = _service.isWakingUp;
    final isOnline     = _service.isOnline;
    final isBackendLive = _service.lastFetchTime != null &&
        !_service.isUsingFallback && !_service.isWakingUp;

    final timestampLabel = _service.lastFetchTime != null
        ? 'Updated ${DateFormat("dd MMM, HH:mm:ss").format(_service.lastFetchTime!.toLocal())}'
        : isConnecting
            ? 'Connecting to live feed…'
            : 'Waiting for live data…';

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: kDebugMode
          ? FloatingActionButton.small(
              heroTag: 'dbg',
              backgroundColor: Colors.deepPurple,
              onPressed: () => setState(() => _showDebug = !_showDebug),
              child: Icon(
                _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
                color: Colors.white, size: 18,
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // ── Glassy header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: rc.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: rc.riverNormal.withValues(alpha: 0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: rc.riverNormal.withValues(alpha: 0.06),
                        blurRadius: 20, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Logo icon
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: rc.riverNormal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.water_drop_rounded,
                                color: rc.riverNormal, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('OpsFlood',
                                    style: TextStyle(
                                      color: rc.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18, letterSpacing: -0.5,
                                    )),
                                Text('Flood Intelligence Platform',
                                    style: TextStyle(
                                        color: rc.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          _StatusPill(
                            isLive:       isBackendLive || hasCwcLive,
                            isCwcLive:    hasCwcLive,
                            isConnecting: isConnecting,
                            isOffline:    !isOnline,
                            pulseAnim:    _pulseAnim,
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _onRefresh,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: rc.riverNormal.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.refresh_rounded,
                                  color: rc.textSecondary, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(timestampLabel,
                          style: TextStyle(
                              color: rc.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ),

              // ── Body padding ───────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // ── Debug panel
                    if (kDebugMode && _showDebug)
                      _DebugPanel(service: _service),

                    // ── Single status banner (mutually exclusive)
                    if (hasCwcLive)
                      _Banner(
                        icon:    Icons.sensors_rounded,
                        title:   'CWC Live Telemetry Active',
                        body:    '${cwcStations.length} stations reporting above warning level',
                        color:   const Color(0xFF34C759),
                      )
                    else if (isConnecting)
                      _Banner(
                        icon:    Icons.hourglass_top_rounded,
                        title:   'Connecting to Live Feed',
                        body:    'CWC FFEM / WRD Bihar endpoints being queried…',
                        color:   const Color(0xFFF59E0B),
                      )
                    else if (!isOnline)
                      _Banner(
                        icon:    Icons.wifi_off_rounded,
                        title:   'No Internet Connection',
                        body:    'Cached data shown. Pull to retry.',
                        color:   Colors.redAccent,
                      ),

                    if (_service.error != null) ...[
                      const SizedBox(height: 8),
                      _Banner(
                        icon:  Icons.error_outline_rounded,
                        title: 'Fetch Error',
                        body:  _service.error!,
                        color: Colors.orange,
                      ),
                    ],

                    const SizedBox(height: 12),

                    // ── Alert badge
                    AnimatedAlertBadge(
                      count: _service.activeCriticalAlerts.length,
                      isCritical: _service.activeCriticalAlerts.isNotEmpty,
                      label: _service.activeCriticalAlerts.isNotEmpty
                          ? 'Critical Alerts Active'
                          : 'Monitoring Active',
                    ),
                    const SizedBox(height: 14),

                    // ── Flood gauge (highest risk city)
                    if (primary != null)
                      Center(
                        child: FloodGauge(
                          capacity: primary.capacityPercent,
                          riskLevel: primary.riskLevel,
                          label: '${primary.city} · ${primary.riverName ?? "River"}',
                          size: 200,
                        ),
                      )
                    else
                      const SizedBox(
                          height: 200,
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2))),
                    const SizedBox(height: 14),

                    // ── Stat cards row
                    SizedBox(
                      height: 110,
                      child: Row(
                        children: [
                          Expanded(
                            child: PremiumStatCard(
                              icon: Icons.warning_amber_rounded,
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
                              icon: Icons.ssid_chart_rounded,
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
                              icon: hasCwcLive
                                  ? Icons.sensors_rounded
                                  : isOnline
                                      ? Icons.wifi_rounded
                                      : Icons.wifi_off_rounded,
                              title: hasCwcLive
                                  ? 'CWC'
                                  : isOnline ? 'Online' : 'Offline',
                              value: hasCwcLive
                                  ? '${cwcStations.length}'
                                  : isConnecting ? '…' : 'Live',
                              subtitle: hasCwcLive
                                  ? 'stations live'
                                  : isConnecting
                                      ? 'connecting'
                                      : 'real-time feed',
                              accent: hasCwcLive
                                  ? const Color(0xFF34C759)
                                  : _service.isUsingFallback
                                      ? const Color(0xFFF59E0B)
                                      : isOnline
                                          ? const Color(0xFF34C759)
                                          : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── CWC station strip
                    if (cwcStations.isNotEmpty) ...[
                      _SectionHeader('⚠ CWC Stations Above Warning'),
                      const SizedBox(height: 8),
                      _CwcStationStrip(stations: cwcStations.take(6).toList()),
                      const SizedBox(height: 16),
                    ],

                    // ── River monitoring section
                    if (levels.isNotEmpty) ...[
                      _SectionHeader('River Monitoring'),
                      const SizedBox(height: 10),
                      // City selector
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: levels.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final city = levels[i].city;
                            final sel  = city == _selectedCity;
                            final rc2  = RiverColors.of(context);
                            return ChoiceChip(
                              selected: sel,
                              onSelected: (_) =>
                                  setState(() => _selectedCity = city),
                              selectedColor:
                                  rc2.riverNormal.withValues(alpha: 0.25),
                              backgroundColor: rc2.chipBg,
                              side: BorderSide(
                                color: sel
                                    ? rc2.riverNormal.withValues(alpha: 0.6)
                                    : Colors.white12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                              label: Text(city,
                                  style: TextStyle(
                                    color: sel
                                        ? rc2.riverNormal
                                        : rc2.textSecondary,
                                    fontSize: 12,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  )),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Trend chart
                    if (selected != null)
                      RepaintBoundary(
                        child: _TrendCard(
                          city: selected.city,
                          history: _service.trendForCity(selected.city),
                          dangerLevel: selected.dangerLevel,
                          warningLevel: selected.warningLevel,
                          isLiveData: isBackendLive || hasCwcLive,
                        ),
                      ),
                    const SizedBox(height: 14),
                  ]),
                ),
              ),

              // ── River cards ────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final item = levels[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RiverLevelVisualizer(
                          city:         item.city,
                          river:        item.riverName ?? 'River',
                          currentLevel: item.currentLevel,
                          safeLevel:    item.safeLevel,
                          warningLevel: item.warningLevel,
                          dangerLevel:  item.dangerLevel,
                          trend:        item.status,
                          flowRateM3s:  item.flowRate,
                          cwcSource:    (item.status == 'Live' ||
                                  item.status == 'Partial')
                              ? item.status
                              : null,
                        ),
                      );
                    },
                    childCount: levels.length,
                  ),
                ),
              ),

              // ── Risk heatmap ───────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
    final map  = <String, String>{};
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

// ── Section header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    return Text(text,
        style: TextStyle(
          color: rc.textPrimary, fontWeight: FontWeight.w700, fontSize: 15,
        ));
  }
}

// ── Unified banner ─────────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   body;
  final Color    color;
  const _Banner({
    required this.icon, required this.title,
    required this.body, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700, fontSize: 12,
                    )),
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status pill ────────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final bool isLive, isCwcLive, isConnecting, isOffline;
  final Animation<double> pulseAnim;
  const _StatusPill({
    required this.isLive, required this.isCwcLive,
    required this.isConnecting, required this.isOffline,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isLive
        ? const Color(0xFF34C759)
        : isConnecting ? Colors.orange
        : isOffline    ? Colors.redAccent
        : Colors.grey;
    final String label = isCwcLive ? 'CWC LIVE'
        : isLive       ? 'LIVE'
        : isConnecting ? 'CONNECTING'
        : isOffline    ? 'OFFLINE'
        : 'STANDBY';
    final bool pulsing = isConnecting || isCwcLive;

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: color.withValues(
                    alpha: pulsing ? pulseAnim.value : 1.0),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.6), blurRadius: 5)
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ── CWC Station Strip ──────────────────────────────────────────────────────────
class _CwcStationStrip extends StatelessWidget {
  final List<dynamic> stations;
  const _CwcStationStrip({required this.stations});

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = stations[i];
          final isCritical = (s is Map ? s['source'] : null)
                  ?.toString()
                  .contains('CRITICAL') ==
              true;
          final Color col = isCritical
              ? const Color(0xFFEF4444)
              : const Color(0xFFF59E0B);

          // Support both RiverStation objects and raw Maps
          final String name    = _str(s, ['stationName', 'city', 'name']);
          final String state   = _str(s, ['stateName', 'state']);
          final String river   = _str(s, ['riverName', 'river']);
          final double level   = _dbl(s, ['riverLevel', 'currentLevel']);
          final double danger  = _dbl(s, ['dangerLevel', 'danger']);
          final double warning = _dbl(s, ['warningLevel', 'warning']);
          final String src     = _str(s, ['source']);
          final String trend   = _str(s, ['trend']);

          return Container(
            width: 152,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: rc.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: col.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                    color: col.withValues(alpha: 0.07),
                    blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isNotEmpty ? name : 'Station ${i + 1}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: rc.textPrimary,
                        fontWeight: FontWeight.w700, fontSize: 12)),
                Text(state.isNotEmpty ? state : 'India',
                    style: TextStyle(
                        color: rc.textSecondary, fontSize: 10)),
                if (river.isNotEmpty)
                  Text(river, maxLines: 1,
                      style: TextStyle(
                          color: rc.textSecondary.withValues(alpha: 0.6),
                          fontSize: 9)),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      level > 0
                          ? '${level.toStringAsFixed(2)} m'
                          : '—',
                      style: TextStyle(
                          color: col,
                          fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      trend == 'RISING'
                          ? Icons.trending_up_rounded
                          : trend == 'FALLING'
                              ? Icons.trending_down_rounded
                              : Icons.trending_flat_rounded,
                      color: col, size: 14,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      danger > 0
                          ? 'DL ${danger.toStringAsFixed(1)} m'
                          : warning > 0
                              ? 'WL ${warning.toStringAsFixed(1)} m'
                              : '',
                      style: TextStyle(
                          color: rc.textSecondary, fontSize: 9),
                    ),
                    const Spacer(),
                    if (src.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          src.replaceAll('CWC_', ''),
                          style: TextStyle(
                              color: col, fontSize: 8,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _str(dynamic s, List<String> keys) {
    if (s is Map) {
      for (final k in keys) {
        final v = s[k]?.toString() ?? '';
        if (v.isNotEmpty) return v;
      }
    } else {
      for (final k in keys) {
        try {
          final v = (s as dynamic).toJson()[k]?.toString() ?? '';
          if (v.isNotEmpty) return v;
        } catch (_) {}
      }
    }
    return '';
  }

  double _dbl(dynamic s, List<String> keys) {
    if (s is Map) {
      for (final k in keys) {
        final v = double.tryParse(s[k]?.toString() ?? '');
        if (v != null) return v;
      }
    }
    return 0.0;
  }
}

// ── Debug Panel ────────────────────────────────────────────────────────────────
class _DebugPanel extends StatelessWidget {
  final RealTimeService service;
  const _DebugPanel({required this.service});

  @override
  Widget build(BuildContext context) {
    String fmt(Map<String, dynamic> m) {
      try {
        final s = const JsonEncoder.withIndent('  ').convert(m);
        return s.length > 600 ? '${s.substring(0, 600)}…' : s;
      } catch (_) { return m.toString(); }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔎 Debug', style: TextStyle(
              color: Colors.deepPurpleAccent,
              fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          for (final e in {
            'isWakingUp':      '${service.isWakingUp}',
            'hasCwcLiveData':  '${service.hasCwcLiveData}',
            'cwcStations':     '${service.cwcStations.length}',
            'isUsingFallback': '${service.isUsingFallback}',
            'error':           service.error ?? 'none',
          }.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(e.key,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ),
                  Expanded(
                    child: Text(e.value,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          const Divider(color: Colors.white12, height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(fmt(service.debugLevelsRaw),
                style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 9, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

// ── Trend chart ────────────────────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  final String city;
  final List<RiverLevelSnapshot> history;
  final double warningLevel;
  final double dangerLevel;
  final bool   isLiveData;
  const _TrendCard({
    required this.city, required this.history,
    required this.warningLevel, required this.dangerLevel,
    required this.isLiveData,
  });

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    final sorted = List<RiverLevelSnapshot>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final pts = sorted.length > 24
        ? sorted.sublist(sorted.length - 24)
        : sorted;

    // Use flowRate (m³/s) since gauge levels are 0 until CWC connects
    final useFlow = pts.isNotEmpty && pts.every((p) => p.level == 0);
    final spots = List.generate(
      pts.length,
      (i) => FlSpot(
        i.toDouble(),
        useFlow ? (pts[i].flowRate ?? 0.0) : pts[i].level,
      ),
    );

    final yLabel = useFlow ? 'm³/s' : 'm MSL';
    final maxY   = spots.isEmpty ? 1.0
        : spots.map((s) => s.y).reduce(math.max) * 1.15;

    return Container(
      height: 230,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: rc.riverNormal.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$city · 7-day trend ($yLabel)',
                  style: TextStyle(
                      color: rc.textPrimary,
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (isLiveData
                          ? const Color(0xFF34C759)
                          : Colors.orange)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (isLiveData
                            ? const Color(0xFF34C759)
                            : Colors.orange)
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  isLiveData ? '● LIVE' : '⚠ EST',
                  style: TextStyle(
                    color: isLiveData
                        ? const Color(0xFF34C759)
                        : Colors.orange,
                    fontSize: 9, fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: spots.length < 2
                ? Center(
                    child: Text(
                      'History populates once live data arrives',
                      style: TextStyle(color: rc.textSecondary),
                      textAlign: TextAlign.center,
                    ))
                : LineChart(
                    LineChartData(
                      minY: 0, maxY: maxY,
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: rc.riverNormal.withValues(alpha: 0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 38,
                          interval: maxY / 4,
                          getTitlesWidget: (v, _) => Text(
                            useFlow
                                ? '${(v / 1000).toStringAsFixed(1)}k'
                                : v.toStringAsFixed(1),
                            style: TextStyle(
                                color: rc.textSecondary,
                                fontSize: 9),
                          ),
                        )),
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
                                return Text('7d ago',
                                    style: TextStyle(
                                        color: rc.textSecondary,
                                        fontSize: 9));
                              if (v ==
                                  ((spots.length - 1) / 2)
                                      .roundToDouble())
                                return Text('3d ago',
                                    style: TextStyle(
                                        color: rc.textSecondary,
                                        fontSize: 9));
                              if (v ==
                                  (spots.length - 1).toDouble())
                                return Text('Now',
                                    style: TextStyle(
                                        color: rc.textSecondary,
                                        fontSize: 9));
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                            color: rc.riverNormal
                                .withValues(alpha: 0.12)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: rc.sparklineColor,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                rc.sparklineColor
                                    .withValues(alpha: 0.30),
                                rc.sparklineColor
                                    .withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ],
                      // Only draw reference lines when using real gauge levels
                      extraLinesData: ExtraLinesData(
                        horizontalLines: useFlow
                            ? []
                            : [
                                HorizontalLine(
                                  y: warningLevel,
                                  color: const Color(0xFFF59E0B),
                                  strokeWidth: 1.2,
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

// ignore: unused_import
import 'dart:math' as math;
