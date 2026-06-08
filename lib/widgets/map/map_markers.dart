// lib/widgets/map/map_markers.dart
// PulseMarker  — animated ring for CRITICAL / HIGH stations.
// StaticMarker — plain dot for MODERATE / LOW stations.
import 'package:flutter/material.dart';
import '../../providers/map_command_provider.dart';
import 'map_risk_helpers.dart';

// ── PulseMarker ─────────────────────────────────────────────────────────────
class PulseMarker extends StatelessWidget {
  final DangerClass dangerClass;
  final AnimationController ctrl;

  const PulseMarker({
    super.key,
    required this.dangerClass,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = riskColorSolid(dangerClass);
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final scale = 1.0 + 0.35 * ctrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring
            Transform.scale(
              scale: scale,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:  color.withOpacity(0.15 * (1 - ctrl.value)),
                  border: Border.all(
                    color: color.withOpacity(0.4 * (1 - ctrl.value)),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Core dot
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color:      color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.white,
                size:  12,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── StaticMarker ─────────────────────────────────────────────────────────────
class StaticMarker extends StatelessWidget {
  final DangerClass dangerClass;
  const StaticMarker({super.key, required this.dangerClass});

  @override
  Widget build(BuildContext context) {
    final color = riskColorSolid(dangerClass);
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.85),
        border: Border.all(
            color: Colors.white.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 6),
        ],
      ),
      child: const Icon(
        Icons.water_drop_rounded,
        color: Colors.white,
        size:  14,
      ),
    );
  }
}
