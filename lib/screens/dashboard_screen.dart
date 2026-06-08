// lib/screens/dashboard_screen.dart
// EQUINOX-BH — Dashboard Screen v1
//
// Architecture:
//   - ConsumerStatefulWidget (Riverpod 3)
//   - Pulls live data from: realTimeProvider, liveLevelsProvider,
//     criticalCountProvider, isOfflineProvider, isWakingUpProvider
//   - Delegates chart/widget rendering to dashboard_screen_part2.dart
//   - Pull-to-refresh via RefreshIndicator → service.refreshData()
//   - Animated entry: gauge anim (0→1), wave ctrl (looping), entry ctrl
//   - Respects prefers-reduced-motion via MediaQuery
//
// Widgets provided by dashboard_screen_part2.dart (same library):
//   AnimatedAreaChart, AlertLog, SystemStats, DashboardFooter,
//   DashboardEmptyState
//
// P1 fixes applied (2026-06-08):
//   1. All fontSize values floored at 10px minimum.
//      Affected: _KpiStrip label (8.5→10), _SectionHeader label (10 kept),
//      _StationTile river/state sub-text (10 kept), capacity label (9→10),
//      capacity % value (9→10), _LevelChip label (9→10),
//      _DashboardAppBar subtitle (10 kept), _CriticalBadge text (11 kept).
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import 'dashboard_screen_part2.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Risk helpers (shared with part2)
// ─────────────────────────────────────────────────────────────────────────────

