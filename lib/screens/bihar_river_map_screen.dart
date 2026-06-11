// lib/screens/bihar_river_map_screen.dart
// OpsFlood — BiharRiverMapScreen v5.2
//
// v5.2 fixes:
//   • Suppress flutter_map fallback-freshness log spam for RainViewer tiles.
//     RainViewer sends no Cache-Control header; we inject max-age=600 (10 min)
//     via NetworkTileProvider so the caching layer never hits its 168h fallback.
//   • Fix latlong2 import path (latlong2/latlong2 → latlong2/latlong2).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong2.dart';
import 'package:geolocator/geolocator.dart';

import '../data/bihar_rivers.dart';
import '../providers/bihar_live_provider.dart';
import '../theme/river_theme.dart';
import 'city_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Severity system  (5 levels)
// ─────────────────────────────────────────────────────────────────────────────

enum RiskLevel { critical, severe, moderate, safe, noData }

RiskLevel _parseRisk(String? raw, {bool hasLiveData = true}) {
  if (!hasLiveData || raw == null || raw.isEmpty) return RiskLevel.noData;
  switch (raw.toUpperCase()) {
    case 'CRITICAL':
    case 'DANGER':
      return RiskLevel.critical;
    case 'SEVERE':
      return RiskLevel.severe;
    case 'MODERATE':
    case 'WARNING':
    case 'HIGH':
      return RiskLevel.moderate;
    case 'NORMAL':
    case 'SAFE':
    case 'LOW':
      return RiskLevel.safe;
    default:
      return RiskLevel.safe;
  }
}

Color _riskColor(RiskLevel level) {
  switch (level) {
    case RiskLevel.critical: return const Color(0xFFFF3B30); // vivid red
    case RiskLevel.severe:   return const Color(0xFFFF6B35); // orange
    case RiskLevel.moderate: return const Color(0xFFFFCC00); // bright yellow
    case RiskLevel.safe:     return const Color(0xFF34C759); // bright green
    case RiskLevel.noData:   return const Color(0xFF8E8E93); // grey
  }
}

String _riskLabel(RiskLevel level) {
  switch (level) {
    case RiskLevel.critical: return 'CRITICAL';
    case RiskLevel.severe:   return 'SEVERE';
    case RiskLevel.moderate: return 'WARNING';
    case RiskLevel.safe:     return 'SAFE';
    case RiskLevel.noData:   return 'NO DATA';
  }
}

IconData _riskIcon(RiskLevel level) {
  switch (level) {
    case RiskLevel.critical: return Icons.warning_rounded;
    case RiskLevel.severe:   return Icons.warning_amber_rounded;
    case RiskLevel.moderate: return Icons.info_rounded;
    case RiskLevel.safe:     return Icons.check_circle_rounded;
    case RiskLevel.noData:   return Icons.help_outline_rounded;
  }
}

// Legacy colour helper used in the bottom sheet (accepts raw string)
Color _riskColour(String risk, RiverColors t) => _riskColor(_parseRisk(risk));

// ─────────────────────────────────────────────────────────────────────────────
// RainViewer — free, no API key required
// Docs: https://www.rainviewer.com/api/weather-maps.html
// ─────────────────────────────────────────────────────────────────────────────
//
// RainViewer serves radar tiles at a fixed path; colorScheme 2 = standard,
// smooth=1, snow=1 gives best visibility.
const _rainViewerUrl =
    'https://tilecache.rainviewer.com/v2/radar/nowcast/{z}/{x}/{y}/2/1_1.png';

// RainViewer does not send Cache-Control headers, which causes flutter_map's
// caching layer to fall back to a 168-hour TTL and log a notice per tile.
// Injecting max-age=600 (10 min) matches the nowcast update cadence and
// silences the fallback log entirely.
const _rainViewerHeaders = <String, String>{
  'Cache-Control': 'max-age=600',
};

// ─────────────────────────────────────────────────────────────────────────────
// Tile styles
// ─────────────────────────────────────────────────────────────────────────────

enum _TileStyle { voyager, dark, osm, satellite, terrain, hybrid }

