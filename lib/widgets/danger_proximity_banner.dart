// lib/widgets/danger_proximity_banner.dart
// OpsFlood — "Am I in Danger?" GPS proximity banner
// Shows at top of HomeScreen when user is near a Critical/Severe gauge.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../providers/location_provider.dart';
import '../theme/river_theme.dart';

class DangerProximityBanner extends ConsumerWidget {
  const DangerProximityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc    = ref.watch(locationProvider);
    final gauges = ref.watch(liveLevelsProvider);

    if (!loc.hasLocation) return const SizedBox.shrink();

    // Find the nearest gauge within 80 km
    FloodData? nearest;
    double minDistKm = 80.0;

    for (final g in gauges) {
      if (g.lat == null || g.lon == null) continue;
      final d = _haversine(loc.lat!, loc.lon!, g.lat!, g.lon!);
      if (d < minDistKm) {
        minDistKm = d;
        nearest = g;
      }
    }

    if (nearest == null) return const SizedBox.shrink();

    final risk  = nearest.riskLevel;
    final isBad = risk == 'CRITICAL' || risk == 'SEVERE';
    final col   = nearest.priorityColor;
    final gap   = nearest.dangerLevel - nearest.currentLevel;
    final above = gap < 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: col.withValues(alpha: isBad ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: col.withValues(alpha: isBad ? 0.40 : 0.20),
          width: isBad ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isBad ? Icons.crisis_alert_rounded : Icons.location_on_rounded,
            color: col, size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBad
                      ? '⚠ Nearest gauge at ${risk.toLowerCase()} risk!'
                      : 'Nearest gauge: ${nearest.riskLevel.toLowerCase()} risk',
                  style: TextStyle(
                    color: col, fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${nearest.city} · ${nearest.riverName ?? ""} · '
                  '${minDistKm.toStringAsFixed(1)} km away · '
                  '${above ? "${gap.abs().toStringAsFixed(2)} m ABOVE danger" : "${gap.toStringAsFixed(2)} m to danger"}',
                  style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Haversine distance in km between two lat/lon points.
  double _haversine(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180;
}
