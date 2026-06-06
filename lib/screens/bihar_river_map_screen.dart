// lib/screens/bihar_river_map_screen.dart
// BiharRiverMapScreen v6.2
// Fixes:
//  1. GeoJSON URL: Bihar.json (404) → bihar.geojson, branch main → master
//  2. River polyline strokeWidth 2.5 → 3.5 so lines are visible over polygons
//  3. District polygon fill alpha 0.04 → 0.10 (normal) so boundaries show on dark tile
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/bihar_station_metadata.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity.dart';
import '../utils/flood_severity_helper.dart';
import '../screens/city_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Coordinate resolver — priority: API lat/lng > registry > null
// ─────────────────────────────────────────────────────────────────────────────

LatLng? _coordsFor(FloodData fd) {
  if (fd.lat != null && fd.lng != null) return LatLng(fd.lat!, fd.lng!);
  return BiharStationRegistry.forSite(fd.city)?.latLng;
}

String _districtFor(FloodData fd) {
  if (fd.district.isNotEmpty) return fd.district;
  return BiharStationRegistry.forSite(fd.city)?.district ?? '';
}

// ─────────────────────────────────────────────────────────────────────────────
// River colour lookup
// ─────────────────────────────────────────────────────────────────────────────

const _kRiverColors = <String, Color>{
  'Ganga':        Color(0xFF38BDF8),
  'Kosi':         Color(0xFFF87171),
  'Gandak':       Color(0xFF34D399),
  'Bagmati':      Color(0xFFA78BFA),
  'Burhi Gandak': Color(0xFFFBBF24),
  'Sone':         Color(0xFFFF8C00),
  'Ghaghra':      Color(0xFFEC4899),
  'Kamla':        Color(0xFF6EE7B7),
  'Kamalabalan':  Color(0xFF6EE7B7),
  'Mahananda':    Color(0xFF67E8F9),
  'Punpun':       Color(0xFFC084FC),
  'Adhwara':      Color(0xFFBEF264),
};

Color _riverColor(String? river) =>
    _kRiverColors[river ?? ''] ?? const Color(0xFF94A3B8);

// ─────────────────────────────────────────────────────────────────────────────
// River polylines
// ─────────────────────────────────────────────────────────────────────────────

class _RiverLine {
  final String       name;
  final Color        color;
  final List<LatLng> points;
  const _RiverLine({required this.name, required this.color, required this.points});
}

const _biharRivers = [
  _RiverLine(name: 'Ganga',        color: Color(0xFF38BDF8), points: [LatLng(25.56,83.97),LatLng(25.57,84.50),LatLng(25.61,85.14),LatLng(25.60,85.52),LatLng(25.42,86.17),LatLng(25.37,86.47),LatLng(25.37,86.98),LatLng(25.25,87.01),LatLng(25.24,87.49),LatLng(25.20,87.80),LatLng(25.23,87.91)]),
  _RiverLine(name: 'Kosi',         color: Color(0xFFF87171), points: [LatLng(26.90,87.15),LatLng(26.52,86.90),LatLng(26.11,86.90),LatLng(25.88,86.85),LatLng(25.63,86.69),LatLng(25.42,86.17)]),
  _RiverLine(name: 'Gandak',       color: Color(0xFF34D399), points: [LatLng(27.48,84.43),LatLng(27.10,84.35),LatLng(26.80,84.45),LatLng(26.60,84.43),LatLng(26.18,84.67),LatLng(25.69,85.02)]),
  _RiverLine(name: 'Bagmati',      color: Color(0xFFA78BFA), points: [LatLng(26.87,85.72),LatLng(26.60,85.55),LatLng(26.35,85.42),LatLng(26.20,85.63),LatLng(25.87,85.78),LatLng(25.60,86.00)]),
  _RiverLine(name: 'Burhi Gandak', color: Color(0xFFFBBF24), points: [LatLng(26.95,84.80),LatLng(26.60,84.96),LatLng(26.37,85.10),LatLng(26.10,85.42),LatLng(25.83,86.12)]),
  _RiverLine(name: 'Sone',         color: Color(0xFFFF8C00), points: [LatLng(24.40,83.77),LatLng(24.60,83.99),LatLng(24.80,84.10),LatLng(25.00,84.30),LatLng(25.57,84.64)]),
  _RiverLine(name: 'Ghaghra',      color: Color(0xFFEC4899), points: [LatLng(26.77,83.42),LatLng(26.23,84.05),LatLng(25.91,84.50),LatLng(25.76,84.75)]),
  _RiverLine(name: 'Kamla',        color: Color(0xFF6EE7B7), points: [LatLng(26.90,86.10),LatLng(26.60,86.08),LatLng(26.35,86.09),LatLng(26.10,86.10)]),
  _RiverLine(name: 'Mahananda',    color: Color(0xFF67E8F9), points: [LatLng(26.85,88.10),LatLng(26.62,87.87),LatLng(25.97,87.70),LatLng(25.24,87.90)]),
  _RiverLine(name: 'Punpun',       color: Color(0xFFC084FC), points: [LatLng(24.55,84.85),LatLng(24.80,85.00),LatLng(25.10,85.00),LatLng(25.32,85.00),LatLng(25.55,85.08)]),
];

