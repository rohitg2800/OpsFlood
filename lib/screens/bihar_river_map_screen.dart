// lib/screens/bihar_river_map_screen.dart
// BiharRiverMapScreen v4 — Real interactive map
// • flutter_map with OpenStreetMap tiles (dark style via CartoDB DarkMatter)
// • Bihar district boundaries from GeoJSON CDN (udit-001/india-maps-data)
// • 10 major river polylines with real lat/lng coordinates
// • Severity-coloured district fills driven by live flood data
// • Station marker pins with tap-to-detail sheet
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity.dart';
import '../utils/flood_severity_helper.dart';
import '../screens/city_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// River data — key lat/lng waypoints for Bihar's 10 major rivers
// ─────────────────────────────────────────────────────────────────────────────

class _RiverLine {
  final String       name;
  final Color        color;
  final List<LatLng> points;
  const _RiverLine({
    required this.name,
    required this.color,
    required this.points,
  });
}

const _biharRivers = [
  _RiverLine(
    name: 'Ganga',
    color: Color(0xFF38BDF8),
    points: [
      LatLng(25.56, 83.97), // Chausa/Buxar entry
      LatLng(25.57, 84.50), // Arrah
      LatLng(25.61, 85.14), // Patna (Dighaghat)
      LatLng(25.60, 85.52), // Barh
      LatLng(25.42, 86.17), // Mokameh
      LatLng(25.37, 86.47), // Luckeesarai/Lakhisarai
      LatLng(25.37, 86.98), // Munger
      LatLng(25.25, 87.01), // Sultanganj
      LatLng(25.25, 86.98),
      LatLng(25.24, 87.49), // Bhagalpur
      LatLng(25.20, 87.80), // Kahalgaon
      LatLng(25.23, 87.91), // Bihar/WB border
    ],
  ),
  _RiverLine(
    name: 'Kosi',
    color: Color(0xFFF87171),
    points: [
      LatLng(26.90, 87.15), // Nepal border (Birpur)
      LatLng(26.52, 86.90),
      LatLng(26.11, 86.90), // Supaul
      LatLng(25.88, 86.85), // Saharsa
      LatLng(25.63, 86.69), // Naugachia
      LatLng(25.42, 86.17), // Kosi meets Ganga near Kursela/Khagaria
    ],
  ),
  _RiverLine(
    name: 'Gandak',
    color: Color(0xFF34D399),
    points: [
      LatLng(27.48, 84.43), // Nepal border near Tribeni
      LatLng(27.10, 84.35), // Valmiki Nagar barrage
      LatLng(26.80, 84.45), // Champaran
      LatLng(26.60, 84.43), // Muzaffarpur north
      LatLng(26.18, 84.67), // Hajipur
      LatLng(25.69, 85.02), // Sonepur confluence with Ganga
    ],
  ),
  _RiverLine(
    name: 'Bagmati',
    color: Color(0xFFA78BFA),
    points: [
      LatLng(26.87, 85.72), // Nepal border / Sitamarhi
      LatLng(26.60, 85.55), // Sitamarhi
      LatLng(26.35, 85.42), // Muzaffarpur
      LatLng(26.20, 85.63), // Samastipur
      LatLng(25.87, 85.78), // Rosera
      LatLng(25.60, 86.00), // Meets Kosi near Khagaria
    ],
  ),
  _RiverLine(
    name: 'Burhi Gandak',
    color: Color(0xFFFBBF24),
    points: [
      LatLng(26.95, 84.80), // Champaran source
      LatLng(26.60, 84.96),
      LatLng(26.37, 85.10), // Muzaffarpur
      LatLng(26.10, 85.42), // Samastipur
      LatLng(25.83, 86.12), // Khagaria meets Ganga
    ],
  ),
  _RiverLine(
    name: 'Sone',
    color: Color(0xFFFF8C00),
    points: [
      LatLng(24.40, 83.77), // MP/Jharkhand border
      LatLng(24.60, 83.99),
      LatLng(24.80, 84.10), // Rohtas
      LatLng(25.00, 84.30), // Arwal
      LatLng(25.57, 84.64), // Patna confluence (Danapur)
    ],
  ),
  _RiverLine(
    name: 'Ghaghra',
    color: Color(0xFFEC4899),
    points: [
      LatLng(26.77, 83.42), // UP/Bihar border near Siwan
      LatLng(26.23, 84.05), // Siwan
      LatLng(25.91, 84.50), // Saran / Chapra
      LatLng(25.76, 84.75), // Meets Ganga at Chhapra
    ],
  ),
  _RiverLine(
    name: 'Kamla',
    color: Color(0xFF6EE7B7),
    points: [
      LatLng(26.90, 86.10), // Nepal border
      LatLng(26.60, 86.08), // Madhubani
      LatLng(26.35, 86.09), // Darbhanga
      LatLng(26.10, 86.10), // Samastipur meets Bagmati
    ],
  ),
  _RiverLine(
    name: 'Mahananda',
    color: Color(0xFF67E8F9),
    points: [
      LatLng(26.85, 88.10), // Nepal/WB border
      LatLng(26.62, 87.87), // Kishanganj
      LatLng(25.97, 87.70), // Purnia
      LatLng(25.24, 87.90), // Meets Ganga near Manikpur
    ],
  ),
  _RiverLine(
    name: 'Punpun',
    color: Color(0xFFC084FC),
    points: [
      LatLng(24.55, 84.85), // Jharkhand source
      LatLng(24.80, 85.00),
      LatLng(25.10, 85.00), // Gaya
      LatLng(25.32, 85.00), // Jehanabad
      LatLng(25.55, 85.08), // Meets Ganga near Fatuha
    ],
  ),
];

