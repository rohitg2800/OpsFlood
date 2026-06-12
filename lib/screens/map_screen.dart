// lib/screens/map_screen.dart
// MapScreen — Bihar Flood Command Center Map v9.1
// v9.1: _isCritical now includes aboveNormal (WARNING) stations → amber pulse.
//       AboveNormal stations rendered with AmberPulseMarker (softer amber ring).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/river_station.dart';
import '../providers/map_command_provider.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/live_engine_bridge_provider.dart';
import '../theme/rx.dart';
import '../widgets/map/map_widgets.dart';

// ── View constants ────────────────────────────────────────────────────────────
const _biharCenter = LatLng(25.5, 85.1);
const _biharZoom   = 6.8;
const _indiaCenter = LatLng(22.5, 80.0);
const _indiaZoom   = 4.5;

// ─────────────────────────────────────────────────────────────────────────────
class MapScreen extends ConsumerStatefulWidget {
  static const String route = '/map';
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  bool _showLegend = true;
  bool _showDrawer = false;

  // One AnimationController per pulsing station, keyed by station name.
  // Covers extreme, severe AND aboveNormal now.
  final Map<String, AnimationController> _pulseCtrl = {};

  @override
  void dispose() {
    _mapController.dispose();
    for (final c in _pulseCtrl.values) c.dispose();
    super.dispose();
  }

