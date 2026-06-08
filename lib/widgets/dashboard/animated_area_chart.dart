// lib/widgets/dashboard/animated_area_chart.dart
// Capacity-distribution area chart with animated fill + Y-axis grid labels.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/river_theme.dart';

// ─── Public widget ────────────────────────────────────────────────────────────
class AnimatedAreaChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Animation<double> gaugeAnim;
  final AnimationController waveCtrl;
  final bool reduceMotion;

  const AnimatedAreaChart({
    super.key,
    required this.values,
    required this.labels,
    required this.gaugeAnim,
    required this.waveCtrl,
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
                  Icon(Icons.area_chart_rounded, size: 13, color: t.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Capacity Distribution',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
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
                            child: Text(
                              l,
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 110,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([gaugeAnim, waveCtrl]),
                      builder: (_, __) => CustomPaint(
                        painter: _AreaChartPainter(
                          values: values,
                          progress: gaugeAnim.value,
                          wavePhase: reduceMotion
                              ? 0
                              : waveCtrl.value * 2 * math.pi,
                          lineColor: t.accent,
                          fillColor: t.accent.withValues(alpha: 0.15),
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
                      labels[i].substring(0, math.min(3, labels[i].length)),
                      style: TextStyle(color: t.textSecondary, fontSize: 10),
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

// ─── Private: legend dot ──────────────────────────────────────────────────────
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Private: CustomPainter ───────────────────────────────────────────────────
class _AreaChartPainter extends CustomPainter {
  final List<double> values;
  final double progress;
  final double wavePhase;
  final Color lineColor, fillColor, dotColor, gridColor;

  const _AreaChartPainter({
    required this.values,
    required this.progress,
    required this.wavePhase,
    required this.lineColor,
    required this.fillColor,
    required this.dotColor,
    required this.gridColor,
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

    // Data points with wave shimmer
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = i * xStep;
      final rawY = (1 - values[i] / maxV) * size.height;
      final shimmer = math.sin(wavePhase + i * 0.5) * 1.5 * progress;
      pts.add(Offset(x, rawY + shimmer));
    }

    // Fill area
    final fillPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(pts[0].dx, pts[0].dy * progress);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final cur = Offset(pts[i].dx, pts[i].dy * progress);
      fillPath.cubicTo(
        prev.dx + xStep * 0.4, prev.dy,
        cur.dx - xStep * 0.4, cur.dy,
        cur.dx, cur.dy,
      );
    }
    fillPath
      ..lineTo(size.width, size.height)
      ..close();
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
    final linePath = Path()
      ..moveTo(pts[0].dx, pts[0].dy * progress);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final cur = Offset(pts[i].dx, pts[i].dy * progress);
      linePath.cubicTo(
        prev.dx + xStep * 0.4, prev.dy,
        cur.dx - xStep * 0.4, cur.dy,
        cur.dx, cur.dy,
      );
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Data-point dots
    for (final p in pts.map((pt) => Offset(pt.dx, pt.dy * progress))) {
      canvas.drawCircle(p, 3.5, Paint()..color = dotColor);
      canvas.drawCircle(p, 2.0, Paint()..color = Colors.white.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) =>
      old.progress != progress || old.wavePhase != wavePhase;
}