// GeoJSON CDN for Bihar district boundaries
const _biharGeoJsonUrl =
    'https://cdn.jsdelivr.net/gh/udit-001/india-maps-data@main/geojson/states/Bihar.json';

// ─────────────────────────────────────────────────────────────────────────────
// GeoJSON provider
// ─────────────────────────────────────────────────────────────────────────────

final _biharGeoJsonProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await http.get(Uri.parse(_biharGeoJsonUrl));
  if (res.statusCode == 200) {
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
  throw Exception('GeoJSON fetch failed: ${res.statusCode}');
});

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  const BiharRiverMapScreen({super.key});
  static const String route = '/bihar_river_map';

  @override
  ConsumerState<BiharRiverMapScreen> createState() =>
      _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState
    extends ConsumerState<BiharRiverMapScreen> {
  // Layers
  bool _showRivers    = true;
  bool _showDistricts = true;
  bool _showStations  = true;

  // Selected station for bottom sheet
  FloodData? _selected;

  // Map controller
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t          = RiverColors.of(context);
    final stations   = ref.watch(liveLevelsProvider);
    final geoAsync   = ref.watch(_biharGeoJsonProvider);

    // Build district → worst-severity map
    final Map<String, FloodData> districtData = {};
    for (final fd in stations) {
      final key = fd.district.isNotEmpty ? fd.district : fd.city;
      final existing = districtData[key];
      if (existing == null ||
          FloodSeverityHelper.fromString(fd.status).index >
              FloodSeverityHelper.fromString(existing.status).index) {
        districtData[key] = fd;
      }
    }

    final biharStations = stations
        .where((fd) => fd.state.toUpperCase().contains('BIHAR') &&
            fd.lat != null && fd.lng != null)
        .toList();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Stack(
        children: [
          // ── THE MAP ───────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(25.78, 85.82), // Bihar centroid
              initialZoom:   7.2,
              minZoom:       6.0,
              maxZoom:       13.0,
              onTap: (_, __) => setState(() => _selected = null),
            ),
            children: [
              // ─ Base tile layer (CartoDB Dark Matter — no API key needed)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'in.befiqr.equinox_flood',
                maxZoom: 19,
              ),

              // ─ District boundaries from GeoJSON
              if (_showDistricts)
                geoAsync.when(
                  data: (geo) => _DistrictLayer(
                      geoJson: geo, districtData: districtData),
                  loading: () => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                ),

              // ─ River polylines
              if (_showRivers)
                PolylineLayer(
                  polylines: _biharRivers
                      .map((r) => Polyline(
                            points:       r.points,
                            color:        r.color.withValues(alpha: 0.85),
                            strokeWidth:  2.5,
                          ))
                      .toList(),
                ),

              // ─ River name labels (markers at midpoint)
              if (_showRivers)
                MarkerLayer(
                  markers: _biharRivers.map((r) {
                    final mid = r.points[r.points.length ~/ 2];
                    return Marker(
                      point:  mid,
                      width:  80,
                      height: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: r.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: r.color.withValues(alpha: 0.35),
                              width: 0.5),
                        ),
                        child: Text(
                          r.name,
                          style: TextStyle(
                            color: r.color,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(
                                  color: Colors.black,
                                  blurRadius: 3),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // ─ Station marker pins
              if (_showStations)
                MarkerLayer(
                  markers: biharStations.map((fd) {
                    final sev   = FloodSeverityHelper.fromString(fd.status);
                    final color = FloodSeverityHelper.color(sev);
                    final isSelected = _selected?.city == fd.city;
                    return Marker(
                      point:  LatLng(fd.lat!, fd.lng!),
                      width:  isSelected ? 46 : 34,
                      height: isSelected ? 46 : 34,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selected = fd),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(
                                alpha: isSelected ? 0.30 : 0.18),
                            border: Border.all(
                              color: color,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color
                                          .withValues(alpha: 0.5),
                                      blurRadius: 10,
                                    )
                                  ]
                                : null,
                          ),
                          child: Icon(
                            FloodSeverityHelper.icon(sev),
                            color: color,
                            size: isSelected ? 22 : 16,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // ── Top app bar overlay ──────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    _GlassBack(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GlassCard(
                        child: Row(
                          children: [
                            Icon(Icons.map_rounded,
                                color: t.accent, size: 16),
                            const SizedBox(width: 6),
                            Text('Bihar River Map',
                                style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800)),
                            const Spacer(),
                            if (stations.isNotEmpty)
                              Text(
                                '${biharStations.length} stations',
                                style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Layer toggle FABs ────────────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: _selected != null ? 260 : 120,
            child: Column(
              children: [
                _LayerToggle(
                  icon:    Icons.water_rounded,
                  label:   'Rivers',
                  active:  _showRivers,
                  color:   const Color(0xFF38BDF8),
                  onTap:   () => setState(() => _showRivers = !_showRivers),
                ),
                const SizedBox(height: 8),
                _LayerToggle(
                  icon:    Icons.grid_view_rounded,
                  label:   'Districts',
                  active:  _showDistricts,
                  color:   t.accent,
                  onTap:   () => setState(() =>
                      _showDistricts = !_showDistricts),
                ),
                const SizedBox(height: 8),
                _LayerToggle(
                  icon:    Icons.sensors_rounded,
                  label:   'Stations',
                  active:  _showStations,
                  color:   AppPalette.safe,
                  onTap:   () => setState(() =>
                      _showStations = !_showStations),
                ),
              ],
            ),
          ),

          // ── River legend strip ───────────────────────────────────────────────
          if (_showRivers && _selected == null)
            Positioned(
              left: 12,
              bottom: 100,
              child: _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rivers',
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    ..._biharRivers.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 18,
                                  height: 3,
                                  color: r.color),
                              const SizedBox(width: 5),
                              Text(r.name,
                                  style: TextStyle(
                                      color: r.color,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),

          // ── Selected station detail sheet ──────────────────────────────────
          if (_selected != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StationSheet(
                data: _selected!,
                onClose:     () => setState(() => _selected = null),
                onOpenDetail: () => Navigator.pushNamed(
                  context,
                  CityDetailScreen.route,
                  arguments: _selected!.city,
                ),
              ),
            ),

          // ── GeoJSON loading indicator ─────────────────────────────────────────
          if (geoAsync.isLoading)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: _GlassCard(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: t.accent),
                      ),
                      const SizedBox(width: 8),
                      Text('Loading district boundaries…',
                          style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 11)),
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
// District polygon layer (parses GeoJSON in-widget)
// ─────────────────────────────────────────────────────────────────────────────

class _DistrictLayer extends StatelessWidget {
  final Map<String, dynamic> geoJson;
  final Map<String, FloodData> districtData;

  const _DistrictLayer({
    required this.geoJson,
    required this.districtData,
  });

  List<LatLng> _ring(List coords) => coords
      .map<LatLng>((c) => LatLng(
          (c[1] as num).toDouble(), (c[0] as num).toDouble()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final polygons = <Polygon>[];

    final features =
        (geoJson['features'] as List?) ?? [];

    for (final feat in features) {
      final props    = feat['properties'] as Map? ?? {};
      final name     = (props['district'] ??
                        props['District'] ??
                        props['NAME_2'] ??
                        props['name'] ??
                        '').toString();
      final geometry = feat['geometry'] as Map? ?? {};
      final type     = geometry['type'] as String? ?? '';
      final coords   = geometry['coordinates'] as List? ?? [];

      // Find severity for this district
      final fd  = districtData[name];
      final sev = fd != null
          ? FloodSeverityHelper.fromString(fd.status)
          : FloodSeverity.normal;
      final fillColor   = FloodSeverityHelper.color(sev)
          .withValues(alpha: sev == FloodSeverity.normal ? 0.04 : 0.18);
      final borderColor = FloodSeverityHelper.color(sev)
          .withValues(alpha: sev == FloodSeverity.normal ? 0.20 : 0.50);

      void addPolygon(List ring) {
        final pts = _ring(ring);
        if (pts.length < 3) return;
        polygons.add(Polygon(
          points:       pts,
          color:        fillColor,
          borderColor:  borderColor,
          borderStrokeWidth: 0.8,
          label:        name,
          labelStyle: TextStyle(
            color: FloodSeverityHelper.color(sev)
                .withValues(alpha: 0.70),
            fontSize: 7,
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 2),
            ],
          ),
          labelPlacement: PolygonLabelPlacement.centroid,
          rotateLabel: false,
        ));
      }

      if (type == 'Polygon') {
        for (final ring in coords) addPolygon(ring as List);
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          for (final ring in (poly as List)) addPolygon(ring as List);
        }
      }
    }

    return PolygonLayer(polygons: polygons);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Station detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _StationSheet extends StatelessWidget {
  final FloodData    data;
  final VoidCallback onClose;
  final VoidCallback onOpenDetail;
  const _StationSheet({
    required this.data,
    required this.onClose,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final sev   = FloodSeverityHelper.fromString(data.status);
    final color = FloodSeverityHelper.color(sev);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: FloodSeverityHelper.cardBorder(sev), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: FloodSeverityHelper.glowColor(sev),
              blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: t.stroke,
                borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              Icon(FloodSeverityHelper.icon(sev),
                  color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.city,
                        style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text(
                      [
                        if ((data.riverName ?? '').isNotEmpty)
                          data.riverName!,
                        if (data.district.isNotEmpty) data.district,
                      ].join('  ·  '),
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close_rounded,
                    color: t.textSecondary, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SheetStat('Level',
                  '${data.currentLevel.toStringAsFixed(2)} m', color),
              const SizedBox(width: 8),
              _SheetStat('Warning',
                  '${data.warningLevel.toStringAsFixed(1)} m',
                  AppPalette.warning),
              const SizedBox(width: 8),
              _SheetStat('Danger',
                  '${data.dangerLevel.toStringAsFixed(1)} m',
                  AppPalette.danger),
            ],
          ),
          const SizedBox(height: 12),
          // Level bar
          _MiniLevelBar(
            current: data.currentLevel,
            warning: data.warningLevel,
            danger:  data.dangerLevel,
            color:   color,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: onOpenDetail,
              child: Text('View ${data.city} Detail →',
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _SheetStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(
                    color: t.textSecondary, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _MiniLevelBar extends StatelessWidget {
  final double current, warning, danger;
  final Color  color;
  const _MiniLevelBar({
    required this.current,
    required this.warning,
    required this.danger,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final t   = RiverColors.of(context);
    final pct = danger > 0 ? (current / danger).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8,
            color: t.cardBgElevated,
            child: FractionallySizedBox(
              widthFactor: pct,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.5), color],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${current.toStringAsFixed(1)} m',
                style: TextStyle(
                    fontSize: 9, color: t.textSecondary)),
            Text('⚠ ${warning.toStringAsFixed(1)} m',
                style: const TextStyle(
                    fontSize: 9, color: AppPalette.warning)),
            Text('🔴 ${danger.toStringAsFixed(1)} m',
                style: const TextStyle(
                    fontSize: 9, color: AppPalette.danger)),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI helpers
// ─────────────────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.cardBg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.stroke),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 12)
        ],
      ),
      child: child,
    );
  }
}

class _GlassBack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: t.cardBg.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.stroke),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 10)
          ],
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded,
            color: t.accent, size: 16),
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  final Color    color;
  final VoidCallback onTap;
  const _LayerToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.18)
              : t.cardBg.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active ? color : t.stroke,
              width: active ? 1.2 : 0.8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? color : t.stroke, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: active ? color : t.stroke,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
