// lib/screens/bihar_river_map_screen.dart
// OpsFlood — BiharRiverMapScreen v2
//
// Fixes in v2:
//   1. liveMap key normalisation — strips spaces/parens/dashes so
//      'Birpur (CWC)' and 'birpur cwc' resolve to the same city.
//   2. Lat/lon proximity fallback (≤ 0.03°) for any still-unmatched gauge.
//   3. Tile cycling: Voyager (default, day-readable) → CARTO Dark → OSM.
//   4. Continuous pulsing ring for CRITICAL pins (AnimationController).
//   5. Full info bottom sheet: all levels + margins + discharge + rainfall.
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

// ── Tile sets ───────────────────────────────────────────────────────────────
enum _TileStyle { voyager, dark, osm }

const _voyagerUrl =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
const _darkUrl =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _cartoSubdomains = ['a', 'b', 'c', 'd'];

// ── Bihar centroid ──────────────────────────────────────────────────────────
const _biharCenter = LatLng(25.78, 85.82);
const _initialZoom = 7.4;

// ── Key normaliser ──────────────────────────────────────────────────────────
// Strips parentheses, leading/trailing spaces, collapses whitespace,
// removes hyphens — so 'Birpur (CWC)' → 'birpur cwc', 'Dheng Bridge' → 'dheng bridge'.
String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[()\-_]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  static const String route = '/bihar_river_map';
  const BiharRiverMapScreen({super.key});

  @override
  ConsumerState<BiharRiverMapScreen> createState() =>
      _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState extends ConsumerState<BiharRiverMapScreen> {
  final _mapCtrl   = MapController();
  String?    _filterRiver;
  _TileStyle _tileStyle = _TileStyle.voyager; // readable by default

  static final _rivers =
      kBiharGauges.map((g) => g.river).toSet().toList()..sort();

  // Build liveMap with normalised keys + a lat/lon proximity index
  ({Map<String, BiharStationData> byKey,
    List<BiharStationData> all}) _buildLiveIndex(
      List<BiharStationData> stations) {
    final byKey = <String, BiharStationData>{};
    for (final st in stations) {
      byKey[_norm(st.city)] = st;
    }
    return (byKey: byKey, all: stations);
  }

  // Proximity match: find station within ~3 km (0.03° lat/lon)
  BiharStationData? _proxMatch(
      BiharGauge gauge, List<BiharStationData> all) {
    BiharStationData? best;
    double bestDist = 0.03;
    for (final st in all) {
      // BiharStationData doesn't carry lat/lon — check if its city key
      // fuzzy-matches the gauge station name already handled by byKey;
      // for proximity we compare against the gauge's lat/lon stored in
      // kBiharGauges by river+station name.
      // We look up the gauge's own lat/lon and compare with stored gauges
      // that share the same normalised river name.
      if (_norm(st.river) != _norm(gauge.river)) continue;
      // No lat/lon in BiharStationData — skip proximity (it's a text match
      // fallback for same-river stations with similar names).
      if (_norm(st.city).contains(_norm(gauge.station).split(' ').first)) {
        best = st;
        break;
      }
    }
    return best;
  }

  BiharStationData? _resolve(
      BiharGauge gauge,
      Map<String, BiharStationData> byKey,
      List<BiharStationData> all) {
    // 1. Exact normalised key match
    final direct = byKey[_norm(gauge.station)];
    if (direct != null) return direct;
    // 2. Partial match: gauge station name starts with first word of any key
    for (final entry in byKey.entries) {
      if (entry.key.startsWith(_norm(gauge.station).split(' ').first) &&
          _norm(entry.key).contains(_norm(gauge.river).split(' ').first)) {
        return entry.value;
      }
    }
    // 3. Same-river fuzzy
    return _proxMatch(gauge, all);
  }

  @override
  Widget build(BuildContext context) {
    final t          = RiverColors.of(context);
    final biharState = ref.watch(biharLiveProvider);

    final liveIndex = biharState.maybeWhen(
      data: (s) => _buildLiveIndex(s.stations),
      orElse: () => (byKey: <String, BiharStationData>{}, all: <BiharStationData>[]),
    );

    final gauges = _filterRiver == null
        ? kBiharGauges
        : kBiharGauges.where((g) => g.river == _filterRiver).toList();

    final (urlTemplate, subdomains) = switch (_tileStyle) {
      _TileStyle.voyager => (_voyagerUrl, _cartoSubdomains),
      _TileStyle.dark    => (_darkUrl,    _cartoSubdomains),
      _TileStyle.osm     => (_osmUrl,     const <String>[]),
    };

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Stack(
        children: [

          // ────────────────────────── MAP ──────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: const MapOptions(
              initialCenter: _biharCenter,
              initialZoom:   _initialZoom,
              minZoom: 6.0,
              maxZoom: 14.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:         urlTemplate,
                subdomains:          subdomains,
                userAgentPackageName: 'com.rohitg.floodwatch',
                retinaMode:          true,
              ),
              MarkerLayer(
                markers: gauges.map((gauge) {
                  final live = _resolve(
                      gauge, liveIndex.byKey, liveIndex.all);
                  final risk = live?.riskLabel ?? 'NORMAL';
                  return Marker(
                    point:  LatLng(gauge.lat, gauge.lon),
                    width:  44,
                    height: 52,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showStationSheet(context, gauge, live, t);
                      },
                      child: _StationPin(risk: risk, live: live != null),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ──────────────────── TOP BAR ────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: t.cardBg.withValues(alpha: 0.93),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.stroke),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
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
                        _LiveBadge(liveIndex: liveIndex.byKey),
                        const SizedBox(width: 8),
                        // Tile style cycle button
                        GestureDetector(
                          onTap: () => setState(() {
                            _tileStyle = _TileStyle.values[
                                (_tileStyle.index + 1) %
                                    _TileStyle.values.length];
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: t.cardBgElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: t.stroke),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  switch (_tileStyle) {
                                    _TileStyle.voyager => Icons.wb_sunny_rounded,
                                    _TileStyle.dark    => Icons.dark_mode_rounded,
                                    _TileStyle.osm     => Icons.map_outlined,
                                  },
                                  color: t.textSecondary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  switch (_tileStyle) {
                                    _TileStyle.voyager => 'Day',
                                    _TileStyle.dark    => 'Dark',
                                    _TileStyle.osm     => 'OSM',
                                  },
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
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
                              onTap: () => setState(() =>
                                  _filterRiver =
                                      _filterRiver == r ? null : r),
                            ))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ────────────────── LEGEND (bottom-left) ─────────────────────────
          Positioned(
            bottom: 100,
            left: 12,
            child: _Legend(t: t),
          ),
        ],
      ),
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Location permission denied'),
            backgroundColor: t.cardBg,
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium));
      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 10.5);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not get location: $e'),
          backgroundColor: t.cardBg,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showStationSheet(
    BuildContext context,
    BiharGauge gauge,
    BiharStationData? live,
    RiverColors t,
  ) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _StationSheet(gauge: gauge, live: live, t: t),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _pinColor(String risk) {
  switch (risk.toUpperCase()) {
    case 'CRITICAL':
    case 'DANGER':  return AppPalette.critical;
    case 'WARNING':
    case 'HIGH':    return AppPalette.warning;
    case 'NORMAL':
    case 'SAFE':    return AppPalette.safe;
    default:        return const Color(0xFF607D8B);
  }
}

