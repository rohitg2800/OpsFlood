// lib/screens/bihar_river_map_screen.dart
// BiharRiverMapScreen v9.0
//
// NEW in v9.0
// ─────────────────────────────────────────────────────────────────────────────
// • Station pins colour-coded by live ThresholdAlert.level from alertsProvider
//   (previously only used FloodData.status)
// • Danger/Extreme stations pulse with AnimatedOpacity ring
// • River polylines show inline AlertLevel chip at midpoint (river worst alert)
// • Station sheet shows:
//     – ThresholdAlert level badge + fill-percent bar
//     – AI 24 h prediction (next peak, trend, confidence) from predictionProvider
//     – CWC risk score bar from cwcRiskScore on FloodPrediction
//     – 6 h sparkline preview
// • CWC-only stations (no FloodData entry) rendered as a secondary layer
// • Alerts layer toggle + legend alert count badges
// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/bihar_station_metadata.dart';
import '../models/flood_data.dart';
import '../models/threshold_alert.dart';
import '../providers/alerts_provider.dart';
import '../providers/cwc_provider.dart';
import '../providers/flood_providers.dart';
import '../providers/prediction_provider.dart';
import '../screens/city_detail_screen.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity.dart';
import '../utils/flood_severity_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
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
// River colours
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
// AlertLevel helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _alertLevelColor(AlertLevel l) => switch (l) {
  AlertLevel.normal  => const Color(0xFF10E88A),
  AlertLevel.watch   => const Color(0xFF00C6FF),
  AlertLevel.warning => const Color(0xFFFFA520),
  AlertLevel.danger  => const Color(0xFFFF5500),
  AlertLevel.extreme => const Color(0xFFFF1A44),
};

IconData _alertLevelIcon(AlertLevel l) => switch (l) {
  AlertLevel.normal  => Icons.check_circle_rounded,
  AlertLevel.watch   => Icons.visibility_rounded,
  AlertLevel.warning => Icons.warning_amber_rounded,
  AlertLevel.danger  => Icons.crisis_alert_rounded,
  AlertLevel.extreme => Icons.emergency_rounded,
};

String _alertLevelHindi(AlertLevel l) => switch (l) {
  AlertLevel.normal  => 'सामान्य',
  AlertLevel.watch   => 'सतर्क',
  AlertLevel.warning => 'चेतावनी',
  AlertLevel.danger  => 'खतरा',
  AlertLevel.extreme => 'अतिखतरा',
};

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
// GeoJSON provider
// ─────────────────────────────────────────────────────────────────────────────

const _biharGeoJsonUrl =
    'https://cdn.jsdelivr.net/gh/udit-001/india-maps-data@master/geojson/states/bihar.geojson';

final _biharGeoJsonProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await http.get(Uri.parse(_biharGeoJsonUrl));
  if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
  throw Exception('GeoJSON fetch failed: ${res.statusCode}');
});

// ─────────────────────────────────────────────────────────────────────────────
// Build river → worst AlertLevel map
// ─────────────────────────────────────────────────────────────────────────────

Map<String, AlertLevel> _buildAlertMap(List<ThresholdAlert> alerts) {
  final map = <String, AlertLevel>{};
  for (final a in alerts) {
    final r = a.river.trim();
    if (r.isEmpty) continue;
    final existing = map[r];
    if (existing == null || a.level.index > existing.index) {
      map[r] = a.level;
    }
  }
  return map;
}

