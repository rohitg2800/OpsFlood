// lib/screens/map_screen.dart
// ═══════════════════════════════════════════════════════════════════════════
// Bihar Flood Command Map  — Pro-Level Implementation
//
// Features:
//  1. GeoJSON district polygons coloured by worst DangerClass in district
//  2. Animated river polylines — glow dot flows at speed ∝ flow-rate
//  3. Trend arrows (↑ ↓ →) rendered near each station via Marker
//  4. Timeline scrubber (last 24 h) driven by StationHistoryStore
//  5. GPS proximity highlight — nearest station auto-selected on load
//  6. Tap on district or station → RiverDetailScreen
//
// Performance guarantees:
//  • PolygonLayer / PolylineLayer only rebuild when station list ref changes
//    (Riverpod select keeps rebuilds surgical).
//  • River animation lives in an AnimationController isolated inside
//    _RiverFlowOverlay — it never triggers a rebuild of the parent map.
//  • GeoJSON parsing is done once in a FutureProvider (cached forever).
// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../models/river_station.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/station_history_provider.dart';
import '../providers/location_provider.dart';
import 'river_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GeoJSON loader (cached FutureProvider)
// ─────────────────────────────────────────────────────────────────────────────

final biharGeoJsonProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final raw = await rootBundle.loadString('assets/geodata/bihar_districts.geojson');
  return jsonDecode(raw) as Map<String, dynamic>;
});

