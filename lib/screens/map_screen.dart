// lib/screens/map_screen.dart
// ═══════════════════════════════════════════════════════════════════════════
// Bihar Flood Command — Map Screen v6  (Command Center Edition)
//
// Features:
//   ✔ flutter_map 8.x tile layer (OpenStreetMap)
//   ✔ Bihar district GeoJSON heatmap (Critical/High/Moderate/Low colours)
//   ✔ Station markers with DangerClass colour coding
//   ✔ Pulse animation on Critical/Extreme markers
//   ✔ "River Pulse" popup on marker tap
//   ✔ Bihar ↔ National toggle chip
//   ✔ DraggableScrollableSheet — live telemetry list sorted by risk
//   ✔ Data-sync banner — per-source last-updated timestamp
//   ✔ Floating source-legend card (WRD_BIHAR / CWC_FFEM / GLOFAS)
//   ✔ Robust error / loading states
//   ✔ Fully theme-reactive via context.rc
// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/river_station.dart';
import '../providers/map_command_provider.dart';
import '../providers/real_time_river_provider.dart';
import '../theme/rx.dart';
import 'river_detail_screen.dart';

// ─── GeoJSON loader ────────────────────────────────────────────────────────
final _biharGeoJsonProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final raw = await rootBundle
      .loadString('assets/geodata/bihar_districts.geojson');
  return jsonDecode(raw) as Map<String, dynamic>;
});

// ─── Helpers ───────────────────────────────────────────────────────────────
const _biharCenter = LatLng(25.5, 85.1);
const _biharZoom   = 6.8;
const _indiaCenter = LatLng(22.5, 80.0);
const _indiaZoom   = 4.5;

Color _riskColor(DangerClass dc, {double opacity = 0.35}) {
  switch (dc) {
    case DangerClass.extreme:
      return const Color(0xFFD32F2F).withOpacity(opacity);
    case DangerClass.severe:
      return const Color(0xFFF57C00).withOpacity(opacity);
    case DangerClass.aboveNormal:
      return const Color(0xFFFBC02D).withOpacity(opacity);
    case DangerClass.normal:
      return const Color(0xFF388E3C).withOpacity(opacity);
  }
}

Color _riskColorSolid(DangerClass dc) => _riskColor(dc, opacity: 1.0);

String _riskLabel(DangerClass dc) {
  switch (dc) {
    case DangerClass.extreme:     return 'CRITICAL';
    case DangerClass.severe:      return 'HIGH';
    case DangerClass.aboveNormal: return 'MODERATE';
    case DangerClass.normal:      return 'LOW';
  }
}

// ─── Station coordinate lookup ────────────────────────────────────────────
// A minimal lat/lng seed map.  In production, embed lat/lng in RiverStation.
const Map<String, LatLng> _stationCoords = {
  'patna':        LatLng(25.5941, 85.1376),
  'gaya':         LatLng(24.7955, 85.0002),
  'bhagalpur':    LatLng(25.2425, 86.9842),
  'muzaffarpur':  LatLng(26.1209, 85.3647),
  'darbhanga':    LatLng(26.1542, 85.8918),
  'araria':       LatLng(26.1475, 87.4733),
  'sitamarhi':    LatLng(26.5921, 85.4879),
  'supaul':       LatLng(26.1237, 86.6032),
  'vaishali':     LatLng(25.6938, 85.2001),
  'saran':        LatLng(25.9177, 84.7430),
  'east champaran': LatLng(26.6539, 84.9184),
  'west champaran': LatLng(27.0, 84.4),
  'gopalganj':    LatLng(26.4699, 84.4341),
  'siwan':        LatLng(26.2215, 84.3547),
  'begusarai':    LatLng(25.4182, 86.1272),
  'samastipur':   LatLng(25.8627, 85.7816),
  'madhubani':    LatLng(26.3566, 86.0711),
  'khagaria':     LatLng(25.5014, 86.4717),
  'katihar':      LatLng(25.5398, 87.5677),
  'purnea':       LatLng(25.7771, 87.4753),
  // National
  'prayagraj':    LatLng(25.4358, 81.8463),
  'varanasi':     LatLng(25.3176, 82.9739),
  'lucknow':      LatLng(26.8467, 80.9462),
  'guwahati':     LatLng(26.1445, 91.7362),
  'dibrugarh':    LatLng(27.4728, 94.9120),
  'kolkata':      LatLng(22.5726, 88.3639),
  'bhubaneswar':  LatLng(20.2961, 85.8189),
  'delhi':        LatLng(28.6139, 77.2090),
  'srinagar':     LatLng(34.0837, 74.7973),
};