// Match a FloodData city to its ThresholdAlert (by cityName)
AlertLevel _alertForStation(FloodData fd, List<ThresholdAlert> alerts) {
  final cityLow = fd.city.toLowerCase();
  for (final a in alerts) {
    if (a.cityName.toLowerCase() == cityLow ||
        a.cityId.toLowerCase() == cityLow) {
      return a.level;
    }
  }
  // Fall back to FloodData.status
  final sev = FloodSeverityHelper.fromString(fd.status);
  return switch (sev) {
    FloodSeverity.extreme => AlertLevel.extreme,
    FloodSeverity.danger  => AlertLevel.danger,
    FloodSeverity.warning => AlertLevel.warning,
    FloodSeverity.watch   => AlertLevel.watch,
    _                     => AlertLevel.normal,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  const BiharRiverMapScreen({super.key});
  static const String route = '/bihar_river_map';

  @override
  ConsumerState<BiharRiverMapScreen> createState() => _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState extends ConsumerState<BiharRiverMapScreen>
    with TickerProviderStateMixin {

  bool _showRivers    = true;
  bool _showDistricts = true;
  bool _showStations  = true;
  bool _showAlerts    = true;   // river alert chips

  FloodData?        _selected;
  BiharStationMeta? _selectedMeta;
  String?           _selectedDistrict;

  // Pulse animation for danger/extreme stations
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _selectStation(FloodData fd) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected         = fd;
      _selectedMeta     = BiharStationRegistry.forSite(fd.city);
      _selectedDistrict = null;
    });
  }

  void _selectDistrict(String district) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDistrict = district;
      _selected         = null;
      _selectedMeta     = null;
    });
  }

  void _clearSelection() => setState(() {
    _selected = null; _selectedMeta = null; _selectedDistrict = null;
  });

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final stations = ref.watch(liveLevelsProvider);
    final geoAsync = ref.watch(_biharGeoJsonProvider);
    final alertsState   = ref.watch(alertsProvider);
    final allAlerts     = alertsState.cwcAlerts;
    final riverAlertMap = _buildAlertMap(allAlerts);

    // CWC live stations for merging
    final cwcAsync = ref.watch(cwcStationsProvider);

    // Build district → worst FloodData
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

    final Map<String, List<FloodData>> districtStations = {};
    for (final fd in stations) {
      final key = _districtFor(fd);
      if (key.isEmpty) continue;
      districtStations.putIfAbsent(key, () => []).add(fd);
    }

    final biharStations = stations
        .where((fd) =>
            fd.state.toUpperCase().contains('BIHAR') &&
            _coordsFor(fd) != null)
        .toList();

    // CWC-only stations not already in biharStations
    final cwcOnlyMetas = <BiharStationMeta>[];
    cwcAsync.whenData((cwcList) {
      final knownSites = biharStations
          .map((fd) => fd.city.toLowerCase().trim())
          .toSet();
      for (final cwc in cwcList) {
        final siteLow = cwc.site.toLowerCase().trim();
        if (!knownSites.contains(siteLow)) {
          final meta = BiharStationRegistry.forSite(cwc.site);
          if (meta != null) cwcOnlyMetas.add(meta);
        }
      }
    });

    final alertCount = biharStations
        .where((fd) => _alertForStation(fd, allAlerts).requiresEmergency)
        .length;

    final bool anySheetOpen = _selected != null || _selectedDistrict != null;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Stack(
        children: [

          // ── MAP ────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(25.78, 85.82),
              initialZoom: 7.2, minZoom: 6.0, maxZoom: 13.0,
              onTap: (_, __) => _clearSelection(),
            ),
            children: [

              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a','b','c','d'],
                userAgentPackageName: 'in.befiqr.equinox_flood',
                maxZoom: 19,
              ),

              // District polygons
              if (_showDistricts)
                geoAsync.when(
                  data: (geo) => _DistrictLayer(
                    geoJson:          geo,
                    districtData:     districtData,
                    selectedDistrict: _selectedDistrict,
                    onDistrictTap:    _selectDistrict,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                ),

              // River polylines
              if (_showRivers)
                PolylineLayer(
                  polylines: _biharRivers.map((r) {
                    final alertLevel = riverAlertMap[r.name] ?? AlertLevel.normal;
                    final strokeW = alertLevel.requiresEmergency ? 5.0
                        : alertLevel != AlertLevel.normal ? 4.0 : 3.5;
                    return Polyline(
                      points: r.points,
                      color:  r.color,
                      strokeWidth: strokeW,
                    );
                  }).toList(),
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

              // River alert chips (one per river, placed ¾ along the polyline)
              if (_showRivers && _showAlerts)
                MarkerLayer(
                  markers: _biharRivers
                    .where((r) {
                      final lvl = riverAlertMap[r.name] ?? AlertLevel.normal;
                      return lvl != AlertLevel.normal;
                    })
                    .map((r) {
                      final lvl   = riverAlertMap[r.name]!;
                      final idx   = (r.points.length * 3 / 4).floor()
                                      .clamp(0, r.points.length - 1);
                      final pt    = r.points[idx];
                      final col   = _alertLevelColor(lvl);
                      return Marker(
                        point: pt, width: 78, height: 22,
                        child: _RiverAlertChip(level: lvl, riverColor: r.color, col: col),
                      );
                    }).toList(),
                ),

              // Station pins (live alert level governed)
              if (_showStations)
                MarkerLayer(
                  markers: biharStations.map((fd) {
                    final coords     = _coordsFor(fd)!;
                    final alertLevel = _alertForStation(fd, allAlerts);
                    final color      = _alertLevelColor(alertLevel);
                    final isSelected = _selected?.city == fd.city;
                    final isEmergency = alertLevel.requiresEmergency;

                    return Marker(
                      point: coords,
                      width:  isSelected ? 48 : 36,
                      height: isSelected ? 48 : 36,
                      child: GestureDetector(
                        onTap: () => _selectStation(fd),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulsing outer ring for emergency stations
                            if (isEmergency)
                              AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (_, __) => Container(
                                  width:  (isSelected ? 48 : 36) * _pulseAnim.value * 1.4,
                                  height: (isSelected ? 48 : 36) * _pulseAnim.value * 1.4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withValues(alpha: 0.18 * (1 - _pulseAnim.value)),
                                  ),
                                ),
                              ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width:  isSelected ? 44 : 32,
                              height: isSelected ? 44 : 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: isSelected ? 0.30 : 0.18),
                                border: Border.all(color: color, width: isSelected ? 2.5 : 1.8),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
                                    : isEmergency
                                        ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6)]
                                        : null,
                              ),
                              child: Icon(
                                _alertLevelIcon(alertLevel),
                                color: color,
                                size:  isSelected ? 22 : 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // CWC-only secondary station layer
              if (_showStations && cwcOnlyMetas.isNotEmpty)
                MarkerLayer(
                  markers: cwcOnlyMetas.map((meta) => Marker(
                    point: meta.latLng,
                    width: 26, height: 26,
                    child: Tooltip(
                      message: '${meta.site}\n${meta.river}',
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _riverColor(meta.river).withValues(alpha: 0.20),
                          border: Border.all(
                              color: _riverColor(meta.river).withValues(alpha: 0.70),
                              width: 1.2),
                        ),
                        child: Icon(Icons.sensors_rounded,
                            color: _riverColor(meta.river), size: 11),
                      ),
                    ),
                  )).toList(),
                ),
            ],
          ),

          // ── App bar ─────────────────────────────────────────────────────
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
                            if (alertCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5500).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFF5500).withValues(alpha: 0.40)),
                                ),
                                child: Text('$alertCount alerts',
                                    style: const TextStyle(color: Color(0xFFFF5500), fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                            if (alertCount > 0) const SizedBox(width: 6),
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

          // ── Layer toggles ───────────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: anySheetOpen ? 290 : 130,
            child: Column(
              children: [
                _LayerToggle(icon: Icons.water_rounded,     label: 'Rivers',    active: _showRivers,    color: const Color(0xFF38BDF8), onTap: () => setState(() => _showRivers    = !_showRivers)),
                const SizedBox(height: 8),
                _LayerToggle(icon: Icons.grid_view_rounded, label: 'Districts', active: _showDistricts, color: t.accent,                onTap: () => setState(() => _showDistricts = !_showDistricts)),
                const SizedBox(height: 8),
                _LayerToggle(icon: Icons.sensors_rounded,   label: 'Stations',  active: _showStations,  color: const Color(0xFF10E88A), onTap: () => setState(() => _showStations  = !_showStations)),
                const SizedBox(height: 8),
                _LayerToggle(icon: Icons.warning_amber_rounded, label: 'Alerts', active: _showAlerts,   color: const Color(0xFFFFA520), onTap: () => setState(() => _showAlerts    = !_showAlerts)),
              ],
            ),
          ),

          // ── Legend ──────────────────────────────────────────────────────
          if (!anySheetOpen)
            Positioned(
              left: 12, bottom: 100,
              child: _MapLegend(
                showRivers:    _showRivers,
                showDistricts: _showDistricts,
                alertsByLevel: {
                  for (final lvl in AlertLevel.values)
                    lvl: allAlerts.where((a) => a.level == lvl).length,
                },
              ),
            ),

          // ── Station bottom sheet ────────────────────────────────────────
          if (_selected != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _StationSheet(
                data:         _selected!,
                meta:         _selectedMeta,
                alertLevel:   _alertForStation(_selected!, allAlerts),
                onClose:      _clearSelection,
                onOpenDetail: () => Navigator.pushNamed(
                  context, CityDetailScreen.route,
                  arguments: _selected!.city,
                ),
              ),
            ),

          // ── District bottom sheet ───────────────────────────────────────
          if (_selectedDistrict != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _DistrictSheet(
                districtName:  _selectedDistrict!,
                worstStation:  districtData[_selectedDistrict],
                allStations:   districtStations[_selectedDistrict] ?? [],
                allAlerts:     allAlerts,
                onClose:       _clearSelection,
                onStationTap:  _selectStation,
              ),
            ),

          // ── GeoJSON loading / error ─────────────────────────────────────
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
// River alert chip (on polyline)
// ─────────────────────────────────────────────────────────────────────────────

class _RiverAlertChip extends StatelessWidget {
  final AlertLevel level;
  final Color riverColor;
  final Color col;
  const _RiverAlertChip({required this.level, required this.riverColor, required this.col});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color:        col.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(5),
      border:       Border.all(color: col.withValues(alpha: 0.65), width: 0.8),
      boxShadow:    [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 4)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_alertLevelIcon(level), color: col, size: 9),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            level.label,
            style: TextStyle(
              color: col, fontSize: 8.5, fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// District polygon layer
// ─────────────────────────────────────────────────────────────────────────────

class _DistrictLayer extends StatefulWidget {
  final Map<String, dynamic>   geoJson;
  final Map<String, FloodData> districtData;
  final String?                selectedDistrict;
  final ValueChanged<String>   onDistrictTap;

  const _DistrictLayer({
    required this.geoJson,
    required this.districtData,
    required this.selectedDistrict,
    required this.onDistrictTap,
  });

  @override
  State<_DistrictLayer> createState() => _DistrictLayerState();
}

class _DistrictLayerState extends State<_DistrictLayer> {
  final LayerHitNotifier<String> _hitNotifier = ValueNotifier(null);

  List<LatLng> _ring(List coords) => coords
      .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final List<Polygon<String>> basePolygons      = [];
    final List<Polygon<String>> highlightPolygons = [];
    final features = (widget.geoJson['features'] as List?) ?? [];

    for (final feat in features) {
      final props    = feat['properties'] as Map? ?? {};
      final name     = (props['district'] ?? props['District'] ??
                        props['NAME_2'] ?? props['name'] ?? '').toString();
      final geometry = feat['geometry'] as Map? ?? {};
      final type     = geometry['type'] as String? ?? '';
      final coords   = geometry['coordinates'] as List? ?? [];

      final fd         = widget.districtData[name];
      final sev        = fd != null ? FloodSeverityHelper.fromString(fd.status) : FloodSeverity.normal;
      final isNormal   = sev == FloodSeverity.normal;
      final isSelected = widget.selectedDistrict == name;
      final sevColor   = FloodSeverityHelper.color(sev);

      final fillAlpha   = isSelected ? 0.38 : (isNormal ? 0.10 : 0.22);
      final borderAlpha = isSelected ? 0.90 : (isNormal ? 0.35 : 0.60);
      final borderWidth = isSelected ? 2.2  : 1.0;

      void addPolygon(List ring) {
        final pts = _ring(ring);
        if (pts.length < 3) return;

        basePolygons.add(Polygon<String>(
          points:            pts,
          color:             sevColor.withValues(alpha: fillAlpha),
          borderColor:       sevColor.withValues(alpha: borderAlpha),
          borderStrokeWidth: borderWidth,
          label: name,
          labelStyle: TextStyle(
            color: sevColor.withValues(alpha: isSelected ? 1.0 : 0.80),
            fontSize: isSelected ? 8.5 : 7.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
          labelPlacement: PolygonLabelPlacement.centroid,
          rotateLabel: false,
          hitValue: name,
        ));

        if (isSelected) {
          highlightPolygons.add(Polygon<String>(
            points:            pts,
            color:             sevColor.withValues(alpha: 0.0),
            borderColor:       sevColor.withValues(alpha: 0.55),
            borderStrokeWidth: 5.0,
            pattern: const StrokePattern.solid(),
          ));
        }
      }

      if (type == 'Polygon') {
        for (final ring in coords) addPolygon(ring as List);
      } else if (type == 'MultiPolygon') {
        for (final poly in coords)
          for (final ring in (poly as List)) addPolygon(ring as List);
      }
    }

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final result = _hitNotifier.value;
            if (result == null || result.hitValues.isEmpty) return;
            widget.onDistrictTap(result.hitValues.first);
          },
          child: PolygonLayer<String>(
            polygons:    basePolygons,
            hitNotifier: _hitNotifier,
          ),
        ),
        if (highlightPolygons.isNotEmpty)
          PolygonLayer<String>(polygons: highlightPolygons),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Station bottom sheet v2 — includes AI prediction + alert level
// ─────────────────────────────────────────────────────────────────────────────

class _StationSheet extends ConsumerWidget {
  final FloodData data;
  final BiharStationMeta? meta;
  final AlertLevel alertLevel;
  final VoidCallback onClose;
  final VoidCallback onOpenDetail;

  const _StationSheet({
    required this.data,
    required this.meta,
    required this.alertLevel,
    required this.onClose,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t          = RiverColors.of(context);
    final alertColor = _alertLevelColor(alertLevel);
    final riverName  = meta?.river ?? data.riverName ?? '';
    final riverCol   = _riverColor(riverName);
    final district   = meta?.district ?? _districtFor(data);
    final cities     = meta?.coversCities ?? const <String>[];

    // AI prediction
    final predAsync = ref.watch(predictionProvider(data.city));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alertColor.withValues(alpha: 0.45), width: 1.4),
        boxShadow: [BoxShadow(color: alertColor.withValues(alpha: 0.22), blurRadius: 22)],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // drag handle
            Center(child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: t.stroke, borderRadius: BorderRadius.circular(2)))),

            // ── Header ────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: riverCol.withValues(alpha: 0.15),
                      border: Border.all(color: riverCol.withValues(alpha: 0.40), width: 1.2)),
                    child: Icon(_alertLevelIcon(alertLevel), color: alertColor, size: 18)),
                  Positioned(bottom: -2, right: -2,
                    child: Container(width: 12, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: riverCol,
                        border: Border.all(color: t.cardBg, width: 1.5)))),
                ]),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.city, style: TextStyle(
                      color: t.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Row(children: [
                    // Alert level badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: alertColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: alertColor.withValues(alpha: 0.35))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_alertLevelIcon(alertLevel), color: alertColor, size: 9),
                        const SizedBox(width: 3),
                        Text(alertLevel.label,
                            style: TextStyle(color: alertColor, fontSize: 9, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 3),
                        Text(_alertLevelHindi(alertLevel),
                            style: TextStyle(color: alertColor.withValues(alpha: 0.70), fontSize: 8)),
                      ]),
                    ),
                    if (riverName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(width: 7, height: 7,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: riverCol)),
                      const SizedBox(width: 3),
                      Text(riverName,
                          style: TextStyle(color: riverCol, fontSize: 9, fontWeight: FontWeight.w700)),
                    ],
                    if (district.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.cardBgElevated, borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: t.stroke, width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.location_on_rounded, color: t.textSecondary, size: 9),
                          const SizedBox(width: 3),
                          Text(district, style: TextStyle(
                              color: t.textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ]),
                ])),
                IconButton(onPressed: onClose, padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.close_rounded, color: t.textSecondary, size: 18)),
              ],
            ),

            const SizedBox(height: 12),

            // ── Level stats ───────────────────────────────────────────────
            Row(children: [
              _SheetStat('Level',   '${data.currentLevel.toStringAsFixed(2)} m', alertColor),
              const SizedBox(width: 8),
              _SheetStat('Warning', '${data.warningLevel.toStringAsFixed(1)} m',  AppPalette.warning),
              const SizedBox(width: 8),
              _SheetStat('Danger',  '${data.dangerLevel.toStringAsFixed(1)} m',   AppPalette.danger),
            ]),
            const SizedBox(height: 10),
            _MiniLevelBar(current: data.currentLevel, warning: data.warningLevel, danger: data.dangerLevel, color: alertColor),

            // ── Fill percent bar (from ThresholdAlert) ────────────────────
            if (data.dangerLevel > 0) ...[
              const SizedBox(height: 8),
              _FillPercentRow(
                fillPct: (data.currentLevel / data.dangerLevel).clamp(0.0, 1.5),
                color:   alertColor,
                t:       t,
              ),
            ],

            // ── AI prediction block ───────────────────────────────────────
            const SizedBox(height: 12),
            _PredictionBlock(predAsync: predAsync, alertColor: alertColor, t: t),

            // ── Covered cities ────────────────────────────────────────────
            if (cities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.location_city_rounded, color: t.textSecondary, size: 11),
                const SizedBox(width: 4),
                Text('Covers', style: TextStyle(color: t.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 5, runSpacing: 4,
                children: cities.map((city) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: alertColor.withValues(alpha: 0.20), width: 0.7)),
                  child: Text(city, style: TextStyle(
                      color: alertColor.withValues(alpha: 0.85), fontSize: 9.5, fontWeight: FontWeight.w600)),
                )).toList()),
            ],

            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: alertColor.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: onOpenDetail,
                child: Text('View ${data.city} Detail →',
                    style: TextStyle(color: alertColor, fontSize: 13, fontWeight: FontWeight.w700)),
              )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fill percent row
