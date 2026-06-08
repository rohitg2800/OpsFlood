// lib/screens/dashboard_screen.dart
// EQUINOX-BH — Dashboard Screen v2 (Redesign)
//
// Design direction:
//   Dark command-center / flood-ops aesthetic.
//   Hero section: full-width avg-capacity arc gauge with live colour.
//   KPI grid: 2×2 instead of 4-column cramped strip.
//   Station tiles: status colour runs as left accent bar + ring icon.
//   Section headers: full-width coloured underline pill.
//   Capacity bars: gradient fill (safe → danger colour).
//   Removed: light cream background → deep scaffoldBg from theme.
//   Typography floor: 11px minimum on all visible text.
library;

import 'dart:math' as math;
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
// Risk colour / icon helpers
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

  late AnimationController _gaugeCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _gaugeAnim;

  bool _reduceMotion = false;
  bool _isRefreshing = false;

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
      vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { _gaugeCtrl.forward(); _entryCtrl.forward(); }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) { _waveCtrl.stop(); _pulseCtrl.stop(); }
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose(); _waveCtrl.dispose();
    _entryCtrl.dispose(); _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    _gaugeCtrl.reset(); _entryCtrl.reset();
    try {
      await ref.read(realTimeProvider).refreshData();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _gaugeCtrl.forward(); _entryCtrl.forward();
      }
    }
  }

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
              parent: BouncingScrollPhysics()),
          slivers: [
            // ── App bar ────────────────────────────────────────────────────
            _DashboardAppBar(
              t: t,
              criticalCount: critCount,
              isOffline: isOffline,
              isWakingUp: isWakingUp,
              pulseCtrl: _pulseCtrl,
              lastUpdated: service.lastFetchTime,
              onRefresh: _onRefresh,
            ),

            // ── Status banner (offline / waking) ───────────────────────────
            if (isOffline || isWakingUp)
              SliverToBoxAdapter(
                child: _StatusBanner(
                    t: t, isOffline: isOffline, isWakingUp: isWakingUp)),

            // ── Loading skeleton or content ─────────────────────────────────
            if (service.isLoading && liveLevels.isEmpty)
              SliverToBoxAdapter(child: _LoadingSkeleton(t: t))
            else if (liveLevels.isEmpty)
              const SliverToBoxAdapter(child: DashboardEmptyState())
            else ...[

              // ── Hero arc gauge ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: _HeroGauge(
                  t: t,
                  levels: liveLevels,
                  criticalCount: critCount,
                  gaugeAnim: _gaugeAnim,
                  pulseCtrl: _pulseCtrl,
                  reduceMotion: _reduceMotion,
                ),
              ),

              // ── 2×2 KPI grid ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: _KpiGrid(
                  t: t,
                  levels: liveLevels,
                  criticalCount: critCount,
                  gaugeAnim: _gaugeAnim,
                  entryCtrl: _entryCtrl,
                  reduceMotion: _reduceMotion,
                ),
              ),

              // ── Active alerts section ──────────────────────────────────
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

              // ── All stations ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  label: 'MONITORED STATIONS',
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

              // ── Capacity trend chart ───────────────────────────────────
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

              // ── Data sources ───────────────────────────────────────────
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

              // ── Footer ─────────────────────────────────────────────────
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
// _DashboardAppBar
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
                        ? AppPalette.critical.withValues(
                            alpha: 0.5 + pulseCtrl.value * 0.5)
                        : AppPalette.safe.withValues(
                            alpha: 0.5 + pulseCtrl.value * 0.5),
                boxShadow: isOffline ? null : [
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
              Text('OpsFlood',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  )),
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
        border: Border.all(color: AppPalette.critical.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_rounded, color: AppPalette.critical, size: 13),
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
// _StatusBanner
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final RiverColors t;
  final bool isOffline, isWakingUp;
  const _StatusBanner({
    required this.t, required this.isOffline, required this.isWakingUp});

  @override
  Widget build(BuildContext context) {
    final color = isOffline ? AppPalette.warning : t.accent;
    final msg   = isOffline
        ? 'No internet — showing last cached data'
        : 'Connecting to OpsFlood servers…';
    final icon  = isOffline ? Icons.wifi_off_rounded : Icons.cloud_sync_rounded;

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
                    color: color, fontSize: 12, fontWeight: FontWeight.w600))),
          if (isWakingUp)
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeroGauge — full-width arc gauge showing avg capacity
// ─────────────────────────────────────────────────────────────────────────────

class _HeroGauge extends StatelessWidget {
  final RiverColors t;
  final List<FloodData> levels;
  final int criticalCount;
  final Animation<double> gaugeAnim;
  final AnimationController pulseCtrl;
  final bool reduceMotion;