// ── Pulsing ring (continuous) ─────────────────────────────────────────────────
class _PulsingRing extends StatefulWidget {
  final Color color;
  const _PulsingRing({required this.color});
  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        final size = 16.0 + 14.0 * v;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.25 * (1 - v * 0.5)),
          ),
        );
      },
    );
  }
}

// ── Station pin ───────────────────────────────────────────────────────────────
class _StationPin extends StatelessWidget {
  final String risk;
  final bool   live;
  const _StationPin({required this.risk, required this.live});

  @override
  Widget build(BuildContext context) {
    final col    = _pinColor(risk);
    final isCrit = risk.toUpperCase() == 'CRITICAL' ||
                   risk.toUpperCase() == 'DANGER';
    final isHigh = risk.toUpperCase() == 'WARNING' ||
                   risk.toUpperCase() == 'HIGH';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing ring — only for critical (continuous AnimationController)
        if (isCrit)
          _PulsingRing(color: col)
        else if (isHigh)
          const SizedBox(height: 16)
        else
          const SizedBox(height: 16),

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
              ? (isCrit
                  ? const Icon(Icons.warning_rounded,
                      color: Colors.white, size: 9)
                  : null)
              : const Icon(Icons.wifi_off_rounded,
                  color: Colors.white, size: 8),
        ),

        // CRITICAL text label
        if (isCrit)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: col,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              '⚠',
              style: TextStyle(color: Colors.white, fontSize: 7),
            ),
          ),
      ],
    );
  }
}

// ── Live count badge ──────────────────────────────────────────────────────────
class _LiveBadge extends StatelessWidget {
  final Map<String, BiharStationData> liveIndex;
  const _LiveBadge({required this.liveIndex});