// ─────────────────────────────────────────────────────────────────────────────

class _FillPercentRow extends StatelessWidget {
  final double fillPct;
  final Color  color;
  final RiverColors t;
  const _FillPercentRow({required this.fillPct, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    final pct   = fillPct.clamp(0.0, 1.0);
    final label = '${(pct * 100).toStringAsFixed(0)}% of danger level';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Danger fill', style: TextStyle(color: t.textSecondary, fontSize: 9.5)),
        Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 6, color: t.cardBgElevated,
          child: FractionallySizedBox(
            widthFactor: pct, alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.50), color]))),
          ),
        )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI prediction block
// ─────────────────────────────────────────────────────────────────────────────

class _PredictionBlock extends StatelessWidget {
  final AsyncValue<FloodPrediction> predAsync;
  final Color alertColor;
  final RiverColors t;
  const _PredictionBlock({required this.predAsync, required this.alertColor, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        t.cardBgElevated,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: t.stroke),
      ),
      child: predAsync.when(
        loading: () => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: alertColor)),
            const SizedBox(width: 8),
            Text('Loading AI forecast…',
                style: TextStyle(color: t.textSecondary, fontSize: 10)),
          ],
        ),
        error: (_, __) => Row(children: [
          Icon(Icons.info_outline_rounded, color: t.textSecondary, size: 12),
          const SizedBox(width: 6),
          Text('Forecast unavailable', style: TextStyle(color: t.textSecondary, fontSize: 10)),
        ]),
        data: (pred) {
          // Peak level in next 24 h
          final pts24  = pred.next24h;
          double? peak;
          int?    peakHourIdx;
          for (int i = 0; i < pts24.length; i++) {
            if (peak == null || pts24[i].level > peak) {
              peak = pts24[i].level;
              peakHourIdx = i;
            }
          }
          final trend   = peak != null && peak > pred.currentLevel ? '⬆' :
                          peak != null && peak < pred.currentLevel ? '⬇' : '→';
          final trendCol = trend == '⬆' ? AppPalette.danger
                         : trend == '⬇' ? const Color(0xFF10E88A)
                         : t.textSecondary;
          final conf    = pred.confidencePct.toStringAsFixed(0);
          final model   = pred.modelVersion;

          // 6 h sparkline (first 6 points of next24h)
          final spark   = pts24.take(6).toList();
          final sparkMin = spark.isEmpty ? 0.0 : spark.map((p) => p.level).reduce(math.min);
          final sparkMax = spark.isEmpty ? 1.0 : spark.map((p) => p.level).reduce(math.max);
          final sparkRange = (sparkMax - sparkMin).clamp(0.01, double.infinity);

          // CWC risk score bar
          final riskScore = pred.cwcRiskScore;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Icon(Icons.psychology_rounded, color: alertColor, size: 12),
              const SizedBox(width: 5),
              Text('AI Flood Forecast', style: TextStyle(
                  color: t.textPrimary, fontSize: 10, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(model, style: TextStyle(color: t.textSecondary, fontSize: 8)),
            ]),
            const SizedBox(height: 8),

            // Key metrics row
            Row(children: [
              Expanded(child: _PredStat(
                label: '24 h Peak',
                value: peak != null ? '${peak.toStringAsFixed(2)} m' : '—',
                color: alertColor, t: t,
              )),
              const SizedBox(width: 6),
              Expanded(child: _PredStat(
                label: 'Trend',
                value: '$trend ${peakHourIdx != null ? '+${peakHourIdx}h' : ''}',
                color: trendCol, t: t,
              )),
              const SizedBox(width: 6),
              Expanded(child: _PredStat(
                label: 'Confidence',
                value: '$conf%',
                color: t.textSecondary, t: t,
              )),
            ]),

            // CWC risk score bar
            if (riskScore != null) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('CWC Risk Score', style: TextStyle(color: t.textSecondary, fontSize: 9)),
                Text('${riskScore.toStringAsFixed(0)}/100',
                    style: TextStyle(color: alertColor, fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 3),
              ClipRRect(borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 5, color: t.cardBg,
                  child: FractionallySizedBox(
                    widthFactor: (riskScore / 100).clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          const Color(0xFF10E88A),
                          const Color(0xFFFFA520),
                          AppPalette.danger,
                        ], stops: const [0.0, 0.6, 1.0])),
                    ),
                  ),
                )),
            ],

            // 6 h sparkline
            if (spark.length > 1) ...[
              const SizedBox(height: 8),
              Text('Next 6 h', style: TextStyle(color: t.textSecondary, fontSize: 9)),
              const SizedBox(height: 4),
              SizedBox(height: 28,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    points: spark.map((p) =>
                      (p.level - sparkMin) / sparkRange).toList(),
                    color: alertColor,
                  ),
                  size: const Size(double.infinity, 28),
                ),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

