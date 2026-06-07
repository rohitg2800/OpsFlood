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
import 'dart:ui' as ui;

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
                                    style: const TextStyle(
                                        color: Color(0xFFFF5500), fontSize: 10,
                                        fontWeight: FontWeight.w800)),
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

          // ── Layer toggles ───────────────────────────────────────────────
          Positioned(
            top: 60, right: 8,
            child: SafeArea(
              child: Column(
                children: [
                  _LayerToggle(icon: Icons.water_rounded,        label: 'Rivers',    active: _showRivers,    onTap: () => setState(() => _showRivers    = !_showRivers)),
                  const SizedBox(height: 6),
                  _LayerToggle(icon: Icons.map_outlined,         label: 'Districts', active: _showDistricts, onTap: () => setState(() => _showDistricts = !_showDistricts)),
                  const SizedBox(height: 6),
                  _LayerToggle(icon: Icons.sensors_rounded,      label: 'Stations',  active: _showStations,  onTap: () => setState(() => _showStations  = !_showStations)),
                  const SizedBox(height: 6),
                  _LayerToggle(icon: Icons.notifications_active_rounded, label: 'Alerts', active: _showAlerts, onTap: () => setState(() => _showAlerts = !_showAlerts)),
                ],
              ),
            ),
          ),

          // ── Legend (bottom-left, hide when sheet open) ───────────────────
          if (!anySheetOpen)
            Positioned(
              bottom: 16, left: 8,
              child: SafeArea(
                child: _MapLegend(
                  showRivers:    _showRivers,
                  showDistricts: _showDistricts,
                ),
              ),
            ),

          // ── Station bottom sheet ─────────────────────────────────────────
          if (_selected != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: _StationSheet(
                  data:       _selected!,
                  meta:       _selectedMeta,
                  alertLevel: _alertForStation(_selected!, allAlerts),
                  onClose:    _clearSelection,
                  onOpenDetail: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CityDetailScreen(city: _selected!.city)));
                  },
                ),
              ),
            ),

          // ── District bottom sheet ────────────────────────────────────────
          if (_selectedDistrict != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: _DistrictSheet(
                  districtName:  _selectedDistrict!,
                  worstStation:  districtData[_selectedDistrict],
                  allStations:   districtStations[_selectedDistrict] ?? [],
                  allAlerts:     allAlerts,
                  onClose:       _clearSelection,
                  onStationTap:  _selectStation,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// River alert chip
// ─────────────────────────────────────────────────────────────────────────────

class _RiverAlertChip extends StatelessWidget {
  final AlertLevel level;
  final Color      riverColor;
  final Color      col;
  const _RiverAlertChip({required this.level, required this.riverColor, required this.col});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: col.withValues(alpha: 0.70), width: 1.0),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_alertLevelIcon(level), color: col, size: 9),
      const SizedBox(width: 3),
      Text(level.label,
          style: TextStyle(color: col, fontSize: 8, fontWeight: FontWeight.w800)),
    ]),
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
  final _hitNotifier = ValueNotifier<LayerHitResult<String>?>(null);

  static List<LatLng> _ring(List ring) => ring
      .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
      .toList();

  @override
  void dispose() {
    _hitNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final features = (widget.geoJson['features'] as List? ?? []);
    final basePolygons      = <Polygon<String>>[];
    final highlightPolygons = <Polygon<String>>[];

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
              ),
            ],

            // ── Covered cities ────────────────────────────────────────────
            if (cities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: cities.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: riverCol.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: riverCol.withValues(alpha: 0.25))),
                  child: Text(c, style: TextStyle(
                      color: riverCol, fontSize: 8.5, fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // ── AI Prediction block ───────────────────────────────────────
            predAsync.when(
              data:    (pred) => _PredictionBlock(pred: pred, alertColor: alertColor),
              loading: () => Container(
                height: 52,
                decoration: BoxDecoration(
                  color: t.cardBgElevated, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)))),
              error:   (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // ── Open full detail ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: alertColor.withValues(alpha: 0.12),
                  foregroundColor: alertColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: onOpenDetail,
                child: const Text('Open Full Detail →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fill-percent row
// ─────────────────────────────────────────────────────────────────────────────

class _FillPercentRow extends StatelessWidget {
  final double fillPct;   // 0.0–1.5
  final Color  color;
  const _FillPercentRow({required this.fillPct, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final pct = fillPct.clamp(0.0, 1.0);
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 6,
            color: t.cardBgElevated,
            child: FractionallySizedBox(
              widthFactor: pct,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.50), color]),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text('${(fillPct * 100).toStringAsFixed(0)}% of danger',
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI prediction block
// ─────────────────────────────────────────────────────────────────────────────

class _PredictionBlock extends StatelessWidget {
  final FloodPrediction pred;
  final Color           alertColor;
  const _PredictionBlock({required this.pred, required this.alertColor});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    // Sparkline: use next24h normalised to 0-1 between current and danger
    final points = pred.next24h.isEmpty
        ? <double>[]
        : pred.next24h.map((p) {
            if (pred.dangerLevel <= pred.currentLevel) return 0.5;
            return ((p.level - pred.currentLevel) /
                    (pred.dangerLevel - pred.currentLevel))
                .clamp(0.0, 1.0);
          }).toList();

    // Trend
    final trend = pred.next24h.isEmpty
        ? TrendDirection.steady
        : pred.next24h.last.level > pred.currentLevel * 1.005
            ? TrendDirection.rising
            : pred.next24h.last.level < pred.currentLevel * 0.995
                ? TrendDirection.falling
                : TrendDirection.steady;

    final trendColor = switch (trend) {
      TrendDirection.rising  => const Color(0xFFFF5500),
      TrendDirection.falling => const Color(0xFF10E88A),
      TrendDirection.steady  => const Color(0xFF00C6FF),
    };
    final trendIcon = switch (trend) {
      TrendDirection.rising  => Icons.trending_up_rounded,
      TrendDirection.falling => Icons.trending_down_rounded,
      TrendDirection.steady  => Icons.trending_flat_rounded,
    };

    // Peak in next 24h
    final peakPt = pred.next24h.isEmpty
        ? null
        : pred.next24h.reduce((a, b) => a.level > b.level ? a : b);

    // CWC risk score
    final cwcRisk = pred.cwcRiskScore;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alertColor.withValues(alpha: 0.20)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Icon(Icons.psychology_rounded, color: alertColor, size: 13),
          const SizedBox(width: 5),
          Text('AI Prediction · 24 h',
              style: TextStyle(color: t.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
          const Spacer(),
          // Trend badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: trendColor.withValues(alpha: 0.35))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(trendIcon, color: trendColor, size: 10),
              const SizedBox(width: 3),
              Text(trend.label,
                  style: TextStyle(color: trendColor, fontSize: 9, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),

        if (points.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: CustomPaint(
              painter: _SparklinePainter(points: points, color: alertColor),
              size: const Size(double.infinity, 36),
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Stats row
        Row(children: [
          if (peakPt != null) ...[
            _PredStat('Peak', '${peakPt.level.toStringAsFixed(2)} m', alertColor),
            const SizedBox(width: 8),
          ],
          _PredStat('Confidence', '${pred.confidencePct.toStringAsFixed(0)}%',
              const Color(0xFF00C6FF)),
          const SizedBox(width: 8),
          _PredStat('Model', pred.modelVersion, t.textSecondary),
        ]),

        // CWC risk bar
        if (cwcRisk != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Text('CWC Risk', style: TextStyle(color: t.textSecondary, fontSize: 9)),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 5, color: t.cardBg,
                  child: FractionallySizedBox(
                    widthFactor: (cwcRisk / 100).clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          const Color(0xFF10E88A),
                          const Color(0xFFFFA520),
                          const Color(0xFFFF1A44),
                        ], stops: const [0.0, 0.5, 1.0]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('${cwcRisk.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF00C6FF), fontSize: 9, fontWeight: FontWeight.w800)),
          ]),
        ],
      ]),
    );
  }
}

class _PredStat extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _PredStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: t.textSecondary, fontSize: 8)),
      Text(value,  style: TextStyle(color: color,          fontSize: 11, fontWeight: FontWeight.w800)),
    ]);
  }
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
    final path = ui.Path();
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
    final fill = ui.Path()
      ..addPath(path, Offset.zero)
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
                style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w700))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: t.textSecondary, size: 14),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Map Legend (collapsible)
