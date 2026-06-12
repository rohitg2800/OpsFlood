// lib/widgets/dashboard/animated_area_chart.dart
// Multi-river interconnected capacity-trend graph v2.
//
// Changes from v1:
//   • Reads DataFetchEngine.instance.stream (StreamBuilder) — live data.
//   • Groups stations by river, picks peak station per river.
//   • Draws one colour-coded line per river:
//       Ganga  → cyan   (#00E5FF)
//       Kosi   → red    (#FF3B30)
//       Gandak → orange (#FF9500)
//       Punpun → green  (#34C759)
//       Other  → grey   (#8E8E93)
//   • Threshold bands at 75 % (warning) and 100 % (danger).
//   • Animated fill area + pulsing dot at current level.
//   • Falls back gracefully to the passed-in [values]/[labels] if engine
//     has no data yet (backward compatible).
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/data_fetch_engine.dart';
import '../../theme/river_theme.dart';

// River-name → line colour map
const _kRiverColors = <String, Color>{
  'ganga':   Color(0xFF00E5FF),
  'kosi':    Color(0xFFFF3B30),
  'gandak':  Color(0xFFFF9500),
  'punpun':  Color(0xFF34C759),
  'bagmati': Color(0xFF5AC8FA),
  'kamla':   Color(0xFFAF52DE),
  'burhi':   Color(0xFFFF2D55),
  'other':   Color(0xFF8E8E93),
};

Color _riverColor(String river) {
  final k = river.toLowerCase();
  for (final entry in _kRiverColors.entries) {
    if (k.contains(entry.key)) return entry.value;
  }
  return _kRiverColors['other']!;
}