class _PredStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  final RiverColors t;
  const _PredStat({required this.label, required this.value, required this.color, required this.t});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.18))),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center),
      Text(label, style: TextStyle(color: t.textSecondary, fontSize: 8)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sparkline painter (6 h)
// ─────────────────────────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> points;   // 0.0–1.0 normalised
  final Color        color;
  const _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final n    = points.length;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      final y = size.height * (1 - points[i]);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()
      ..color       = color
      ..strokeWidth = 1.8
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round);
    // fill
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.0)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter)
        .createShader(Offset.zero & size)
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// District bottom sheet (updated with alert awareness)
// ─────────────────────────────────────────────────────────────────────────────

class _DistrictSheet extends StatelessWidget {
  final String             districtName;
  final FloodData?         worstStation;
  final List<FloodData>    allStations;
  final List<ThresholdAlert> allAlerts;
  final VoidCallback       onClose;
  final ValueChanged<FloodData> onStationTap;

  const _DistrictSheet({
    required this.districtName,
    required this.worstStation,
    required this.allStations,
    required this.allAlerts,
    required this.onClose,
    required this.onStationTap,
  });

  @override
  Widget build(BuildContext context) {
    final t   = RiverColors.of(context);
    final sev = worstStation != null
        ? FloodSeverityHelper.fromString(worstStation!.status)
        : FloodSeverity.normal;
    final color = FloodSeverityHelper.color(sev);

    final sorted = [...allStations]
      ..sort((a, b) =>
          FloodSeverityHelper.fromString(b.status).index -
          FloodSeverityHelper.fromString(a.status).index);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: t.cardBg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FloodSeverityHelper.cardBorder(sev), width: 1.2),
        boxShadow: [BoxShadow(color: FloodSeverityHelper.glowColor(sev), blurRadius: 24)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          decoration: BoxDecoration(color: t.stroke, borderRadius: BorderRadius.circular(2)))),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color.withValues(alpha: 0.40), width: 1.2)),
              child: Icon(Icons.location_city_rounded, color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(districtName, style: TextStyle(
                  color: t.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.35))),
                  child: Text(FloodSeverityHelper.label(sev),
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800))),
                const SizedBox(width: 6),
                Text('${allStations.length} station${allStations.length != 1 ? 's' : ''}',
                    style: TextStyle(color: t.textSecondary, fontSize: 10)),
              ]),
            ])),
            IconButton(onPressed: onClose, padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.close_rounded, color: t.textSecondary, size: 18)),
          ]),
        ),

        if (worstStation != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _DistrictWorstCard(fd: worstStation!, color: color, t: t, allAlerts: allAlerts)),

        if (sorted.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('All Stations',
                style: TextStyle(color: t.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: sorted.length,
              itemBuilder: (_, i) => _DistrictStationRow(
                fd:        sorted[i],
                alertLevel: _alertForStation(sorted[i], allAlerts),
                onTap:     () => onStationTap(sorted[i]),
                t:         t,
              ),
            ),
          ),
        ],

        if (allStations.isEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('No monitoring stations in this district.',
                style: TextStyle(color: t.textSecondary, fontSize: 11))),

        const SizedBox(height: 4),
      ]),
    );
  }
}

