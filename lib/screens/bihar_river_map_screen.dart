// lib/screens/bihar_river_map_screen.dart
// OpsFlood — BiharRiverMapScreen v1
//
// Interactive flutter_map showing all 32 WRD Bihar gauge stations.
// Each pin is colour-coded by live risk from biharLiveProvider:
//   CRITICAL / DANGER  →  red pulsing pin
//   WARNING / HIGH     →  orange pin
//   NORMAL / SAFE      →  green pin
//   No live data       →  grey pin (static threshold from kBiharGauges)
//
// Tap a pin → bottom sheet with:
//   river name, district, live level vs warning/danger thresholds,
//   GloFAS discharge + rainfall, trend arrow, "Open City Detail" button
//
// Legend + river filter chip row at the top.
// Locate-me FAB centres the map on the device location (geolocator).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../data/bihar_rivers.dart';
import '../providers/bihar_live_provider.dart';
import '../theme/river_theme.dart';
import 'city_detail_screen.dart';

// ── Tile URL (OpenStreetMap — no API key needed) ────────────────────────
// Fallback dark tiles from CARTO for the dark theme feel.
const _osmTileUrl =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _cartoTileUrl =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
const _cartoSubdomains = ['a', 'b', 'c', 'd'];

// ── Bihar centroid ──────────────────────────────────────────────────────
const _biharCenter = LatLng(25.78, 85.82);
const _initialZoom  = 7.4;

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  static const String route = '/bihar_river_map';
  const BiharRiverMapScreen({super.key});

  @override
  ConsumerState<BiharRiverMapScreen> createState() =>
      _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState
    extends ConsumerState<BiharRiverMapScreen> {
  final _mapCtrl     = MapController();
  String? _filterRiver; // null = show all
  bool    _darkTiles  = true;

  // All unique river names for the filter chips
  static final _rivers =
      kBiharGauges.map((g) => g.river).toSet().toList()..sort();

  @override
  Widget build(BuildContext context) {
    final t          = RiverColors.of(context);
    final biharState = ref.watch(biharLiveProvider);

    // Build a city → BiharStationData lookup from live data
    final liveMap = biharState.maybeWhen(
      data: (s) => {
        for (final st in s.stations)
          st.city.trim().toLowerCase(): st,
      },
      orElse: () => <String, BiharStationData>{},
    );

    final gauges = _filterRiver == null
        ? kBiharGauges
        : kBiharGauges.where((g) => g.river == _filterRiver).toList();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Stack(
        children: [

          // ────────────────────────── MAP ───────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _biharCenter,
              initialZoom:   _initialZoom,
              minZoom: 6.0,
              maxZoom: 14.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: _darkTiles ? _cartoTileUrl : _osmTileUrl,
                subdomains:  _darkTiles ? _cartoSubdomains : const [],
                userAgentPackageName: 'com.equinox.floodwatch',
                retinaMode: true,
              ),

              // Station markers
              MarkerLayer(
                markers: gauges.map((gauge) {
                  final key  = gauge.station.trim().toLowerCase();
                  final live = liveMap[key];
                  final risk = live?.riskLabel ?? 'NORMAL';
                  return Marker(
                    point:  LatLng(gauge.lat, gauge.lon),
                    width:  40,
                    height: 48,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showStationSheet(
                            context, gauge, live, t);
                      },
                      child: _StationPin(
                          risk: risk, live: live != null),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ──────────────────── TOP BAR ─────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  // Title row
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: t.cardBg.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.stroke),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.map_rounded,
                            color: t.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bihar River Gauge Map',
                            style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        // Live count badge
                        _LiveBadge(liveMap: liveMap),
                        const SizedBox(width: 8),
                        // Dark/light tile toggle
                        GestureDetector(
                          onTap: () =>
                              setState(() => _darkTiles = !_darkTiles),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: t.cardBgElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: t.stroke),
                            ),
                            child: Icon(
                              _darkTiles
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              color: t.textSecondary,
                              size: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // River filter chips
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      children: [
                        _FilterChip(
                          label: 'All',
                          active: _filterRiver == null,
                          t: t,
                          onTap: () =>
                              setState(() => _filterRiver = null),
                        ),
                        ...(_rivers.map((r) => _FilterChip(
                              label: r,
                              active: _filterRiver == r,
                              t: t,
                              onTap: () => setState(
                                  () => _filterRiver =
                                      _filterRiver == r ? null : r),
                            ))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ────────────────── LEGEND (bottom-left) ─────────────────
          Positioned(
            bottom: 100,
            left: 12,
            child: _Legend(t: t),
          ),
        ],
      ),

      // ────────────────── Locate-me FAB ────────────────────
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'locate_me',
        backgroundColor: t.cardBg,
        foregroundColor: t.accent,
        tooltip: 'Centre on my location',
        onPressed: () => _locateMe(context),
        child: const Icon(Icons.my_location_rounded, size: 18),
      ),
    );
  }

  // ── locate-me ─────────────────────────────────────────────────────────
  Future<void> _locateMe(BuildContext context) async {
    final t = RiverColors.of(context);
    HapticFeedback.lightImpact();
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission denied'),
              backgroundColor: t.cardBg,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium));
      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 10.5);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get location: $e'),
            backgroundColor: t.cardBg,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── station bottom sheet ───────────────────────────────────────────────
  void _showStationSheet(
    BuildContext context,
    BiharGauge      gauge,
    BiharStationData? live,
    RiverColors     t,
  ) {
    showModalBottomSheet(
      context:          context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StationSheet(
          gauge: gauge, live: live, t: t),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

// ── Station pin ───────────────────────────────────────────────────────────────────

Color _pinColor(String risk) {
  switch (risk.toUpperCase()) {
    case 'CRITICAL':
    case 'DANGER':   return AppPalette.critical;
    case 'WARNING':
    case 'HIGH':     return AppPalette.warning;
    case 'NORMAL':
    case 'SAFE':     return AppPalette.safe;
    default:         return const Color(0xFF607D8B); // grey = no data
  }
}

class _StationPin extends StatelessWidget {
  final String risk;
  final bool   live;
  const _StationPin({required this.risk, required this.live});

  @override
  Widget build(BuildContext context) {
    final col     = _pinColor(risk);
    final isCrit  = risk.toUpperCase() == 'CRITICAL' ||
                    risk.toUpperCase() == 'DANGER';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing ring for critical stations
        if (isCrit)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (_, v, child) => Opacity(
              opacity: v,
              child: Container(
                width: 28 * v,
                height: 28 * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: col.withValues(alpha: 0.25),
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 10),

        // Pin dot
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: col,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: col.withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 1),
            ],
          ),
          child: live
              ? null
              : const Icon(Icons.wifi_off_rounded,
                  color: Colors.white, size: 8),
        ),
      ],
    );
  }
}

