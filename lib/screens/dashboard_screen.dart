// lib/screens/dashboard_screen.dart
// EQUINOX-BH — Dashboard v5.4
//
// v5.4:
//   • App name renamed Equinox-BBR05 → EQUINOX-BR05 (AppBar title + status banner)
// v5.3:
//   • App name renamed OpsFlood → Equinox-BBR05 (AppBar title + status banner)
//   • Safe KPI count now includes LOW risk level to match _AlertColorStrip
//     (was only counting NORMAL and SAFE, missing LOW → showed wrong number)
library;

import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../providers/bihar_dashboard_provider.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/nearby_stations_provider.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import 'dashboard_screen_part2.dart';
import 'main_shell.dart';
import 'alerts_screen.dart';
import 'live_stations_screen.dart';
import 'river_monitor_screen.dart';
import 'city_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _riskColor(String level) {
  switch (level.toUpperCase()) {
    case 'CRITICAL': return AppPalette.critical;
    case 'SEVERE':   return AppPalette.danger;
    case 'MODERATE':
    case 'WARNING':  return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}

IconData _riskIcon(String level) {
  switch (level.toUpperCase()) {
    case 'CRITICAL': return Icons.warning_rounded;
    case 'SEVERE':   return Icons.warning_amber_rounded;
    case 'MODERATE':
    case 'WARNING':  return Icons.info_rounded;
    default:         return Icons.check_circle_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alert level colours — single source of truth matching the map legend
// ─────────────────────────────────────────────────────────────────────────────

const _kCriticalColor  = Color(0xFFFF3B30);
const _kSevereColor    = Color(0xFFFF6B35);
const _kWarningColor   = Color(0xFFFFCC00);
const _kSafeColor      = Color(0xFF34C759);
const _kNoDataColor    = Color(0xFF8E8E93);

// ─────────────────────────────────────────────────────────────────────────────
// Safe-bucket helper — single source of truth used by both _KpiGrid and
// _AlertColorStrip so the two widgets always show the same number.
// ─────────────────────────────────────────────────────────────────────────────
bool _isSafe(String riskLevel) {
  switch (riskLevel.toUpperCase()) {
    case 'NORMAL':
    case 'SAFE':
    case 'LOW':
      return true;
    default:
      return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DashboardScreen
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  static const String route = '/dashboard';
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {

  late AnimationController _gaugeCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _gaugeAnim;

  Timer?  _autoRefreshTimer;
  bool    _reduceMotion  = false;
  bool    _isRefreshing  = false;
  bool    _nearbyBooted  = false;
  bool    _bannerDismissed = false;

  @override
  void initState() {
    super.initState();

    _gaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _gaugeAnim = CurvedAnimation(
        parent: _gaugeCtrl, curve: Curves.easeOutCubic);
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _gaugeCtrl.forward();
        _entryCtrl.forward();
        _bootNearby();
      }
    });

    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) { if (mounted) _onRefresh(); },
    );
  }

  Future<void> _bootNearby() async {
    if (_nearbyBooted) return;
    _nearbyBooted = true;
    await ref.read(nearbyStationsProvider.notifier).refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) { _waveCtrl.stop(); _pulseCtrl.stop(); }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _gaugeCtrl.dispose();
    _waveCtrl.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    _gaugeCtrl.reset(); _entryCtrl.reset();
    try {
      await Future.wait([
        ref.read(realTimeProvider).refreshData(),
        ref.read(biharLiveProvider.notifier).refresh(),
      ]);
      _nearbyBooted = false;
      await _bootNearby();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _gaugeCtrl.forward(); _entryCtrl.forward();
      }
    }
  }

  void _goAlerts()        => MainShell.jumpTo(context, 2);
  void _goMap()           => MainShell.jumpTo(context, 1);
  void _goRiverMonitor()  => Navigator.pushNamed(context, RiverMonitorScreen.route);
  void _goLiveStations()  => Navigator.pushNamed(context, LiveStationsScreen.route);
  void _goCityDetail(FloodData d) =>
      Navigator.pushNamed(context, '/city_detail', arguments: d.city);

  @override
  Widget build(BuildContext context) {
    final t          = RiverColors.of(context);
    final service    = ref.watch(realTimeProvider);
    final liveLevels = ref.watch(liveLevelsProvider);
    final critCount  = ref.watch(criticalCountProvider);
    final isOffline  = ref.watch(isOfflineProvider);
    final isWakingUp = ref.watch(isWakingUpProvider);

    final biharCount     = ref.watch(biharStationCountProvider);
    final biharCritical  = ref.watch(biharCriticalCountProvider);
    final biharWarning   = ref.watch(biharWarningCountProvider);
    final biharRainfall  = ref.watch(biharAvgRainfallProvider);
    final biharDischarge = ref.watch(biharAvgDischargeProvider);
    final biharAlerts    = ref.watch(biharTopAlertsProvider);
    final biharLoading   = ref.watch(biharIsLoadingProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: RefreshIndicator(
        color: t.accent,
        backgroundColor: t.cardBg,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            _DashboardAppBar(
              t: t,
              criticalCount: critCount,
              isOffline: isOffline,
              isWakingUp: isWakingUp,
              pulseCtrl: _pulseCtrl,
              lastUpdated: service.lastFetchTime,
              onRefresh: _onRefresh,
              onAlertsTap: _goAlerts,
            ),

            if (critCount > 0 && !_bannerDismissed)
              SliverToBoxAdapter(
                child: _CriticalBanner(
                  count: critCount,
                  onView: _goAlerts,
                  onDismiss: () => setState(() => _bannerDismissed = true),
                ),
              ),

            if (isOffline || isWakingUp)
              SliverToBoxAdapter(
                child: _StatusBanner(
                    t: t, isOffline: isOffline, isWakingUp: isWakingUp)),

            if (service.isLoading && liveLevels.isEmpty)
              SliverToBoxAdapter(child: _LoadingSkeleton(t: t))
            else if (liveLevels.isEmpty)
              const SliverToBoxAdapter(child: DashboardEmptyState())
            else ...[

              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: _goMap,
                  child: _HeroGauge(
                    t: t,
                    levels: liveLevels,
                    criticalCount: critCount,
                    gaugeAnim: _gaugeAnim,
                    pulseCtrl: _pulseCtrl,
                    reduceMotion: _reduceMotion,
                    onAlertsTap: _goAlerts,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _KpiGrid(
                  t: t,
                  levels: liveLevels,
                  criticalCount: critCount,
                  gaugeAnim: _gaugeAnim,
                  entryCtrl: _entryCtrl,
                  reduceMotion: _reduceMotion,
                  onAlertsTap: _goAlerts,
                  onStationsTap: _goLiveStations,
                  onSafeTap: _goLiveStations,
                ),
              ),

              SliverToBoxAdapter(
                child: _AlertColorStrip(
                  t: t,
                  levels: liveLevels,
                  onAlertsTap: _goAlerts,
                  onSafeTap: _goLiveStations,
                ),
              ),

              const SliverToBoxAdapter(
                child: NearbyStationsSection(),
              ),

              SliverToBoxAdapter(
                child: _SectionHeader(
                  label: 'BIHAR LIVE',
                  icon: Icons.water_drop_rounded,
                  color: AppPalette.cyan,
                  t: t,
                  onSeeAll: _goRiverMonitor,
                ),
              ),
              SliverToBoxAdapter(
                child: _BiharLivePanel(
                  t: t,
                  stationCount:   biharCount,
                  criticalCount:  biharCritical,
                  warningCount:   biharWarning,
                  avgRainfall:    biharRainfall,
                  avgDischarge:   biharDischarge,
                  topAlerts:      biharAlerts,
                  isLoading:      biharLoading,
                  onStationsTap:  _goRiverMonitor,
                  onAlertsTap:    _goAlerts,
                ),
              ),

              SliverToBoxAdapter(
                child: _SectionHeader(
                  label: 'ACTIVE ALERTS',
                  icon: Icons.warning_rounded,
                  color: AppPalette.critical,
                  t: t,
                  onSeeAll: _goAlerts,
                ),
              ),
              SliverToBoxAdapter(
                child: AlertLog(
                  data: liveLevels
                      .where((d) =>
                          d.riskLevel.toUpperCase() == 'CRITICAL' ||
                          d.riskLevel.toUpperCase() == 'SEVERE')
                      .toList(),
                  entryCtrl: _entryCtrl,
                ),
              ),

              SliverToBoxAdapter(
                child: _SectionHeader(
                  label: 'MONITORED STATIONS',
                  icon: Icons.sensors_rounded,
                  color: t.accent,
                  t: t,
                  onSeeAll: _goLiveStations,
                ),
              ),
              SliverList.builder(
                itemCount: liveLevels.length,
                itemBuilder: (ctx, i) => _StationTile(
                  data: liveLevels[i],
                  index: i,
                  entryCtrl: _entryCtrl,
                  gaugeAnim: _gaugeAnim,
                  t: t,
                  reduceMotion: _reduceMotion,
                  onTap: () => _goCityDetail(liveLevels[i]),
                ),
              ),

              SliverToBoxAdapter(
                child: _SectionHeader(
                  label: 'CAPACITY TREND',
                  icon: Icons.area_chart_rounded,
                  color: t.accent,
                  t: t,
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedAreaChart(
                  values: liveLevels
                      .map((d) => d.capacityPercent.clamp(0.0, 100.0))
                      .toList(),
                  labels: liveLevels.map((d) => d.city).toList(),
                  gaugeAnim: _gaugeAnim,
                  waveCtrl: _waveCtrl,
                  reduceMotion: _reduceMotion,
                ),
              ),

              SliverToBoxAdapter(
                child: _SectionHeader(
                  label: 'DATA SOURCES',
                  icon: Icons.hub_rounded,
                  color: t.accent,
                  t: t,
                ),
              ),
              SliverToBoxAdapter(
                child: SystemStats(
                  service: service,
                  pulseCtrl: _pulseCtrl,
                  gaugeAnim: _gaugeAnim,
                  reduceMotion: _reduceMotion,
                ),
              ),

              SliverToBoxAdapter(
                child: DashboardFooter(
                  totalStations: liveLevels.length,
                  riversCount: liveLevels
                      .map((d) => d.riverName)
                      .whereType<String>()
                      .toSet()
                      .length,
                  statesAtRisk: liveLevels
                      .where((d) =>
                          d.riskLevel.toUpperCase() == 'CRITICAL' ||
                          d.riskLevel.toUpperCase() == 'SEVERE')
                      .map((d) => d.state)
                      .toSet()
                      .length,
                  lastUpdated: service.lastFetchTime,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AlertColorStrip
// ─────────────────────────────────────────────────────────────────────────────

class _AlertColorStrip extends StatelessWidget {
  final RiverColors    t;
  final List<FloodData> levels;
  final VoidCallback   onAlertsTap;
  final VoidCallback   onSafeTap;

  const _AlertColorStrip({
    required this.t,
    required this.levels,
    required this.onAlertsTap,
    required this.onSafeTap,
  });

  @override
  Widget build(BuildContext context) {
    int critical = 0, severe = 0, warning = 0, safe = 0, noData = 0;
    for (final d in levels) {
      switch (d.riskLevel.toUpperCase()) {
        case 'CRITICAL':
        case 'DANGER':   critical++; break;
        case 'SEVERE':   severe++;   break;
        case 'MODERATE':
        case 'WARNING':
        case 'HIGH':     warning++;  break;
        case 'NORMAL':
        case 'SAFE':
        case 'LOW':      safe++;     break;
        default:         noData++;   break;
      }
    }

    final items = [
      _StripItem(color: _kCriticalColor, label: 'Critical',  count: critical, icon: Icons.warning_rounded,       onTap: onAlertsTap, pulse: critical > 0),
      _StripItem(color: _kSevereColor,   label: 'Severe',    count: severe,   icon: Icons.warning_amber_rounded,  onTap: onAlertsTap, pulse: severe > 0),
      _StripItem(color: _kWarningColor,  label: 'Warning',   count: warning,  icon: Icons.info_rounded,           onTap: onAlertsTap),
      _StripItem(color: _kSafeColor,     label: 'Safe',      count: safe,     icon: Icons.check_circle_rounded,   onTap: onSafeTap),
      _StripItem(color: _kNoDataColor,   label: 'No data',   count: noData,   icon: Icons.help_outline_rounded,   onTap: onSafeTap),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.stroke),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(width: 1, height: 36, color: t.stroke),
              Expanded(child: _StripCell(item: items[i], t: t)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StripItem {
  final Color      color;
  final String     label;
  final int        count;
  final IconData   icon;
  final VoidCallback onTap;
  final bool       pulse;
  const _StripItem({
    required this.color,
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
    this.pulse = false,
  });
}

class _StripCell extends StatelessWidget {
  final _StripItem  item;
  final RiverColors t;
  const _StripCell({required this.item, required this.t});

  @override
  Widget build(BuildContext context) {
    final isActive = item.count > 0;
    final dotColor = isActive ? item.color : item.color.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        item.onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28, height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (item.pulse && isActive)
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: item.color.withValues(alpha: 0.30),
                        width: 2,
                      ),
                    ),
                  ),
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: isActive ? 0.80 : 0.30),
                      width: 1.5,
                    ),
                    boxShadow: isActive ? [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.45),
                        blurRadius: 6,
                        spreadRadius: item.pulse ? 1 : 0,
                      ),
                    ] : null,
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${item.count}',
            style: TextStyle(
              color: isActive ? item.color : t.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CriticalBanner
// ─────────────────────────────────────────────────────────────────────────────

class _CriticalBanner extends StatelessWidget {
  final int count;
  final VoidCallback onView;
  final VoidCallback onDismiss;
  const _CriticalBanner({
    required this.count,
    required this.onView,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.critical.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.critical.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: AppPalette.critical, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count station${count > 1 ? 's' : ''} at CRITICAL level right now',
              style: const TextStyle(
                color: AppPalette.critical,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onView,
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.critical,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View →',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: AppPalette.critical, size: 16),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BiharLivePanel
// ─────────────────────────────────────────────────────────────────────────────

class _BiharLivePanel extends StatelessWidget {
  final RiverColors t;
  final int stationCount, criticalCount, warningCount;
  final double? avgRainfall, avgDischarge;
  final List<BiharStationData> topAlerts;
  final bool isLoading;
  final VoidCallback onStationsTap;
  final VoidCallback onAlertsTap;

  const _BiharLivePanel({
    required this.t,
    required this.stationCount,
    required this.criticalCount,
    required this.warningCount,
    required this.avgRainfall,
    required this.avgDischarge,
    required this.topAlerts,
    required this.isLoading,
    required this.onStationsTap,
    required this.onAlertsTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Center(
          child: SizedBox(
            height: 36, width: 36,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppPalette.cyan),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: onStationsTap,
                  child: _BiharChip(
                      icon: Icons.sensors_rounded,
                      label: '$stationCount Stations',
                      color: AppPalette.cyan),
                ),
                const SizedBox(width: 8),
                if (criticalCount > 0) ...[
                  GestureDetector(
                    onTap: onAlertsTap,
                    child: _BiharChip(
                        icon: Icons.warning_rounded,
                        label: '$criticalCount Critical',
                        color: AppPalette.danger),
                  ),
                  const SizedBox(width: 8),
                ],
                if (warningCount > 0) ...[
                  GestureDetector(
                    onTap: onAlertsTap,
                    child: _BiharChip(
                        icon: Icons.info_outline_rounded,
                        label: '$warningCount Warning',
                        color: AppPalette.warning),
                  ),
                  const SizedBox(width: 8),
                ],
                if (avgRainfall != null)
                  _BiharChip(
                      icon: Icons.grain,
                      label: '${avgRainfall!.toStringAsFixed(1)} mm avg rain',
                      color: Colors.lightBlue),
                const SizedBox(width: 8),
                if (avgDischarge != null)
                  _BiharChip(
                      icon: Icons.water,
                      label: '${_fmt(avgDischarge!)} m³/s GloFAS',
                      color: AppPalette.cyan),
              ],
            ),
          ),
          if (topAlerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...topAlerts.map((s) => GestureDetector(
                  onTap: onAlertsTap,
                  child: _BiharAlertRow(t: t, station: s),
                )),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.safe.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppPalette.safe.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppPalette.safe, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'All Bihar stations within safe limits',
                    style: TextStyle(
                        color: AppPalette.safe,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _BiharChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _BiharChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BiharAlertRow extends StatelessWidget {
  final RiverColors t;
  final BiharStationData station;
  const _BiharAlertRow({required this.t, required this.station});

  @override
  Widget build(BuildContext context) {
    final s     = station;
    final color = s.isCritical ? AppPalette.danger : AppPalette.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
              s.isCritical
                  ? Icons.warning_rounded
                  : Icons.info_outline_rounded,
              color: color,
              size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.city,
                    style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(
                  [s.river, s.district]
                      .where((v) => v.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(color: t.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (s.currentLevel != null)
                Text(
                  '${s.currentLevel!.toStringAsFixed(2)} m',
                  style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
              if (s.discharge != null)
                Text('${_fmt(s.discharge!)} m³/s',
                    style: const TextStyle(
                        color: AppPalette.cyan, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(s.riskLabel,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DashboardAppBar
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardAppBar extends StatelessWidget {
  final RiverColors t;
  final int criticalCount;
  final bool isOffline, isWakingUp;
  final AnimationController pulseCtrl;
  final DateTime? lastUpdated;
  final VoidCallback onRefresh;
  final VoidCallback onAlertsTap;

  const _DashboardAppBar({
    required this.t,
    required this.criticalCount,
    required this.isOffline,
    required this.isWakingUp,
    required this.pulseCtrl,
    required this.lastUpdated,
    required this.onRefresh,
    required this.onAlertsTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = isWakingUp
        ? 'Connecting to servers…'
        : isOffline
            ? 'Offline — cached data'
            : lastUpdated != null
                ? 'Updated ${DateFormat('HH:mm').format(lastUpdated!)}'
                : 'Fetching live data…';

    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: true,
      expandedHeight: 56,
      backgroundColor: t.scaffoldBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: t.stroke,
      title: Row(
        children: [
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOffline
                    ? AppPalette.warning
                    : criticalCount > 0
                        ? AppPalette.critical
                            .withValues(alpha: 0.5 + pulseCtrl.value * 0.5)
                        : AppPalette.safe
                            .withValues(alpha: 0.5 + pulseCtrl.value * 0.5),
                boxShadow: isOffline
                    ? null
                    : [
                        BoxShadow(
                          color: (criticalCount > 0
                                  ? AppPalette.critical
                                  : AppPalette.safe)
                              .withValues(alpha: pulseCtrl.value * 0.7),
                          blurRadius: 10,
                        ),
                      ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EQUINOX-BR05',   // v5.4: renamed from Equinox-BBR05
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(subtitle,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ],
      ),
      actions: [
        if (criticalCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: onAlertsTap,
              child: _CriticalBadge(count: criticalCount),
            ),
          ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: t.accent, size: 22),
          tooltip: 'Refresh now',
          onPressed: onRefresh,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CriticalBadge
// ─────────────────────────────────────────────────────────────────────────────

class _CriticalBadge extends StatelessWidget {
  final int count;
  const _CriticalBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppPalette.critical.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.critical.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_rounded,
              color: AppPalette.critical, size: 13),
          const SizedBox(width: 4),
          Text('$count critical',
              style: const TextStyle(
                  color: AppPalette.critical,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusBanner
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final RiverColors t;
  final bool isOffline, isWakingUp;
  const _StatusBanner(
      {required this.t,
      required this.isOffline,
      required this.isWakingUp});

  @override
  Widget build(BuildContext context) {
    final color = isOffline ? AppPalette.warning : t.accent;
    final msg   = isOffline
        ? 'No internet — showing last cached data'
        : 'Connecting to EQUINOX-BR05 servers…';  // v5.4: renamed
    final icon =
        isOffline ? Icons.wifi_off_rounded : Icons.cloud_sync_rounded;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
          if (isWakingUp)
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeroGauge
// ─────────────────────────────────────────────────────────────────────────────

class _HeroGauge extends StatelessWidget {
  final RiverColors t;
  final List<FloodData> levels;
  final int criticalCount;
  final Animation<double> gaugeAnim;
  final AnimationController pulseCtrl;
  final bool reduceMotion;
  final VoidCallback onAlertsTap;

  const _HeroGauge({
    required this.t,
    required this.levels,
    required this.criticalCount,
    required this.gaugeAnim,
    required this.pulseCtrl,
    required this.reduceMotion,
    required this.onAlertsTap,
  });

  @override
  Widget build(BuildContext context) {
    final avgCap = levels.isEmpty
        ? 0.0
        : levels
                .map((d) => d.capacityPercent)
                .reduce((a, b) => a + b) /
            levels.length;
    final gaugeColor = avgCap > 80
        ? AppPalette.critical
        : avgCap > 60
            ? AppPalette.warning
            : AppPalette.safe;
    final statusLabel = criticalCount > 0
        ? '$criticalCount CRITICAL'
        : avgCap > 80
            ? 'HIGH RISK'
            : avgCap > 60
                ? 'ELEVATED'
                : 'ALL CLEAR';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gaugeColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: gaugeColor.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: gaugeAnim,
            builder: (_, __) => SizedBox(
              height: 140,
              child: CustomPaint(
                painter: _ArcGaugePainter(
                    value: avgCap / 100 * gaugeAnim.value,
                    color: gaugeColor,
                    trackColor: t.stroke),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        '${(avgCap * gaugeAnim.value).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          letterSpacing: -1,
                        ),
                      ),
                      Text('AVG CAPACITY',
                          style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: criticalCount > 0 ? onAlertsTap : null,
            child: AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: gaugeColor.withValues(
                      alpha: reduceMotion
                          ? 0.12
                          : 0.08 + pulseCtrl.value * 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: gaugeColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        _riskIcon(criticalCount > 0
                            ? 'CRITICAL'
                            : avgCap > 80
                                ? 'SEVERE'
                                : 'NORMAL'),
                        color: gaugeColor,
                        size: 13),
                    const SizedBox(width: 6),
                    Text(statusLabel,
                        style: TextStyle(
                            color: gaugeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                    if (criticalCount > 0) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          color: gaugeColor, size: 11),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _GaugeSubStat(
                  t: t,
                  label: 'STATIONS',
                  value: '${levels.length}',
                  icon: Icons.sensors_rounded),
              _GaugeDivider(t: t),
              _GaugeSubStat(
                  t: t,
                  label: 'RIVERS',
                  value:
                      '${levels.map((d) => d.riverName).whereType<String>().toSet().length}',
                  icon: Icons.water_rounded),
              _GaugeDivider(t: t),
              _GaugeSubStat(
                  t: t,
                  label: 'STATES',
                  value: '${levels.map((d) => d.state).toSet().length}',
                  icon: Icons.map_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugeSubStat extends StatelessWidget {
  final RiverColors t;
  final String label, value;
  final IconData icon;
  const _GaugeSubStat(
      {required this.t,
      required this.label,
      required this.value,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: t.textSecondary, size: 14),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()])),
        Text(label,
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ],
    );
  }
}

class _GaugeDivider extends StatelessWidget {
  final RiverColors t;
  const _GaugeDivider({required this.t});
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: t.stroke);
}

class _ArcGaugePainter extends CustomPainter {
  final double value;
  final Color color, trackColor;
  const _ArcGaugePainter(
      {required this.value,
      required this.color,
      required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.85;
    final radius = math.min(cx, cy) * 0.92;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.5), color],
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
      ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);
    if (value > 0)
      canvas.drawArc(
          rect, startAngle, sweepAngle * value, false, valuePaint);
    if (value > 0.02) {
      final tipAngle = startAngle + sweepAngle * value;
      canvas.drawCircle(
          Offset(cx + radius * math.cos(tipAngle),
              cy + radius * math.sin(tipAngle)),
          8,
          Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.value != value || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// _KpiGrid
// ─────────────────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final RiverColors t;
  final List<FloodData> levels;
  final int criticalCount;
  final Animation<double> gaugeAnim;
  final AnimationController entryCtrl;
  final bool reduceMotion;
  final VoidCallback onAlertsTap;
  final VoidCallback onStationsTap;
  final VoidCallback onSafeTap;

  const _KpiGrid({
    required this.t,
    required this.levels,
    required this.criticalCount,
    required this.gaugeAnim,
    required this.entryCtrl,
    required this.reduceMotion,
    required this.onAlertsTap,
    required this.onStationsTap,
    required this.onSafeTap,
  });

  @override
  Widget build(BuildContext context) {
    final severeCount = levels
        .where((d) => d.riskLevel.toUpperCase() == 'SEVERE')
        .length;
    final avgCap = levels.isEmpty
        ? 0.0
        : levels
                .map((d) => d.capacityPercent)
                .reduce((a, b) => a + b) /
            levels.length;

    final safeCount = levels.where((d) => _isSafe(d.riskLevel)).length;

    final kpis = [
      _KpiItem(
          label: 'CRITICAL',
          value: '$criticalCount',
          color: AppPalette.critical,
          icon: Icons.warning_rounded,
          onTap: onAlertsTap),
      _KpiItem(
          label: 'SEVERE',
          value: '$severeCount',
          color: AppPalette.danger,
          icon: Icons.warning_amber_rounded,
          onTap: onAlertsTap),
      _KpiItem(
          label: 'AVG CAPACITY',
          value: '${avgCap.toStringAsFixed(0)}%',
          color: avgCap > 80
              ? AppPalette.critical
              : avgCap > 60
                  ? AppPalette.warning
                  : AppPalette.safe,
          icon: Icons.water_rounded,
          onTap: onStationsTap),
      _KpiItem(
          label: 'SAFE',
          value: '$safeCount',
          color: AppPalette.safe,
          icon: Icons.check_circle_rounded,
          onTap: onSafeTap),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.8,
        children: kpis.asMap().entries.map((e) {
          final i   = e.key;
          final kpi = e.value;
          return AnimatedBuilder(
            animation: entryCtrl,
            builder: (_, child) {
              final delay = i * 0.07;
              final p = ((entryCtrl.value - delay) / (1.0 - delay))
                  .clamp(0.0, 1.0);
              return Opacity(
                opacity: reduceMotion ? 1.0 : p,
                child: Transform.translate(
                    offset: Offset(0, reduceMotion ? 0 : 16 * (1 - p)),
                    child: child),
              );
            },
            child: GestureDetector(
              onTap: kpi.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: kpi.color.withValues(alpha: 0.20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kpi.color.withValues(alpha: 0.12),
                        border: Border.all(
                            color: kpi.color.withValues(alpha: 0.30),
                            width: 1.5),
                      ),
                      child: Icon(kpi.icon, color: kpi.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: gaugeAnim,
                            builder: (_, __) {
                              final num = int.tryParse(kpi.value) ??
                                  double.tryParse(kpi.value
                                          .replaceAll('%', ''))
                                      ?.toInt();
                              final displayVal = num != null
                                  ? '${(num * gaugeAnim.value).round()}${kpi.value.contains('%') ? '%' : ''}'
                                  : kpi.value;
                              return Text(displayVal,
                                  style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                      letterSpacing: -0.5));
                            },
                          ),
                          Text(kpi.label,
                              style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: kpi.color.withValues(alpha: 0.5), size: 16),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _KpiItem {
  final String label, value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _KpiItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final RiverColors t;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
    required this.t,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4, height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2)),
          ),
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: t.textPrimary.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('See all',
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  Icon(Icons.arrow_forward_rounded,
                      color: color, size: 13),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StationTile
// ─────────────────────────────────────────────────────────────────────────────

class _StationTile extends StatelessWidget {
  final FloodData data;
  final int index;
  final AnimationController entryCtrl;
  final Animation<double> gaugeAnim;
  final RiverColors t;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _StationTile({
    required this.data,
    required this.index,
    required this.entryCtrl,
    required this.gaugeAnim,
    required this.t,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = _riskColor(data.riskLevel);
    final cap = (data.capacityPercent / 100).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: entryCtrl,
      builder: (_, child) {
        final delay = (index * 0.04).clamp(0.0, 0.7);
        final p =
            ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: reduceMotion ? 1.0 : p,
          child: Transform.translate(
              offset: Offset(reduceMotion ? 0 : 16 * (1 - p), 0),
              child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.stroke)),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: col,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: col.withValues(alpha: 0.10),
                                border: Border.all(
                                    color: col.withValues(alpha: 0.35),
                                    width: 1.5),
                              ),
                              child: Icon(_riskIcon(data.riskLevel),
                                  color: col, size: 15),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(data.city,
                                      style: TextStyle(
                                          color: t.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800)),
                                  Text(
                                    '${data.riverName ?? 'River'} · ${data.state}',
                                    style: TextStyle(
                                        color: t.textSecondary,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${data.currentLevel.toStringAsFixed(2)} m',
                                  style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ]),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    data.riskLevel.toUpperCase(),
                                    style: TextStyle(
                                        color: col,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded,
                                color: t.textSecondary
                                    .withValues(alpha: 0.4),
                                size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AnimatedBuilder(
                          animation: gaugeAnim,
                          builder: (_, __) {
                            final animatedCap = cap * gaugeAnim.value;
                            final displayPct =
                                (data.capacityPercent * gaugeAnim.value)
                                    .toStringAsFixed(0);
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Capacity',
                                        style: TextStyle(
                                            color: t.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                    Text('$displayPct%',
                                        style: TextStyle(
                                            color: col,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures()
                                            ])),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: t.stroke,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: FractionallySizedBox(
                                      widthFactor: animatedCap,
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          gradient: LinearGradient(
                                              colors: [
                                                AppPalette.safe,
                                                col
                                              ]),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (data.dangerLevel != null ||
                            data.warningLevel != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                if (data.warningLevel != null)
                                  _LevelChip(
                                      label: 'Warning',
                                      value:
                                          '${data.warningLevel!.toStringAsFixed(1)} m',
                                      color: AppPalette.warning),
                                if (data.dangerLevel != null) ...[
                                  const SizedBox(width: 6),
                                  _LevelChip(
                                      label: 'Danger',
                                      value:
                                          '${data.dangerLevel!.toStringAsFixed(1)} m',
                                      color: AppPalette.danger),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _LevelChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text('$label $value',
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoadingSkeleton
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatefulWidget {
  final RiverColors t;
  const _LoadingSkeleton({required this.t});
  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        final gradient = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [widget.t.stroke, widget.t.cardBg, widget.t.stroke],
          stops: [
            (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
            _shimmerCtrl.value.clamp(0.0, 1.0),
            (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0)
          ],
        );
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                  height: 220,
                  decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(24))),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: List.generate(
                  4,
                  (_) => Container(
                    decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(
                4,
                (_) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  height: 100,
                  decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