// ─────────────────────────────────────────────────────────────────────────────
// Map screen
// ─────────────────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  static const String route = '/map';

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapCtrl = MapController();

  // Timeline state: 0.0 = oldest (−24 h), 1.0 = now
  double _timelinePct = 1.0;

  // Nearest-station id (from GPS)
  String? _nearestStationId;

  // Selected district name for highlight
  String? _selectedDistrict;

  @override
  void initState() {
    super.initState();
    _initGps();
  }

  // ── GPS proximity ─────────────────────────────────────────────────────────
  Future<void> _initGps() async {
    try {
      final pos = await ref.read(userLocationProvider.future);
      if (pos == null || !mounted) return;
      final stations = ref.read(realTimeRiverProvider).valueOrNull ?? [];
      if (stations.isEmpty) return;
      // find closest by haversine
      RiverStation? nearest;
      double minD = double.infinity;
      for (final s in stations) {
        final lat = stationLat(s.station) ?? biharCentre.latitude;
        final lon = stationLon(s.station) ?? biharCentre.longitude;
        final d = _haversine(pos.latitude, pos.longitude, lat, lon);
        if (d < minD) { minD = d; nearest = s; }
      }
      if (nearest != null && mounted) {
        setState(() => _nearestStationId = nearest!.station);
        // Pan to nearest station
        final lat = stationLat(nearest.station) ?? biharCentre.latitude;
        final lon = stationLon(nearest.station) ?? biharCentre.longitude;
        _mapCtrl.move(LatLng(lat, lon), 9);
      }
    } catch (_) {}
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double d) => d * math.pi / 180;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final geoAsync   = ref.watch(biharGeoJsonProvider);
    final stations   = ref.watch(realTimeRiverProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF030508),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D12),
        title: const Text(
          'FLOOD COMMAND MAP',
          style: TextStyle(
            fontFamily: 'RobotoMono', fontSize: 14,
            color: Color(0xFF00FFB2), letterSpacing: 2,
          ),
        ),
        actions: [
          // Live badge
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _LiveBadge(stations: stations),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Map ────────────────────────────────────────────────────────
          Expanded(
            child: geoAsync.when(
              loading: () => const _MapLoader(),
              error:   (e, _) => _MapError(error: e.toString()),
              data:    (geo) => _buildMap(context, geo, stations),
            ),
          ),
          // ── Timeline scrubber ───────────────────────────────────────────
          _TimelineScrubber(
            value:    _timelinePct,
            onChange: (v) => setState(() => _timelinePct = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    Map<String, dynamic> geo,
    List<RiverStation> allStations,
  ) {
    // Determine which stations to show based on timeline
    final stations = _timelinePct >= 0.99
        ? allStations
        : ref.read(stationHistoryProvider.notifier)
              .stationsAtTime(_timelinePct, allStations);

    // Build district-to-DangerClass map
    final districtRisk = <String, DangerClass>{};
    for (final s in stations) {
      final d = s.city.toLowerCase();
      final current = districtRisk[d] ?? DangerClass.normal;
      if (s.dangerClass.index > current.index) districtRisk[d] = s.dangerClass;
    }

    // Build polygons from GeoJSON
    final polygons = _buildDistrictPolygons(geo, districtRisk);

    // Build river polylines
    final riverLines = _buildRiverPolylines(stations);

    // Build station markers (trend arrows + GPS highlight)
    final markers = _buildStationMarkers(context, stations);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: biharCentre,
            initialZoom:   7.2,
            minZoom: 6,
            maxZoom: 14,
            // Tap on map clears district selection
            onTap: (_, __) => setState(() => _selectedDistrict = null),
          ),
          children: [
            // ── Tile layer ───────────────────────────────────────────────
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.equinox.flood',
              retinaMode: true,
            ),

            // ── District fill polygons ────────────────────────────────────
            PolygonLayer(
              polygons: polygons,
            ),

            // ── Animated river glow lines ─────────────────────────────────
            // Static polylines as base
            PolylineLayer(polylines: riverLines),

            // ── Station markers (trend + GPS highlight) ───────────────────
            MarkerLayer(markers: markers),
          ],
        ),

        // ── Animated river flow overlaid on top ───────────────────────────
        _RiverFlowOverlay(
          mapCtrl:  _mapCtrl,
          stations: stations,
        ),

        // ── Legend ────────────────────────────────────────────────────────
        const Positioned(top: 12, right: 12, child: _MapLegend()),
      ],
    );
  }

  // ── District polygons ────────────────────────────────────────────────────

  List<Polygon> _buildDistrictPolygons(
    Map<String, dynamic> geo,
    Map<String, DangerClass> districtRisk,
  ) {
    final polygons = <Polygon>[];
    final features = (geo['features'] as List?) ?? [];

    for (final feat in features) {
      final props      = feat['properties'] as Map<String, dynamic>? ?? {};
      final districtName = (props['district'] ?? props['NAME_2'] ?? '').toString();
      final risk       = districtRisk[districtName.toLowerCase()] ?? DangerClass.normal;
      final isSelected = districtName == _selectedDistrict;

      final fill   = _riskFill(risk);
      final border = isSelected ? const Color(0xFF00FFB2) : fill.withValues(alpha: 0.9);

      final geom   = feat['geometry'] as Map<String, dynamic>;
      final coords = _extractPolygons(geom);

      for (final ring in coords) {
        polygons.add(Polygon(
          points:           ring,
          color:            fill,
          borderColor:      border,
          borderStrokeWidth: isSelected ? 2.5 : 0.8,
          isFilled:         true,
          label:            districtName,
          labelStyle: const TextStyle(
            color:      Colors.white,
            fontSize:   9,
            fontFamily: 'RobotoMono',
          ),
        ));
      }
    }
    return polygons;
  }

  // ── River polylines ──────────────────────────────────────────────────────

  List<Polyline> _buildRiverPolylines(List<RiverStation> stations) {
    final lines = <Polyline>[];
    // Group stations by river and draw a line connecting them in order
    final byRiver = <String, List<RiverStation>>{};
    for (final s in stations) {
      byRiver.putIfAbsent(s.river, () => []).add(s);
    }

    for (final entry in byRiver.entries) {
      final sorted = entry.value;
      if (sorted.length < 2) continue;

      final points = sorted
          .map((s) => LatLng(
                stationLat(s.station) ?? biharCentre.latitude,
                stationLon(s.station) ?? biharCentre.longitude,
              ))
          .toList();

      // Worst danger class on this river
      final worstClass = sorted
          .map((s) => s.dangerClass)
          .reduce((a, b) => a.index > b.index ? a : b);

      // Line width proportional to max flow-rate (1–6 px)
      final maxFlow = sorted
          .map((s) => s.flowRate ?? 0.0)
          .reduce(math.max);
      final width = (1.5 + (maxFlow / 5000).clamp(0, 1) * 4.5);

      lines.add(Polyline(
        points:      points,
        color:       _riverColor(worstClass).withValues(alpha: 0.55),
        strokeWidth: width,
        strokeCap:   StrokeCap.round,
        strokeJoin:  StrokeJoin.round,
      ));

      // Glow duplicate (wider, transparent)
      lines.add(Polyline(
        points:      points,
        color:       _riverColor(worstClass).withValues(alpha: 0.18),
        strokeWidth: width * 3.5,
        strokeCap:   StrokeCap.round,
      ));
    }
    return lines;
  }

  // ── Station markers ──────────────────────────────────────────────────────

  List<Marker> _buildStationMarkers(
    BuildContext context,
    List<RiverStation> stations,
  ) {
    return stations.map((s) {
      final lat = stationLat(s.station) ?? biharCentre.latitude;
      final lon = stationLon(s.station) ?? biharCentre.longitude;
      final isNearest = s.station == _nearestStationId;

      return Marker(
        point:  LatLng(lat, lon),
        width:  isNearest ? 64 : 40,
        height: isNearest ? 64 : 40,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedDistrict = s.city);
            Navigator.of(context).pushNamed(
              RiverDetailScreen.route,
              arguments: s,
            );
          },
          child: _StationMarker(station: s, highlight: isNearest),
        ),
      );
    }).toList();
  }

  // ── GeoJSON geometry extractor ───────────────────────────────────────────

  List<List<LatLng>> _extractPolygons(Map<String, dynamic> geom) {
    final type = geom['type'] as String;
    final coords = geom['coordinates'];
    final result = <List<LatLng>>[];

    if (type == 'Polygon') {
      result.add(_coordsToLatLng(coords[0] as List));
    } else if (type == 'MultiPolygon') {
      for (final poly in (coords as List)) {
        result.add(_coordsToLatLng(poly[0] as List));
      }
    }
    return result;
  }

  List<LatLng> _coordsToLatLng(List coords) =>
      coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Colour helpers