  AnimationController _pulseFor(String key) =>
      _pulseCtrl.putIfAbsent(
        key,
        () => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        )..repeat(reverse: true),
      );

  void _flyTo(LatLng pt, double zoom) => _mapController.move(pt, zoom);

  // ── GeoJSON → Polygon layer ────────────────────────────────────────────────
  List<Polygon> _buildPolygons(
    Map<String, dynamic> geoJson,
    Map<String, DangerClass> riskMap,
  ) {
    final features = geoJson['features'] as List<dynamic>? ?? [];
    final polygons = <Polygon>[];

    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final name  = (
        props['district'] ??
        props['District'] ??
        props['NAME_2']   ??
        props['name']     ??
        ''
      ).toString().toLowerCase();

      final dc  = riskMap[name] ?? DangerClass.normal;
      final geo = f['geometry'] as Map<String, dynamic>? ?? {};
      final type = geo['type']  as String? ?? '';

      final rings = <List<LatLng>>[];
      if (type == 'Polygon') {
        rings.addAll(_parseRings(geo['coordinates'] as List));
      } else if (type == 'MultiPolygon') {
        for (final p in (geo['coordinates'] as List)) {
          rings.addAll(_parseRings(p as List));
        }
      }

      for (final ring in rings) {
        if (ring.length < 3) continue;
        polygons.add(Polygon(
          points:            ring,
          color:             riskColor(dc),
          borderColor:       riskColor(dc, opacity: 0.7),
          borderStrokeWidth: 1.0,
        ));
      }
    }
    return polygons;
  }

  List<List<LatLng>> _parseRings(List raw) => raw
      .map((ring) => (ring as List)
          .map((pt) {
            final p = pt as List;
            return LatLng(
              (p[1] as num).toDouble(),
              (p[0] as num).toDouble(),
            );
          })
          .toList())
      .toList();

  // ── Marker builder ────────────────────────────────────────────────────────
  String? _levelLabel(RiverStation s) {
    if (s.current <= 0) return null;
    return '${s.current.toStringAsFixed(2)}m';
  }

  List<Marker> _buildMarkers(List<RiverStation> stations) {
    return [
      for (final s in stations)
        if (coordFor(s) case final coord?)
          Marker(
            point:  coord,
            width:  _markerSize(s),
            height: _markerSize(s),
            child:  GestureDetector(
              onTap: () => _onMarkerTap(s),
              child: _buildMarkerWidget(s),
            ),
          ),
    ];
  }

  double _markerSize(RiverStation s) {
    switch (s.dangerClass) {
      case DangerClass.extreme:
      case DangerClass.severe:      return 58;
      case DangerClass.aboveNormal: return 50;
      case DangerClass.normal:      return 44;
    }
  }

  Widget _buildMarkerWidget(RiverStation s) {
    final level = _levelLabel(s);
    switch (s.dangerClass) {
      case DangerClass.extreme:
      case DangerClass.severe:
        // Red / orange full pulse for critical/severe
        return PulseMarker(
          dangerClass: s.dangerClass,
          ctrl:        _pulseFor(s.station),
          level:       level,
        );
      case DangerClass.aboveNormal:
        // Softer amber pulse for WARNING stations
        return AmberPulseMarker(
          ctrl:  _pulseFor(s.station),
          level: level,
        );
      case DangerClass.normal:
        return StaticMarker(
          dangerClass: s.dangerClass,
          level:       level,
          isLive:      s.isLive,
        );
    }
  }

  void _onMarkerTap(RiverStation s) {
    HapticFeedback.selectionClick();
    ref.read(mapSelectedStationProvider.notifier).state = s;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RiverPulsePopup(station: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc       = context.rc;
    final mode     = ref.watch(mapViewModeProvider);
    final stations = ref.watch(mapStationsProvider);
    final distRisk = ref.watch(biharDistrictRiskProvider);
    final syncMeta = ref.watch(mapSyncMetaProvider);
    final geoAsync = ref.watch(biharGeoJsonProvider);
    final isBihar  = mode == MapViewMode.bihar;

    ref.watch(liveEngineStationsProvider);

    return Scaffold(
      backgroundColor: rc.scaffoldBg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: isBihar ? _biharCenter : _indiaCenter,
              initialZoom:   isBihar ? _biharZoom   : _indiaZoom,
              minZoom: 3,
              maxZoom: 18,
              onTap: (_, __) =>
                  ref.read(mapSelectedStationProvider.notifier).state = null,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.opsflood.app',
              ),
              if (isBihar)
                geoAsync.when(
                  data:    (gj) => PolygonLayer(
                      polygons: _buildPolygons(gj, distRisk)),
                  loading: ()      => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                ),
              MarkerLayer(markers: _buildMarkers(stations)),
            ],
          ),

          Positioned(
            top:   MediaQuery.of(context).padding.top + 8,
            left:  12,
            right: 12,
            child: MapTopBar(
              mode:           mode,
              syncMeta:       syncMeta,
              drawerOpen:     _showDrawer,
              onToggle: () {
                final next = isBihar
                    ? MapViewMode.national
                    : MapViewMode.bihar;
                ref.read(mapViewModeProvider.notifier).state = next;
                _flyTo(
                  next == MapViewMode.bihar ? _biharCenter : _indiaCenter,
                  next == MapViewMode.bihar ? _biharZoom   : _indiaZoom,
                );
              },
              onDrawerToggle: () =>
                  setState(() => _showDrawer = !_showDrawer),
            ),
          ),

          if (_showLegend)
            Positioned(
              bottom: _showDrawer ? 340 : 100,
              right:  12,
              child: MapSourceLegend(
                syncMeta: syncMeta,
                onClose:  () => setState(() => _showLegend = false),
              ),
            ),

          if (!_showLegend)
            Positioned(
              bottom: _showDrawer ? 340 : 100,
              right:  12,
              child: FloatingActionButton.small(
                heroTag:         'legend_fab',
                backgroundColor: rc.cardBg,
                onPressed: () => setState(() => _showLegend = true),
                child: Icon(Icons.layers_outlined,
                    color: rc.accent, size: 20),
              ),
            ),

          if (_showDrawer)
            MapTelemetrySheet(
              stations: stations,
              onClose:  () => setState(() => _showDrawer = false),
              onTap: (s) {
                if (coordFor(s) case final coord?) {
                  _flyTo(coord, 10);
                  setState(() => _showDrawer = false);
                }
                _onMarkerTap(s);
              },
            ),

          if (ref.watch(realTimeRiverProvider).isLoading)
            Positioned(
              top:   MediaQuery.of(context).padding.top + 72,
              left:  0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color:        rc.cardBg.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: rc.accent),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fetching live data…',
                        style: TextStyle(
                          color:      rc.textPrimary,
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