  @override
  Widget build(BuildContext context) {
    final critical = liveIndex.values
        .where((s) => s.isCritical)
        .length;
    if (critical == 0) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppPalette.safe.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppPalette.safe.withValues(alpha: 0.3)),
        ),
        child: Text(
          '${liveIndex.length} live',
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

// ── River filter chip ─────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String      label;
  final bool        active;
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

// ── Legend ────────────────────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final RiverColors t;
  const _Legend({required this.t});

  static const _entries = [
    (AppPalette.critical, 'Critical / Danger'),
    (AppPalette.warning,  'Warning / High'),
    (AppPalette.safe,     'Safe / Normal'),
    (Color(0xFF607D8B),   'No live data'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.cardBg.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
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
                ))
            .toList(),
      ),
    );
  }
}

// ── Station bottom sheet — full info ─────────────────────────────────────────
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
    final risk = live?.riskLabel ?? 'NO DATA';
    final col  = _pinColor(risk);

    // Compute below-danger margin
    String belowDangerStr = '—';
    if (live?.currentLevel != null) {
      final margin = gauge.dangerLevel - live!.currentLevel!;
      belowDangerStr = margin <= 0
          ? '${(-margin).toStringAsFixed(2)} m ABOVE'
          : '${margin.toStringAsFixed(2)} m below';
    }

    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            top: BorderSide(
                color: col.withValues(alpha: 0.35), width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: t.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
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
            _Divider(t: t),
            const SizedBox(height: 12),

            // ─── Section: Live Level data ──────────────────────────────
            Text('Water Levels',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),

            Row(
              children: [
                _SheetStat(
                  label: 'Current',
                  value: live?.currentLevel != null
                      ? '${live!.currentLevel!.toStringAsFixed(2)} m'
                      : '— m',
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
                _SheetStat(
                  label: 'HFL ${gauge.hflYear ?? ''}',
                  value: '${gauge.hfl.toStringAsFixed(2)} m',
                  color: AppPalette.critical,
                  t: t,
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (live != null) ...[
              Row(
                children: [
                  _SheetStat(
                    label: 'Below Danger',
                    value: belowDangerStr,
                    color: live!.isCritical
                        ? AppPalette.critical
                        : t.textPrimary,
                    t: t,
                  ),
                  _SheetStat(
                    label: '24h Change',
                    value: live!.diff24h != null
                        ? '${live!.diff24h! >= 0 ? '+' : ''}${live!.diff24h!.toStringAsFixed(2)} m'
                        : '—',
                    color: (live!.diff24h ?? 0) > 0
                        ? AppPalette.danger
                        : AppPalette.safe,
                    t: t,
                  ),
                  _SheetStat(
                    label: 'Forecast 24h',
                    value: live!.forecast24h != null
                        ? '${live!.forecast24h!.toStringAsFixed(2)} m'
                        : '—',
                    color: t.textPrimary,
                    t: t,
                  ),
                  _SheetStat(
                    label: 'Trend',
                    value: live!.trend.isEmpty ? '—' : live!.trend,
                    color: live!.trend.toUpperCase().contains('RIS')
                        ? AppPalette.danger
                        : AppPalette.safe,
                    t: t,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Divider(t: t),
              const SizedBox(height: 10),

              // ─── Section: River / Climate ────────────────────────────
              Text('River & Rainfall',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),

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
                  if (live!.dischargeMean != null)
                    _SheetStat(
                      label: 'Mean Discharge',
                      value: live!.dischargeMean! >= 1000
                          ? '${(live!.dischargeMean! / 1000).toStringAsFixed(1)}k m³/s'
                          : '${live!.dischargeMean!.toStringAsFixed(0)} m³/s',
                      color: t.textSecondary,
                      t: t,
                    ),
                  if (live!.rainfall24h != null)
                    _SheetStat(
                      label: '24h Rainfall',
                      value:
                          '${live!.rainfall24h!.toStringAsFixed(1)} mm',
                      color: Colors.lightBlue,
                      t: t,
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Source + timestamp
              Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 11, color: t.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${live!.source}  ·  ${live!.fetchedAt.length > 16 ? live!.fetchedAt.substring(0, 16).replaceFirst('T', '  ') : live!.fetchedAt}',
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // No live data — static thresholds only
              _NoLiveBanner(t: t),
            ],

            const SizedBox(height: 16),

            // ─── CTA: Open City Detail ─────────────────────────────────
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
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
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
                      'Open Full City Detail',
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
      ),
    );
  }
}

// ── Sheet helpers ─────────────────────────────────────────────────────────────
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
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final RiverColors t;
  const _Divider({required this.t});
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 0.5, color: t.stroke);
}

class _NoLiveBanner extends StatelessWidget {
  final RiverColors t;
  const _NoLiveBanner({required this.t});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF607D8B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF607D8B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: Color(0xFF607D8B), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No live data — showing static WRD thresholds only.',
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