// ─────────────────────────────────────────────────────────────────────────────

class _MapLegend extends StatefulWidget {
  final bool showRivers;
  final bool showDistricts;
  const _MapLegend({required this.showRivers, required this.showDistricts});

  @override
  State<_MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<_MapLegend> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;

  // Section collapse states
  bool _alertsExpanded    = true;
  bool _levelsExpanded    = false;
  bool _riversExpanded    = true;
  bool _districtExpanded  = false;

  @override
  void initState() {
    super.initState();
    _ctrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 0.8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.40), blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (tap to expand/collapse) ───────────────────────────
          GestureDetector(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(children: [
                Icon(Icons.legend_toggle_rounded,
                    color: t.accent, size: 13),
                const SizedBox(width: 5),
                Text('Legend',
                    style: TextStyle(color: t.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: t.textSecondary, size: 14)),
              ]),
            ),
          ),

          // ── Expandable body ───────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? FadeTransition(
                    opacity: _fadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LegendDivider(),

                          // ── Alert Levels ───────────────────────────────
                          _SectionHeader(
                            label: 'Flood Alert Levels',
                            expanded: _alertsExpanded,
                            onTap: () => setState(() => _alertsExpanded = !_alertsExpanded),
                          ),
                          if (_alertsExpanded) ...[
                            for (final lvl in AlertLevel.values)
                              _AlertLevelRow(level: lvl),
                          ],

                          _LegendDivider(),

                          // ── Water Level Zones ──────────────────────────
                          _SectionHeader(
                            label: 'Water Level Zones',
                            expanded: _levelsExpanded,
                            onTap: () => setState(() => _levelsExpanded = !_levelsExpanded),
                          ),
                          if (_levelsExpanded) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: _WaterLevelBar(),
                            ),
                            const SizedBox(height: 4),
                          ],

                          // ── Rivers ─────────────────────────────────────
                          if (widget.showRivers) ...[
                            _LegendDivider(),
                            _SectionHeader(
                              label: 'Rivers',
                              expanded: _riversExpanded,
                              onTap: () => setState(() => _riversExpanded = !_riversExpanded),
                            ),
                            if (_riversExpanded)
                              for (final r in _biharRivers)
                                _RiverRow(name: r.name, color: r.color),
                          ],

                          // ── District Shading ───────────────────────────
                          if (widget.showDistricts) ...[
                            _LegendDivider(),
                            _SectionHeader(
                              label: 'District Fill',
                              expanded: _districtExpanded,
                              onTap: () => setState(() => _districtExpanded = !_districtExpanded),
                            ),
                            if (_districtExpanded) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: _DistrictShadingBar(),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ],
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _LegendDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 0.5, color: Colors.white.withValues(alpha: 0.08),
          indent: 10, endIndent: 10);
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  const _SectionHeader({required this.label, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 2),
      child: Row(children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8.5,
            fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        const Spacer(),
        Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: const Color(0xFF94A3B8), size: 12),
      ]),
    ),
  );
}