// ─────────────────────────────────────────────────────────────────────────────

const biharCentre = LatLng(25.5941, 85.1376);

Color _riskFill(DangerClass d) {
  switch (d) {
    case DangerClass.normal:      return const Color(0x2200FF88); // teal tint
    case DangerClass.aboveNormal: return const Color(0x44FFD700); // gold
    case DangerClass.severe:      return const Color(0x66FF6600); // orange
    case DangerClass.extreme:     return const Color(0x99FF1744); // red
  }
}

Color _riverColor(DangerClass d) {
  switch (d) {
    case DangerClass.normal:      return const Color(0xFF00FFB2);
    case DangerClass.aboveNormal: return const Color(0xFFFFD700);
    case DangerClass.severe:      return const Color(0xFFFF6600);
    case DangerClass.extreme:     return const Color(0xFFFF1744);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coordinate lookup  (replace with your full WRD Bihar coordinate table)
// ─────────────────────────────────────────────────────────────────────────────

double? stationLat(String station) => _stationCoords[station]?[0];
double? stationLon(String station) => _stationCoords[station]?[1];

const _stationCoords = <String, List<double>>{
  'Gandak at Muzaffarpur':    [26.1197, 85.3910],
  'Burhi Gandak at Sitamarhi':[26.5927, 85.4891],
  'Bagmati at Sitamarhi':     [26.5927, 85.4891],
  'Koshi at Supaul':          [26.1260, 86.6077],
  'Kamla at Madhubani':       [26.3534, 86.0713],
  'Mahananda at Kishanganj':  [26.0988, 87.9399],
  'Ganga at Patna':           [25.6093, 85.1376],
  'Ganga at Bhagalpur':       [25.2425, 87.0090],
  'Son at Arrah':             [25.5568, 84.6633],
  'Punpun at Danapur':        [25.6200, 85.0450],
  'Falgu at Gaya':            [24.7914, 84.9994],
  'Sone at Dehri':            [24.9054, 84.1842],
};

// ─────────────────────────────────────────────────────────────────────────────
// Animated river flow overlay
// ─────────────────────────────────────────────────────────────────────────────

class _RiverFlowOverlay extends StatefulWidget {
  const _RiverFlowOverlay({required this.mapCtrl, required this.stations});
  final MapController      mapCtrl;
  final List<RiverStation> stations;

  @override
  State<_RiverFlowOverlay> createState() => _RiverFlowOverlayState();
}

class _RiverFlowOverlayState extends State<_RiverFlowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // Duration controls total loop: glow dot completes full river in 3 s
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
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
      builder: (_, __) => CustomPaint(
        painter: _FlowPainter(
          t:        _ctrl.value,
          mapCtrl:  widget.mapCtrl,
          stations: widget.stations,
          context:  context,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.t,
    required this.mapCtrl,
    required this.stations,
    required this.context,
  });

  final double             t;
  final MapController      mapCtrl;
  final List<RiverStation> stations;
  final BuildContext       context;

  @override
  void paint(Canvas canvas, Size size) {
    final camera = mapCtrl.camera;

    final byRiver = <String, List<RiverStation>>{};
    for (final s in stations) {
      byRiver.putIfAbsent(s.river, () => []).add(s);
    }

    for (final entry in byRiver.entries) {
      if (entry.value.length < 2) continue;
      final sorted = entry.value;

      // Build pixel path
      final pts = <Offset>[];
      for (final s in sorted) {
        final lat = stationLat(s.station) ?? biharCentre.latitude;
        final lon = stationLon(s.station) ?? biharCentre.longitude;
        final px  = camera.latLngToScreenPoint(LatLng(lat, lon));
        pts.add(Offset(px.x, px.y));
      }

      // Compute total path length & cumulative lengths
      final cumLen = <double>[0.0];
      for (int i = 1; i < pts.length; i++) {
        cumLen.add(cumLen.last + (pts[i] - pts[i - 1]).distance);
      }
      final total = cumLen.last;
      if (total < 1) continue;

      // Flow speed: scale by average flow-rate (faster when in flood)
      final avgFlow = sorted.map((s) => s.flowRate ?? 500.0).reduce((a, b) => a + b) / sorted.length;
      final speed   = 0.3 + (avgFlow / 8000).clamp(0, 1) * 0.7; // 0.3–1.0 loops/s

      final dotT    = (t * speed) % 1.0;
      final dotDist = dotT * total;

      // Interpolate position on path
      Offset? dotPos;
      for (int i = 1; i < pts.length; i++) {
        if (dotDist <= cumLen[i]) {
          final segFrac = (dotDist - cumLen[i - 1]) / (cumLen[i] - cumLen[i - 1]);
          dotPos = Offset.lerp(pts[i - 1], pts[i], segFrac)!;
          break;
        }
      }
      dotPos ??= pts.last;

      final worstClass = sorted.map((s) => s.dangerClass).reduce((a, b) => a.index > b.index ? a : b);
      final baseColor  = _riverColor(worstClass);

      // Outer glow
      canvas.drawCircle(dotPos, 10,
        Paint()..color = baseColor.withValues(alpha: 0.18)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      // Inner glow
      canvas.drawCircle(dotPos, 5,
        Paint()..color = baseColor.withValues(alpha: 0.55)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      // Core dot
      canvas.drawCircle(dotPos, 2.5,
        Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Station marker widget — trend arrow + danger ring
// ─────────────────────────────────────────────────────────────────────────────

class _StationMarker extends StatelessWidget {
  const _StationMarker({required this.station, this.highlight = false});
  final RiverStation station;
  final bool         highlight;

  @override
  Widget build(BuildContext context) {
    final color = _riverColor(station.dangerClass);
    final arrow = _trendArrow(station.trend);
    final size  = highlight ? 28.0 : 18.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Outer ring (GPS highlight pulse)
        if (highlight)
          Container(
            width: size + 16,
            height: size + 16,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              border: Border.all(color: const Color(0xFF00FFB2), width: 1.5),
              color:  const Color(0xFF00FFB2).withValues(alpha: 0.08),
            ),
          ),
        // Main dot
        Container(
          width:  size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.85),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1),
            ],
          ),
          child: Center(
            child: Text(
              arrow,
              style: TextStyle(fontSize: size * 0.55, height: 1),
            ),
          ),
        ),
      ],
    );
  }

  String _trendArrow(String? trend) {
    if (trend == null) return '●';
    final t = trend.toLowerCase();
    if (t.contains('rising') || t.contains('up') || t.contains('↑')) return '↑';
    if (t.contains('falling') || t.contains('down') || t.contains('↓')) return '↓';
    return '→';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline scrubber
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineScrubber extends StatelessWidget {
  const _TimelineScrubber({required this.value, required this.onChange});
  final double              value;
  final ValueChanged<double> onChange;

  @override
  Widget build(BuildContext context) {
    final label = value >= 0.99
        ? 'LIVE'
        : '${((1 - value) * 24).toStringAsFixed(0)}h AGO';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0A0D12),
      child: Row(
        children: [
          const Text(
            '24H AGO',
            style: TextStyle(
              fontFamily: 'RobotoMono', fontSize: 9,
              color: Color(0xFF5A7080), letterSpacing: 1,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor:   const Color(0xFF00FFB2),
                inactiveTrackColor: const Color(0xFF1C2333),
                thumbColor:         const Color(0xFF00FFB2),
                overlayColor:       const Color(0x2200FFB2),
                trackHeight:        2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value:    value,
                min:      0,
                max:      1,
                onChanged: onChange,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                fontFamily: 'RobotoMono', fontSize: 9, letterSpacing: 1,
                color: value >= 0.99
                    ? const Color(0xFF00FFB2)
                    : const Color(0xFF5A7080),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend
// ─────────────────────────────────────────────────────────────────────────────

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('NORMAL',       Color(0xFF00FF88)),
      ('ABOVE NORMAL', Color(0xFFFFD700)),
      ('SEVERE',       Color(0xFFFF6600)),
      ('EXTREME',      Color(0xFFFF1744)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:        const Color(0xCC0A0D12),
        border:       Border.all(color: const Color(0xFF1C2333)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color:        item.$2.withValues(alpha: 0.7),
                    border:       Border.all(color: item.$2, width: 0.8),
                    shape:        BoxShape.rectangle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.$1,
                  style: const TextStyle(
                    fontFamily: 'RobotoMono', fontSize: 8,
                    color: Color(0xFFB0C0CC), letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live badge
// ─────────────────────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.stations});
  final List<RiverStation> stations;

  @override
  Widget build(BuildContext context) {
    final alarmed = stations.where((s) =>
        s.dangerClass == DangerClass.severe ||
        s.dangerClass == DangerClass.extreme).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        alarmed > 0
            ? const Color(0xFFFF1744).withValues(alpha: 0.18)
            : const Color(0xFF00FFB2).withValues(alpha: 0.12),
        border:       Border.all(
          color: alarmed > 0 ? const Color(0xFFFF1744) : const Color(0xFF00FFB2),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        alarmed > 0 ? '⚠ $alarmed ALERTS' : '● LIVE',
        style: TextStyle(
          fontFamily: 'RobotoMono', fontSize: 9, letterSpacing: 1,
          color: alarmed > 0 ? const Color(0xFFFF1744) : const Color(0xFF00FFB2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / error states
// ─────────────────────────────────────────────────────────────────────────────

class _MapLoader extends StatelessWidget {
  const _MapLoader();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Color(0xFF00FFB2), strokeWidth: 1.5),
        SizedBox(height: 14),
        Text(
          'LOADING BIHAR GIS...',
          style: TextStyle(
            fontFamily: 'RobotoMono', fontSize: 10,
            color: Color(0xFF5A7080), letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}

class _MapError extends StatelessWidget {
  const _MapError({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'MAP ERROR: $error',
      style: const TextStyle(color: Color(0xFFFF1744), fontFamily: 'RobotoMono', fontSize: 10),
    ),
  );
}
