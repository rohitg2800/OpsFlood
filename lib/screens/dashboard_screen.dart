// lib/screens/dashboard_screen.dart
//
// OpsFlood — DashboardScreen  v13  (Midnight Ops redesign)
// ─────────────────────────────────────────────────────────────────────────────
// Layout (top → bottom):
//   1. Alert Hero Strip        [D] full-bleed color-coded top banner
//   2. OpsFlood Header         compact identity row + live pill + refresh
//   3. Live Stat Chips Row     [A] 4 mini KPI chips (cities / healthy% / warn / danger)
//   4. India Map Preview Card  [C] tappable card → IndiaRiversScreen
//   5. Primary Flood Gauge     centered arc gauge for highest-risk city
//   6. City Selector chips     horizontal pill scroll
//   7. Trend chart             7-day sparkline for selected city
//   8. CWC Station Strip       horizontal scroll if CWC live
//   9. City Cards Grid         [A+B] 2-column grid of RiverLevelVisualizer cards
//  10. Risk Heatmap
library;

import 'dart:convert';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../screens/india_rivers_screen.dart';
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

  bool _showDebug     = false;
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

  // ── Derived state helpers ──────────────────────────────────────────────────

  List<FloodData> _sortedLevels() {
    final h = _service.liveLevels.length ^
        (_service.lastFetchTime?.millisecondsSinceEpoch ?? 0);
    if (h != _cachedHash) {
      _cachedHash = h;
      _cachedSortedLevels = List<FloodData>.from(_service.liveLevels)
        ..sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));
    }
    return _cachedSortedLevels;
  }

  // Highest alert level across all cities
  String _worstLevel(List<FloodData> lvls) {
    const rank = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1};
    String best = 'NORMAL';
    for (final l in lvls) {
      if ((rank[l.riskLevel] ?? 0) > (rank[best] ?? 0)) best = l.riskLevel;
    }
    return best;
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);

    final levels       = _sortedLevels();
    final primary      = levels.isNotEmpty ? levels.first : null;
    final cwcStations  = _service.cwcStations;
    final hasCwcLive   = _service.hasCwcLiveData;
    final isConnecting = _service.isWakingUp;
    final isOnline     = _service.isOnline;
    final isBackendLive = _service.lastFetchTime != null &&
        !_service.isUsingFallback && !_service.isWakingUp;

    // Sync selected city
    if (levels.isNotEmpty &&
        (_selectedCity == null ||
            levels.every((e) => e.city != _selectedCity))) {
      _selectedCity = levels.first.city;
    }
    final selected = levels.isEmpty
        ? null
        : levels.firstWhere((e) => e.city == _selectedCity,
            orElse: () => primary!);

    final worstLevel  = _worstLevel(levels);
    final critCount   = levels.where((l) => l.riskLevel == 'CRITICAL').length;
    final warnCount   = levels.where((l) => l.riskLevel == 'HIGH' ||
                                            l.riskLevel == 'MODERATE').length;
    final healthyPct  = levels.isEmpty ? 100
        : ((levels.where((l) => l.riskLevel == 'LOW' ||
                                l.riskLevel == 'NORMAL').length /
            levels.length) * 100).round();

    final timestampLabel = _service.lastFetchTime != null
        ? 'Updated ${DateFormat("dd MMM, HH:mm").format(_service.lastFetchTime!.toLocal())}'
        : isConnecting ? 'Connecting…'
        : 'Awaiting data…';

    return Scaffold(
      backgroundColor: AppPalette.navy0,
      floatingActionButton: kDebugMode
          ? FloatingActionButton.small(
              heroTag:         'dbg',
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
          color:       AppPalette.cyan,
          backgroundColor: AppPalette.navy2,
          onRefresh:   _onRefresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [

              // ─────────────────────────────────────────────────────────────────
              // 1. ALERT HERO STRIP  [D]
              // Full-bleed color-coded banner for the worst active alert level.
              // ─────────────────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _AlertHeroStrip(
                  worstLevel:   worstLevel,
                  critCount:    critCount,
                  warnCount:    warnCount,
                  isConnecting: isConnecting,
                  isOffline:    !isOnline,
                  pulseAnim:    _pulseAnim,
                ),
              ),

              // ─────────────────────────────────────────────────────────────────
              // 2. OPSFLOOD HEADER
              // ─────────────────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      // Logo mark
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppPalette.navy3, AppPalette.navy4],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppPalette.navyStroke, width: 1),
                        ),
                        child: const Icon(Icons.water_rounded,
                            color: AppPalette.cyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('OpsFlood',
                                style: TextStyle(
                                  color: AppPalette.textWhite,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: -0.5,
                                )),
                            Text(timestampLabel,
                                style: const TextStyle(
                                    color: AppPalette.textGrey, fontSize: 11)),
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
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _onRefresh,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppPalette.navy3,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: AppPalette.navyStroke, width: 1),
                          ),
                          child: const Icon(Icons.refresh_rounded,
                              color: AppPalette.textGrey, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    if (kDebugMode && _showDebug)
                      _DebugPanel(service: _service),

                    // ───────────────────────────────────────────────────────────
                    // 3. LIVE STAT CHIPS ROW  [A]
                    // ───────────────────────────────────────────────────────────
                    _LiveStatRow(
                      totalCities:  levels.length,
                      healthyPct:   healthyPct,
                      warnCount:    warnCount,
                      critCount:    critCount,
                    ),
                    const SizedBox(height: 14),

                    // ───────────────────────────────────────────────────────────
                    // 4. INDIA MAP PREVIEW CARD  [C]
                    // ───────────────────────────────────────────────────────────
                    _MapPreviewCard(stateRisks: _stateRiskMap(levels)),
                    const SizedBox(height: 16),

                    // ───────────────────────────────────────────────────────────
                    // 5. PRIMARY FLOOD GAUGE
                    // ───────────────────────────────────────────────────────────
                    AnimatedAlertBadge(
                      count:      _service.activeCriticalAlerts.length,
                      isCritical: _service.activeCriticalAlerts.isNotEmpty,
                      label: _service.activeCriticalAlerts.isNotEmpty
                          ? 'Critical Alerts Active'
                          : 'All Systems Monitoring',
                    ),
                    const SizedBox(height: 12),

                    if (primary != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppPalette.navy2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppPalette.navyStroke, width: 1),
                        ),
                        child: Column(
                          children: [
                            FloodGauge(
                              capacity:  primary.capacityPercent,
                              riskLevel: primary.riskLevel,
                              label: '${primary.city} · '
                                  '${primary.riverName ?? "River"}',
                              size: 196,
                            ),
                            const SizedBox(height: 12),
                            // FittedBox prevents the legend row from
                            // overflowing on narrow grid cells
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _GaugeLegendDot(
                                      AppPalette.safe, 'Normal'),
                                  const SizedBox(width: 16),
                                  _GaugeLegendDot(
                                      AppPalette.warning, 'Warning'),
                                  const SizedBox(width: 16),
                                  _GaugeLegendDot(
                                      AppPalette.danger, 'Danger'),
                                  const SizedBox(width: 16),
                                  _GaugeLegendDot(
                                      AppPalette.critical, 'Critical'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(
                          height: 200,
                          child: Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppPalette.cyan))),
                    const SizedBox(height: 16),

                    // ───────────────────────────────────────────────────────────
                    // 6. CITY SELECTOR + TREND CHART
                    // ───────────────────────────────────────────────────────────
                    if (levels.isNotEmpty) ...[
                      _SectionHeader('River Trend'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: levels.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 7),
                          itemBuilder: (ctx, i) {
                            final city = levels[i].city;
                            final sel  = city == _selectedCity;
                            final clr  = _riskColor(levels[i].riskLevel);
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCity = city),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 0),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: sel
                                      ? clr.withValues(alpha: 0.15)
                                      : AppPalette.navy3,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                  border: Border.all(
                                    color: sel
                                        ? clr.withValues(alpha: 0.7)
                                        : AppPalette.navyStroke,
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (sel) ...[
                                      Container(
                                        width: 6, height: 6,
                                        decoration: BoxDecoration(
                                          color: clr,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(city,
                                        style: TextStyle(
                                          color: sel
                                              ? clr
                                              : AppPalette.textGrey,
                                          fontSize: 12,
                                          fontWeight: sel
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        )),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (selected != null)
                      RepaintBoundary(
                        child: _TrendCard(
                          city:         selected.city,
                          history:      _service.trendForCity(selected.city),
                          dangerLevel:  selected.dangerLevel,
                          warningLevel: selected.warningLevel,
                          isLiveData:   isBackendLive || hasCwcLive,
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ───────────────────────────────────────────────────────────
                    // 7. CWC STATION STRIP
                    // ───────────────────────────────────────────────────────────
                    if (cwcStations.isNotEmpty) ...[
                      _SectionHeader('⚠ CWC Stations · Above Warning'),
                      const SizedBox(height: 8),
                      _CwcStationStrip(
                          stations: cwcStations.take(6).toList()),
                      const SizedBox(height: 16),
                    ],

                    // ───────────────────────────────────────────────────────────
                    // 8. CITY CARDS SECTION HEADER
                    // ───────────────────────────────────────────────────────────
                    if (levels.isNotEmpty)
                      _SectionHeader('River Monitor · ${levels.length} Cities'),
                    if (levels.isNotEmpty)
                      const SizedBox(height: 10),
                  ]),
                ),
              ),

              // ─────────────────────────────────────────────────────────────────
              // 9. CITY CARDS GRID  [A+B] 2-column
              // ─────────────────────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:   2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing:  10,
                    childAspectRatio: 0.88,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _CityGridCard(data: levels[i]),
                    childCount: levels.length,
                  ),
                ),
              ),

              // ─────────────────────────────────────────────────────────────────
              // 10. RISK HEATMAP
              // ─────────────────────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader('State Risk Matrix'),
                      const SizedBox(height: 10),
                      RiskHeatmap(
                          stateRisks: _stateRiskMap(levels)),
                    ],
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