class _AlertLevelRow extends StatelessWidget {
  final AlertLevel level;
  const _AlertLevelRow({required this.level});

  @override
  Widget build(BuildContext context) {
    final col = _alertLevelColor(level);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 0),
      child: Row(children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: col,
                boxShadow: [BoxShadow(color: col.withValues(alpha: 0.50), blurRadius: 4)])),
        const SizedBox(width: 6),
        Icon(_alertLevelIcon(level), color: col, size: 9),
        const SizedBox(width: 4),
        Expanded(child: Text(level.label,
            style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w700))),
        Text(_alertLevelHindi(level),
            style: TextStyle(color: col.withValues(alpha: 0.60), fontSize: 8)),
      ]),
    );
  }
}

class _WaterLevelBar extends StatelessWidget {
  const _WaterLevelBar();

  static const _zones = [
    (Color(0xFF10E88A), 'Normal'),
    (Color(0xFF00C6FF), 'Watch'),
    (Color(0xFFFFA520), 'Warning'),
    (Color(0xFFFF5500), 'Danger'),
    (Color(0xFFFF1A44), 'Extreme'),
  ];

  static const _labels = ['90%W', 'W', 'D', '115%D'];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Segmented colour bar
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: _zones.map((z) => Expanded(
            child: Container(height: 8, color: z.$1),
          )).toList(),
        ),
      ),
      const SizedBox(height: 2),
      // Threshold tick labels
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _labels.map((l) => Text(l,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 7))).toList(),
      ),
      const SizedBox(height: 3),
      // Colour name row
      Row(
        children: _zones.map((z) => Expanded(
          child: Text(z.$2,
              style: TextStyle(color: z.$1, fontSize: 7, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        )).toList(),
      ),
    ]);
  }
}