  const _HeroGauge({
    required this.t,
    required this.levels,
    required this.criticalCount,
    required this.gaugeAnim,
    required this.pulseCtrl,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final avgCap = levels.isEmpty
        ? 0.0
        : levels.map((d) => d.capacityPercent).reduce((a, b) => a + b) /
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
        // Subtle top glow matching gauge colour
        boxShadow: [
          BoxShadow(
            color: gaugeColor.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Arc gauge
          AnimatedBuilder(
            animation: gaugeAnim,
            builder: (_, __) {
              return SizedBox(
                height: 140,
                child: CustomPaint(
                  painter: _ArcGaugePainter(
                    value: avgCap / 100 * gaugeAnim.value,
                    color: gaugeColor,
                    trackColor: t.stroke,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20), // optical centre in arc
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
                        Text(
                          'AVG CAPACITY',
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Status pill
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  Icon(_riskIcon(criticalCount > 0
                          ? 'CRITICAL'
                          : avgCap > 80
                              ? 'SEVERE'
                              : 'NORMAL'),
                      color: gaugeColor,
                      size: 13),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: gaugeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Quick stats row below gauge
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
                  value: '${levels.map((d) => d.riverName).whereType<String>().toSet().length}',
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
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 32, color: t.stroke);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ArcGaugePainter — semicircular arc gauge
// ─────────────────────────────────────────────────────────────────────────────

class _ArcGaugePainter extends CustomPainter {
  final double value; // 0.0 – 1.0
  final Color color;
  final Color trackColor;

  const _ArcGaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.85; // push centre down so arc sits at bottom
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

    final rect =
        Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Track
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);
    // Value
    if (value > 0) {
      canvas.drawArc(
          rect, startAngle, sweepAngle * value, false, valuePaint);
    }

    // Tip dot
    if (value > 0.02) {
      final tipAngle = startAngle + sweepAngle * value;
      final tipX = cx + radius * math.cos(tipAngle);
      final tipY = cy + radius * math.sin(tipAngle);
      canvas.drawCircle(
          Offset(tipX, tipY),
          8,
          Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.value != value || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// _KpiGrid — 2×2 grid replacing old 4-column cramped strip
// ─────────────────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final RiverColors t;
  final List<FloodData> levels;
  final int criticalCount;
  final Animation<double> gaugeAnim;
  final AnimationController entryCtrl;
  final bool reduceMotion;

  const _KpiGrid({
    required this.t,
    required this.levels,
    required this.criticalCount,
    required this.gaugeAnim,
    required this.entryCtrl,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final severeCount = levels
        .where((d) => d.riskLevel.toUpperCase() == 'SEVERE')
        .length;
    final avgCap = levels.isEmpty
        ? 0.0
        : levels.map((d) => d.capacityPercent).reduce((a, b) => a + b) /
            levels.length;
    final normalCount = levels
        .where((d) =>
            d.riskLevel.toUpperCase() == 'NORMAL' ||
            d.riskLevel.toUpperCase() == 'SAFE')
        .length;

    final kpis = [
      _KpiItem(
          label: 'CRITICAL',
          value: '$criticalCount',
          color: AppPalette.critical,
          icon: Icons.warning_rounded),
      _KpiItem(
          label: 'SEVERE',
          value: '$severeCount',
          color: AppPalette.danger,
          icon: Icons.warning_amber_rounded),
      _KpiItem(
          label: 'AVG CAPACITY',
          value: '${avgCap.toStringAsFixed(0)}%',
          color: avgCap > 80
              ? AppPalette.critical
              : avgCap > 60
                  ? AppPalette.warning
                  : AppPalette.safe,
          icon: Icons.water_rounded),
      _KpiItem(
          label: 'NORMAL',
          value: '$normalCount',
          color: AppPalette.safe,
          icon: Icons.check_circle_rounded),
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
                  child: child,
                ),
              );
            },
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
                  // Left colour ring icon
                  Container(
                    width: 40,
                    height: 40,
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
                                double.tryParse(
                                    kpi.value.replaceAll('%', ''))?.toInt();
                            final displayVal = num != null
                                ? '${(num * gaugeAnim.value).round()}${kpi.value.contains('%') ? '%' : ''}'
                                : kpi.value;
                            return Text(
                              displayVal,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),
                        Text(
                          kpi.label,
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
  const _KpiItem(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader — coloured accent pill + label
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4, height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: t.textPrimary.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StationTile — redesigned with left colour accent bar + ring icon
// Fix: IntrinsicHeight wraps the Row so CrossAxisAlignment.stretch gets a
// finite height from the content Column instead of the unbounded list item.
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
        final p = ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: reduceMotion ? 1.0 : p,
          child: Transform.translate(
            offset: Offset(reduceMotion ? 0 : 16 * (1 - p), 0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke),
        ),
        // FIX: IntrinsicHeight gives the Row a finite height derived from
        // the content Column, resolving the "BoxConstraints forces an
        // infinite height" crash when CrossAxisAlignment.stretch is used
        // inside a SliverList item (which has unbounded height).
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left colour accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: col,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Ring icon
                          Container(
                            width: 34,
                            height: 34,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.city,
                                  style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${data.riverName ?? 'River'} · ${data.state}',
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 11,
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  data.riskLevel.toUpperCase(),
                                  style: TextStyle(
                                    color: col,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Gradient capacity bar
                      AnimatedBuilder(
                        animation: gaugeAnim,
                        builder: (_, __) {
                          final animatedCap = cap * gaugeAnim.value;
                          final displayPct = (data.capacityPercent *
                                  gaugeAnim.value)
                              .toStringAsFixed(0);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Capacity',
                                      style: TextStyle(
                                        color: t.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      )),
                                  Text('$displayPct%',
                                      style: TextStyle(
                                        color: col,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      )),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: t.stroke,
                                    borderRadius: BorderRadius.circular(6),
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
                                            col,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      // Warning / Danger chips
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
                                  color: AppPalette.warning,
                                ),
                              if (data.dangerLevel != null) ...[
                                const SizedBox(width: 6),
                                _LevelChip(
                                  label: 'Danger',
                                  value:
                                      '${data.dangerLevel!.toStringAsFixed(1)} m',
                                  color: AppPalette.danger,
                                ),
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
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
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
      vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
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
            (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
          ],
        );
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Hero gauge skeleton
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 12),
              // 2×2 KPI skeleton
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
                      borderRadius: BorderRadius.circular(16),
                    ),
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