// ───────────────────────────────────────────────────────────────────────────────
//  SECTION 1 — Alert Hero Strip
// ───────────────────────────────────────────────────────────────────────────────
class _AlertHeroStrip extends StatelessWidget {
  final String  worstLevel;
  final int     critCount;
  final int     warnCount;
  final bool    isConnecting;
  final bool    isOffline;
  final Animation<double> pulseAnim;

  const _AlertHeroStrip({
    required this.worstLevel, required this.critCount,
    required this.warnCount,  required this.isConnecting,
    required this.isOffline,  required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;
    final String title;
    final String sub;

    if (isOffline) {
      bg = const Color(0xFF1A0A0A);
      fg = AppPalette.critical;
      icon = Icons.wifi_off_rounded;
      title = 'NO CONNECTION';
      sub = 'Showing cached data — pull down to retry';
    } else if (worstLevel == 'CRITICAL' || critCount > 0) {
      bg = const Color(0xFF1A0408);
      fg = AppPalette.critical;
      icon = Icons.warning_rounded;
      title = 'CRITICAL ALERT — $critCount ${critCount == 1 ? "CITY" : "CITIES"}';
      sub = 'River levels above danger threshold';
    } else if (worstLevel == 'HIGH' || worstLevel == 'MODERATE' || warnCount > 0) {
      bg = const Color(0xFF1A1000);
      fg = AppPalette.warning;
      icon = Icons.notifications_active_rounded;
      title = 'WARNING — $warnCount ${warnCount == 1 ? "LOCATION" : "LOCATIONS"}';
      sub = 'Elevated river levels detected';
    } else if (isConnecting) {
      bg = const Color(0xFF0A0F1A);
      fg = AppPalette.cyan;
      icon = Icons.radar_rounded;
      title = 'CONNECTING TO LIVE FEED';
      sub = 'CWC FFEM / GloFAS endpoints being queried…';
    } else {
      bg = const Color(0xFF041A0A);
      fg = AppPalette.safe;
      icon = Icons.check_circle_rounded;
      title = 'ALL CLEAR';
      sub = 'No active flood warnings across monitored cities';
    }

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) {
        final pulse = (worstLevel == 'CRITICAL' || critCount > 0)
            ? pulseAnim.value
            : 1.0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              bottom: BorderSide(
                  color: fg.withValues(alpha: 0.5 * pulse), width: 1.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: fg.withValues(alpha: pulse), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        )),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                            color: AppPalette.textGrey,
                            fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
//  SECTION 3 — Live Stat Row
// ───────────────────────────────────────────────────────────────────────────────
class _LiveStatRow extends StatelessWidget {
  final int totalCities;
  final int healthyPct;
  final int warnCount;
  final int critCount;

  const _LiveStatRow({
    required this.totalCities,
    required this.healthyPct,
    required this.warnCount,
    required this.critCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
            icon: Icons.location_city_rounded,
            value: '$totalCities',
            label: 'CITIES',
            color: AppPalette.cyan),
        const SizedBox(width: 8),
        _StatChip(
            icon: Icons.check_circle_outline_rounded,
            value: '$healthyPct%',
            label: 'HEALTHY',
            color: AppPalette.safe),
        const SizedBox(width: 8),
        _StatChip(
            icon: Icons.notification_important_outlined,
            value: '$warnCount',
            label: 'WARNING',
            color: AppPalette.warning),
        const SizedBox(width: 8),
        _StatChip(
            icon: Icons.dangerous_outlined,
            value: '$critCount',
            label: 'CRITICAL',
            color: AppPalette.critical),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;

  const _StatChip({
    required this.icon, required this.value,
    required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.5,
                )),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                )),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
//  SECTION 4 — India Map Preview Card  [C]
// ───────────────────────────────────────────────────────────────────────────────
class _MapPreviewCard extends StatelessWidget {
  final List<Map<String, String>> stateRisks;
  const _MapPreviewCard({required this.stateRisks});

  @override
  Widget build(BuildContext context) {
    final critStates = stateRisks
        .where((r) => r['risk'] == 'CRITICAL')
        .map((r) => r['state'] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final warnStates = stateRisks
        .where((r) => r['risk'] == 'HIGH' || r['risk'] == 'MODERATE')
        .map((r) => r['state'] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const IndiaRiversScreen(),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.navy2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.navyStroke, width: 1),
        ),
        child: Row(
          children: [
            // Map icon block
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppPalette.cyan.withValues(alpha: 0.12),
                    AppPalette.cyan.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppPalette.cyan.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(Icons.map_rounded,
                  color: AppPalette.cyan, size: 32),
            ),
            const SizedBox(width: 14),
            // State risk summary
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('India River Map',
                      style: TextStyle(
                        color: AppPalette.textWhite,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    critStates.isNotEmpty
                        ? '⚠️ Critical: ${critStates.take(3).join(", ")}'
                            '${critStates.length > 3 ? " +${critStates.length - 3} more" : ""}'
                        : warnStates.isNotEmpty
                            ? '⚠ Warning: ${warnStates.take(3).join(", ")}'
                            : '✅ No active alerts',
                    style: TextStyle(
                      color: critStates.isNotEmpty
                          ? AppPalette.critical
                          : warnStates.isNotEmpty
                              ? AppPalette.warning
                              : AppPalette.safe,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Tap to explore all rivers →',
                      style: TextStyle(
                          color: AppPalette.textGrey, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppPalette.textDim, size: 22),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
//  SECTION 9 — City Grid Card  [A+B]
// ───────────────────────────────────────────────────────────────────────────────
class _CityGridCard extends StatelessWidget {
  final FloodData data;
  const _CityGridCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _riskColor(data.riskLevel);
    final double pct        = data.capacityPercent.clamp(0.0, 1.0);
    final bool   isRising   = data.status == 'RISING';
    final bool   isFalling  = data.status == 'FALLING';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.navy2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.06),
            blurRadius: 12, offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // City name + risk badge row
          Row(
            children: [
              Expanded(
                child: Text(data.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.textWhite,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    )),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.riskLevel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            data.riverName ?? data.state,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppPalette.textGrey, fontSize: 10),
          ),

          const Spacer(),

          // Level value + trend icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.currentLevel > 0
                    ? data.currentLevel.toStringAsFixed(2)
                    : (pct * 100).toStringAsFixed(0),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3, left: 3),
                child: Text(
                  data.currentLevel > 0 ? ' m' : '%',
                  style: const TextStyle(
                      color: AppPalette.textGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Icon(
                isRising
                    ? Icons.trending_up_rounded
                    : isFalling
                        ? Icons.trending_down_rounded
                        : Icons.trending_flat_rounded,
                color: isRising
                    ? AppPalette.danger
                    : isFalling
                        ? AppPalette.safe
                        : AppPalette.textGrey,
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Gauge bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:          pct,
              minHeight:      6,
              backgroundColor: AppPalette.navy4,
              valueColor:      AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),

          const SizedBox(height: 6),

          // DL label
          if (data.dangerLevel > 0)
            Text(
              'DL ${data.dangerLevel.toStringAsFixed(1)} m',
              style: const TextStyle(
                  color: AppPalette.textDim, fontSize: 9),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
//  Shared helpers
// ───────────────────────────────────────────────────────────────────────────────

Color _riskColor(String level) {
  switch (level) {
    case 'CRITICAL': return AppPalette.critical;
    case 'HIGH':     return AppPalette.danger;
    case 'MODERATE': return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}

class _GaugeLegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _GaugeLegendDot(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: AppPalette.textGrey, fontSize: 9)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          color: AppPalette.textWhite,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: -0.3,
        ));
  }
}

// ───────────────────────────────────────────────────────────────────────────────
//  Status Pill
// ───────────────────────────────────────────────────────────────────────────────
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
        ? AppPalette.safe
        : isConnecting ? AppPalette.cyan
        : isOffline    ? AppPalette.critical
        : AppPalette.textGrey;
    final String label = isCwcLive    ? 'CWC LIVE'
        : isLive       ? 'LIVE'
        : isConnecting ? 'SYNC'
        : isOffline    ? 'OFFLINE'
        : 'STANDBY';
    final bool pulsing = isConnecting || isCwcLive;

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: color.withValues(alpha: 0.40), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: color.withValues(
                    alpha: pulsing ? pulseAnim.value : 1.0),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 4)
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
//  CWC Station Strip
// ───────────────────────────────────────────────────────────────────────────────
class _CwcStationStrip extends StatelessWidget {
  final List<dynamic> stations;
  const _CwcStationStrip({required this.stations});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount:       stations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = stations[i];
          final isCrit = (s is Map ? s['source'] : null)
                  ?.toString().contains('CRITICAL') == true;
          final Color col = isCrit
              ? AppPalette.critical
              : AppPalette.warning;

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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.navy2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: col.withValues(alpha: 0.40), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name.isNotEmpty ? name : 'Station ${i + 1}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppPalette.textWhite,
                        fontWeight: FontWeight.w700, fontSize: 12)),
                Text(state.isNotEmpty ? state : 'India',
                    style: const TextStyle(
                        color: AppPalette.textGrey, fontSize: 10)),
                if (river.isNotEmpty)
                  Text(river, maxLines: 1,
                      style: TextStyle(
                          color: AppPalette.textGrey.withValues(alpha: 0.6),
                          fontSize: 9)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      level > 0
                          ? '${level.toStringAsFixed(2)} m'
                          : '—',
                      style: TextStyle(
                          color: col,
                          fontWeight: FontWeight.w900,
                          fontSize: 15),
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
                    Expanded(
                      child: Text(
                        danger > 0
                            ? 'DL ${danger.toStringAsFixed(1)} m'
                            : warning > 0
                                ? 'WL ${warning.toStringAsFixed(1)} m'
                                : '',
                        style: const TextStyle(
                            color: AppPalette.textGrey, fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

// ───────────────────────────────────────────────────────────────────────────────
//  Debug Panel
// ───────────────────────────────────────────────────────────────────────────────
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
          const Text('🔎 Debug',
              style: TextStyle(
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

// ───────────────────────────────────────────────────────────────────────────────
//  Trend Chart
// ───────────────────────────────────────────────────────────────────────────────
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
    final sorted = List<RiverLevelSnapshot>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final pts = sorted.length > 24
        ? sorted.sublist(sorted.length - 24)
        : sorted;

    final useFlow = pts.isNotEmpty && pts.every((p) => p.level == 0);
    final spots   = List.generate(
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
      height: 226,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppPalette.navy2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.navyStroke, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$city · 7-day ($yLabel)',
                  style: const TextStyle(
                      color: AppPalette.textWhite,
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (isLiveData
                          ? AppPalette.safe
                          : AppPalette.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (isLiveData
                            ? AppPalette.safe
                            : AppPalette.warning)
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  isLiveData ? '● LIVE' : '⚠ EST',
                  style: TextStyle(
                    color: isLiveData ? AppPalette.safe : AppPalette.warning,
                    fontSize: 9, fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: spots.length < 2
                ? const Center(
                    child: Text(
                      'History populates once live data arrives',
                      style: TextStyle(color: AppPalette.textGrey),
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
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: AppPalette.navyStroke,
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
                            style: const TextStyle(
                                color: AppPalette.textGrey, fontSize: 9),
                          ),
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
                                return const Text('7d ago',
                                    style: TextStyle(
                                        color: AppPalette.textGrey,
                                        fontSize: 9));
                              if (v ==
                                  ((spots.length - 1) / 2)
                                      .roundToDouble())
                                return const Text('3d ago',
                                    style: TextStyle(
                                        color: AppPalette.textGrey,
                                        fontSize: 9));
                              if (v == (spots.length - 1).toDouble())
                                return const Text('Now',
                                    style: TextStyle(
                                        color: AppPalette.textGrey,
                                        fontSize: 9));
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                            color: AppPalette.navyStroke, width: 1),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots:    spots,
                          isCurved: true,
                          color:    AppPalette.cyan,
                          barWidth: 2.5,
                          dotData:  const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end:   Alignment.bottomCenter,
                              colors: [
                                AppPalette.cyan.withValues(alpha: 0.25),
                                AppPalette.cyan.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ],
                      extraLinesData: ExtraLinesData(
                        horizontalLines: useFlow ? [] : [
                          HorizontalLine(
                            y: warningLevel,
                            color: AppPalette.warning,
                            strokeWidth: 1.2,
                            dashArray: [4, 4],
                          ),
                          HorizontalLine(
                            y: dangerLevel,
                            color: AppPalette.danger,
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