extension _TileStyleInfo on _TileStyle {
  String get label {
    switch (this) {
      case _TileStyle.voyager:   return 'Day';
      case _TileStyle.dark:      return 'Dark';
      case _TileStyle.osm:       return 'OSM';
      case _TileStyle.satellite: return 'Satellite';
      case _TileStyle.terrain:   return 'Terrain';
      case _TileStyle.hybrid:    return 'Hybrid';
    }
  }

  IconData get icon {
    switch (this) {
      case _TileStyle.voyager:   return Icons.wb_sunny_rounded;
      case _TileStyle.dark:      return Icons.dark_mode_rounded;
      case _TileStyle.osm:       return Icons.map_outlined;
      case _TileStyle.satellite: return Icons.satellite_alt_rounded;
      case _TileStyle.terrain:   return Icons.terrain_rounded;
      case _TileStyle.hybrid:    return Icons.layers_rounded;
    }
  }

  String get urlTemplate {
    switch (this) {
      case _TileStyle.voyager:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      case _TileStyle.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case _TileStyle.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _TileStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _TileStyle.terrain:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case _TileStyle.hybrid:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  List<String> get subdomains {
    switch (this) {
      case _TileStyle.voyager:
      case _TileStyle.dark:
        return ['a', 'b', 'c', 'd'];
      case _TileStyle.terrain:
        return ['a', 'b', 'c'];
      default:
        return [];
    }
  }

  bool get retinaMode {
    switch (this) {
      case _TileStyle.voyager:
      case _TileStyle.dark:
        return true;
      default:
        return false;
    }
  }

  bool get needsLabelLayer => this == _TileStyle.hybrid;

  String get attribution {
    switch (this) {
      case _TileStyle.satellite:
      case _TileStyle.hybrid:
        return '© Esri';
      case _TileStyle.terrain:
        return '© OpenTopoMap contributors';
      default:
        return '© OpenStreetMap / CARTO';
    }
  }
}

const _biharCenter = LatLng(25.78, 85.82);
const _initialZoom = 7.4;

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[()_\-]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// ─────────────────────────────────────────────────────────────────────────────
// BiharRiverMapScreen
// ─────────────────────────────────────────────────────────────────────────────

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
  RiskLevel? _filterRisk;
  _TileStyle _tileStyle      = _TileStyle.voyager;
  bool       _showPrecip     = false;
  double     _precipOpacity  = 0.65;
  bool       _layerPanelOpen = false;

  ({Map<String, BiharStationData> byKey, List<BiharStationData> all})?
      _cachedIndex;
  Object? _lastData;

  static final _rivers =
      kBiharGauges.map((g) => g.river).toSet().toList()..sort();

  ({Map<String, BiharStationData> byKey, List<BiharStationData> all})
      _buildLiveIndex(List<BiharStationData> stations) {
    final byKey = <String, BiharStationData>{};
    for (final st in stations) byKey[_norm(st.city)] = st;
    return (byKey: byKey, all: stations);
  }

  BiharStationData? _resolve(
    BiharGauge gauge,
    Map<String, BiharStationData> byKey,
    List<BiharStationData> all,
  ) {
    final normStation  = _norm(gauge.station);
    final normRiver    = _norm(gauge.river);
    final direct       = byKey[normStation];
    if (direct != null) return direct;
    final stationFirst = normStation.split(' ').first;
    final riverFirst   = normRiver.split(' ').first;
    for (final entry in byKey.entries) {
      if (entry.key.contains(stationFirst) &&
          entry.key.contains(riverFirst)) return entry.value;
    }
    for (final st in all) {
      if (_norm(st.river) != normRiver) continue;
      if (_norm(st.city).contains(stationFirst)) return st;
    }
    return null;
  }

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

    final rawData = biharState.whenOrNull(data: (v) => v);
    if (rawData != _lastData) {
      _lastData    = rawData;
      _cachedIndex = rawData != null
          ? _buildLiveIndex(rawData.stations)
          : (byKey: <String, BiharStationData>{},
             all:   <BiharStationData>[]);
    }
    final liveIndex = _cachedIndex ??
        (byKey: <String, BiharStationData>{}, all: <BiharStationData>[]);

    final gauges = kBiharGauges.where((g) {
      if (_filterRiver != null && g.river != _filterRiver) return false;
      if (_filterRisk != null) {
        final live  = _resolve(g, liveIndex.byKey, liveIndex.all);
        final level = _parseRisk(live?.riskLabel, hasLiveData: live != null);
        if (level != _filterRisk) return false;
      }
      return true;
    }).toList();

    // counts for severity chips
    final Map<RiskLevel, int> riskCounts = {};
    for (final g in kBiharGauges) {
      final live  = _resolve(g, liveIndex.byKey, liveIndex.all);
      final level = _parseRisk(live?.riskLabel, hasLiveData: live != null);
      riskCounts[level] = (riskCounts[level] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: const MapOptions(
              initialCenter: _biharCenter,
              initialZoom:   _initialZoom,
              minZoom: 5.0,
              maxZoom: 16.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:          _tileStyle.urlTemplate,
                subdomains:           _tileStyle.subdomains,
                userAgentPackageName: 'com.rohitg.floodwatch',
                retinaMode:           _tileStyle.retinaMode,
              ),
              if (_tileStyle.needsLabelLayer)
                TileLayer(
                  urlTemplate:
                      'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.rohitg.floodwatch',
                ),
              // ── RainViewer precipitation overlay (FREE, no key) ──
              // NetworkTileProvider injects Cache-Control: max-age=600 so the
              // caching layer derives a 10-min freshness age directly from the
              // header, eliminating the 168h fallback log.
              if (_showPrecip)
                Opacity(
                  opacity: _precipOpacity,
                  child: TileLayer(
                    urlTemplate:          _rainViewerUrl,
                    userAgentPackageName: 'com.rohitg.floodwatch',
                    tileProvider: NetworkTileProvider(
                      headers: _rainViewerHeaders,
                    ),
                  ),
                ),
              // ── Markers ──────────────────────────────────────────────
              MarkerLayer(
                markers: gauges.map((gauge) {
                  final live     = _resolve(gauge, liveIndex.byKey, liveIndex.all);
                  final level    = _parseRisk(live?.riskLabel, hasLiveData: live != null);
                  final rainfall = live?.rainfall24h;
                  return Marker(
                    point:  LatLng(gauge.lat, gauge.lon),
                    width:  64,
                    height: 84,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showStationSheet(context, gauge, live, t);
                      },
                      child: _StationPin(level: level, rainfall: rainfall),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Top overlay ─────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  // Title bar
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: t.cardBg.withValues(alpha: 0.93),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.stroke),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 12,
                      )],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.map_rounded, color: t.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Bihar River Gauge Map',
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ),
                        _LiveBadge(count: liveIndex.all.length),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(
                              () => _layerPanelOpen = !_layerPanelOpen),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _layerPanelOpen
                                  ? t.accent.withValues(alpha: 0.15)
                                  : t.cardBgElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _layerPanelOpen ? t.accent : t.stroke),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.layers_rounded,
                                    color: _layerPanelOpen
                                        ? t.accent
                                        : t.textSecondary,
                                    size: 14),
                                const SizedBox(width: 4),
                                Text('Layers',
                                    style: TextStyle(
                                        color: _layerPanelOpen
                                            ? t.accent
                                            : t.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Layer panel
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: _layerPanelOpen
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: _LayerPanel(
                      t:                t,
                      tileStyle:        _tileStyle,
                      showPrecip:       _showPrecip,
                      precipOpacity:    _precipOpacity,
                      onTileChanged:    (s) => setState(() => _tileStyle = s),
                      onPrecipToggle:   () =>
                          setState(() => _showPrecip = !_showPrecip),
                      onOpacityChanged: (v) =>
                          setState(() => _precipOpacity = v),
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),

                  // River filter
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      children: [
                        _FilterChip(
                            label: 'All Rivers',
                            active: _filterRiver == null,
                            t: t,
                            onTap: () =>
                                setState(() => _filterRiver = null)),
                        ..._rivers.map((r) => _FilterChip(
                              label: r,
                              active: _filterRiver == r,
                              t: t,
                              onTap: () => setState(() =>
                                  _filterRiver =
                                      _filterRiver == r ? null : r),
                            )),
                      ],
                    ),
                  ),

