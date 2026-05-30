import 'package:flutter/material.dart';
import '../models/station.dart';

class GaugeBar extends StatelessWidget {
  final Station station;
  final double height;
  final bool showLabels;

  const GaugeBar({
    super.key,
    required this.station,
    this.height = 8,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = station;
    final fill = s.fillFraction;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final range = s.dangerLevel - s.safeLevel;

        // Calculate marker positions
        double _pos(double level) {
          if (range <= 0) return 0;
          return ((level - s.safeLevel) / range).clamp(0.0, 1.0) * w;
        }

        final warnPos   = _pos(s.warningLevel);
        final dangerPos = _pos(s.dangerLevel);
        final fillColor = s.isDanger
          ? const Color(0xFFFF4757)
          : (s.isWarning ? const Color(0xFFFFA502) : const Color(0xFF00D4FF));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Background track
                Container(
                  height: height,
                  width: w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2840),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
                // Fill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  height: height,
                  width: fill * w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00D4FF),
                        fillColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
                // Warning marker
                Positioned(
                  left: warnPos - 1,
                  child: Container(
                    width: 2,
                    height: height,
                    color: const Color(0xFFFFA502),
                  ),
                ),
                // Danger marker
                Positioned(
                  left: dangerPos - 1,
                  child: Container(
                    width: 2,
                    height: height,
                    color: const Color(0xFFFF4757),
                  ),
                ),
              ],
            ),
            if (showLabels) ...
              [
                const SizedBox(height: 4),
                Stack(
                  children: [
                    SizedBox(width: w, height: 14),
                    Positioned(
                      left: (warnPos - 16).clamp(0, w - 32),
                      child: const Text('WARN', style: TextStyle(color: Color(0xFFFFA502), fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                    Positioned(
                      left: (dangerPos - 20).clamp(0, w - 40),
                      child: const Text('DANGER', style: TextStyle(color: Color(0xFFFF4757), fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
          ],
        );
      },
    );
  }
}
