// lib/widgets/danger_proximity_banner.dart
// Shows animated danger/warning banner when user is within 80 km of a flood gauge.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bihar_rivers.dart';
import '../models/flood_data.dart';              // ← FloodData
import '../providers/flood_providers.dart';      // liveLevelsProvider
import '../providers/location_provider.dart';
import '../theme/river_theme.dart';

class DangerProximityBanner extends ConsumerWidget {
  const DangerProximityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locState = ref.watch(locationProvider);
    final stations = ref.watch(liveLevelsProvider); // List<FloodData>

    if (locState.isLoading || locState.lat == null) {
      return const SizedBox.shrink();
    }

    BiharGauge? nearest;
    double      minDist       = double.infinity;
    String      nearestStatus = '';

    for (final gauge in kBiharGauges) {
      final d = _haversine(
        locState.lat!, locState.lon!,
        gauge.lat,     gauge.lon,
      );
      if (d > 80.0) continue;

      final live = stations.firstWhere(
        (s) => s.city.toLowerCase().contains(
                   gauge.station.toLowerCase().split(' ').first),
        orElse: () => stations.isNotEmpty ? stations.first : _emptyFlood(),
      );

      final level  = live.currentLevel;
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
      station:  nearest.station,
      district: nearest.district,
      distKm:   minDist,
      status:   nearestStatus,
    );
  }

  static FloodData _emptyFlood() => FloodData(
    city: '', district: '', state: '',
    currentLevel: 0, warningLevel: 0, dangerLevel: 0,
    safeLevel: 0, capacityPercent: 0,
    riskLevel: 'LOW', status: 'ESTIMATED',
    effectiveRainfallMm: 0,
    lastUpdated: DateTime.now(),
  );

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r    = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a    = sin(dLat / 2) * sin(dLat / 2) +
                 cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
                 sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

// ── Animated banner ───────────────────────────────────────────────────────────
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
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDanger  = widget.status == 'DANGER';
    final baseColor = isDanger ? AppPalette.critical : AppPalette.warning;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color:   Color.lerp(
            baseColor, baseColor.withValues(alpha: 0.7), _anim.value),
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
                  color:      Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize:   13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
