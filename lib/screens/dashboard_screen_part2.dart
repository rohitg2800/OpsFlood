// lib/screens/dashboard_screen_part2.dart
// Continuation widgets for DashboardScreen redesign v25
// These are private to the library so they are exported via the main file.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';

// Re-expose colour helper for this part
Color _riskCol(String lvl) {
  switch (lvl.toUpperCase()) {
    case 'CRITICAL': return AppPalette.critical;
    case 'SEVERE':   return AppPalette.danger;
    case 'MODERATE': return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}

// ───────────────────────────────────────────────────────────────────────────
// _AnimatedAreaChart — smooth CustomPainter area chart
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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capacity Distribution',
                style: TextStyle(
                  color: t.textSecondary, fontSize: 10,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: AnimatedBuilder(
                animation: Listenable.merge([gaugeAnim, waveCtrl]),
                builder: (_, __) => CustomPaint(
                  painter: _AreaChartPainter(
                    values: values,
                    progress: gaugeAnim.value,
                    wavePhase: reduceMotion ? 0 : waveCtrl.value * 2 * math.pi,
                    lineColor: t.accent,
                    fillColor: t.accent.withValues(alpha: 0.15),
                    dotColor: t.accent,
                    gridColor: t.stroke,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // X labels — take every other to avoid clutter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 0; i < labels.length; i += math.max(1, labels.length ~/ 5))
                  Text(
                    labels[i].substring(0, math.min(3, labels[i].length)),
                    style: TextStyle(color: t.textSecondary, fontSize: 8),
                  ),
              ],
            ),
          ],
        ),
      ),
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

    // Grid lines
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (int g = 0; g <= 4; g++) {
      final y = size.height - (g / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Compute points
    List<Offset> pts = [];
    for (int i = 0; i < n; i++) {
      final x = i * xStep;
      final rawY = (1 - values[i] / maxV) * size.height;
      // Apply wave shimmer near the top of each bar
      final shimmer = math.sin(wavePhase + i * 0.5) * 1.5 * progress;
      pts.add(Offset(x, rawY + shimmer));
    }

    // Fill area
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

    // Line
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

    // Dots at each data point
    for (int i = 0; i < pts.length; i++) {
      final p = Offset(pts[i].dx, pts[i].dy * progress);
      canvas.drawCircle(p, 3.5,
          Paint()..color = dotColor);
      canvas.drawCircle(p, 2.0,
          Paint()..color = Colors.white.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) =>
      old.progress != progress || old.wavePhase != wavePhase;
}

// ───────────────────────────────────────────────────────────────────────────
// _AlertLog — slide-in list
// ───────────────────────────────────────────────────────────────────────────
class AlertLog extends StatelessWidget {
  final List<FloodData> data;
  final AnimationController entryCtrl;

  const AlertLog({super.key, required this.data, required this.entryCtrl});

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
            border: Border.all(color: AppPalette.safe.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: AppPalette.safe, size: 18),
              const SizedBox(width: 10),
              Text('No critical alerts logged',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
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
            return AnimatedBuilder(
              animation: entryCtrl,
              builder: (_, child) {
                final delay = (i * 0.07).clamp(0.0, 0.6);
                final p = ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
                return Opacity(
                  opacity: p,
                  child: Transform.translate(
                    offset: Offset(-16 * (1 - p), 0),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: i < data.length - 1
                      ? Border(bottom: BorderSide(color: t.stroke, width: 0.7))
                      : null,
                ),
                child: Row(
                  children: [
                    // Left accent line
                    Container(
                      width: 3, height: 36,
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
                          Text(d.city,
                              style: TextStyle(
                                color: t.textPrimary, fontSize: 12,
                                fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('${d.riverName ?? d.state} · ${d.capacityPercent.toStringAsFixed(0)}% capacity',
                              style: TextStyle(
                                color: t.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(d.riskLevel,
                          style: TextStyle(
                            color: col, fontSize: 9,
                            fontWeight: FontWeight.w800)),
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

// ───────────────────────────────────────────────────────────────────────────
// _SystemStats
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
    final health = [
      (label: 'GloFAS',  ok: service.isOnline, detail: 'flood forecast'),
      (label: 'WRD Bihar',ok: service.isOnline, detail: 'river gauge'),
      (label: 'IMD',      ok: service.isOnline, detail: 'rainfall'),
      (label: 'CWC',      ok: true,             detail: 'central water'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: health.map((h) {
            final col = h.ok ? AppPalette.safe : AppPalette.critical;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: col.withValues(alpha: 0.20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: pulseCtrl,
                    builder: (_, __) => Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: col.withValues(
                          alpha: h.ok
                              ? 0.5 + pulseCtrl.value * 0.5
                              : 0.8),
                        boxShadow: h.ok ? [
                          BoxShadow(
                            color: col.withValues(
                              alpha: pulseCtrl.value * 0.5),
                            blurRadius: 6),
                        ] : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.label,
                          style: TextStyle(
                            color: t.textPrimary, fontSize: 11,
                            fontWeight: FontWeight.w800)),
                      Text(h.detail,
                          style: TextStyle(
                            color: t.textSecondary, fontSize: 9)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// _Footer
// ───────────────────────────────────────────────────────────────────────────
class DashboardFooter extends StatelessWidget {
  final int totalStations, riversCount, statesAtRisk;
  final DateTime? lastUpdated;
  const DashboardFooter({
    super.key,
    required this.totalStations, required this.riversCount,
    required this.statesAtRisk, required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final fmt = lastUpdated != null
        ? DateFormat('dd MMM, HH:mm').format(lastUpdated!)
        : 'Never';
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
            const SizedBox(height: 12),
            Text('Last updated: $fmt · Data: WRD Bihar, GloFAS, IMD',
                style: TextStyle(
                  color: t.textSecondary, fontSize: 9.5,
                  fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _Stat(String val, String label, RiverColors t) => Column(
    children: [
      Text(val, style: TextStyle(
          color: t.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
      Text(label, style: TextStyle(
          color: t.textSecondary, fontSize: 10)),
    ],
  );

  Widget _Divider(RiverColors t) => Container(
    width: 1, height: 32,
    color: t.stroke,
  );
}

// ───────────────────────────────────────────────────────────────────────────
// _EmptyState
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
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent.withValues(alpha: 0.10),
              ),
              child: Icon(Icons.water_drop_outlined, color: t.accent, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          Text('No River Data',
              style: TextStyle(
                color: t.textPrimary, fontSize: 18,
                fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Pull down to refresh or check your network connection.',
              style: TextStyle(
                color: t.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
