// lib/screens/bihar_river_map_screen.dart
// OpsFlood — BiharRiverMapScreen v3
//
// Bug fixes vs v2:
//   1. _norm() key matching — strips parens/dashes/underscores, collapses
//      spaces, then 3-pass resolve: exact → partial → same-river fuzzy.
//      Covers 'Birpur (CWC)', 'Dheng Bridge', 'Gangpur Siswan', etc.
//   2. Tile cycling fixed — retinaMode is false for OSM (no {r} placeholder).
//      3 styles: Voyager (default/day) → CARTO Dark → OSM.
//   3. _StationSheet shows full live payload: level, warning, danger, HFL,
//      margin, 24h change, forecast, trend, GloFAS, rainfall, source, time.
//      Static-only mode shows a clean "no live data" banner.
//   4. _PulsingRing uses AnimationController.repeat(reverse:true) — true
//      heartbeat. Marker uses Stack (not Column) so ring never overflows.
//      Critical pins show ⚠ icon + red label. Marker height bumped to 72.
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

// ── Tile sets ────────────────────────────────────────────────────────────────
enum _TileStyle { voyager, dark, osm }

const _voyagerUrl =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
const _darkUrl =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _cartoSubdomains = ['a', 'b', 'c', 'd'];

// ── Bihar centroid ───────────────────────────────────────────────────────────
const _biharCenter = LatLng(25.78, 85.82);
const _initialZoom = 7.4;

// ── Key normaliser ───────────────────────────────────────────────────────────
// 'Birpur (CWC)'  → 'birpur cwc'
// 'Dheng Bridge'  → 'dheng bridge'
// 'Gangpur Siswan'→ 'gangpur siswan'
String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[()_\-]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// ── Risk colour helper ───────────────────────────────────────────────────────
Color _riskColour(String risk, RiverColors t) {
  switch (risk.toUpperCase()) {
    case 'CRITICAL':
    case 'DANGER':
      return AppPalette.critical;
    case 'WARNING':
    case 'HIGH':
      return AppPalette.warning;
    default:
      return AppPalette.safe;
  }
}

// ── Main screen ──────────────────────────────────────────────────────────────
class BiharRiverMapScreen extends ConsumerStatefulWidget {
  static const String route = '/bihar_river_map';
  const BiharRiverMapScreen({super.key});