Color _riskColor(String level) {
  switch (level.toUpperCase()) {
    case 'CRITICAL': return AppPalette.critical;
    case 'SEVERE':   return AppPalette.danger;
    case 'MODERATE': return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}

IconData _riskIcon(String level) {
  switch (level.toUpperCase()) {
    case 'CRITICAL': return Icons.warning_rounded;
    case 'SEVERE':   return Icons.warning_amber_rounded;
    case 'MODERATE': return Icons.info_rounded;
    default:         return Icons.check_circle_rounded;
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

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _gaugeCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _gaugeAnim;

  bool _reduceMotion = false;

  // ── Refresh state ──────────────────────────────────────────────────────────
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    _gaugeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _gaugeAnim = CurvedAnimation(
      parent: _gaugeCtrl,
      curve: Curves.easeOutCubic,
    );

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Kick off entry animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _gaugeCtrl.forward();
        _entryCtrl.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _waveCtrl.stop();
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    _waveCtrl.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Pull-to-refresh ────────────────────────────────────────────────────────
  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();

    // Reset animations
    _gaugeCtrl.reset();
    _entryCtrl.reset();

    try {
      await ref.read(realTimeProvider).refreshData();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _gaugeCtrl.forward();
        _entryCtrl.forward();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t          = RiverColors.of(context);
    final service    = ref.watch(realTimeProvider);
    final liveLevels = ref.watch(liveLevelsProvider);
    final critCount  = ref.watch(criticalCountProvider);
    final isOffline  = ref.watch(isOfflineProvider);
    final isWakingUp = ref.watch(isWakingUpProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: RefreshIndicator(
        color: t.accent,
        backgroundColor: t.cardBg,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── App bar ───────────────────────────────────────────────────
            _DashboardAppBar(
              t: t,
              criticalCount: critCount,
              isOffline: isOffline,
              isWakingUp: isWakingUp,
              pulseCtrl: _pulseCtrl,
              lastUpdated: service.lastFetchTime,
              onRefresh: _onRefresh,
            ),

            // ── Offline / waking-up banner ────────────────────────────────
            if (isOffline || isWakingUp)
              SliverToBoxAdapter(
                child: _StatusBanner(
                  t: t,
                  isOffline: isOffline,
                  isWakingUp: isWakingUp,
                ),
              ),

            // ── Loading skeleton or content ───────────────────────────────
            if (service.isLoading && liveLevels.isEmpty)
              SliverToBoxAdapter(child: _LoadingSkeleton(t: t))
            else if (liveLevels.isEmpty)
              const SliverToBoxAdapter(child: DashboardEmptyState())
            else ...[
              // ── Summary KPI strip ─────────────────────────────────────
              SliverToBoxAdapter(
                child: _KpiStrip(
                  t: t,
                  levels: liveLevels,
                  criticalCount: critCount,
                  gaugeAnim: _gaugeAnim,
                  entryCtrl: _entryCtrl,
                  reduceMotion: _reduceMotion,
                ),
              ),

              // ── Critical / Severe alert cards ─────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  label: 'ACTIVE ALERTS',
                  icon: Icons.warning_rounded,
                  color: AppPalette.critical,
                  t: t,
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

              // ── All stations list ─────────────────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  label: 'ALL MONITORED STATIONS',
                  icon: Icons.sensors_rounded,
                  color: t.accent,
                  t: t,
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
                ),
              ),

              // ── Capacity distribution chart ───────────────────────────
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

              // ── Data source health ────────────────────────────────────
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

              // ── Footer stats ──────────────────────────────────────────
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

              // Bottom padding for nav bar
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DashboardAppBar — SliverAppBar with live critical badge
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardAppBar extends StatelessWidget {
  final RiverColors t;
  final int criticalCount;
  final bool isOffline, isWakingUp;
  final AnimationController pulseCtrl;
  final DateTime? lastUpdated;
  final VoidCallback onRefresh;

  const _DashboardAppBar({
    required this.t,
    required this.criticalCount,
    required this.isOffline,
    required this.isWakingUp,
    required this.pulseCtrl,
    required this.lastUpdated,
    required this.onRefresh,
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
      expandedHeight: 100,
      backgroundColor: t.scaffoldBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: t.stroke,
      title: Row(
        children: [
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOffline
                    ? AppPalette.warning
                    : criticalCount > 0
                        ? AppPalette.critical.withValues(
                            alpha: 0.5 + pulseCtrl.value * 0.5)
                        : AppPalette.safe.withValues(
                            alpha: 0.5 + pulseCtrl.value * 0.5),
                boxShadow: isOffline
                    ? null
                    : [
                        BoxShadow(
                          color: (criticalCount > 0
                                  ? AppPalette.critical
                                  : AppPalette.safe)
                              .withValues(alpha: pulseCtrl.value * 0.6),
                          blurRadius: 8,
                        ),
                      ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpsFlood',
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (criticalCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _CriticalBadge(count: criticalCount),
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
        border: Border.all(color: AppPalette.critical.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_rounded,
              color: AppPalette.critical, size: 13),
          const SizedBox(width: 4),
          Text(
            '$count critical',
            style: const TextStyle(
              color: AppPalette.critical,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusBanner — offline / waking up ribbon
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final RiverColors t;
  final bool isOffline, isWakingUp;
  const _StatusBanner({
    required this.t,
    required this.isOffline,
    required this.isWakingUp,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOffline ? AppPalette.warning : t.accent;
    final msg   = isOffline
        ? 'No internet — showing last cached data'
        : 'Connecting to OpsFlood servers…';
    final icon  = isOffline
        ? Icons.wifi_off_rounded
        : Icons.cloud_sync_rounded;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isWakingUp)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _KpiStrip — 4 animated summary KPI cards
// ─────────────────────────────────────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  final RiverColors t;
  final List<FloodData> levels;
  final int criticalCount;
  final Animation<double> gaugeAnim;
  final AnimationController entryCtrl;
  final bool reduceMotion;

  const _KpiStrip({
    required this.t,
    required this.levels,
    required this.criticalCount,
    required this.gaugeAnim,
    required this.entryCtrl,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final severeCount  = levels.where((d) =>
        d.riskLevel.toUpperCase() == 'SEVERE').length;
    final avgCapacity  = levels.isEmpty
        ? 0.0
        : levels.map((d) => d.capacityPercent).reduce((a, b) => a + b) /
            levels.length;
    final normalCount  = levels.where((d) =>
        d.riskLevel.toUpperCase() == 'NORMAL' ||
        d.riskLevel.toUpperCase() == 'SAFE').length;

    final kpis = [
      _KpiItem(
        label: 'CRITICAL',
        value: '$criticalCount',
        color: AppPalette.critical,
        icon: Icons.warning_rounded,
      ),
      _KpiItem(
        label: 'SEVERE',
        value: '$severeCount',
        color: AppPalette.danger,
        icon: Icons.warning_amber_rounded,
      ),
      _KpiItem(
        label: 'AVG CAP',
        value: '${avgCapacity.toStringAsFixed(0)}%',
        color: avgCapacity > 80
            ? AppPalette.critical
            : avgCapacity > 60
                ? AppPalette.warning
                : AppPalette.safe,
        icon: Icons.water_rounded,
      ),
      _KpiItem(
        label: 'NORMAL',
        value: '$normalCount',
        color: AppPalette.safe,
        icon: Icons.check_circle_rounded,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: kpis.asMap().entries.map((e) {
          final i    = e.key;
          final kpi  = e.value;
          return Expanded(
            child: AnimatedBuilder(
              animation: entryCtrl,
              builder: (_, child) {
                final delay = i * 0.08;
                final p = ((entryCtrl.value - delay) / (1.0 - delay))
                    .clamp(0.0, 1.0);
                return Opacity(
                  opacity: reduceMotion ? 1.0 : p,
                  child: Transform.translate(
                    offset: Offset(0, reduceMotion ? 0 : 20 * (1 - p)),
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.only(right: i < kpis.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: kpi.color.withValues(alpha: 0.20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(kpi.icon, color: kpi.color, size: 18),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: gaugeAnim,
                      builder: (_, __) {
                        final num = int.tryParse(kpi.value) ??
                            double.tryParse(
                                kpi.value.replaceAll('%', ''))?.toInt();
                        final displayVal = num != null
                            ? '${(num * gaugeAnim.value).round()}${kpi.value.contains('%') ? '%' : ''}'
                            : kpi.value;
                        return Text(
                          displayVal,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        );
                      },
                    ),
                    Text(
                      kpi.label,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 10, // P1 FIX: was 8.5
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
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
  const _KpiItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
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

  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StationTile — individual river station row with animated capacity bar
// ─────────────────────────────────────────────────────────────────────────────

class _StationTile extends StatelessWidget {
  final FloodData data;
  final int index;
  final AnimationController entryCtrl;
  final Animation<double> gaugeAnim;
  final RiverColors t;
  final bool reduceMotion;

  const _StationTile({
    required this.data,
    required this.index,
    required this.entryCtrl,
    required this.gaugeAnim,
    required this.t,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final col = _riskColor(data.riskLevel);
    final cap = (data.capacityPercent / 100).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: entryCtrl,
      builder: (_, child) {
        final delay = (index * 0.04).clamp(0.0, 0.7);
        final p = ((entryCtrl.value - delay) / (1.0 - delay))
            .clamp(0.0, 1.0);
        return Opacity(
          opacity: reduceMotion ? 1.0 : p,
          child: Transform.translate(
            offset: Offset(reduceMotion ? 0 : 20 * (1 - p), 0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: col.withValues(alpha: 0.12),
                  ),
                  child: Icon(_riskIcon(data.riskLevel),
                      color: col, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.city,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${data.riverName ?? 'River'} · ${data.state}',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 10,
                        ),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data.riskLevel,
                        style: TextStyle(
                          color: col,
                          fontSize: 10, // P1 FIX: was 9
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: gaugeAnim,
              builder: (_, __) {
                final animatedCap = cap * gaugeAnim.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Capacity',
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 10, // P1 FIX: was 9
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(data.capacityPercent * gaugeAnim.value).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: col,
                            fontSize: 10, // P1 FIX: was 9
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: animatedCap,
                        minHeight: 5,
                        backgroundColor: t.stroke,
                        color: col,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (data.dangerLevel != null || data.warningLevel != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    if (data.warningLevel != null)
                      _LevelChip(
                        label: 'Warning',
                        value: '${data.warningLevel!.toStringAsFixed(1)} m',
                        color: AppPalette.warning,
                      ),
                    if (data.dangerLevel != null) ...[
                      const SizedBox(width: 6),
                      _LevelChip(
                        label: 'Danger',
                        value: '${data.dangerLevel!.toStringAsFixed(1)} m',
                        color: AppPalette.danger,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _LevelChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 10, // P1 FIX: was 9
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoadingSkeleton — shimmer placeholders while service.isLoading
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
      duration: const Duration(milliseconds: 1500),
    )..repeat();
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
          colors: [
            widget.t.stroke,
            widget.t.cardBg,
            widget.t.stroke,
          ],
          stops: [
            (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
            _shimmerCtrl.value.clamp(0.0, 1.0),
            (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
          ],
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 120,
                height: 10,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(
                5,
                (_) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