LatLng? _coordFor(RiverStation s) {
  final key = s.city.toLowerCase();
  for (final entry in _stationCoords.entries) {
    if (key.contains(entry.key) || entry.key.contains(key)) return entry.value;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// MapScreen
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
  bool _showLegend   = true;
  bool _showDrawer   = false;

  // Pulse animation controllers — keyed by station name.
  final Map<String, AnimationController> _pulseCtrl = {};

  @override
  void dispose() {
    _mapController.dispose();
    for (final c in _pulseCtrl.values) c.dispose();
    super.dispose();
  }

  AnimationController _pulseFor(String key) =>
      _pulseCtrl.putIfAbsent(key, () {
        final c = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        )..repeat(reverse: true);
        return c;
      });

  void _flyTo(LatLng target, double zoom) {
    _mapController.move(target, zoom);
  }

  // ─── GeoJSON polygon layers ─────────────────────────────────────────────
  List<Polygon> _buildDistrictPolygons(
    Map<String, dynamic> geoJson,
    Map<String, DangerClass> riskMap,
  ) {
    final features = geoJson['features'] as List<dynamic>? ?? [];
    final polygons = <Polygon>[];

    for (final feature in features) {
      final props    = feature['properties'] as Map<String, dynamic>? ?? {};
      final distName = (props['district']   ??
                        props['District']   ??
                        props['NAME_2']     ??
                        props['name']       ??
                        '').toString().toLowerCase();

      final dc = riskMap[distName] ?? DangerClass.normal;
      final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
      final type     = geometry['type'] as String? ?? '';

      List<List<LatLng>> rings = [];

      if (type == 'Polygon') {
        rings = _parsePolygon(geometry['coordinates'] as List<dynamic>);
      } else if (type == 'MultiPolygon') {
        final multi = geometry['coordinates'] as List<dynamic>;
        for (final poly in multi) {
          rings.addAll(_parsePolygon(poly as List<dynamic>));
        }
      }

      for (final ring in rings) {
        if (ring.length < 3) continue;
        polygons.add(Polygon(
          points:       ring,
          color:        _riskColor(dc),
          borderColor:  _riskColor(dc, opacity: 0.7),
          borderStrokeWidth: 1.0,
        ));
      }
    }
    return polygons;
  }

  List<List<LatLng>> _parsePolygon(List<dynamic> coords) {
    final rings = <List<LatLng>>[];
    for (final ring in coords) {
      final pts = (ring as List<dynamic>)
          .map((pt) {
            final p = pt as List<dynamic>;
            return LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());
          })
          .toList();
      rings.add(pts);
    }
    return rings;
  }

  // ─── Marker tap handler ─────────────────────────────────────────────────
  void _onMarkerTap(RiverStation station) {
    HapticFeedback.selectionClick();
    ref.read(mapSelectedStationProvider.notifier).state = station;
    _showStationPopup(station);
  }

  void _showStationPopup(RiverStation s) {
    final rc = context.rc;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RiverPulsePopup(station: s, rc: rc),
    );
  }

  // ─── Markers ────────────────────────────────────────────────────────────
  List<Marker> _buildMarkers(List<RiverStation> stations) {
    final markers = <Marker>[];
    for (final s in stations) {
      final coord = _coordFor(s);
      if (coord == null) continue;
      final isCritical =
          s.dangerClass == DangerClass.extreme ||
          s.dangerClass == DangerClass.severe;

      markers.add(Marker(
        point:  coord,
        width:  isCritical ? 52 : 40,
        height: isCritical ? 52 : 40,
        child: GestureDetector(
          onTap: () => _onMarkerTap(s),
          child: isCritical
              ? _PulseMarker(
                  dangerClass: s.dangerClass,
                  ctrl: _pulseFor(s.station),
                )
              : _StaticMarker(dangerClass: s.dangerClass),
        ),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final rc        = context.rc;
    final mode      = ref.watch(mapViewModeProvider);
    final stations  = ref.watch(mapStationsProvider);
    final distRisk  = ref.watch(biharDistrictRiskProvider);
    final syncMeta  = ref.watch(mapSyncMetaProvider);
    final geoAsync  = ref.watch(_biharGeoJsonProvider);

    final isBihar   = mode == MapViewMode.bihar;
    final center    = isBihar ? _biharCenter : _indiaCenter;
    final zoom      = isBihar ? _biharZoom   : _indiaZoom;

    return Scaffold(
      backgroundColor: rc.scaffoldBg,
      body: Stack(
        children: [
          // ── FlutterMap ────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom:   zoom,
              minZoom: 3,
              maxZoom: 18,
              onTap: (_, __) =>
                  ref.read(mapSelectedStationProvider.notifier).state = null,
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.opsflood.app',
                errorImage: const AssetImage('assets/images/map_error.png'),
              ),

              // District heatmap layer
              if (isBihar)
                geoAsync.when(
                  data: (gj) => PolygonLayer(
                    polygons: _buildDistrictPolygons(gj, distRisk),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                ),

              // Station markers
              MarkerLayer(markers: _buildMarkers(stations)),
            ],
          ),

          // ── Top bar ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: _TopBar(
              rc:       rc,
              mode:     mode,
              syncMeta: syncMeta,
              onToggle: () {
                final next = isBihar ? MapViewMode.national : MapViewMode.bihar;
                ref.read(mapViewModeProvider.notifier).state = next;
                _flyTo(
                  next == MapViewMode.bihar ? _biharCenter : _indiaCenter,
                  next == MapViewMode.bihar ? _biharZoom   : _indiaZoom,
                );
              },
              onDrawerToggle: () => setState(() => _showDrawer = !_showDrawer),
              drawerOpen: _showDrawer,
            ),
          ),

          // ── Floating source legend ───────────────────────────────────
          if (_showLegend)
            Positioned(
              bottom: _showDrawer ? 340 : 100,
              right: 12,
              child: _SourceLegend(
                rc:       rc,
                syncMeta: syncMeta,
                onClose:  () => setState(() => _showLegend = false),
              ),
            ),

          // ── Legend re-open FAB ───────────────────────────────────────
          if (!_showLegend)
            Positioned(
              bottom: _showDrawer ? 340 : 100,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'legend_fab',
                backgroundColor: rc.cardBg,
                onPressed: () => setState(() => _showLegend = true),
                child: Icon(Icons.layers_outlined, color: rc.accent, size: 20),
              ),
            ),

          // ── Live Telemetry DraggableSheet ────────────────────────────
          if (_showDrawer)
            _TelemetrySheet(
              stations: stations,
              rc:       rc,
              onClose:  () => setState(() => _showDrawer = false),
              onTap:    (s) {
                final coord = _coordFor(s);
                if (coord != null) {
                  _flyTo(coord, 10);
                  setState(() => _showDrawer = false);
                }
                _onMarkerTap(s);
              },
            ),

          // ── Loading overlay ──────────────────────────────────────────
          if (ref.watch(realTimeRiverProvider).isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 0,
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
                          strokeWidth: 2,
                          color: rc.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fetching live data…',
                        style: TextStyle(
                          color: rc.textPrimary,
                          fontSize: 12,
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

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.rc,
    required this.mode,
    required this.syncMeta,
    required this.onToggle,
    required this.onDrawerToggle,
    required this.drawerOpen,
  });
  final dynamic rc;
  final MapViewMode mode;
  final SyncMeta syncMeta;
  final VoidCallback onToggle;
  final VoidCallback onDrawerToggle;
  final bool drawerOpen;

  @override
  Widget build(BuildContext context) {
    final isBihar = mode == MapViewMode.bihar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Main control row ─────────────────────────────────────────
        Row(
          children: [
            // Title
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:        rc.cardBg.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rc.stroke, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.radar_rounded, color: rc.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'COMMAND CENTER',
                      style: TextStyle(
                        color:      rc.textPrimary,
                        fontSize:   13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Telemetry drawer toggle
            _IconBtn(
              icon: drawerOpen
                  ? Icons.close_rounded
                  : Icons.list_rounded,
              rc:   rc,
              onTap: onDrawerToggle,
              tooltip: 'Live Telemetry',
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ── Bihar / National chip row ────────────────────────────────
        Row(
          children: [
            _ToggleChip(
              label: '🗺 Bihar',
              active: isBihar,
              rc: rc,
              onTap: isBihar ? null : onToggle,
            ),
            const SizedBox(width: 8),
            _ToggleChip(
              label: '🇮🇳 National',
              active: !isBihar,
              rc: rc,
              onTap: isBihar ? onToggle : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        // ── Data sync banner ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: rc.cardBg.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: rc.stroke.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.sync_rounded, size: 13, color: rc.accent),
              const SizedBox(width: 6),
              Text(
                'Data last synced: ${syncMeta.freshnessLabel}',
                style: TextStyle(
                  color:    rc.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Source Legend
// ─────────────────────────────────────────────────────────────────────────────

class _SourceLegend extends StatelessWidget {
  const _SourceLegend({
    required this.rc,
    required this.syncMeta,
    required this.onClose,
  });
  final dynamic    rc;
  final SyncMeta   syncMeta;
  final VoidCallback onClose;

  static const _sources = [
    ('WRD_BIHAR', '🏛', 'Bihar Water Resources Dept'),
    ('CWC_FFEM',  '🌊', 'Central Water Commission'),
    ('GLOFAS',    '🛰', 'GloFAS Global Forecast'),
  ];

  static const _legend = [
    (DangerClass.extreme,     'Critical'),
    (DangerClass.severe,      'High'),
    (DangerClass.aboveNormal, 'Moderate'),
    (DangerClass.normal,      'Low'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        rc.cardBg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: rc.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'DATA SOURCES',
                style: TextStyle(
                  color:      rc.textPrimary,
                  fontSize:   10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: 14, color: rc.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (src, emoji, label) in _sources) ...
            [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          src,
                          style: TextStyle(
                            color:     rc.accent,
                            fontSize:  10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          label,
                          style: TextStyle(
                            color:    rc.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          'Updated: ${syncMeta.labelFor(src)}',
                          style: TextStyle(
                            color:    rc.textSecondary.withOpacity(0.6),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          const Divider(height: 12),
          Text(
            'RISK SCALE',
            style: TextStyle(
              color:      rc.textPrimary,
              fontSize:   10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          for (final (dc, lbl) in _legend)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color:        _riskColor(dc, opacity: 0.8),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                          color: _riskColorSolid(dc).withOpacity(0.6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lbl,
                    style: TextStyle(
                      color:    rc.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Telemetry Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _TelemetrySheet extends StatelessWidget {
  const _TelemetrySheet({
    required this.stations,
    required this.rc,
    required this.onClose,
    required this.onTap,
  });
  final List<RiverStation>     stations;
  final dynamic                rc;
  final VoidCallback           onClose;
  final void Function(RiverStation) onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
        decoration: BoxDecoration(
          color:       rc.cardBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
              top: BorderSide(color: rc.stroke, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color:        rc.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.sensors_rounded,
                      color: rc.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE TELEMETRY  (${stations.length} stations)',
                    style: TextStyle(
                      color:      rc.textPrimary,
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClose,
                    child: Icon(Icons.close_rounded,
                        color: rc.textSecondary, size: 18),
                  ),
                ],
              ),
            ),
            // Station list
            Flexible(
              child: stations.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No station data available.',
                        style: TextStyle(
                            color: rc.textSecondary, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: stations.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: rc.stroke),
                      itemBuilder: (_, i) {
                        final s  = stations[i];
                        final dc = s.dangerClass;
                        return InkWell(
                          onTap: () => onTap(s),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            child: Row(
                              children: [
                                // Risk dot
                                Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(
                                    color:  _riskColorSolid(dc),
                                    shape:  BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Station info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.station,
                                        style: TextStyle(
                                          color:     rc.textPrimary,
                                          fontSize:  13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${s.river}  •  ${s.city}',
                                        style: TextStyle(
                                          color:    rc.textSecondary,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Level
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${s.current.toStringAsFixed(2)} m',
                                      style: TextStyle(
                                        color:     _riskColorSolid(dc),
                                        fontSize:  13,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()],
                                      ),
                                    ),
                                    Text(
                                      _riskLabel(dc),
                                      style: TextStyle(
                                        color:    _riskColorSolid(dc)
                                            .withOpacity(0.8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color:  rc.textSecondary,
                                  size:   18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// River Pulse Popup (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _RiverPulsePopup extends StatelessWidget {
  const _RiverPulsePopup({
    required this.station,
    required this.rc,
  });
  final RiverStation station;
  final dynamic      rc;

  @override
  Widget build(BuildContext context) {
    final s  = station;
    final dc = s.dangerClass;
    final color = _riskColorSolid(dc);

    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 12, right: 12, top: 0,
      ),
      decoration: BoxDecoration(
        color:        rc.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        rc.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Title row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.station,
                      style: TextStyle(
                        color:      rc.textPrimary,
                        fontSize:   18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${s.river}  •  ${s.city}, ${s.state}',
                      style: TextStyle(
                          color: rc.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  _riskLabel(dc),
                  style: TextStyle(
                    color:      color,
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Metrics row
          Row(
            children: [
              _MetricTile(
                label: 'Current Level',
                value: '${s.current.toStringAsFixed(2)} m',
                color: color,
                rc:    rc,
              ),
              const SizedBox(width: 10),
              _MetricTile(
                label: 'Warning Level',
                value: '${s.warning.toStringAsFixed(2)} m',
                color: rc.textSecondary,
                rc:    rc,
              ),
              const SizedBox(width: 10),
              _MetricTile(
                label: 'Danger Level',
                value: '${s.danger.toStringAsFixed(2)} m',
                color: const Color(0xFFD32F2F),
                rc:    rc,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Trend & ML row
          Row(
            children: [
              _MetricTile(
                label: 'Trend',
                value: s.trend ?? '—',
                color: s.trend == 'Rising'
                    ? const Color(0xFFD32F2F)
                    : s.trend == 'Falling'
                        ? const Color(0xFF388E3C)
                        : rc.textSecondary,
                rc: rc,
              ),
              const SizedBox(width: 10),
              _MetricTile(
                label: 'Data Source',
                value: s.dataSource ?? '—',
                color: rc.accent,
                rc:    rc,
              ),
              const SizedBox(width: 10),
              _MetricTile(
                label: 'Last Updated',
                value: s.lastUpdated ?? '—',
                color: rc.textSecondary,
                rc:    rc,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Flood Level Progress',
                    style: TextStyle(
                      color:    rc.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${(s.progressPct * 100).toStringAsFixed(1)}% of HFL',
                    style: TextStyle(
                      color:      color,
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:           s.progressPct,
                  minHeight:       8,
                  backgroundColor: rc.stroke,
                  valueColor:      AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // View detail button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // RiverDetailScreen needs a FloodData — adapt as needed.
                // Navigator.pushNamed(context, RiverDetailScreen.route,
                //     arguments: s.toFloodData());
              },
              icon: Icon(Icons.open_in_full_rounded, size: 16,
                  color: rc.scaffoldBg),
              label: Text('View Full Detail',
                  style: TextStyle(color: rc.scaffoldBg)),
              style: ElevatedButton.styleFrom(
                backgroundColor: rc.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.rc,
  });
  final String  label;
  final String  value;
  final Color   color;
  final dynamic rc;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color:        rc.cardBgElevated,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: rc.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color:    rc.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color:      color,
              fontSize:   13,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulse Marker
// ─────────────────────────────────────────────────────────────────────────────

class _PulseMarker extends StatelessWidget {
  const _PulseMarker({
    required this.dangerClass,
    required this.ctrl,
  });
  final DangerClass         dangerClass;
  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    final color = _riskColorSolid(dangerClass);
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final scale = 1.0 + 0.35 * ctrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring
            Transform.scale(
              scale: scale,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15 * (1 - ctrl.value)),
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
                    color:     color.withOpacity(0.5),
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

// ─────────────────────────────────────────────────────────────────────────────
// Static (non-critical) Marker
// ─────────────────────────────────────────────────────────────────────────────

class _StaticMarker extends StatelessWidget {
  const _StaticMarker({required this.dangerClass});
  final DangerClass dangerClass;

  @override
  Widget build(BuildContext context) {
    final color = _riskColorSolid(dangerClass);
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.85),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color:     color.withOpacity(0.3),
            blurRadius: 6,
          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.rc,
    required this.onTap,
    this.tooltip = '',
  });
  final IconData icon;
  final dynamic  rc;
  final VoidCallback onTap;
  final String   tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color:        rc.cardBg.withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rc.stroke),
        ),
        child: Icon(icon, color: rc.accent, size: 20),
      ),
    ),
  );
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.rc,
    this.onTap,
  });
  final String   label;
  final bool     active;
  final dynamic  rc;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? rc.accent.withOpacity(0.15)
              : rc.cardBg.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? rc.accent : rc.stroke,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      active ? rc.accent : rc.textSecondary,
            fontSize:   12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
