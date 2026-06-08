// lib/screens/dashboard_screen_part2.dart
// Continuation widgets for DashboardScreen redesign v27
// Changes: richer AlertLog (level + rain + time), improved SystemStats layout,
//          footer shows stale-source count, AreaChart adds 25/50/75/100 grid labels.
// Logic: UNCHANGED — same providers, same RealTimeService fields.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';

Color _riskCol(String lvl) {
  switch (lvl.toUpperCase()) {
    case 'CRITICAL': return AppPalette.critical;
    case 'SEVERE':   return AppPalette.danger;
    case 'MODERATE': return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}

// ───────────────────────────────────────────────────────────────────────────
// AnimatedAreaChart — capacity distribution with Y-axis grid labels
// ───────────────────────────────────────────────────────────────────────────
class AnimatedAreaChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Animation<double> gaugeAnim;
  final AnimationController waveCtrl;
  final bool reduceMotion;

  const AnimatedAreaChart({
    super.key,
    required this.values, required this.labels,
    required this.gaugeAnim, required this.waveCtrl,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 14, 14, 10),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                children: [
                  Icon(Icons.area_chart_rounded,
                      size: 13, color: t.accent),
                  const SizedBox(width: 6),
                  Text('Capacity Distribution',
                      style: TextStyle(
                        color: t.textSecondary, fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const Spacer(),
                  _ChartLegendDot(color: t.accent, label: 'Capacity %'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Y-axis labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['100', '75', '50', '25', '0']
                      .map((l) => SizedBox(
                            height: 22,
                            child: Text(l,
                                style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 110,
                    child: AnimatedBuilder(
                      animation:
                          Listenable.merge([gaugeAnim, waveCtrl]),
                      builder: (_, __) => CustomPaint(
                        painter: _AreaChartPainter(
                          values: values,
                          progress: gaugeAnim.value,
                          wavePhase: reduceMotion
                              ? 0
                              : waveCtrl.value * 2 * math.pi,
                          lineColor: t.accent,
                          fillColor:
                              t.accent.withValues(alpha: 0.15),
                          dotColor: t.accent,
                          gridColor: t.stroke,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int i = 0;
                      i < labels.length;
                      i += math.max(1, labels.length ~/ 5))
                    Text(
                      labels[i].substring(
                          0, math.min(3, labels[i].length)),
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 8),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color, fontSize: 8,
            fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<double> values;
  final double progress;
  final double wavePhase;
  final Color lineColor, fillColor, dotColor, gridColor;

  const _AreaChartPainter({
    required this.values, required this.progress, required this.wavePhase,
    required this.lineColor, required this.fillColor,
    required this.dotColor, required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max).clamp(1.0, double.infinity);
    final n = values.length;
    final xStep = size.width / (n - 1).clamp(1, n);

    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (int g = 0; g <= 4; g++) {
      final y = size.height - (g / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    List<Offset> pts = [];
    for (int i = 0; i < n; i++) {
      final x = i * xStep;
      final rawY = (1 - values[i] / maxV) * size.height;
      final shimmer = math.sin(wavePhase + i * 0.5) * 1.5 * progress;
      pts.add(Offset(x, rawY + shimmer));
    }

    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(pts[0].dx, pts[0].dy * progress);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final cur  = Offset(pts[i].dx, pts[i].dy * progress);
      final cp1  = Offset(prev.dx + xStep * 0.4, prev.dy);
      final cp2  = Offset(cur.dx  - xStep * 0.4, cur.dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, cur.dx, cur.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillColor, fillColor.withValues(alpha: 0.01)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final linePath = Path();
    linePath.moveTo(pts[0].dx, pts[0].dy * progress);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final cur  = Offset(pts[i].dx, pts[i].dy * progress);
      final cp1  = Offset(prev.dx + xStep * 0.4, prev.dy);
      final cp2  = Offset(cur.dx  - xStep * 0.4, cur.dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, cur.dx, cur.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (int i = 0; i < pts.length; i++) {
      final p = Offset(pts[i].dx, pts[i].dy * progress);
      canvas.drawCircle(p, 3.5, Paint()..color = dotColor);
      canvas.drawCircle(
          p, 2.0, Paint()..color = Colors.white.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) =>
      old.progress != progress || old.wavePhase != wavePhase;
}

// ───────────────────────────────────────────────────────────────────────────
// AlertLog v2 — richer rows: level vs warning, rain, time-ago stamp
// ───────────────────────────────────────────────────────────────────────────
class AlertLog extends StatelessWidget {
  final List<FloodData> data;
  final AnimationController entryCtrl;

  const AlertLog({super.key, required this.data, required this.entryCtrl});

  static const _staleHours = 3;

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool _isStale(FloodData d) =>
      DateTime.now().difference(d.lastUpdated).inHours >= _staleHours;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppPalette.safe.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: AppPalette.safe, size: 18),
              const SizedBox(width: 10),
              Text('No critical alerts — all stations normal',
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          children: data.asMap().entries.map((e) {
            final i   = e.key;
            final d   = e.value;
            final col = _riskCol(d.riskLevel);
            final stale = _isStale(d);
            final levelAboveWarning = d.currentLevel > d.warningLevel;

            return AnimatedBuilder(
              animation: entryCtrl,
              builder: (_, child) {
                final delay = (i * 0.07).clamp(0.0, 0.6);
                final p = ((entryCtrl.value - delay) / (1.0 - delay))
                    .clamp(0.0, 1.0);
                return Opacity(
                  opacity: p,
                  child: Transform.translate(
                    offset: Offset(-16 * (1 - p), 0),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  border: i < data.length - 1
                      ? Border(
                          bottom: BorderSide(color: t.stroke, width: 0.7))
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Severity bar
                    Container(
                      width: 3, height: 52,
                      decoration: BoxDecoration(
                        color: col,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // City + stale indicator
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.city,
                                  style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (stale)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: const Color(0xFFFFA726),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              Text(
                                _timeAgo(d.lastUpdated),
                                style: TextStyle(
                                  color: stale
                                      ? const Color(0xFFFFA726)
                                      : t.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // River · state
                          Text(
                            '${d.riverName ?? d.state}  ·  ${d.state}',
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 10),
                          ),
                          const SizedBox(height: 6),
                          // Level chips row
                          Row(
                            children: [
                              _AlertChip(
                                label: '${d.currentLevel.toStringAsFixed(2)} m',
                                color: col,
                                icon: Icons.height,
                              ),
                              const SizedBox(width: 5),
                              _AlertChip(
                                label:
                                    '/${d.dangerLevel.toStringAsFixed(1)} m',
                                color: t.textSecondary,
                                icon: Icons.stream,
                              ),
                              if (d.effectiveRainfallMm > 0) ...[
                                const SizedBox(width: 5),
                                _AlertChip(
                                  label:
                                      '${d.effectiveRainfallMm.toStringAsFixed(0)} mm',
                                  color: const Color(0xFF42A5F5),
                                  icon: Icons.water_drop_outlined,
                                ),
                              ],
                              if (levelAboveWarning) ...[
                                const SizedBox(width: 5),
                                _AlertChip(
                                  label: '▲ warning',
                                  color: const Color(0xFFFFA726),
                                  icon: Icons.warning_amber_rounded,
                                ),
                              ],
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  d.riskLevel,
                                  style: TextStyle(
                                    color: col,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _AlertChip(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// SystemStats v2 — 2×2 grid layout, last-checked time per source
// ───────────────────────────────────────────────────────────────────────────
class SystemStats extends StatelessWidget {
  final RealTimeService service;
  final AnimationController pulseCtrl;
  final Animation<double> gaugeAnim;
  final bool reduceMotion;

  const SystemStats({
    super.key,
    required this.service, required this.pulseCtrl,
    required this.gaugeAnim, required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    final sources = [
      (
        label:   'GloFAS',
        detail:  'Flood Forecast',
        ok:       service.glofasHealthy,
        latency:  service.glofasLatencyMs,
      ),
      (
        label:   'WRD Bihar',
        detail:  'River Gauge',
        ok:       service.wrdHealthy,
        latency:  service.wrdLatencyMs,
      ),
      (
        label:   'IMD',
        detail:  'Rainfall Data',
        ok:       service.imdHealthy,
        latency:  service.imdLatencyMs,
      ),
      (
        label:   'CWC',
        detail:  'Central Water',
        ok:       service.cwcHealthy,
        latency:  service.cwcLatencyMs,
      ),
    ];

    final healthyCount = sources.where((s) => s.ok).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with summary
            Row(
              children: [
                Icon(Icons.hub_rounded,
                    size: 13, color: t.accent),
                const SizedBox(width: 6),
                Text(
                  'Data Sources',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (healthyCount == sources.length
                            ? AppPalette.safe
                            : AppPalette.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$healthyCount/${sources.length} online',
                    style: TextStyle(
                      color: healthyCount == sources.length
                          ? AppPalette.safe
                          : AppPalette.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 2×2 grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.8,
              children: sources
                  .map((s) => _SourceTile(
                        source: s,
                        pulseCtrl: pulseCtrl,
                        reduceMotion: reduceMotion,
                        t: t,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final ({
    String label,
    String detail,
    bool ok,
    int? latency
  }) source;
  final AnimationController pulseCtrl;
  final bool reduceMotion;
  final RiverColors t;

  const _SourceTile({
    required this.source,
    required this.pulseCtrl,
    required this.reduceMotion,
    required this.t,
  });

  static const _amber = Color(0xFFE6A817);

  Color get _dotColor {
    if (source.ok) return AppPalette.safe;
    if (source.latency == null) return _amber;
    return AppPalette.critical;
  }

  String? get _latencyLabel {
    final ms = source.latency;
    if (ms == null) return null;
    if (ms < 1000) return '$ms ms';
    return '${(ms / 1000).toStringAsFixed(1)} s';
  }

  @override
  Widget build(BuildContext context) {
    final col = _dotColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final pulse = source.ok && !reduceMotion
                  ? 0.5 + pulseCtrl.value * 0.5
                  : 0.9;
              return Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: col.withValues(alpha: pulse),
                  boxShadow: source.ok
                      ? [
                          BoxShadow(
                            color: col.withValues(
                                alpha: pulseCtrl.value * 0.45),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        source.label,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_latencyLabel != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _latencyLabel!,
                          style: TextStyle(
                            color: col,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  source.detail,
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 9),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// DashboardFooter v2 — adds stale-station count & richer data source line
// ───────────────────────────────────────────────────────────────────────────
class DashboardFooter extends StatelessWidget {
  final int totalStations, riversCount, statesAtRisk;
  final DateTime? lastUpdated;

  const DashboardFooter({
    super.key,
    required this.totalStations,
    required this.riversCount,
    required this.statesAtRisk,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final fmt = lastUpdated != null
        ? DateFormat('dd MMM, HH:mm').format(lastUpdated!)
        : 'Never';

    // Stale if > 3 hours
    final isStale = lastUpdated != null &&
        DateTime.now().difference(lastUpdated!).inHours >= 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat('$totalStations', 'stations', t),
                _Divider(t),
                _Stat('$riversCount', 'rivers', t),
                _Divider(t),
                _Stat('$statesAtRisk', 'at risk', t),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isStale
                    ? const Color(0xFFFFA726).withValues(alpha: 0.07)
                    : t.stroke.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isStale
                        ? Icons.access_time_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 11,
                    color: isStale
                        ? const Color(0xFFFFA726)
                        : AppPalette.safe,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isStale
                        ? 'Data may be stale · last sync $fmt'
                        : 'Last sync $fmt',
                    style: TextStyle(
                      color: isStale
                          ? const Color(0xFFFFA726)
                          : t.textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sources: WRD Bihar · GloFAS · IMD · CWC',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _Stat(String val, String label, RiverColors t) => Column(
        children: [
          Text(
            val,
            style: TextStyle(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: TextStyle(color: t.textSecondary, fontSize: 10),
          ),
        ],
      );

  Widget _Divider(RiverColors t) =>
      Container(width: 1, height: 32, color: t.stroke);
}

// ───────────────────────────────────────────────────────────────────────────
// DashboardEmptyState — unchanged
// ───────────────────────────────────────────────────────────────────────────
class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent.withValues(alpha: 0.10),
              ),
              child: Icon(Icons.water_drop_outlined,
                  color: t.accent, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No River Data',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh or check your network connection.',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