  @override
  ConsumerState<BiharRiverMapScreen> createState() =>
      _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState extends ConsumerState<BiharRiverMapScreen> {
  final _mapCtrl = MapController();
  String?    _filterRiver;
  _TileStyle _tileStyle = _TileStyle.voyager;

  // Cached live index — rebuilt only when provider data object changes
  ({Map<String, BiharStationData> byKey, List<BiharStationData> all})?
      _cachedIndex;
  Object? _lastData;

  static final _rivers =
      kBiharGauges.map((g) => g.river).toSet().toList()..sort();

  // ── Live index builder ───────────────────────────────────────────────────
  ({Map<String, BiharStationData> byKey, List<BiharStationData> all})
      _buildLiveIndex(List<BiharStationData> stations) {
    final byKey = <String, BiharStationData>{};
    for (final st in stations) {
      byKey[_norm(st.city)] = st;
    }
    return (byKey: byKey, all: stations);
  }

  // ── 3-pass resolver ──────────────────────────────────────────────────────
  BiharStationData? _resolve(
    BiharGauge gauge,
    Map<String, BiharStationData> byKey,
    List<BiharStationData> all,
  ) {
    final normStation = _norm(gauge.station);
    final normRiver   = _norm(gauge.river);

    // Pass 1 — exact normalised key
    final direct = byKey[normStation];
    if (direct != null) return direct;

    // Pass 2 — partial: gauge first token appears inside a key that also
    //          contains the river's first token
    final stationFirst = normStation.split(' ').first;
    final riverFirst   = normRiver.split(' ').first;
    for (final entry in byKey.entries) {
      if (entry.key.contains(stationFirst) &&
          entry.key.contains(riverFirst)) {
        return entry.value;
      }
    }

    // Pass 3 — same-river fuzzy: any station on the same river whose
    //          city key contains the first token of the gauge station name
    for (final st in all) {
      if (_norm(st.river) != normRiver) continue;
      if (_norm(st.city).contains(stationFirst)) return st;
    }

    return null;
  }

  // ── Bottom sheet ─────────────────────────────────────────────────────────
  void _showStationSheet(
    BuildContext context,
    BiharGauge gauge,
    BiharStationData? live,
    RiverColors t,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StationSheet(gauge: gauge, live: live, t: t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t          = RiverColors.of(context);
    final biharState = ref.watch(biharLiveProvider);

    // Rebuild index only when provider data actually changes
    final rawData = biharState.valueOrNull;
    if (rawData != _lastData) {
      _lastData    = rawData;
      _cachedIndex = rawData != null
          ? _buildLiveIndex(rawData.stations)
          : (byKey: <String, BiharStationData>{},
             all:   <BiharStationData>[]);
    }
    final liveIndex = _cachedIndex ??
        (byKey: <String, BiharStationData>{},
         all:   <BiharStationData>[]);

    final gauges = _filterRiver == null
        ? kBiharGauges
        : kBiharGauges.where((g) => g.river == _filterRiver).toList();

    // Tile config — OSM must NOT use retinaMode (no {r} in its URL template)
    final String       urlTemplate;
    final List<String> subdomains;
    final bool         retina;
    switch (_tileStyle) {
      case _TileStyle.voyager:
        urlTemplate = _voyagerUrl;
        subdomains  = _cartoSubdomains;
        retina      = true;
        break;
      case _TileStyle.dark:
        urlTemplate = _darkUrl;
        subdomains  = _cartoSubdomains;
        retina      = true;
        break;
      case _TileStyle.osm:
        urlTemplate = _osmUrl;
        subdomains  = const [];
        retina      = false;
        break;
    }

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Stack(
        children: [

          // ───────────────────────── MAP ───────────────────────────────────
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
                urlTemplate:          urlTemplate,
                subdomains:           subdomains,
                userAgentPackageName: 'com.rohitg.floodwatch',
                retinaMode:           retina,
              ),
              MarkerLayer(
                markers: gauges.map((gauge) {
                  final live = _resolve(
                      gauge, liveIndex.byKey, liveIndex.all);
                  final risk = live?.riskLabel ?? 'NORMAL';
                  return Marker(
                    point:  LatLng(gauge.lat, gauge.lon),
                    width:  48,
                    height: 72, // tall enough: Stack ring(36) + label(18) + gap
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
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.map_rounded, color: t.accent, size: 18),
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
                        _LiveBadge(count: liveIndex.all.length),
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
                                    _TileStyle.voyager =>
                                      Icons.wb_sunny_rounded,
                                    _TileStyle.dark =>
                                      Icons.dark_mode_rounded,
                                    _TileStyle.osm =>
                                      Icons.map_outlined,
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

          // ─────────────────── LEGEND (bottom-left) ───────────────────────
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
          desiredAccuracy: LocationAccuracy.low);
      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 10.0);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not get location'),
          backgroundColor: t.cardBg,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ── Station pin ──────────────────────────────────────────────────────────────
// Stack layout: pulsing ring sits BEHIND the dot — no Column height overflow.
class _StationPin extends StatelessWidget {
  final String risk;
  final bool   live;
  const _StationPin({required this.risk, required this.live});

  @override
  Widget build(BuildContext context) {
    final isCritical = risk == 'CRITICAL' || risk == 'DANGER';
    final isWarning  = risk == 'WARNING'  || risk == 'HIGH';

    final Color dotColor;
    if (isCritical)     dotColor = AppPalette.critical;
    else if (isWarning) dotColor = AppPalette.warning;
    else if (live)      dotColor = AppPalette.safe;
    else                dotColor = AppPalette.textGrey;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fixed-size Stack: ring(34×34) behind dot(18×18)
        SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isCritical) const _PulsingRing(),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.55),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: isCritical
                    ? const Icon(Icons.warning_rounded,
                        color: Colors.white, size: 11)
                    : null,
              ),
            ],
          ),
        ),
        // Compact label for critical / warning pins
        if (isCritical || isWarning)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: dotColor.withValues(alpha: 0.50)),
            ),
            child: Text(
              isCritical ? '⚠ CRIT' : 'WARN',
              style: TextStyle(
                color: dotColor,
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Pulsing ring — continuous heartbeat via AnimationController.repeat() ─────
class _PulsingRing extends StatefulWidget {
  const _PulsingRing();

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true); // ← true continuous heartbeat
    _scale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.85, end: 0.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppPalette.critical.withValues(alpha: _opacity.value),
              width: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Station bottom sheet ─────────────────────────────────────────────────────
class _StationSheet extends StatelessWidget {
  final BiharGauge        gauge;
  final BiharStationData? live;
  final RiverColors       t;
  const _StationSheet({
    required this.gauge,
    required this.live,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final hasLive = live != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: t.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
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
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${gauge.river}  ·  ${gauge.district}',
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (hasLive)
                  _badge(
                    label: live!.riskLabel,
                    color: _riskColour(live!.riskLabel, t),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (!hasLive) ...[
              // ── No live data banner ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.cardBgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.stroke),
                ),
                child: Row(
                  children: [
                    Icon(Icons.signal_wifi_off_rounded,
                        color: t.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No live data — static thresholds only',
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _thresholdsSection(),
            ] else ...[
              _liveSection(context),
              const SizedBox(height: 12),
              _thresholdsSection(),
              const SizedBox(height: 12),
              _changeSection(),
              const SizedBox(height: 12),
              _riverSection(),
              const SizedBox(height: 12),
              _sourceRow(),
            ],

            // Open detail CTA
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  CityDetailScreen.route,
                  arguments: gauge.station,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: t.accent.withValues(alpha: 0.40)),
                ),
                child: Center(
                  child: Text(
                    'Open Full Detail  →',
                    style: TextStyle(
                      color: t.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Current level + margin ───────────────────────────────────────────────
  Widget _liveSection(BuildContext context) {
    final s   = live!;
    final rc  = _riskColour(s.riskLabel, t);
    final cur = s.currentLevel;
    final dan = gauge.dangerLevel;

    String margin     = '—';
    Color  marginColor = AppPalette.safe;
    if (cur != null) {
      final diff = dan - cur;
      if (diff <= 0) {
        margin      = '${(-diff).toStringAsFixed(2)} m ABOVE danger';
        marginColor = AppPalette.critical;
      } else {
        margin      = '${diff.toStringAsFixed(2)} m below danger';
        marginColor = diff < 0.5 ? AppPalette.warning : AppPalette.safe;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rc.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rc.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                cur != null ? '${cur.toStringAsFixed(2)} m' : '— m',
                style: TextStyle(
                  color: rc,
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('Current Level',
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                cur != null && cur >= dan
                    ? Icons.crisis_alert_rounded
                    : Icons.check_circle_outline_rounded,
                color: marginColor,
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(margin,
                  style: TextStyle(
                      color: marginColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Static thresholds (always shown) ────────────────────────────────────
  Widget _thresholdsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        children: [
          _threshRow('Warning Level',
              '${gauge.warningLevel.toStringAsFixed(2)} m',
              AppPalette.warning),
          const SizedBox(height: 8),
          _threshRow('Danger Level',
              '${gauge.dangerLevel.toStringAsFixed(2)} m',
              AppPalette.danger),
          const SizedBox(height: 8),
          _threshRow(
            'HFL${gauge.hflYear != null ? ' (${gauge.hflYear})' : ''}',
            '${gauge.hfl.toStringAsFixed(2)} m',
            AppPalette.critical,
          ),
        ],
      ),
    );
  }

  Widget _threshRow(String label, String value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: t.textSecondary, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ],
      );

  // ── 24h change + forecast + trend ───────────────────────────────────────
  Widget _changeSection() {
    final s = live!;

    Color  diffColor = t.textPrimary;
    String diffStr   = '—';
    if (s.diff24h != null) {
      final d = s.diff24h!;
      diffStr  = '${d >= 0 ? '+' : ''}${d.toStringAsFixed(2)} m';
      diffColor = d > 0.2
          ? AppPalette.danger
          : d < 0
              ? AppPalette.safe
              : AppPalette.warning;
    }

    final IconData trendIcon;
    final Color    trendColor;
    switch (s.trend.toUpperCase()) {
      case 'RISING':
        trendIcon  = Icons.trending_up_rounded;
        trendColor = AppPalette.danger;
        break;
      case 'FALLING':
        trendIcon  = Icons.trending_down_rounded;
        trendColor = AppPalette.safe;
        break;
      default:
        trendIcon  = Icons.trending_flat_rounded;
        trendColor = AppPalette.warning;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: _miniCell(
              icon: Icons.height_rounded,
              label: '24h Change',
              value: diffStr,
              valueColor: diffColor,
            ),
          ),
          Container(width: 1, height: 36, color: t.stroke),
          Expanded(
            child: _miniCell(
              icon: Icons.update_rounded,
              label: 'Forecast 24h',
              value: s.forecast24h != null
                  ? '${s.forecast24h!.toStringAsFixed(2)} m'
                  : '—',
              valueColor: t.textPrimary,
              centered: true,
            ),
          ),
          Container(width: 1, height: 36, color: t.stroke),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Trend',
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(trendIcon, color: trendColor, size: 16),
                      const SizedBox(width: 3),
                      Text(
                        s.trend.isEmpty ? '—' : s.trend,
                        style: TextStyle(
                            color: trendColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── GloFAS + Rainfall (hidden if both null) ──────────────────────────────
  Widget _riverSection() {
    final s           = live!;
    final hasGloFAS   = s.discharge != null;
    final hasRainfall = s.rainfall24h != null;
    if (!hasGloFAS && !hasRainfall) return const SizedBox.shrink();

    String dischargeStr  = '—';
    Color  dischargeColor = AppPalette.safe;
    String deltaBadge    = '';
    if (hasGloFAS) {
      dischargeStr = _fmtQ(s.discharge!);
      if (s.dischargeMean != null && s.dischargeMean! > 0) {
        final pct =
            (s.discharge! - s.dischargeMean!) / s.dischargeMean! * 100;
        deltaBadge = pct >= 0
            ? '+${pct.toStringAsFixed(0)}%'
            : '${pct.toStringAsFixed(0)}%';
        dischargeColor = pct > 50
            ? AppPalette.critical
            : pct > 20
                ? AppPalette.warning
                : AppPalette.safe;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.cyanGlow2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppPalette.cyan.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          if (hasGloFAS)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_rounded,
                          color: AppPalette.cyan, size: 11),
                      const SizedBox(width: 4),
                      Text('GloFAS Discharge',
                          style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('$dischargeStr m³/s',
                      style: TextStyle(
                          color: dischargeColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                  if (s.dischargeMean != null)
                    Text('Mean: ${_fmtQ(s.dischargeMean!)} m³/s',
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 10)),
                ],
              ),
            ),
          if (hasGloFAS && deltaBadge.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: dischargeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: dischargeColor.withValues(alpha: 0.35)),
              ),
              child: Text(deltaBadge,
                  style: TextStyle(
                      color: dischargeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 10)),
            ),
          ],
          if (hasRainfall) ...[
            if (hasGloFAS)
              Container(
                  width: 1,
                  height: 36,
                  color: t.stroke.withValues(alpha: 0.5)),
            Expanded(
              child: _miniCell(
                icon: Icons.grain_rounded,
                label: '24h Rainfall',
                value:
                    '${s.rainfall24h!.toStringAsFixed(1)} mm',
                valueColor: Colors.lightBlue,
                centered: hasGloFAS,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Source + timestamp ───────────────────────────────────────────────────
  Widget _sourceRow() {
    final s = live!;
    return Row(
      children: [
        Icon(Icons.verified_outlined,
            color: t.textSecondary, size: 12),
        const SizedBox(width: 5),
        Text(s.source,
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        if (s.fetchedAt.isNotEmpty)
          Text(s.fetchedAt,
              style: TextStyle(color: t.stroke, fontSize: 9)),
      ],
    );
  }

  // ── Shared mini data cell ────────────────────────────────────────────────
  Widget _miniCell({
    required IconData icon,
    required String   label,
    required String   value,
    required Color    valueColor,
    bool              centered = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: centered ? 10 : 0),
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: centered
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 10, color: t.textSecondary),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _badge({required String label, required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.50)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10)),
      );

  static String _fmtQ(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(1)}k'
      : v.toStringAsFixed(0);
}

// ── Live badge ───────────────────────────────────────────────────────────────
class _LiveBadge extends StatelessWidget {
  final int count;
  const _LiveBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final t       = RiverColors.of(context);
    final hasData = count > 0;
    final color   = hasData ? AppPalette.safe : t.textSecondary;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            hasData ? 'LIVE · $count' : 'NO DATA',
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ──────────────────────────────────────────────────────────────
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
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? t.accent.withValues(alpha: 0.18)
              : t.cardBgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:  active ? t.accent : t.stroke,
            width:  active ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      active ? t.accent : t.textSecondary,
            fontSize:   11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Legend ───────────────────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final RiverColors t;
  const _Legend({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendDot(
              color: AppPalette.critical,
              label: 'Critical / Danger'),
          SizedBox(height: 5),
          _LegendDot(
              color: AppPalette.warning,
              label: 'Warning / High'),
          SizedBox(height: 5),
          _LegendDot(
              color: AppPalette.safe, label: 'Normal (live)'),
          SizedBox(height: 5),
          _LegendDot(
              color: AppPalette.textGrey, label: 'No data'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