class _DistrictWorstCard extends StatelessWidget {
  final FloodData  fd;
  final Color      color;
  final RiverColors t;
  final List<ThresholdAlert> allAlerts;
  const _DistrictWorstCard({required this.fd, required this.color, required this.t, required this.allAlerts});

  @override
  Widget build(BuildContext context) {
    final meta       = BiharStationRegistry.forSite(fd.city);
    final riverName  = meta?.river ?? fd.riverName ?? '';
    final riverCol   = _riverColor(riverName);
    final alertLevel = _alertForStation(fd, allAlerts);
    final alertCol   = _alertLevelColor(alertLevel);
    final pct        = fd.dangerLevel > 0
        ? (fd.currentLevel / fd.dangerLevel).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertCol.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertCol.withValues(alpha: 0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_alertLevelIcon(alertLevel), color: alertCol, size: 13),
          const SizedBox(width: 5),
          Expanded(child: Text(fd.city,
              style: TextStyle(color: alertCol, fontSize: 12, fontWeight: FontWeight.w800))),
          if (riverName.isNotEmpty) ...[
            Container(width: 7, height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: riverCol)),
            const SizedBox(width: 4),
            Text(riverName, style: TextStyle(color: riverCol, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: Container(height: 7, color: t.cardBg,
            child: FractionallySizedBox(widthFactor: pct, alignment: Alignment.centerLeft,
              child: Container(decoration: BoxDecoration(
                gradient: LinearGradient(colors: [alertCol.withValues(alpha: 0.5), alertCol])))))),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${fd.currentLevel.toStringAsFixed(2)} m',
              style: TextStyle(color: alertCol, fontSize: 10, fontWeight: FontWeight.w700)),
          Text('⚠ ${fd.warningLevel.toStringAsFixed(1)} m',
              style: const TextStyle(color: AppPalette.warning, fontSize: 9)),
          Text('🔴 ${fd.dangerLevel.toStringAsFixed(1)} m',
              style: const TextStyle(color: AppPalette.danger, fontSize: 9)),
        ]),
      ]),
    );
  }
}

