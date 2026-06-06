// lib/widgets/danger_proximity_banner.dart
// Shows a red animated banner if user is within 80 km of a CRITICAL/SEVERE gauge.
// Uses BiharGauge (has lat/lon) instead of FloodData.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bihar_rivers.dart';
import '../providers/flood_providers.dart';
import '../providers/location_provider.dart';
import '../theme/river_theme.dart';

class DangerProximityBanner extends ConsumerWidget {
  const DangerProximityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locState   = ref.watch(locationProvider);
    final floodAsync = ref.watch(floodDataProvider);

    // Not loaded yet or no location
    if (locState.isLoading || locState.lat == null) {
      return const SizedBox.shrink();
    }

    return floodAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (stations) {
        // Find nearest CRITICAL/SEVERE gauge within 80 km using BiharGauge registry
        BiharGauge? nearest;
        double minDist = double.infinity;
        String nearestStatus = '';

        for (final gauge in kBiharGauges) {
          final d = _haversine(
            locState.lat!, locState.lon!,
            gauge.lat,     gauge.lon,
          );
          if (d > 80.0) continue;  // outside 80 km radius

          // Match gauge to live flood data by station name
          final live = stations.firstWhere(
            (s) => s.station.toLowerCase().contains(
                       gauge.station.toLowerCase().split(' ').first),
            orElse: () => stations.first,
          );

          final level  = live.currentLevel ?? 0.0;
          final status = level >= gauge.dangerLevel  ? 'DANGER'
                       : level >= gauge.warningLevel ? 'WARNING'
                       : 'SAFE';

          if ((status == 'DANGER' || status == 'WARNING') && d < minDist) {
            minDist       = d;
            nearest       = gauge;
            nearestStatus = status;
          }
        }

        if (nearest == null) return const SizedBox.shrink();
        return _BannerWidget(
          station: nearest.station,
          district: nearest.district,
          distKm:  minDist,
          status:  nearestStatus,
        );
      },
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r   = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a   = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
                sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

// ── Animated banner widget ────────────────────────────────────────────────────
class _BannerWidget extends StatefulWidget {
  final String station;
  final String district;
  final double distKm;
  final String status;
  const _BannerWidget({
    required this.station,
    required this.district,
    required this.distKm,
    required this.status,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDanger  = widget.status == 'DANGER';
    final baseColor = isDanger ? AppPalette.critical : AppPalette.warning;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color:   Color.lerp(baseColor, baseColor.withValues(alpha: 0.7), _anim.value),
        child: Row(
          children: [
            Icon(
              isDanger ? Icons.warning_rounded : Icons.info_rounded,
              color: Colors.white, size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${widget.status}: ${widget.station} (${widget.district}) '
                '${widget.distKm.toStringAsFixed(0)} km away',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