// ─────────────────────────────────────────────────────────────────────────────
// GeoJSON provider — FIXED URL: bihar.geojson on master branch
// ─────────────────────────────────────────────────────────────────────────────

// FIX 1: was 'Bihar.json' on 'main' — correct path is 'bihar.geojson' on 'master'
const _biharGeoJsonUrl =
    'https://cdn.jsdelivr.net/gh/udit-001/india-maps-data@master/geojson/states/bihar.geojson';

final _biharGeoJsonProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await http.get(Uri.parse(_biharGeoJsonUrl));
  if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
  throw Exception('GeoJSON fetch failed: ${res.statusCode}');
});

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  const BiharRiverMapScreen({super.key});
  static const String route = '/bihar_river_map';

  @override
  ConsumerState<BiharRiverMapScreen> createState() => _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState extends ConsumerState<BiharRiverMapScreen> {
  bool _showRivers    = true;
  bool _showDistricts = true;
  bool _showStations  = true;
  FloodData?        _selected;
  BiharStationMeta? _selectedMeta;
  final _mapController = MapController();

  @override
  void dispose() { _mapController.dispose(); super.dispose(); }

  void _selectStation(FloodData fd) {
    setState(() {
      _selected     = fd;
      _selectedMeta = BiharStationRegistry.forSite(fd.city);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final stations = ref.watch(liveLevelsProvider);
    final geoAsync = ref.watch(_biharGeoJsonProvider);

    final Map<String, FloodData> districtData = {};
    for (final fd in stations) {
      final key = _districtFor(fd);
      if (key.isEmpty) continue;
      final existing = districtData[key];
      if (existing == null ||
          FloodSeverityHelper.fromString(fd.status).index >
              FloodSeverityHelper.fromString(existing.status).index) {
        districtData[key] = fd;
      }
    }

    final biharStations = stations
        .where((fd) =>
            fd.state.toUpperCase().contains('BIHAR') &&
            _coordsFor(fd) != null)
        .toList();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Stack(
        children: [

          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(25.78, 85.82),
              initialZoom: 7.2, minZoom: 6.0, maxZoom: 13.0,
              onTap: (_, __) => setState(() { _selected = null; _selectedMeta = null; }),
            ),
            children: [

              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a','b','c','d'],
                userAgentPackageName: 'in.befiqr.equinox_flood',
                maxZoom: 19,
              ),

              // Districts — rendered first so rivers draw on top
              if (_showDistricts)
                geoAsync.when(
                  data:    (geo) => _DistrictLayer(geoJson: geo, districtData: districtData),
                  loading: () => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                ),

              // FIX 2: strokeWidth 2.5 → 3.5, alpha 0.85 → 1.0 — always on top of polygons
              if (_showRivers)
                PolylineLayer(
                  polylines: _biharRivers.map((r) => Polyline(
                    points: r.points,
                    color: r.color,           // full opacity
                    strokeWidth: 3.5,
                  )).toList(),
                ),

              // River name labels
              if (_showRivers)
                MarkerLayer(
                  markers: _biharRivers.map((r) {
                    final mid = r.points[r.points.length ~/ 2];
                    return Marker(
                      point: mid, width: 80, height: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: r.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: r.color.withValues(alpha: 0.50), width: 0.6),
                        ),
                        child: Text(r.name,
                          style: TextStyle(color: r.color, fontSize: 8, fontWeight: FontWeight.w800,
                            shadows: const [Shadow(color: Colors.black, blurRadius: 3)]),
                          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                      ),
                    );
                  }).toList(),
                ),

              // Station pins
              if (_showStations)
                MarkerLayer(
                  markers: biharStations.map((fd) {
                    final coords     = _coordsFor(fd)!;
                    final sev        = FloodSeverityHelper.fromString(fd.status);
                    final color      = FloodSeverityHelper.color(sev);
                    final isSelected = _selected?.city == fd.city;
                    return Marker(
                      point: coords,
                      width:  isSelected ? 46 : 34,
                      height: isSelected ? 46 : 34,
                      child: GestureDetector(
                        onTap: () => _selectStation(fd),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: isSelected ? 0.30 : 0.18),
                            border: Border.all(color: color, width: isSelected ? 2.5 : 1.5),
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
                                : null,
                          ),
                          child: Icon(FloodSeverityHelper.icon(sev),
                              color: color, size: isSelected ? 22 : 16),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // ── App bar
          Positioned(
            top: 0, left: 0, right: 0,
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
                            Icon(Icons.map_rounded, color: t.accent, size: 16),
                            const SizedBox(width: 6),
                            Text('Bihar River Map', style: TextStyle(
                                color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                            const Spacer(),
                            if (biharStations.isNotEmpty)
                              Text('${biharStations.length} stations',
                                  style: TextStyle(color: t.textSecondary, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Layer toggles
          Positioned(
            right: 12,
            bottom: _selected != null ? 290 : 120,
            child: Column(
              children: [
                _LayerToggle(icon: Icons.water_rounded,     label: 'Rivers',    active: _showRivers,    color: const Color(0xFF38BDF8), onTap: () => setState(() => _showRivers    = !_showRivers)),
                const SizedBox(height: 8),
                _LayerToggle(icon: Icons.grid_view_rounded, label: 'Districts', active: _showDistricts, color: t.accent,                onTap: () => setState(() => _showDistricts = !_showDistricts)),
                const SizedBox(height: 8),
                _LayerToggle(icon: Icons.sensors_rounded,   label: 'Stations',  active: _showStations,  color: AppPalette.safe,         onTap: () => setState(() => _showStations  = !_showStations)),
              ],
            ),
          ),

          // ── River legend
          if (_showRivers && _selected == null)
            Positioned(
              left: 12, bottom: 100,
              child: _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rivers', style: TextStyle(
                        color: t.textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    ..._biharRivers.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 18, height: 3, color: r.color),
                          const SizedBox(width: 5),
                          Text(r.name, style: TextStyle(color: r.color, fontSize: 9, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),

          // ── Station sheet
          if (_selected != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _StationSheet(
                data:         _selected!,
                meta:         _selectedMeta,
                onClose:      () => setState(() { _selected = null; _selectedMeta = null; }),
                onOpenDetail: () => Navigator.pushNamed(
                  context, CityDetailScreen.route,
                  arguments: _selected!.city,
                ),
              ),
            ),

          // ── GeoJSON loading / error feedback
          if (geoAsync.isLoading)
            Positioned(
              top: 80, left: 0, right: 0,
              child: Center(
                child: _GlassCard(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: t.accent)),
                      const SizedBox(width: 8),
                      Text('Loading district boundaries…',
                          style: TextStyle(color: t.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          if (geoAsync.hasError)
            Positioned(
              top: 80, left: 0, right: 0,
              child: Center(
                child: _GlassCard(
                  child: Text('District boundaries unavailable',
                      style: TextStyle(color: AppPalette.danger, fontSize: 11)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// District polygon layer
// FIX 3: normal-state fill alpha 0.04 → 0.10, border alpha 0.20 → 0.35
// ─────────────────────────────────────────────────────────────────────────────

class _DistrictLayer extends StatelessWidget {
  final Map<String, dynamic> geoJson;
  final Map<String, FloodData> districtData;
  const _DistrictLayer({required this.geoJson, required this.districtData});

  List<LatLng> _ring(List coords) => coords
      .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final polygons = <Polygon>[];
    final features = (geoJson['features'] as List?) ?? [];

    for (final feat in features) {
      final props    = feat['properties'] as Map? ?? {};
      // This dataset uses 'district' key (lowercase)
      final name     = (props['district'] ?? props['District'] ?? props['NAME_2'] ?? props['name'] ?? '').toString();
      final geometry = feat['geometry'] as Map? ?? {};
      final type     = geometry['type'] as String? ?? '';
      final coords   = geometry['coordinates'] as List? ?? [];

      final fd  = districtData[name];
      final sev = fd != null ? FloodSeverityHelper.fromString(fd.status) : FloodSeverity.normal;
      final isNormal    = sev == FloodSeverity.normal;
      final fillColor   = FloodSeverityHelper.color(sev).withValues(alpha: isNormal ? 0.10 : 0.22);
      final borderColor = FloodSeverityHelper.color(sev).withValues(alpha: isNormal ? 0.35 : 0.60);

      void addPolygon(List ring) {
        final pts = _ring(ring);
        if (pts.length < 3) return;
        polygons.add(Polygon(
          points: pts,
          color: fillColor,
          borderColor: borderColor,
          borderStrokeWidth: 1.0,
          label: name,
          labelStyle: TextStyle(
            color: FloodSeverityHelper.color(sev).withValues(alpha: 0.80),
            fontSize: 7.5, fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
          ),
          labelPlacement: PolygonLabelPlacement.centroid,
          rotateLabel: false,
        ));
      }

      if (type == 'Polygon') {
        for (final ring in coords) addPolygon(ring as List);
      } else if (type == 'MultiPolygon') {
        for (final poly in coords)
          for (final ring in (poly as List)) addPolygon(ring as List);
      }
    }
    return PolygonLayer(polygons: polygons);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Station detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _StationSheet extends StatelessWidget {
  final FloodData         data;
  final BiharStationMeta? meta;
  final VoidCallback      onClose;
  final VoidCallback      onOpenDetail;
  const _StationSheet({
    required this.data,
    required this.meta,
    required this.onClose,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final t         = RiverColors.of(context);
    final sev       = FloodSeverityHelper.fromString(data.status);
    final color     = FloodSeverityHelper.color(sev);
    final riverName = meta?.river ?? data.riverName ?? '';
    final riverCol  = _riverColor(riverName);
    final district  = meta?.district ?? _districtFor(data);
    final cities    = meta?.coversCities ?? const <String>[];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FloodSeverityHelper.cardBorder(sev), width: 1.2),
        boxShadow: [BoxShadow(color: FloodSeverityHelper.glowColor(sev), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: t.stroke, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: riverCol.withValues(alpha: 0.15),
                      border: Border.all(color: riverCol.withValues(alpha: 0.40), width: 1.2),
                    ),
                    child: Icon(FloodSeverityHelper.icon(sev), color: color, size: 18),
                  ),
                  Positioned(
                    bottom: -2, right: -2,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: riverCol,
                        border: Border.all(color: t.cardBg, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.city, style: TextStyle(
                        color: t.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (riverName.isNotEmpty) ...[
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: riverCol),
                          ),
                          const SizedBox(width: 4),
                          Text(riverName, style: TextStyle(
                              color: riverCol, fontSize: 10, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                        ],
                        if (district.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.cardBgElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: t.stroke, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_rounded, color: t.textSecondary, size: 9),
                                const SizedBox(width: 3),
                                Text(district, style: TextStyle(
                                    color: t.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.close_rounded, color: t.textSecondary, size: 18),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _SheetStat('Level',   '${data.currentLevel.toStringAsFixed(2)} m', color),
              const SizedBox(width: 8),
              _SheetStat('Warning', '${data.warningLevel.toStringAsFixed(1)} m',  AppPalette.warning),
              const SizedBox(width: 8),
              _SheetStat('Danger',  '${data.dangerLevel.toStringAsFixed(1)} m',   AppPalette.danger),
            ],
          ),

          const SizedBox(height: 10),

          _MiniLevelBar(
            current: data.currentLevel,
            warning: data.warningLevel,
            danger:  data.dangerLevel,
            color:   color,
          ),

          if (cities.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_city_rounded, color: t.textSecondary, size: 11),
                const SizedBox(width: 4),
                Text('Covers', style: TextStyle(
                    color: t.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 5, runSpacing: 4,
              children: cities.map((city) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.20), width: 0.7),
                ),
                child: Text(city, style: TextStyle(
                    color: color.withValues(alpha: 0.85), fontSize: 9.5,
                    fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ],

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: onOpenDetail,
              child: Text('View ${data.city} Detail →',
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

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
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: t.textSecondary, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _MiniLevelBar extends StatelessWidget {
  final double current, warning, danger;
  final Color  color;
  const _MiniLevelBar({required this.current, required this.warning, required this.danger, required this.color});
  @override
  Widget build(BuildContext context) {
    final t   = RiverColors.of(context);
    final pct = danger > 0 ? (current / danger).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8, color: t.cardBgElevated,
            child: FractionallySizedBox(
              widthFactor: pct, alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.5), color])),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${current.toStringAsFixed(1)} m', style: TextStyle(fontSize: 9, color: t.textSecondary)),
            Text('⚠ ${warning.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 9, color: AppPalette.warning)),
            Text('🔴 ${danger.toStringAsFixed(1)} m',  style: const TextStyle(fontSize: 9, color: AppPalette.danger)),
          ],
        ),
      ],
    );
  }
}

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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 12)],
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 10)],
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded, color: t.accent, size: 16),
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  final IconData icon; final String label; final bool active;
  final Color color; final VoidCallback onTap;
  const _LayerToggle({required this.icon, required this.label, required this.active, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : t.cardBg.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? color : t.stroke, width: active ? 1.2 : 0.8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? color : t.stroke, size: 14),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
                color: active ? color : t.stroke, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