// ── Live count badge ─────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  final Map<String, BiharStationData> liveMap;
  const _LiveBadge({required this.liveMap});

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final critical = liveMap.values
        .where((s) => s.isCritical)
        .length;
    if (critical == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppPalette.safe.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppPalette.safe.withValues(alpha: 0.3)),
        ),
        child: Text(
          '${liveMap.length} live',
          style: const TextStyle(
              color: AppPalette.safe,
              fontSize: 9,
              fontWeight: FontWeight.w700),
        ),
      );
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppPalette.critical.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppPalette.critical.withValues(alpha: 0.3)),
      ),
      child: Text(
        '⚠ $critical critical',
        style: const TextStyle(
            color: AppPalette.critical,
            fontSize: 9,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── River filter chip ────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String   label;
  final bool     active;
  final RiverColors t;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? t.accent.withValues(alpha: 0.18)
              : t.cardBg.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? t.accent.withValues(alpha: 0.55)
                : t.stroke,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? t.accent : t.textSecondary,
            fontSize: 11,
            fontWeight:
                active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final RiverColors t;
  const _Legend({required this.t});

  static const _entries = [
    (AppPalette.critical, 'Critical'),
    (AppPalette.warning,  'Warning'),
    (AppPalette.safe,     'Safe'),
    (Color(0xFF607D8B),   'No data'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.cardBg.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                          color: e.$1, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(e.$2,
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Station bottom sheet ─────────────────────────────────────────────────────

class _StationSheet extends StatelessWidget {
  final BiharGauge      gauge;
  final BiharStationData? live;
  final RiverColors     t;
  const _StationSheet({
    required this.gauge,
    required this.live,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final risk  = live?.riskLabel ?? 'NO DATA';
    final col   = _pinColor(risk);

    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            top: BorderSide(
                color: col.withValues(alpha: 0.35), width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: t.stroke,
                borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Station name + risk badge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gauge.station,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      '${gauge.river}  ·  ${gauge.district}',
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: col.withValues(alpha: 0.45)),
                ),
                child: Text(
                  risk,
                  style: TextStyle(
                      color: col,
                      fontWeight: FontWeight.w900,
                      fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─ Levels row
          if (live != null) ...[
            Row(
              children: [
                _SheetStat(
                  label: 'Current Level',
                  value: live!.currentLevel != null
                      ? '${live!.currentLevel!.toStringAsFixed(2)} m'
                      : '—',
                  color: col,
                  t: t,
                ),
                _SheetStat(
                  label: 'Warning',
                  value: '${gauge.warningLevel.toStringAsFixed(2)} m',
                  color: AppPalette.warning,
                  t: t,
                ),
                _SheetStat(
                  label: 'Danger',
                  value: '${gauge.dangerLevel.toStringAsFixed(2)} m',
                  color: AppPalette.danger,
                  t: t,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ─ GloFAS + Rainfall + Trend
            Row(
              children: [
                if (live!.discharge != null)
                  _SheetStat(
                    label: 'Discharge',
                    value: live!.discharge! >= 1000
                        ? '${(live!.discharge! / 1000).toStringAsFixed(1)}k m³/s'
                        : '${live!.discharge!.toStringAsFixed(0)} m³/s',
                    color: AppPalette.cyan,
                    t: t,
                  ),
                if (live!.rainfall24h != null)
                  _SheetStat(
                    label: '24h Rain',
                    value:
                        '${live!.rainfall24h!.toStringAsFixed(1)} mm',
                    color: Colors.lightBlue,
                    t: t,
                  ),
                _SheetStat(
                  label: 'Trend',
                  value: live!.trend.isEmpty ? '—' : live!.trend,
                  color: live!.trend.toUpperCase() == 'RISING'
                      ? AppPalette.danger
                      : AppPalette.safe,
                  t: t,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else ...[
            // Static thresholds only
            Row(
              children: [
                _SheetStat(
                  label: 'Warning',
                  value: '${gauge.warningLevel.toStringAsFixed(2)} m',
                  color: AppPalette.warning,
                  t: t,
                ),
                _SheetStat(
                  label: 'Danger',
                  value: '${gauge.dangerLevel.toStringAsFixed(2)} m',
                  color: AppPalette.danger,
                  t: t,
                ),
                _SheetStat(
                  label: 'HFL',
                  value: '${gauge.hfl.toStringAsFixed(2)} m',
                  color: AppPalette.critical,
                  t: t,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // ─ Open City Detail CTA
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                CityDetailScreen.route,
                arguments: gauge.station,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    t.accent.withValues(alpha: 0.7),
                    t.accent,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: t.accentGlow,
                      blurRadius: 14,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_new_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Open City Detail',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  final String    label, value;
  final Color     color;
  final RiverColors t;
  const _SheetStat({
    required this.label,
    required this.value,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