class _DistrictStationRow extends StatelessWidget {
  final FloodData    fd;
  final AlertLevel   alertLevel;
  final VoidCallback onTap;
  final RiverColors  t;
  const _DistrictStationRow({required this.fd, required this.alertLevel, required this.onTap, required this.t});

  @override
  Widget build(BuildContext context) {
    final color    = _alertLevelColor(alertLevel);
    final meta     = BiharStationRegistry.forSite(fd.city);
    final river    = meta?.river ?? fd.riverName ?? '';
    final riverCol = _riverColor(river);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: t.cardBgElevated, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.20))),
        child: Row(children: [
          Container(width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.50), blurRadius: 4)])),
          const SizedBox(width: 8),
          Expanded(child: Text(fd.city,
              style: TextStyle(color: t.textPrimary, fontSize: 11, fontWeight: FontWeight.w700))),
          if (river.isNotEmpty) ...[
            Container(width: 6, height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: riverCol)),
            const SizedBox(width: 4),
            Text(river, style: TextStyle(color: riverCol, fontSize: 8.5, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
          ],
          // Alert level label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4)),
            child: Text(alertLevel.label,
                style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800))),
          const SizedBox(width: 5),
          Text('${fd.currentLevel.toStringAsFixed(1)} m',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: t.textSecondary, size: 14),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MapLegend (updated: alert count badges)
