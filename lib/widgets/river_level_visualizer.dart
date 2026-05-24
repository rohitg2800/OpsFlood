// lib/widgets/river_level_visualizer.dart
//
// OpsFlood — RiverLevelVisualizer
//
// Redesigned card matching the screenshot style:
//   • Dark glass card with risk-coloured left border glow
//   • Horizontal gauge bar with gradient fill
//   • Danger (red) + Warning (orange dashed) lines on bar
//   • Percentage arc badge (top-right)
//   • Live dot with source label
//   • Discharge m³/s chip when gauge is unavailable
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class RiverLevelVisualizer extends StatelessWidget {
  final String  city;
  final String  river;
  final double  currentLevel;   // metres MSL from CWC, 0 = no data
  final double  safeLevel;
  final double  warningLevel;
  final double  dangerLevel;
  final String  trend;          // 'Live', 'Partial', 'RISING', 'FALLING', etc.
  final double? flowRateM3s;    // GloFAS discharge, shown as fallback chip
  final String? cwcSource;      // 'CWC_FFEM', 'WRD_BIHAR', etc.

  const RiverLevelVisualizer({
    super.key,
    required this.city,
    required this.river,
    required this.currentLevel,
    required this.safeLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.trend,
    this.flowRateM3s,
    this.cwcSource,
  });

  // ── Risk label from real gauge ratio ────────────────────────────────────
  String get _riskLabel {
    if (dangerLevel <= 0) return 'LOW';
    if (currentLevel <= 0) return 'LOW';
    final r = currentLevel / dangerLevel;
    if (r >= 1.0)  return 'CRITICAL';
    if (r >= 0.85) return 'HIGH';
    if (r >= 0.65) return 'MODERATE';
    return 'LOW';
  }

  double get _pct {
    if (dangerLevel <= 0 || currentLevel <= 0) return 0.0;
    return (currentLevel / dangerLevel).clamp(0.0, 1.0);
  }

  Color get _riskColor {
    switch (_riskLabel) {
      case 'CRITICAL': return const Color(0xFFEF4444);
      case 'HIGH':     return const Color(0xFFF97316);
      case 'MODERATE': return const Color(0xFFF59E0B);
      default:         return const Color(0xFF34C759);
    }
  }

  bool get _hasRealLevel => currentLevel > 0.5 && dangerLevel > 0;

  @override
  Widget build(BuildContext context) {
    final rc    = RiverColors.of(context);
    final color = _riskColor;
    final pct   = _pct;

    final warnFrac = (dangerLevel > 0 && warningLevel > 0)
        ? (warningLevel / dangerLevel).clamp(0.0, 1.0)
        : 0.8;

    return Container(
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12, spreadRadius: 0, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Left glow edge
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0.2)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Row 1: city name + arc percentage badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: rc.textPrimary, fontWeight: FontWeight.w800,
                                fontSize: 16, letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              river,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: rc.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Arc % badge — fixed 68×68, never expands
                      _ArcBadge(pct: pct, color: color, riskLabel: _riskLabel),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Row 2: level value + live chip
                  // FIX: wrap children in Flexible so the Row never overflows
                  // on narrow cards (~217px in a 2-column grid).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_hasRealLevel) ...[
                        // The big level number can shrink/ellipsis if needed
                        Flexible(
                          child: Text(
                            '${currentLevel.toStringAsFixed(2)} m',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color, fontWeight: FontWeight.w900,
                              fontSize: 26, letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Chip is intrinsic-width but won't push beyond remaining space
                        Flexible(
                          flex: 0,
                          child: _LiveChip(source: cwcSource ?? trend),
                        ),
                      ] else if (flowRateM3s != null && flowRateM3s! > 0) ...[
                        Flexible(
                          child: Text(
                            '${flowRateM3s!.toStringAsFixed(0)} m³/s',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w800, fontSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          flex: 0,
                          child: _Chip(label: 'Discharge', color: Colors.blueAccent),
                        ),
                      ] else ...[
                        Flexible(
                          child: Text(
                            'No Gauge Data',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: rc.textSecondary, fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Gauge bar
                  _GaugeBar(
                    pct: pct, warnFrac: warnFrac, color: color, hasData: _hasRealLevel,
                  ),

                  const SizedBox(height: 8),

                  // Row 3: DL + WL threshold chips
                  // Use Expanded so each chip shares space equally and never overflows
                  Row(
                    children: [
                      Expanded(
                        child: _ThresholdChip(
                          icon: Icons.warning_amber_rounded,
                          label: 'DL',
                          value: dangerLevel > 0
                              ? '${dangerLevel.toStringAsFixed(1)} m'
                              : '—',
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ThresholdChip(
                          icon: Icons.show_chart_rounded,
                          label: 'WL',
                          value: warningLevel > 0
                              ? '${warningLevel.toStringAsFixed(1)} m'
                              : '—',
                          color: const Color(0xFFF59E0B),
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
  }
}

// ── Gauge bar ────────────────────────────────────────────────────────────────────────────────
class _GaugeBar extends StatelessWidget {
  final double pct;
  final double warnFrac;
  final Color  color;
  final bool   hasData;
  const _GaugeBar({required this.pct, required this.warnFrac,
      required this.color, required this.hasData});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      return Stack(
        children: [
          // Track
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          // Fill
          if (hasData && pct > 0)
            Container(
              height: 10,
              width: w * pct,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF34C759),
                    Color(0xFFF59E0B),
                    Color(0xFFEF4444),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          // Warning marker
          if (warnFrac > 0)
            Positioned(
              left: w * warnFrac - 1,
              top: 0, bottom: 0,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          // Danger marker (at 1.0)
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      );
    });
  }
}

// ── Arc percentage badge ─────────────────────────────────────────────────────────────────
class _ArcBadge extends StatelessWidget {
  final double pct;
  final Color  color;
  final String riskLabel;
  const _ArcBadge({required this.pct, required this.color, required this.riskLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68, height: 68,
      child: CustomPaint(
        painter: _ArcPainter(pct: pct, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${(pct * 100).round()}%',
                  style: TextStyle(
                    color: pct > 0 ? color : Colors.white38,
                    fontWeight: FontWeight.w900, fontSize: 14,
                  )),
              Text(riskLabel,
                  style: const TextStyle(
                    color: Colors.white54, fontSize: 7,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double pct;
  final Color  color;
  const _ArcPainter({required this.pct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.width - 8) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawArc(
      rect, math.pi * 0.75, math.pi * 1.5, false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color       = Colors.white.withValues(alpha: 0.08),
    );
    // Fill
    if (pct > 0) {
      canvas.drawArc(
        rect, math.pi * 0.75, math.pi * 1.5 * pct, false,
        Paint()
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap   = StrokeCap.round
          ..color       = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.pct != pct || old.color != color;
}

// ── Live chip ─────────────────────────────────────────────────────────────────────────────
class _LiveChip extends StatelessWidget {
  final String source;
  const _LiveChip({required this.source});

  String get _label {
    if (source.contains('FFEM'))    return 'CWC';
    if (source.contains('BEAMS'))   return 'CWC';
    if (source.contains('WRD'))     return 'WRD';
    if (source.contains('BACKEND')) return 'LIVE';
    return 'LIVE';
  }

  @override
  Widget build(BuildContext context) => _Chip(
    label: _label,
    color: const Color(0xFF34C759),
    dot: true,
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   dot;
  const _Chip({required this.label, required this.color, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5, height: 5,
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Threshold chip ────────────────────────────────────────────────────────────────────────────
class _ThresholdChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _ThresholdChip({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$label: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 10, fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
