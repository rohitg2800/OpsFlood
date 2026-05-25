// lib/screens/dashboard_screen.dart
// OpsFlood — DashboardScreen v15 (Abyss Ops premium rebuild)
// ─────────────────────────────────────────────────────────────────────────────
// Layout (v15 — no gauges, premium cards, area + bar charts):
//   1. AppBar strip          — logo + live pill + refresh
//   2. KPI row               — 4 PremiumStatCards in horizontal scroll
//   3. National risk OpsBarChart — top 8 cities by risk
//   4. River trend OpsAreaChart  — selected city level history
//   5. CWC station row       — compact shimmer cards
//   6. State risk heatmap    — inline
library;

import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../screens/india_rivers_screen.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import '../widgets/animated_alert_badge.dart';
import '../widgets/ops_area_chart.dart';
import '../widgets/ops_bar_chart.dart';
import '../widgets/premium_stat_card.dart';
import '../widgets/risk_heatmap.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final RealTimeService _service = RealTimeService();
  String? _selectedCity;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _service.addListener(_onData);
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onData);
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Data helpers ───────────────────────────────────────────────────
  List<FloodData> get _sorted {
    final list = List<FloodData>.from(_service.floodLevels);
    list.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    return list;
  }

  int get _criticalCount => _sorted
      .where((d) => d.riskScore >= 70)
      .length;

  int get _alertCount => _sorted
      .where((d) => d.riskScore >= 45)
      .length;

  FloodData? get _selectedData {
    if (_selectedCity == null) return null;
    try {
      return _sorted.firstWhere((d) => d.city == _selectedCity);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _sorted;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(child: _kpiRow(data)),
              if (data.isNotEmpty) ...[
                SliverToBoxAdapter(child: _sectionTitle(
                  'National Risk Overview',
                  sub: 'Top cities by composite flood risk score',
                  icon: Icons.bar_chart_rounded,
                  color: AppPalette.amber,
                )),
                SliverToBoxAdapter(child: _nationalBarChart(data)),
                SliverToBoxAdapter(child: _sectionTitle(
                  'River Level Trend',
                  sub: _selectedCity ?? (data.isNotEmpty ? data.first.city : 'Select city'),
                  icon: Icons.show_chart_rounded,
                  color: AppPalette.cyan,
                )),
                SliverToBoxAdapter(child: _riverTrendChart(data)),
                SliverToBoxAdapter(child: _citySelector(data)),
                SliverToBoxAdapter(child: _sectionTitle(
                  'State Risk Heatmap',
                  sub: 'Real-time state-level flood risk',
                  icon: Icons.grid_view_rounded,
                  color: AppPalette.safe,
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: RiskHeatmap(data: data),
                )),
              ] else
                SliverToBoxAdapter(child: _emptyState()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────
  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppPalette.cyan.withValues(alpha: 0.06),
          AppPalette.abyss0,
        ],
      ),
      border: Border(
        bottom: BorderSide(
          color: AppPalette.cyan.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
    ),
    child: Row(
      children: [
        // Logo badge
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppPalette.cyan.withValues(alpha: 0.20),
                AppPalette.abyss2,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppPalette.cyan.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.cyan.withValues(alpha: 0.18),
                blurRadius: 14,
              ),
            ],
          ),
          child: const Icon(Icons.water_drop_rounded,
              color: AppPalette.cyan, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppPalette.cyanBright, AppPalette.cyan],
                ).createShader(b),
                child: const Text(
                  'OpsFlood',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.6,
                  ),
                ),
              ),
              Text(
                'Live Flood Intelligence',
                style: TextStyle(
                  fontSize: 10,
                  color: AppPalette.textGrey.withValues(alpha: 0.7),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        // Live pill
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppPalette.safe.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppPalette.safe
                    .withValues(alpha: 0.30 * _pulseAnim.value),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.safe
                      .withValues(alpha: _pulseAnim.value),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.safe
                          .withValues(alpha: 0.7 * _pulseAnim.value),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Text('LIVE',
                  style: TextStyle(
                    color: AppPalette.safe, fontSize: 10,
                    fontWeight: FontWeight.w800,
                  )),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _service.refreshNow();
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppPalette.abyss2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppPalette.abyssStroke),
            ),
            child: const Icon(Icons.refresh_rounded,
                color: AppPalette.textGrey, size: 18),
          ),
        ),
      ],
    ),
  );

  // ── KPI Row ───────────────────────────────────────────────────────────
  Widget _kpiRow(List<FloodData> data) {
    final critical  = _criticalCount;
    final alerting  = _alertCount;
    final monitored = data.length;
    final avgRisk   = monitored > 0
        ? data.map((d) => d.riskScore).reduce((a, b) => a + b) / monitored
        : 0.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: PremiumStatCard(
              label: 'CRITICAL',
              value: '$critical',
              sub: 'risk score ≥70',
              icon: Icons.crisis_alert_rounded,
              color: critical > 0 ? AppPalette.critical : AppPalette.safe,
              pulse: critical > 0,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: PremiumStatCard(
              label: 'ALERTING',
              value: '$alerting',
              sub: 'risk score ≥45',
              icon: Icons.warning_amber_rounded,
              color: alerting > 0 ? AppPalette.warning : AppPalette.textGrey,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: PremiumStatCard(
              label: 'MONITORED',
              value: '$monitored',
              sub: 'cities live',
              icon: Icons.sensors_rounded,
              color: AppPalette.cyan,
              pulse: true,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: PremiumStatCard(
              label: 'AVG RISK',
              value: avgRisk.toStringAsFixed(0),
              sub: 'national score / 100',
              icon: Icons.analytics_rounded,
              color: AppPalette.amber,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Title ─────────────────────────────────────────────────────
  Widget _sectionTitle(String title, {
    String? sub,
    required IconData icon,
    required Color color,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(
          children: [
            Container(
              width: 3, height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: AppPalette.textWhite, letterSpacing: -0.2,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppPalette.textGrey.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  // ── National bar chart ────────────────────────────────────────────────
  Widget _nationalBarChart(List<FloodData> data) {
    final top = data.take(8).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: AppPalette.glassMorph(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OpsBarChart(
            values: top.map((d) => d.riskScore.clamp(0.0, 100.0)).toList(),
            labels: top.map((d) => d.city).toList(),
            maxY:   100,
            yUnit:  '',
            barWidth: 18,
            height: 160,
          ),
          const SizedBox(height: 4),
          Row(children: [
            _legendDot(AppPalette.safe,     'Safe (<25)'),
            const SizedBox(width: 12),
            _legendDot(AppPalette.warning,  'Alert (25-45)'),
            const SizedBox(width: 12),
            _legendDot(AppPalette.danger,   'High (45-70)'),
            const SizedBox(width: 12),
            _legendDot(AppPalette.critical, 'Critical (≥70)'),
          ]),
        ],
      ),
    );
  }

  // ── River trend area chart ─────────────────────────────────────────────
  Widget _riverTrendChart(List<FloodData> data) {
    final selected = _selectedData ?? (data.isNotEmpty ? data.first : null);
    if (selected == null) return const SizedBox.shrink();

    final history = selected.levelHistory ?? [];
    if (history.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: AppPalette.glassMorph(radius: 22),
        child: Center(
          child: Text(
            'No level history for ${selected.city}',
            style: const TextStyle(
              color: AppPalette.textGrey, fontSize: 12,
            ),
          ),
        ),
      );
    }

    final statusColor = _riskColor(selected.riskScore);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: AppPalette.glassMorph(
        radius: 22,
        borderColor: statusColor.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini header
          Row(children: [
            Text(
              selected.city,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: AppPalette.textWhite,
              ),
            ),
            const SizedBox(width: 8),
            _statusChip(
              '${selected.riskScore.toStringAsFixed(0)} / 100',
              statusColor,
            ),
            const Spacer(),
            Text(
              '${selected.currentLevel?.toStringAsFixed(2) ?? '--'} m',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: statusColor, letterSpacing: -0.5,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          OpsAreaChart(
            values:   history.map((h) => h.level).toList(),
            labels:   history.asMap().entries
                .map((e) => e.key % 4 == 0
                    ? _shortTime(h: history[e.key])
                    : '')
                .toList(),
            lineColor: statusColor,
            warningY:  selected.warningLevel,
            dangerY:   selected.dangerLevel,
            yUnit:     ' m',
            height:    130,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _mini('Warning', '${selected.warningLevel?.toStringAsFixed(1) ?? "--"} m', AppPalette.amber),
              _mini('Danger',  '${selected.dangerLevel?.toStringAsFixed(1)  ?? "--"} m', AppPalette.critical),
              _mini('HFL',     '${selected.hfl?.toStringAsFixed(1)           ?? "--"} m', AppPalette.textGrey),
            ],
          ),
        ],
      ),
    );
  }

  // ── City selector chips ─────────────────────────────────────────────────
  Widget _citySelector(List<FloodData> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    final top = data.take(10).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: top.map((d) {
          final active = (_selectedCity ?? top.first.city) == d.city;
          final color  = _riskColor(d.riskScore);
          return GestureDetector(
            onTap: () => setState(() => _selectedCity = d.city),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.14)
                    : AppPalette.abyss2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? color.withValues(alpha: 0.45)
                      : AppPalette.abyssStroke,
                  width: active ? 1.5 : 1,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.18),
                          blurRadius: 10,
                        )
                      ]
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  d.city,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? color : AppPalette.textGrey,
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────
  Widget _emptyState() => SizedBox(
    height: 300,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.cyan.withValues(alpha: 0.08),
              border: Border.all(
                  color: AppPalette.cyan.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.water_drop_outlined,
                color: AppPalette.cyan, size: 34),
          ),
          const SizedBox(height: 16),
          const Text('Fetching live flood data…',
              style: TextStyle(
                color: AppPalette.textGrey,
                fontSize: 14, fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          const Text('CWC  •  GloFAS  •  IMD',
              style: TextStyle(
                color: AppPalette.textDim,
                fontSize: 10, letterSpacing: 1.5,
              )),
        ],
      ),
    ),
  );

  // ── Atoms ──────────────────────────────────────────────────────────────
  Widget _mini(String label, String val, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(val, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: c)),
      Text(label, style: const TextStyle(
        fontSize: 9, color: AppPalette.textGrey)),
    ],
  );

  Widget _statusChip(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withValues(alpha: 0.35)),
    ),
    child: Text(label,
        style: TextStyle(
          color: c, fontSize: 9, fontWeight: FontWeight.w800)),
  );

  Widget _legendDot(Color c, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: c,
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
              fontSize: 9, color: AppPalette.textGrey)),
      ]);

  Color _riskColor(double score) {
    if (score >= 70) return AppPalette.critical;
    if (score >= 45) return AppPalette.danger;
    if (score >= 25) return AppPalette.warning;
    return AppPalette.safe;
  }

  String _shortTime({required dynamic h}) {
    try {
      final ts = h.timestamp as String?;
      if (ts == null) return '';
      final dt = DateTime.tryParse(ts);
      if (dt == null) return '';
      return DateFormat('HH:mm').format(dt.toLocal());
    } catch (_) {
      return '';
    }
  }
}