// ─── Public widget ────────────────────────────────────────────────────────────
class AnimatedAreaChart extends StatelessWidget {
  /// Legacy single-series fallback (from dashboard_screen.dart build).
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
    return StreamBuilder<DataFetchSnapshot>(
      stream: DataFetchEngine.instance.stream,
      initialData: DataFetchEngine.instance.last,
      builder: (ctx, snap) {
        final stations = snap.data?.stations ?? [];
        // Build per-river series: river → peak progressPct station
        final Map<String, StationReading> riverPeak = {};
        for (final s in stations) {
          final existing = riverPeak[s.river];
          if (existing == null || s.progressPct > existing.progressPct) {
            riverPeak[s.river] = s;
          }
        }
        // Sort rivers by progressPct descending
        final sorted = riverPeak.values.toList()
          ..sort((a, b) => b.progressPct.compareTo(a.progressPct));

        // Fallback to legacy single series when engine empty
        final series = sorted.isEmpty
            ? _legacySeries()
            : sorted
                .map((s) => _RiverSeries(
                      river:   s.river,
                      station: s.stationName,
                      pct:     s.progressPct.clamp(0.0, 150.0),
                      color:   _riverColor(s.river),
                      risk:    s.riskLabel,
                    ))
                .toList();

        return _MultiRiverChart(
          series:       series,
          gaugeAnim:    gaugeAnim,
          waveCtrl:     waveCtrl,
          reduceMotion: reduceMotion,
        );
      },
    );
  }

  List<_RiverSeries> _legacySeries() {
    if (values.isEmpty) return [];
    return List.generate(values.length, (i) => _RiverSeries(
      river:   labels.length > i ? labels[i] : 'S${i + 1}',
      station: labels.length > i ? labels[i] : 'S${i + 1}',
      pct:     values[i],
      color:   _kRiverColors['other']!,
      risk:    values[i] >= 100 ? 'CRITICAL' : values[i] >= 75 ? 'WARNING' : 'NORMAL',
    ));
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────
class _RiverSeries {
  final String river;
  final String station;
  final double pct;
  final Color  color;
  final String risk;
  const _RiverSeries({
    required this.river,
    required this.station,
    required this.pct,
    required this.color,
    required this.risk,
  });
}

// ─── Main chart widget ────────────────────────────────────────────────────────
class _MultiRiverChart extends StatelessWidget {
  final List<_RiverSeries> series;
  final Animation<double>   gaugeAnim;
  final AnimationController waveCtrl;
  final bool                reduceMotion;

  const _MultiRiverChart({
    required this.series,
    required this.gaugeAnim,
    required this.waveCtrl,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (series.isEmpty) return const SizedBox.shrink();

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
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                children: [
                  Icon(Icons.area_chart_rounded, size: 13, color: t.accent),
                  const SizedBox(width: 6),
                  Text(
                    'River Capacity Trend',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  // Live dot
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.safe,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('LIVE',
                      style: TextStyle(
                          color: AppPalette.safe,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Chart area ──────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Y-axis labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['150', '100', '75', '50', '25', '0']
                      .map((l) => SizedBox(
                            height: 18,
                            child: Text(
                              l,
                              style: TextStyle(
                                color: l == '100'
                                    ? AppPalette.danger.withValues(alpha: 0.8)
                                    : l == '75'
                                        ? AppPalette.warning.withValues(alpha: 0.8)
                                        : t.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 108,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([gaugeAnim, waveCtrl]),
                      builder: (_, __) => CustomPaint(
                        painter: _MultiRiverPainter(
                          series:    series,
                          progress:  gaugeAnim.value,
                          wavePhase: reduceMotion ? 0 : waveCtrl.value * 2 * math.pi,
                          gridColor: t.stroke,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Legend: scrollable chips per river ──────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 22),
              child: Row(
                children: [
                  for (final s in series) ...[
                    _RiverLegendChip(series: s),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            // ── Threshold legend ────────────────────────────────────
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Row(
                children: [
                  _ThresholdDash(color: AppPalette.danger,  label: 'Danger 100%'),
                  const SizedBox(width: 12),
                  _ThresholdDash(color: AppPalette.warning, label: 'Warning 75%'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiverLegendChip extends StatelessWidget {
  final _RiverSeries series;
  const _RiverLegendChip({required this.series});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: series.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: series.color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: series.color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            series.river,
            style: TextStyle(
              color: series.color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${series.pct.toStringAsFixed(0)}%',
            style: TextStyle(
              color: series.color.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdDash extends StatelessWidget {
  final Color  color;
  final String label;
  const _ThresholdDash({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16, height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── CustomPainter — multi-river bars + threshold lines ──────────────────────
class _MultiRiverPainter extends CustomPainter {
  final List<_RiverSeries> series;
  final double progress;
  final double wavePhase;
  final Color  gridColor;

  const _MultiRiverPainter({
    required this.series,
    required this.progress,
    required this.wavePhase,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    const maxPct  = 150.0;   // chart ceiling (above danger = red zone)
    final h       = size.height;
    final w       = size.width;
    final n       = series.length;
    final barW    = (w / n).clamp(4.0, 28.0);
    final barGap  = barW * 0.25;

    // ── Grid lines ───────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (final pct in [0.0, 25.0, 50.0, 75.0, 100.0, 150.0]) {
      final y = h - (pct / maxPct) * h;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // ── Threshold bands ──────────────────────────────────────────
    // Danger zone: 100%–150% — faint red fill
    canvas.drawRect(
      Rect.fromLTRB(0, 0, w, h - (100.0 / maxPct) * h),
      Paint()..color = AppPalette.critical.withValues(alpha: 0.05),
    );
    // Warning zone: 75%–100% — faint amber fill
    final warnTop = h - (100.0 / maxPct) * h;
    final warnBot = h - (75.0  / maxPct) * h;
    canvas.drawRect(
      Rect.fromLTRB(0, warnTop, w, warnBot),
      Paint()..color = AppPalette.warning.withValues(alpha: 0.04),
    );

    // ── Danger threshold line (100%) ─────────────────────────────
    final dangerY = h - (100.0 / maxPct) * h;
    _drawDashedLine(canvas, Offset(0, dangerY), Offset(w, dangerY),
        AppPalette.danger.withValues(alpha: 0.50));
    // ── Warning threshold line (75%) ─────────────────────────────
    final warnY = h - (75.0 / maxPct) * h;
    _drawDashedLine(canvas, Offset(0, warnY), Offset(w, warnY),
        AppPalette.warning.withValues(alpha: 0.50));

    // ── Bars ──────────────────────────────────────────────────────
    for (int i = 0; i < n; i++) {
      final s        = series[i];
      final animated = s.pct * progress;
      final shimmer  = math.sin(wavePhase + i * 0.8) * 1.2 * progress;
      final barH     = ((animated + shimmer) / maxPct * h).clamp(0.0, h);
      final x        = i * (barW + barGap);
      final top      = h - barH;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barW, barH),
        const Radius.circular(4),
      );

      // Gradient fill
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [
              s.color.withValues(alpha: 0.85),
              s.color.withValues(alpha: 0.30),
            ],
          ).createShader(Rect.fromLTWH(x, top, barW, barH)),
      );

      // Top-edge pulse dot
      if (progress > 0.3) {
        final dotY = top;
        canvas.drawCircle(
          Offset(x + barW / 2, dotY),
          3.5,
          Paint()..color = s.color,
        );
        canvas.drawCircle(
          Offset(x + barW / 2, dotY),
          2.0,
          Paint()..color = Colors.white.withValues(alpha: 0.70),
        );
      }
    }

    // ── Interconnect line through bar tops ────────────────────────
    if (n >= 2 && progress > 0.5) {
      final pts = <Offset>[];
      for (int i = 0; i < n; i++) {
        final s        = series[i];
        final animated = s.pct * progress;
        final shimmer  = math.sin(wavePhase + i * 0.8) * 1.2 * progress;
        final barH     = ((animated + shimmer) / maxPct * h).clamp(0.0, h);
        final x        = i * (barW + barGap) + barW / 2;
        pts.add(Offset(x, h - barH));
      }
      final linePath = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        final prev = pts[i - 1];
        final cur  = pts[i];
        final dx   = (cur.dx - prev.dx) * 0.45;
        linePath.cubicTo(
          prev.dx + dx, prev.dy,
          cur.dx  - dx, cur.dy,
          cur.dx,       cur.dy,
        );
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color      = Colors.white.withValues(alpha: 0.15 * progress)
          ..strokeWidth = 1.0
          ..style      = PaintingStyle.stroke
          ..strokeCap  = StrokeCap.round,
      );
    }
  }

  void _drawDashedLine(
      Canvas canvas, Offset start, Offset end, Color color) {
    const dashLen = 6.0;
    const gapLen  = 4.0;
    final paint   = Paint()..color = color..strokeWidth = 1.0;
    final total   = (end.dx - start.dx);
    double x      = start.dx;
    while (x < end.dx) {
      canvas.drawLine(
          Offset(x, start.dy),
          Offset(math.min(x + dashLen, end.dx), start.dy),
          paint);
      x += dashLen + gapLen;
    }
    if (total == 0) {
      double y = start.dy;
      while (y < end.dy) {
        canvas.drawLine(
            Offset(start.dx, y),
            Offset(start.dx, math.min(y + dashLen, end.dy)),
            paint);
        y += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_MultiRiverPainter old) =>
      old.progress != progress || old.wavePhase != wavePhase ||
      old.series.length != series.length;
}