// ─────────────────────────────────────────────────────────────────────────────

class _MapLegend extends StatefulWidget {
  final bool showRivers;
  final bool showDistricts;
  final Map<AlertLevel, int> alertsByLevel;
  const _MapLegend({
    required this.showRivers,
    required this.showDistricts,
    required this.alertsByLevel,
  });

  @override
  State<_MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<_MapLegend> with SingleTickerProviderStateMixin {
  bool _expanded     = false;
  bool _showAlerts   = true;
  bool _showLevelBar = true;
  bool _showRiversSec= true;
  bool _showDistrSec = true;

  late final AnimationController _anim;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _anim.forward() : _anim.reverse();
  }

  static const _levels = [
    (AlertLevel.normal,  'Normal',  'सामान्य'),
    (AlertLevel.watch,   'Watch',   'सतर्क'),
    (AlertLevel.warning, 'Warning', 'चेतावनी'),
    (AlertLevel.danger,  'Danger',  'खतरा'),
    (AlertLevel.extreme, 'Extreme', 'अतिखतरा'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.bottomLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        decoration: BoxDecoration(
          color: t.cardBg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _toggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                child: Row(children: [
                  Icon(Icons.legend_toggle_rounded, color: t.accent, size: 13),
                  const SizedBox(width: 6),
                  Text('Legend', style: TextStyle(
                      color: t.textPrimary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: t.textSecondary, size: 16)),
                ]),
              ),
            ),
            FadeTransition(
              opacity: _fade,
              child: _expanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendDivider(t),
                      _SectionHeader(title: 'Alert Levels', icon: Icons.warning_amber_rounded,
                          expanded: _showAlerts,    onToggle: () => setState(() => _showAlerts    = !_showAlerts),    t: t),
                      if (_showAlerts) ...[
                        const SizedBox(height: 4),
                        for (final r in _levels)
                          _AlertLevelRow(
                            sev:   r.$1, label: r.$2, hindi: r.$3, t: t,
                            count: widget.alertsByLevel[r.$1] ?? 0,
                          ),
                        const SizedBox(height: 6),
                      ],
                      _LegendDivider(t),
                      _SectionHeader(title: 'Water Level Zones', icon: Icons.straighten_rounded,
                          expanded: _showLevelBar,  onToggle: () => setState(() => _showLevelBar  = !_showLevelBar),  t: t),
                      if (_showLevelBar) ...[ const SizedBox(height: 6), const _WaterLevelBar(), const SizedBox(height: 6) ],
                      if (widget.showRivers) ...[
                        _LegendDivider(t),
                        _SectionHeader(title: 'Rivers', icon: Icons.water_rounded,
                            expanded: _showRiversSec, onToggle: () => setState(() => _showRiversSec = !_showRiversSec), t: t),
                        if (_showRiversSec) ...[
                          const SizedBox(height: 4),
                          for (final r in _biharRivers) _RiverRow(river: r, t: t),
                          const SizedBox(height: 4),
                        ],
                      ],
                      if (widget.showDistricts) ...[
                        _LegendDivider(t),
                        _SectionHeader(title: 'District Fill', icon: Icons.grid_view_rounded,
                            expanded: _showDistrSec,  onToggle: () => setState(() => _showDistrSec  = !_showDistrSec),  t: t),
                        if (_showDistrSec) ...[ const SizedBox(height: 6), const _DistrictShadingBar(), const SizedBox(height: 8) ],
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _LegendDivider extends StatelessWidget {
  final RiverColors t;
  const _LegendDivider(this.t);
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: t.stroke.withValues(alpha: 0.60));
}

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  final bool expanded; final VoidCallback onToggle; final RiverColors t;
  const _SectionHeader({required this.title, required this.icon, required this.expanded, required this.onToggle, required this.t});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle, behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 10, 3),
      child: Row(children: [
        Icon(icon, color: t.accent, size: 10), const SizedBox(width: 5),
        Text(title, style: TextStyle(color: t.textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.7)),
        const Spacer(),
        Icon(expanded ? Icons.remove_rounded : Icons.add_rounded, color: t.textSecondary, size: 11),
      ]),
    ),
  );
}