                  // Severity filter
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      children: [
                        _RiskFilterChip(
                          label: 'All Levels',
                          color: t.accent,
                          active: _filterRisk == null,
                          count: kBiharGauges.length,
                          t: t,
                          onTap: () =>
                              setState(() => _filterRisk = null),
                        ),
                        ...RiskLevel.values.map((lvl) {
                          final count = riskCounts[lvl] ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return _RiskFilterChip(
                            label: _riskLabel(lvl),
                            color: _riskColor(lvl),
                            active: _filterRisk == lvl,
                            count: count,
                            t: t,
                            onTap: () => setState(() =>
                                _filterRisk =
                                    _filterRisk == lvl ? null : lvl),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Legend ───────────────────────────────────────────────────────
          Positioned(
            bottom: 100,
            left: 12,
            child: _Legend(t: t, showPrecip: _showPrecip),
          ),

          // Attribution
          Positioned(
            bottom: 12, right: 12,
            child: Text(
              '${_tileStyle.attribution}  ·  © RainViewer',
              style: TextStyle(
                  color: t.textSecondary.withValues(alpha: 0.7),
                  fontSize: 8),
            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// _StationPin  — high-visibility 5-level pin
//
// KEY FIX: every dot now has a WHITE border (2px) so it pops on dark tiles.
// Dot sizes increased across the board.
// ─────────────────────────────────────────────────────────────────────────────

class _StationPin extends StatelessWidget {
  final RiskLevel level;
  final double?   rainfall;
  const _StationPin({required this.level, this.rainfall});

  double get _dotSize {
    switch (level) {
      case RiskLevel.critical: return 26;
      case RiskLevel.severe:   return 22;
      case RiskLevel.moderate: return 20;
      case RiskLevel.safe:     return 16;
      case RiskLevel.noData:   return 12;
    }
  }

  double get _glowBlur {
    switch (level) {
      case RiskLevel.critical: return 16;
      case RiskLevel.severe:   return 12;
      case RiskLevel.moderate: return 8;
      case RiskLevel.safe:     return 6;
      case RiskLevel.noData:   return 0;
    }
  }

  bool get _showPulse =>
      level == RiskLevel.critical || level == RiskLevel.severe;

  bool get _showLabel =>
      level == RiskLevel.critical ||
      level == RiskLevel.severe   ||
      level == RiskLevel.moderate;

  @override
  Widget build(BuildContext context) {
    final color         = _riskColor(level);
    final icon          = _riskIcon(level);
    final hasRainfall   = rainfall != null && rainfall! > 10;
    final dotSize       = _dotSize;
    final containerSize = dotSize + 20.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: containerSize,
          height: containerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_showPulse)
                _PulsingRing(color: color, size: containerSize - 4),
              if (hasRainfall && !_showPulse)
                Container(
                  width:  dotSize + 12,
                  height: dotSize + 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.lightBlue.withValues(alpha: 0.7),
                        width: 2),
                  ),
                ),
              Container(
                width: dotSize, height: dotSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.90),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.65),
                      blurRadius: _glowBlur,
                      spreadRadius: level == RiskLevel.critical ? 2 : 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: dotSize * 0.52),
              ),
            ],
          ),
        ),
        if (_showLabel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.80)),
            ),
            child: Text(
              level == RiskLevel.critical
                  ? '⚠ CRIT'
                  : level == RiskLevel.severe
                      ? '⚠ SEV'
                      : 'WARN',
              style: TextStyle(
                  color: color,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3),
            ),
          )
        else if (hasRainfall)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: Colors.lightBlue.withValues(alpha: 0.70)),
            ),
            child: Text(
              '💧 ${rainfall!.toStringAsFixed(0)}mm',
              style: const TextStyle(
                  color: Colors.lightBlue,
                  fontSize: 7,
                  fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PulsingRing
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingRing extends StatefulWidget {
  final Color  color;
  final double size;
  const _PulsingRing({required this.color, required this.size});
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
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale   = Tween<double>(begin: 0.65, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween<double>(begin: 0.85, end: 0.12).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: widget.color.withValues(alpha: _opacity.value),
                width: 2.5),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LayerPanel
// ─────────────────────────────────────────────────────────────────────────────

class _LayerPanel extends StatelessWidget {
  final RiverColors t;
  final _TileStyle  tileStyle;
  final bool        showPrecip;
  final double      precipOpacity;
  final ValueChanged<_TileStyle> onTileChanged;
  final VoidCallback             onPrecipToggle;
  final ValueChanged<double>     onOpacityChanged;

  const _LayerPanel({
    required this.t,
    required this.tileStyle,
    required this.showPrecip,
    required this.precipOpacity,
    required this.onTileChanged,
    required this.onPrecipToggle,
    required this.onOpacityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.stroke),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.25), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BASE MAP',
              style: TextStyle(color: t.textSecondary, fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: _TileStyle.values.map((style) {
              final active = tileStyle == style;
              return GestureDetector(
                onTap: () => onTileChanged(style),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? t.accent.withValues(alpha: 0.18)
                        : t.cardBgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: active ? t.accent : t.stroke,
                        width: active ? 1.5 : 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 12,
                          color: active ? t.accent : t.textSecondary),
                      const SizedBox(width: 5),
                      Text(style.label,
                          style: TextStyle(
                              color: active ? t.accent : t.textSecondary,
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w800
                                  : FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: t.stroke),
          const SizedBox(height: 10),
          Text('OVERLAYS',
              style: TextStyle(color: t.textSecondary, fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onPrecipToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: showPrecip
                    ? Colors.lightBlue.withValues(alpha: 0.18)
                    : t.cardBgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: showPrecip ? Colors.lightBlue : t.stroke,
                    width: showPrecip ? 1.5 : 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grain_rounded, size: 12,
                      color: showPrecip
                          ? Colors.lightBlue
                          : t.textSecondary),
                  const SizedBox(width: 5),
                  Text('Precipitation',
                      style: TextStyle(
                          color: showPrecip
                              ? Colors.lightBlue
                              : t.textSecondary,
                          fontSize: 11,
                          fontWeight: showPrecip
                              ? FontWeight.w800
                              : FontWeight.w500)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.50)),
                    ),
                    child: const Text('FREE',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 8,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
          if (showPrecip) ...[
            const SizedBox(height: 8),
            Text('© RainViewer — live radar',
                style: TextStyle(
                    color: t.textSecondary, fontSize: 9)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Opacity',
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      activeTrackColor: Colors.lightBlue,
                      inactiveTrackColor:
                          Colors.lightBlue.withValues(alpha: 0.2),
                      thumbColor: Colors.lightBlue,
                      overlayColor:
                          Colors.lightBlue.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: precipOpacity,
                      min: 0.1, max: 1.0, divisions: 9,
                      onChanged: onOpacityChanged,
                    ),
                  ),
                ),
                Text('${(precipOpacity * 100).toInt()}%',
                    style: const TextStyle(
                        color: Colors.lightBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StationSheet
// ─────────────────────────────────────────────────────────────────────────────

class _StationSheet extends StatelessWidget {
  final BiharGauge        gauge;
  final BiharStationData? live;
  final RiverColors       t;
  const _StationSheet(
      {required this.gauge, required this.live, required this.t});

  @override
  Widget build(BuildContext context) {
    final hasLive = live != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.stroke),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, -8))],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: t.stroke,
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gauge.station,
                          style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                      const SizedBox(height: 2),
                      Text('${gauge.river}  ·  ${gauge.district}',
                          style: TextStyle(
                              color: t.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (hasLive)
                  _badge(
                      label: live!.riskLabel,
                      color: _riskColour(live!.riskLabel, t)),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasLive) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: t.cardBgElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.stroke)),
                child: Row(
                  children: [
                    Icon(Icons.signal_wifi_off_rounded,
                        color: t.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'No live data — static thresholds only',
                          style: TextStyle(
                              color: t.textSecondary, fontSize: 12)),
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
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, CityDetailScreen.route,
                    arguments: gauge.station);
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
                  child: Text('Open Full Detail  →',
                      style: TextStyle(
                          color: t.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _liveSection(BuildContext context) {
    final s   = live!;
    final rc  = _riskColour(s.riskLabel, t);
    final cur = s.currentLevel;
    final dan = gauge.dangerLevel;
    String margin      = '—';
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
                    letterSpacing: -1),
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
                color: marginColor, size: 13,
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

  Widget _thresholdsSection() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: t.cardBgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.stroke)),
        child: Column(children: [
          _threshRow('Warning Level',
              '${gauge.warningLevel.toStringAsFixed(2)} m',
              AppPalette.warning),
          const SizedBox(height: 8),
          _threshRow('Danger Level',
              '${gauge.dangerLevel.toStringAsFixed(2)} m', AppPalette.danger),
          const SizedBox(height: 8),
          _threshRow(
            'HFL${gauge.hflYear != null ? ' (${gauge.hflYear})' : ''}',
            '${gauge.hfl.toStringAsFixed(2)} m',
            AppPalette.critical,
          ),
        ]),
      );

  Widget _threshRow(String label, String value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: t.textSecondary, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      );

  Widget _changeSection() {
    final s = live!;
    Color  diffColor = t.textPrimary;
    String diffStr   = '—';
    if (s.diff24h != null) {
      final d = s.diff24h!;
      diffStr   = '${d >= 0 ? '+' : ''}${d.toStringAsFixed(2)} m';
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
          border: Border.all(color: t.stroke)),
      child: Row(children: [
        Expanded(child: _miniCell(
            icon: Icons.height_rounded, label: '24h Change',
            value: diffStr, valueColor: diffColor)),
        Container(width: 1, height: 36, color: t.stroke),
        Expanded(child: _miniCell(
            icon: Icons.update_rounded, label: 'Forecast 24h',
            value: s.forecast24h != null
                ? '${s.forecast24h!.toStringAsFixed(2)} m'
                : '—',
            valueColor: t.textPrimary, centered: true)),
        Container(width: 1, height: 36, color: t.stroke),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Trend', style: TextStyle(
                  color: t.textSecondary, fontSize: 10,
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(trendIcon, color: trendColor, size: 16),
                const SizedBox(width: 3),
                Text(s.trend.isEmpty ? '—' : s.trend,
                    style: TextStyle(
                        color: trendColor,
                        fontWeight: FontWeight.w800, fontSize: 11)),
              ]),
            ],
          ),
        )),
      ]),
    );
  }

  Widget _riverSection() {
    final s           = live!;
    final hasGloFAS   = s.discharge != null;
    final hasRainfall = s.rainfall24h != null;
    if (!hasGloFAS && !hasRainfall) return const SizedBox.shrink();
    String dischargeStr   = '—';
    Color  dischargeColor = AppPalette.safe;
    String deltaBadge     = '';
    if (hasGloFAS) {
      dischargeStr = _fmtQ(s.discharge!);
      if (s.dischargeMean != null && s.dischargeMean! > 0) {
        final pct = (s.discharge! - s.dischargeMean!) / s.dischargeMean! * 100;
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
        border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.22)),
      ),
      child: Row(children: [
        if (hasGloFAS)
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.water_rounded,
                    color: AppPalette.cyan, size: 11),
                const SizedBox(width: 4),
                Text('GloFAS Discharge',
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 3),
              Text('$dischargeStr m³/s',
                  style: TextStyle(
                      color: dischargeColor,
                      fontWeight: FontWeight.w800, fontSize: 13)),
              if (s.dischargeMean != null)
                Text('Mean: ${_fmtQ(s.dischargeMean!)} m³/s',
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 10)),
            ],
          )),
        if (hasGloFAS && deltaBadge.isNotEmpty) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
                color: dischargeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: dischargeColor.withValues(alpha: 0.35))),
            child: Text(deltaBadge,
                style: TextStyle(
                    color: dischargeColor,
                    fontWeight: FontWeight.w800, fontSize: 10)),
          ),
        ],
        if (hasRainfall) ...[
          if (hasGloFAS)
            Container(width: 1, height: 36,
                color: t.stroke.withValues(alpha: 0.5)),
          Expanded(child: _miniCell(
              icon: Icons.grain_rounded, label: '24h Rainfall',
              value: '${s.rainfall24h!.toStringAsFixed(1)} mm',
              valueColor: Colors.lightBlue, centered: hasGloFAS)),
        ],
      ]),
    );
  }

  Widget _sourceRow() {
    final s = live!;
    return Row(children: [
      Icon(Icons.verified_outlined, color: t.textSecondary, size: 12),
      const SizedBox(width: 5),
      Text(s.source, style: TextStyle(
          color: t.textSecondary, fontSize: 10,
          fontWeight: FontWeight.w600)),
      const Spacer(),
      if (s.fetchedAt.isNotEmpty)
        Text(s.fetchedAt,
            style: TextStyle(color: t.stroke, fontSize: 9)),
    ]);
  }

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
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                centered ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 10, color: t.textSecondary),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(
                  color: t.textSecondary, fontSize: 10,
                  fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _badge({required String label, required Color color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.50)),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w800, fontSize: 10)),
  );

  static String _fmtQ(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// _LiveBadge
// ─────────────────────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  final int count;
  const _LiveBadge({required this.count});
  @override
  Widget build(BuildContext context) {
    final t       = RiverColors.of(context);
    final hasData = count > 0;
    final color   = hasData ? AppPalette.safe : t.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            hasData ? 'LIVE · $count' : 'NO DATA',
            style: TextStyle(
                color: color, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterChip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool   active;
  final RiverColors t;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label, required this.active,
    required this.t, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? t.accent.withValues(alpha: 0.18)
              : t.cardBgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? t.accent : t.stroke,
              width: active ? 1.5 : 1.0),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? t.accent : t.textSecondary,
                fontSize: 11,
                fontWeight:
                    active ? FontWeight.w800 : FontWeight.w500)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RiskFilterChip
// ─────────────────────────────────────────────────────────────────────────────

class _RiskFilterChip extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   active;
  final int    count;
  final RiverColors  t;
  final VoidCallback onTap;
  const _RiskFilterChip({
    required this.label, required this.color, required this.active,
    required this.count, required this.t, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.20) : t.cardBgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : t.stroke,
              width: active ? 1.5 : 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                  color: active ? color : color.withValues(alpha: 0.5),
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: active ? color : t.textSecondary,
                    fontSize: 11,
                    fontWeight:
                        active ? FontWeight.w800 : FontWeight.w500)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count',
                  style: TextStyle(
                      color: color, fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Legend
// ─────────────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final RiverColors t;
  final bool showPrecip;
  const _Legend({required this.t, required this.showPrecip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.25), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendRow(color: const Color(0xFFFF3B30), dotSize: 9,
              label: 'Critical', pulse: true),
          const SizedBox(height: 5),
          _LegendRow(color: const Color(0xFFFF6B35), dotSize: 8,
              label: 'Severe', pulse: true),
          const SizedBox(height: 5),
          _LegendRow(color: const Color(0xFFFFCC00), dotSize: 7,
              label: 'Warning / Moderate'),
          const SizedBox(height: 5),
          _LegendRow(color: const Color(0xFF34C759), dotSize: 6,
              label: 'Safe / Normal'),
          const SizedBox(height: 5),
          _LegendRow(color: const Color(0xFF8E8E93), dotSize: 5,
              label: 'No data'),
          const SizedBox(height: 5),
          _LegendRow(color: Colors.lightBlue, dotSize: 6,
              label: 'High rainfall >10mm', ring: true),
          if (showPrecip) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14, height: 8,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.cyan]),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Radar (RainViewer)',
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color  color;
  final double dotSize;
  final String label;
  final bool   pulse;
  final bool   ring;
  const _LegendRow({
    required this.color, required this.dotSize, required this.label,
    this.pulse = false, this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14, height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (ring)
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withValues(alpha: 0.55), width: 1.5),
                  ),
                ),
              Container(
                width: dotSize, height: dotSize,
                decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6), width: 1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: t.textSecondary, fontSize: 10,
                fontWeight: FontWeight.w500)),
        if (pulse) ...[
          const SizedBox(width: 4),
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.5),
              border: Border.all(color: color, width: 1),
            ),
          ),
        ],
      ],
    );
  }
}