class _RiverRow extends StatelessWidget {
  final String name;
  final Color  color;
  const _RiverRow({required this.name, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 3, 10, 0),
    child: Row(children: [
      SizedBox(width: 22, height: 10,
          child: CustomPaint(painter: _LinePainter(color: color))),
      const SizedBox(width: 6),
      Text(name, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _LinePainter extends CustomPainter {
  final Color color;
  const _LinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()
        ..color       = color
        ..strokeWidth = 3
        ..strokeCap   = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.color != color;
}

class _DistrictShadingBar extends StatelessWidget {
  const _DistrictShadingBar();

  static const _sevColors = [
    Color(0xFF10E88A), Color(0xFF00C6FF),
    Color(0xFFFFA520), Color(0xFFFF5500), Color(0xFFFF1A44),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _sevColors
                  .map((c) => c.withValues(alpha: 0.70))
                  .toList(),
            ),
          ),
          child: const SizedBox(height: 8, width: double.infinity),
        ),
      ),
      const SizedBox(height: 3),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Low risk',  style: TextStyle(color: Color(0xFF10E88A), fontSize: 7.5)),
        const Text('High risk', style: TextStyle(color: Color(0xFFFF1A44), fontSize: 7.5)),
      ]),
      const SizedBox(height: 3),
      Wrap(
        spacing: 4, runSpacing: 2,
        children: _sevColors.map((c) => Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: 0.70)),
        )).toList(),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet stat chip
// ─────────────────────────────────────────────────────────────────────────────

class _SheetStat extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _SheetStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: t.textSecondary, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value,  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini level bar
// ─────────────────────────────────────────────────────────────────────────────

class _MiniLevelBar extends StatelessWidget {
  final double current;
  final double warning;
  final double danger;
  final Color  color;
  const _MiniLevelBar({required this.current, required this.warning,
    required this.danger, required this.color});

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final maxVal = math.max(danger * 1.1, current * 1.05);
    if (maxVal <= 0) return const SizedBox.shrink();

    final wPct = (warning / maxVal).clamp(0.0, 1.0);
    final dPct = (danger  / maxVal).clamp(0.0, 1.0);
    final cPct = (current / maxVal).clamp(0.0, 1.0);

    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Container(
          height: 10,
          color: t.cardBgElevated,
          child: Row(children: [
            Flexible(flex: (cPct * 100).round(), child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.40), color])))),
            Flexible(flex: ((1 - cPct) * 100).round(), child: const SizedBox.shrink()),
          ]),
        ),
      ),
      // Warning tick
      Positioned(left: wPct * (MediaQuery.of(context).size.width - 64),
        top: 0, bottom: 0,
        child: Container(width: 1.5, color: AppPalette.warning)),
      // Danger tick
      Positioned(left: dPct * (MediaQuery.of(context).size.width - 64),
        top: 0, bottom: 0,
        child: Container(width: 1.5, color: AppPalette.danger)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass card / back button
// ─────────────────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.cardBg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke.withValues(alpha: 0.60), width: 0.8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 12)],
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
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: t.cardBg.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.stroke.withValues(alpha: 0.60), width: 0.8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 8)],
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded, color: t.textPrimary, size: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer toggle button
// ─────────────────────────────────────────────────────────────────────────────

class _LayerToggle extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  final VoidCallback onTap;
  const _LayerToggle({required this.icon, required this.label,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final color = active ? t.accent : t.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? t.accent.withValues(alpha: 0.15)
              : t.cardBg.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? t.accent.withValues(alpha: 0.50) : t.stroke.withValues(alpha: 0.60),
              width: 0.8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