class _AlertLevelRow extends StatelessWidget {
  final AlertLevel sev;
  final String     label, hindi;
  final int        count;     // live alert count for this level
  final RiverColors t;
  const _AlertLevelRow({required this.sev, required this.label, required this.hindi, required this.count, required this.t});

  @override
  Widget build(BuildContext context) {
    final color = _alertLevelColor(sev);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 10, 4),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)])),
        const SizedBox(width: 5),
        Icon(_alertLevelIcon(sev), color: color, size: 11),
        const SizedBox(width: 5),
        Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700))),
        Text(hindi, style: TextStyle(color: color.withValues(alpha: 0.65), fontSize: 8.5, fontWeight: FontWeight.w500)),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.20)),
            child: Center(child: Text('$count',
                style: TextStyle(color: color, fontSize: 7.5, fontWeight: FontWeight.w900))),
          ),
        ],
      ]),
    );
  }
}

class _WaterLevelBar extends StatelessWidget {
  const _WaterLevelBar();
  static const _segments = [
    (Color(0xFF10E88A), 'Normal',  ''),
    (Color(0xFF00C6FF), 'Watch',   '90%W'),
    (Color(0xFFFFA520), 'Warning', 'W'),
    (Color(0xFFFF5500), 'Danger',  'D'),
    (Color(0xFFFF1A44), 'Extreme', '115%D'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(5),
          child: SizedBox(height: 10,
            child: Row(children: _segments.map((s) => Expanded(
              child: Container(color: s.$1))).toList()))),
        const SizedBox(height: 3),
        Row(children: List.generate(_segments.length, (i) {
          final label = _segments[i].$3;
          return Expanded(child: label.isEmpty ? const SizedBox.shrink() :
            Text(label, style: TextStyle(color: t.textSecondary, fontSize: 7.5, fontWeight: FontWeight.w600),
              textAlign: i == 0 ? TextAlign.start : TextAlign.center));
        })),
        const SizedBox(height: 4),
        Row(children: _segments.map((s) => Expanded(child: Text(s.$2,
          style: TextStyle(color: s.$1, fontSize: 7, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis))).toList()),
      ]),
    );
  }
}

class _RiverRow extends StatelessWidget {
  final _RiverLine river; final RiverColors t;
  const _RiverRow({required this.river, required this.t});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 10, 3),
    child: Row(children: [
      SizedBox(width: 20, height: 10, child: CustomPaint(painter: _LinePainter(river.color))),
      const SizedBox(width: 6),
      Text(river.name, style: TextStyle(color: river.color, fontSize: 9, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _LinePainter extends CustomPainter {
  final Color color;
  const _LinePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2),
      Paint()..color = color..strokeWidth = 3.0..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_LinePainter old) => old.color != color;
}

class _DistrictShadingBar extends StatelessWidget {
  const _DistrictShadingBar();
  static const _stops = [
    (Color(0xFF10E88A), 'Normal'),
    (Color(0xFF00C6FF), 'Watch'),
    (Color(0xFFFFA520), 'Warning'),
    (Color(0xFFFF5500), 'Danger'),
    (Color(0xFFFF1A44), 'Extreme'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(5),
          child: SizedBox(height: 8, child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _stops.map((s) => s.$1.withValues(alpha: 0.70)).toList())),
            child: const SizedBox.expand()))),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Low risk',  style: TextStyle(color: t.textSecondary, fontSize: 7.5)),
          Text('High risk', style: const TextStyle(color: AppPalette.danger, fontSize: 7.5)),
        ]),
        const SizedBox(height: 4),
        Row(children: _stops.map((s) => Expanded(child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: s.$1)),
            const SizedBox(width: 2),
            Flexible(child: Text(s.$2,
              style: TextStyle(color: s.$1, fontSize: 6.5, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis)),
          ]))).toList()),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetStat extends StatelessWidget {
  final String label, value; final Color color;
  const _SheetStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20))),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: t.textSecondary, fontSize: 9)),
      ])));
  }
}

class _MiniLevelBar extends StatelessWidget {
  final double current, warning, danger; final Color color;
  const _MiniLevelBar({required this.current, required this.warning, required this.danger, required this.color});
  @override
  Widget build(BuildContext context) {
    final t   = RiverColors.of(context);
    final pct = danger > 0 ? (current / danger).clamp(0.0, 1.0) : 0.0;
    return Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(6),
        child: Container(height: 8, color: t.cardBgElevated,
          child: FractionallySizedBox(widthFactor: pct, alignment: Alignment.centerLeft,
            child: Container(decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.5), color])))))),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${current.toStringAsFixed(1)} m', style: TextStyle(fontSize: 9, color: t.textSecondary)),
        Text('⚠ ${warning.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 9, color: AppPalette.warning)),
        Text('🔴 ${danger.toStringAsFixed(1)} m',  style: const TextStyle(fontSize: 9, color: AppPalette.danger)),
      ]),
    ]);
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
        color: t.cardBg.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.stroke),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 12)]),
      child: child);
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
          color: t.cardBg.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.stroke),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 10)]),
        child: Icon(Icons.arrow_back_ios_new_rounded, color: t.accent, size: 16)));
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? color : t.stroke, size: 14),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              color: active ? color : t.stroke, fontSize: 10, fontWeight: FontWeight.w700)),
        ])));
  }
}
