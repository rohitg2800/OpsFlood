import 'dart:math' as math;

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

// ─── color palette ────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF060D14);
const _kCard     = Color(0xFF0D1B26);
const _kCardBdr  = Color(0xFF1A2E3E);
const _kCyan     = Color(0xFF00C2DE);
const _kGreen    = Color(0xFF22C55E);
const _kYellow   = Color(0xFFF59E0B);
const _kOrange   = Color(0xFFEA580C);
const _kRed      = Color(0xFFEF4444);
const _kPurple   = Color(0xFF8B5CF6);
const _kText     = Color(0xFFE2EAF0);
const _kSub      = Color(0xFF6B8699);

Color _riskColor(String risk) {
  switch (risk) {
    case 'CRITICAL': return _kRed;
    case 'HIGH':     return _kOrange;
    case 'MODERATE': return _kYellow;
    default:         return _kGreen;
  }
}

String _riskEmoji(String risk) {
  switch (risk) {
    case 'CRITICAL': return '🔴';
    case 'HIGH':     return '🟠';
    case 'MODERATE': return '🟡';
    default:         return '🟢';
  }
}

// ─── screen ───────────────────────────────────────────────────────────────────
class MonitorsScreen extends StatefulWidget {
  const MonitorsScreen({super.key});
  @override
  State<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends State<MonitorsScreen>
    with SingleTickerProviderStateMixin {
  final RealTimeService _svc = RealTimeService();
  late AnimationController _pulseCtrl;
  int _lastHash = 0;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onUpdate);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _svc.removeListener(_onUpdate);
    _pulseCtrl.dispose();
    super.dispose();
  }

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
    final levels = List<FloodData>.from(_svc.liveLevels)
      ..sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));

    final critical  = levels.where((l) => l.riskLevel == 'CRITICAL').length;
    final highRisk  = levels.where((l) => l.riskLevel == 'HIGH' || l.riskLevel == 'CRITICAL').length;
    final liveTime  = _svc.lastFetchTime == null
        ? 'Waiting…'
        : 'Live at ${DateFormat('HH:mm:ss').format(_svc.lastFetchTime!.toLocal())}';

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _svc.refreshData,
          color: _kCyan,
          backgroundColor: _kCard,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── header ──────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('River Monitors',
                              style: TextStyle(
                                  color: _kText,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                  letterSpacing: -0.5)),
                          const Spacer(),
                          // pulsing LIVE badge
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (_, __) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _kGreen.withOpacity(
                                    0.12 + _pulseCtrl.value * 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _kGreen.withOpacity(0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: BoxDecoration(
                                      color: _kGreen,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _kGreen.withOpacity(
                                              0.4 + _pulseCtrl.value * 0.4),
                                          blurRadius: 6,
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text('LIVE',
                                      style: TextStyle(
                                          color: _kGreen,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(liveTime,
                          style: const TextStyle(
                              color: _kSub, fontSize: 12)),
                      const SizedBox(height: 14),
                      // ── summary strip ────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                              child: _SummaryTile(
                            value: '${levels.length}',
                            label: 'Stations',
                            icon: Icons.sensors,
                            accent: _kCyan,
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _SummaryTile(
                            value: '$highRisk',
                            label: 'High Risk',
                            icon: Icons.warning_amber_rounded,
                            accent: _kOrange,
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _SummaryTile(
                            value: '$critical',
                            label: 'Critical',
                            icon: Icons.crisis_alert,
                            accent: _kRed,
                          )),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),

              // ── cards ────────────────────────────────────────────────────
              if (levels.isEmpty)
                const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(color: _kCyan)))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final item    = levels[i];
                        final history = _svc.trendForCity(item.city);
                        return _MonitorCard(
                          key: ValueKey(item.city),
                          item: item,
                          history: history,
                          pulseCtrl: _pulseCtrl,
                          rank: i + 1,
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

// ─── summary tile ─────────────────────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  const _SummaryTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              Text(label,
                  style: const TextStyle(
                      color: _kSub, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── monitor card ─────────────────────────────────────────────────────────────
class _MonitorCard extends StatelessWidget {
  final FloodData item;
  final List<RiverLevelSnapshot> history;
  final AnimationController pulseCtrl;
  final int rank;
  const _MonitorCard({
    super.key,
    required this.item,
    required this.history,
    required this.pulseCtrl,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final riskC    = _riskColor(item.riskLevel);
    final isCrit   = item.capacityPercent >= 85.0;
    final pct      = item.capacityPercent.clamp(0.0, 100.0) / 100.0;
    final lvlText  = item.currentLevel.toStringAsFixed(2);
    final dangerM  = item.dangerLevel.toStringAsFixed(1);
    final warnM    = item.warningLevel.toStringAsFixed(1);

    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, child) {
        final glow = isCrit
            ? riskC.withOpacity(0.04 + pulseCtrl.value * 0.06)
            : Colors.transparent;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCrit
                  ? riskC.withOpacity(0.5 + pulseCtrl.value * 0.3)
                  : riskC.withOpacity(0.25),
              width: isCrit ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                  color: glow,
                  blurRadius: 20,
                  spreadRadius: 2)
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── top row: level viz + gauge + info ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // rank badge
                Container(
                  width: 26, height: 26,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: riskC.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: riskC.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text('$rank',
                        style: TextStyle(
                            color: riskC,
                            fontWeight: FontWeight.w800,
                            fontSize: 11)),
                  ),
                ),
                Expanded(
                  child: RiverLevelVisualizer(
                    city: item.city,
                    river: item.riverName ?? 'River',
                    currentLevel: item.currentLevel,
                    safeLevel: item.safeLevel,
                    warningLevel: item.warningLevel,
                    dangerLevel: item.dangerLevel,
                    trend: item.status,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 96,
                  child: FloodGauge(
                    capacity: item.capacityPercent,
                    riskLevel: item.riskLevel,
                    size: 96,
                    label: item.state,
                  ),
                ),
              ],
            ),
          ),

          // ── capacity bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Capacity',
                        style: const TextStyle(
                            color: _kSub, fontSize: 10,
                            fontWeight: FontWeight.w500)),
                    Text(
                      '${item.capacityPercent.toStringAsFixed(0)}%  ${_riskEmoji(item.riskLevel)} ${item.riskLevel}',
                      style: TextStyle(
                          color: riskC,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(
                          height: 7,
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.06)),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                riskC.withOpacity(0.7),
                                riskC,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // warning tick at 70%
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.70 * 0.62,
                        child: Container(
                            width: 1.5,
                            height: 7,
                            color: _kYellow.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── threshold chips ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Chip(
                    icon: Icons.warning_amber_rounded,
                    label: 'Danger: $dangerM m',
                    color: _kRed),
                _Chip(
                    icon: Icons.trending_up,
                    label: 'Warning: $warnM m',
                    color: _kYellow),
                _Chip(
                    icon: Icons.water,
                    label: '$lvlText m now',
                    color: riskC),
                if (item.expectedPeakLevel != null)
                  _Chip(
                      icon: Icons.show_chart,
                      label:
                          'Peak: ${item.expectedPeakLevel!.toStringAsFixed(1)} m',
                      color: _kPurple),
              ],
            ),
          ),

          // ── sparkline ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Row(
              children: [
                const Icon(Icons.show_chart, color: _kSub, size: 11),
                const SizedBox(width: 4),
                const Text('24h trend',
                    style: TextStyle(color: _kSub, fontSize: 10)),
              ],
            ),
          ),
          SizedBox(
            height: 72,
            child: _GradientSparkline(
              history: history,
              dangerLevel: item.dangerLevel,
              warningLevel: item.warningLevel,
              lineColor: riskC,
            ),
          ),

          // ── critical banner ─────────────────────────────────────────────
          if (isCrit)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.12),
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20)),
                border: Border(
                    top: BorderSide(
                        color: _kRed.withOpacity(0.25))),
              ),
              child: Row(
                children: [
                  Icon(Icons.notification_important_rounded,
                      color: _kRed, size: 14),
                  const SizedBox(width: 6),
                  const Text('Critical threshold breached',
                      style: TextStyle(
                          color: _kRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ─── chip ─────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _Chip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── gradient sparkline ───────────────────────────────────────────────────────
class _GradientSparkline extends StatelessWidget {
  final List<RiverLevelSnapshot> history;
  final double warningLevel;
  final double dangerLevel;
  final Color  lineColor;
  const _GradientSparkline({
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
        child: Text('More data soon…',
            style: const TextStyle(color: _kSub, fontSize: 10)),
      );
    }
    final clipped = pts.length > 24 ? pts.sublist(pts.length - 24) : pts;
    final spots   = List.generate(
        clipped.length,
        (i) => FlSpot(i.toDouble(), clipped[i].level));
    final levels  = clipped.map((s) => s.level);
    final minY    = (levels.reduce(math.min) - 0.5).clamp(0.0, 9999.0);
    final maxY    = levels.reduce(math.max) + 0.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 3,
            getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.white.withOpacity(0.05),
                strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style:
                      const TextStyle(color: _kSub, fontSize: 8.5),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots:    spots,
              isCurved: true,
              color:    lineColor,
              barWidth: 2.2,
              dotData:  const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    lineColor.withOpacity(0.35),
                    lineColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
              y:           warningLevel,
              color:       _kYellow.withOpacity(0.7),
              strokeWidth: 1,
              dashArray:   [4, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => ' W ',
                style: const TextStyle(
                    color: _kYellow,
                    fontSize: 8,
                    fontWeight: FontWeight.bold),
              ),
            ),
            HorizontalLine(
              y:           dangerLevel,
              color:       _kRed.withOpacity(0.7),
              strokeWidth: 1.2,
              dashArray:   [5, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => ' D ',
                style: const TextStyle(
                    color: _kRed,
                    fontSize: 8,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }
}
