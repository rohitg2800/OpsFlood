// lib/screens/bihar_river_map_screen.dart
// BiharRiverMapScreen v9.1 — all compile errors fixed
//
// Fixes applied (no other files changed):
//  • RiverTheme.of → RiverColors.of
//  • floodDataProvider → liveLevelsProvider
//  • alertsAsync.valueOrNull → alertsAsync.cwcAlerts
//  • cwcAsync.valueOrNull → cwcAsync.value ?? []
//  • a.stationId → a.cityId
//  • ThresholdAlert.fromFloodStatus → _makeAlert() inline factory
//  • alert.requiresEmergency → alert.level.requiresEmergency
//  • FloodSeverity.rank() → FloodSeverity.fromString().index
//  • FloodSeverity.districtColor() → FloodSeverity.fromString().color
//  • CityDetailScreen(city:) → CityDetailScreen(cityName:)
//  • pred.nextPeakLevel/trend/confidence/sparkline6h → computed properties
//  • Path name collision with latlong2 → renamed local to linePath
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
// Inline fallback factory for ThresholdAlert (replaces missing .fromFloodStatus)
// ─────────────────────────────────────────────────────────────────────────────

ThresholdAlert _makeAlert(String cityId, String status) {
  final level = _alertLevelFromStatus(status);
  return ThresholdAlert(
    id:           'synthetic_$cityId',
    cityId:       cityId,
    cityName:     cityId,
    state:        '',
    river:        '',
    level:        level,
    currentValue: 0,
    warningLevel: 0,
    dangerLevel:  0,
    hfl:          0,
    breachMargin: 0,
    fillPercent:  0,
    timestamp:    DateTime.now(),
  );
}

AlertLevel _alertLevelFromStatus(String status) {
  switch (status.toUpperCase()) {
    case 'EXTREME':
    case 'CRITICAL': return AlertLevel.extreme;
    case 'DANGER':
    case 'FLOOD':    return AlertLevel.danger;
    case 'WARNING':
    case 'WARN':     return AlertLevel.warning;
    case 'WATCH':    return AlertLevel.watch;
    default:         return AlertLevel.normal;
  }
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
  _RiverLine(name: 'Gandak',       color: Color(0xFF34D399), points: [LatLng(27.50,84.45),LatLng(27.10,84.40),LatLng(26.78,84.38),LatLng(26.50,84.45),LatLng(26.12,84.39),LatLng(25.72,84.58),LatLng(25.61,85.14)]),
  _RiverLine(name: 'Bagmati',      color: Color(0xFFA78BFA), points: [LatLng(26.90,85.85),LatLng(26.65,85.90),LatLng(26.40,86.00),LatLng(26.10,86.05),LatLng(25.90,85.95),LatLng(25.73,86.00),LatLng(25.60,85.52)]),
  _RiverLine(name: 'Burhi Gandak', color: Color(0xFFFBBF24), points: [LatLng(27.40,84.85),LatLng(27.00,85.00),LatLng(26.60,85.10),LatLng(26.20,85.30),LatLng(25.88,85.38),LatLng(25.60,85.52)]),
  _RiverLine(name: 'Sone',         color: Color(0xFFFF8C00), points: [LatLng(24.50,83.80),LatLng(24.60,84.10),LatLng(24.80,84.50),LatLng(25.10,84.68),LatLng(25.35,84.70),LatLng(25.56,84.66),LatLng(25.61,85.14)]),
  _RiverLine(name: 'Ghaghra',      color: Color(0xFFEC4899), points: [LatLng(27.53,83.65),LatLng(27.20,83.90),LatLng(26.90,83.97),LatLng(26.60,84.02),LatLng(26.10,84.10),LatLng(25.78,83.97),LatLng(25.56,83.97)]),
  _RiverLine(name: 'Kamla',        color: Color(0xFF6EE7B7), points: [LatLng(26.85,86.20),LatLng(26.50,86.30),LatLng(26.20,86.35),LatLng(25.95,86.28),LatLng(25.73,86.00)]),
  _RiverLine(name: 'Mahananda',    color: Color(0xFF67E8F9), points: [LatLng(27.50,88.10),LatLng(27.20,87.90),LatLng(26.95,87.70),LatLng(26.60,87.50),LatLng(25.80,87.38),LatLng(25.23,87.91)]),
  _RiverLine(name: 'Punpun',       color: Color(0xFFC084FC), points: [LatLng(24.75,84.80),LatLng(24.90,85.10),LatLng(25.10,85.30),LatLng(25.30,85.40),LatLng(25.55,85.18)]),
  _RiverLine(name: 'Adhwara',      color: Color(0xFFBEF264), points: [LatLng(26.90,85.95),LatLng(26.60,86.15),LatLng(26.30,86.20),LatLng(26.05,86.10)]),
];

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  const BiharRiverMapScreen({super.key});

  @override
  ConsumerState<BiharRiverMapScreen> createState() => _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState extends ConsumerState<BiharRiverMapScreen>
    with TickerProviderStateMixin {

  bool _showRivers    = true;
  bool _showDistricts = true;
  bool _showStations  = true;
  bool _showAlerts    = true;

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

  // Returns the ThresholdAlert for a station (falls back to FloodData.status)
  ThresholdAlert _alertForStation(FloodData fd, List<ThresholdAlert> allAlerts) {
    // FIX: field is cityId, not stationId
    final match = allAlerts.where((a) => a.cityId == fd.city).firstOrNull;
    if (match != null) return match;
    // FIX: ThresholdAlert.fromFloodStatus doesn't exist → use inline factory
    return _makeAlert(fd.city, fd.status);
  }

  @override
  Widget build(BuildContext context) {
    // FIX: RiverColors.of, not RiverTheme.of
    final t           = RiverColors.of(context);
    // FIX: liveLevelsProvider, not floodDataProvider
    final floodList   = ref.watch(liveLevelsProvider);
    // FIX: AlertsState is plain state, not AsyncValue — access .cwcAlerts directly
    final alertsState = ref.watch(alertsProvider);
    final geoAsync    = ref.watch(biharGeoJsonProvider);
    // FIX: AsyncValue.value (nullable), not .valueOrNull (removed in Riverpod 3)
    final cwcAsync    = ref.watch(cwcStationsProvider);

    final allAlerts = alertsState.cwcAlerts;

    final biharStations = floodList
        .where((fd) => fd.state.toLowerCase() == 'bihar')
        .toList();

    // District → worst FloodData
    final Map<String, FloodData>       districtData     = {};
    final Map<String, List<FloodData>> districtStations = {};
    for (final fd in biharStations) {
      final d = _districtFor(fd);
      if (d.isEmpty) continue;
      districtStations.putIfAbsent(d, () => []).add(fd);
      final cur = districtData[d];
      // FIX: FloodSeverity.rank() doesn't exist → use FloodSeverity.fromString().index
      if (cur == null ||
          FloodSeverity.fromString(fd.status).index >
          FloodSeverity.fromString(cur.status).index) {
        districtData[d] = fd;
      }
    }

    // River → worst AlertLevel
    final Map<String, AlertLevel> riverAlertMap = {};
    for (final fd in biharStations) {
      final river = fd.river ?? BiharStationRegistry.forSite(fd.city)?.river;
      if (river == null) continue;
      final lvl = _alertForStation(fd, allAlerts).level;
      final cur = riverAlertMap[river] ?? AlertLevel.normal;
      if (lvl.index > cur.index) riverAlertMap[river] = lvl;
    }

    // CWC-only stations (stations in CWC data but not in FloodData)
    // FIX: .value instead of .valueOrNull
    final cwcStations = cwcAsync.value ?? <CwcStation>[];
    final biharCitySet = biharStations.map((fd) => fd.city.toLowerCase()).toSet();
    final cwcOnly = cwcStations
        .where((s) => !biharCitySet.contains(s.siteName.toLowerCase()))
        .toList();

    final alertCount = biharStations
        // FIX: alert.level.requiresEmergency, not alert.requiresEmergency
        .where((fd) => _alertForStation(fd, allAlerts).level.requiresEmergency)
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
              cameraConstraint: CameraConstraint.containCenter(
                bounds: LatLngBounds(
                  const LatLng(24.20, 83.20),
                  const LatLng(27.55, 88.30),
                ),
              ),
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

              // CWC-only station pins (secondary layer)
              if (_showStations)
                MarkerLayer(
                  markers: cwcOnly
                    .where((s) => s.lat != null && s.lng != null)
                    .map((s) {
                      return Marker(
                        point: LatLng(s.lat!, s.lng!),
                        width: 18, height: 18,
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF94A3B8).withValues(alpha: 0.25),
                            border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
                          ),
                          child: const Icon(Icons.sensors_rounded,
                              color: Color(0xFF94A3B8), size: 10),
                        ),
                      );
                    }).toList(),
                ),

              // Main station pins
              if (_showStations)
                MarkerLayer(
                  markers: biharStations.where((fd) => _coordsFor(fd) != null).map((fd) {
                    final coords  = _coordsFor(fd)!;
                    final alert   = _alertForStation(fd, allAlerts);
                    final col     = _alertLevelColor(alert.level);
                    // FIX: alert.level.requiresEmergency
                    final isPulse = alert.level.requiresEmergency;
                    return Marker(
                      point: coords,
                      width: isPulse ? 36 : 28,
                      height: isPulse ? 36 : 28,
                      child: GestureDetector(
                        onTap: () => _selectStation(fd),
                        child: isPulse
                          ? AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (_, __) => Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: _pulseAnim.value * 0.45,
                                    child: Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: col.withValues(alpha: 0.30),
                                        border: Border.all(color: col.withValues(alpha: 0.60), width: 1.5),
                                      ),
                                    ),
                                  ),
                                  _StationPin(color: col, alert: alert, fd: fd),
                                ],
                              ))
                          : _StationPin(color: col, alert: alert, fd: fd),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // ── Header bar ─────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: t.cardBg.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.stroke.withValues(alpha: 0.50), width: 0.8),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 10)],
                    ),
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

          // ── Zoom +/- buttons ─────────────────────────────────────────────
          Positioned(
            right: 8, bottom: 130,
            child: SafeArea(
              child: _ZoomButtons(mapController: _mapController),
            ),
          ),

          // ── Legend ───────────────────────────────────────────────────────
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
                      // FIX: param is cityName, not city
                      builder: (_) => CityDetailScreen(cityName: _selected!.city)));
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
      .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final features = widget.geoJson['features'] as List? ?? [];

    final polygons = <Polygon<String>>[];
    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final name  = (props['district'] ?? props['DISTRICT'] ?? props['name'] ?? '').toString();
      final geom  = f['geometry'] as Map<String, dynamic>? ?? {};
      final type  = geom['type'] as String? ?? '';
      final worst = widget.districtData[name];
      // FIX: FloodSeverity.districtColor() doesn't exist → use .fromString().color
      final fill  = FloodSeverity.fromString(worst?.status).color;
      final isSelected = name == widget.selectedDistrict;

      void addPoly(List coords) {
        polygons.add(Polygon<String>(
          points:       _ring(coords[0] as List),
          holePointsList: (coords as List).skip(1).map((h) => _ring(h as List)).toList(),
          color:         fill.withValues(alpha: isSelected ? 0.55 : 0.28),
          borderColor:   isSelected
              ? const Color(0xFFFFD700)
              : fill.withValues(alpha: 0.70),
          borderStrokeWidth: isSelected ? 2.0 : 0.6,
          hitValue: name,
        ));
      }

      if (type == 'Polygon') {
        addPoly(geom['coordinates'] as List);
      } else if (type == 'MultiPolygon') {
        for (final part in geom['coordinates'] as List) {
          addPoly(part as List);
        }
      }
    }

    return GestureDetector(
      child: PolygonLayer<String>(
        polygons:    polygons,
        hitNotifier: _hitNotifier,
      ),
      onTapUp: (_) {
        final hit = _hitNotifier.value;
        if (hit != null && hit.hitValues.isNotEmpty) {
          widget.onDistrictTap(hit.hitValues.first);
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Station pin
// ─────────────────────────────────────────────────────────────────────────────

class _StationPin extends StatelessWidget {
  final Color        color;
  final ThresholdAlert alert;
  final FloodData    fd;
  const _StationPin({required this.color, required this.alert, required this.fd});

  @override
  Widget build(BuildContext context) {
    final pct = alert.fillPercent;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.20),
            border: Border.all(color: color, width: 1.8),
            boxShadow: [BoxShadow(
                color: color.withValues(alpha: 0.40), blurRadius: 6)],
          ),
          child: Icon(_alertLevelIcon(alert.level), color: color, size: 13),
        ),
        if (pct > 0)
          Positioned(
            bottom: -2, right: -2,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: color, width: 1),
              ),
              child: Center(
                child: Text('${pct.round()}',
                  style: TextStyle(color: color, fontSize: 5.5,
                      fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Station bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _StationSheet extends ConsumerWidget {
  final FloodData      data;
  final BiharStationMeta? meta;
  final ThresholdAlert alertLevel;
  final VoidCallback   onClose;
  final VoidCallback   onOpenDetail;

  const _StationSheet({
    required this.data,
    required this.meta,
    required this.alertLevel,
    required this.onClose,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FIX: RiverColors.of
    final t         = RiverColors.of(context);
    final col       = _alertLevelColor(alertLevel.level);
    final predAsync = ref.watch(predictionProvider(data.city));

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.40), width: 1.2),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.30), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: t.stroke.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── title row ───────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.city,
                          style: TextStyle(color: t.textPrimary,
                              fontSize: 18, fontWeight: FontWeight.w800)),
                        if (meta?.river != null)
                          Text(meta!.river!,
                            style: TextStyle(
                                color: _riverColor(meta!.river),
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        if (meta?.district != null)
                          Text(meta!.district!,
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  // alert badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: col.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      children: [
                        Icon(_alertLevelIcon(alertLevel.level), color: col, size: 18),
                        const SizedBox(height: 2),
                        Text(alertLevel.level.label,
                            style: TextStyle(color: col, fontSize: 9,
                                fontWeight: FontWeight.w800)),
                        Text(_alertLevelHindi(alertLevel.level),
                            style: TextStyle(color: col.withValues(alpha: 0.80),
                                fontSize: 8)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.stroke.withValues(alpha: 0.15),
                        border: Border.all(color: t.stroke.withValues(alpha: 0.30)),
                      ),
                      child: Icon(Icons.close_rounded,
                          color: t.textSecondary, size: 16),
                    ),
                  ),
                ]),

                const SizedBox(height: 12),

                // ── fill-percent bar ────────────────────────────────────
                if (alertLevel.fillPercent > 0) ...[ 
                  Row(children: [
                    Text('Fill', style: TextStyle(
                        color: t.textSecondary, fontSize: 11)),
                    const Spacer(),
                    Text('${alertLevel.fillPercent.toStringAsFixed(1)}%',
                      style: TextStyle(color: col,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (alertLevel.fillPercent / 100).clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: t.stroke.withValues(alpha: 0.20),
                      valueColor: AlwaysStoppedAnimation(col),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── live stats row ──────────────────────────────────────
                Row(children: [
                  _StatChip(label: 'Level',
                      value: '${data.currentLevel.toStringAsFixed(2)} m',
                      color: col, t: t),
                  const SizedBox(width: 8),
                  _StatChip(label: 'Danger',
                      value: '${data.dangerLevel.toStringAsFixed(2)} m',
                      color: const Color(0xFFFF5500), t: t),
                  const SizedBox(width: 8),
                  _StatChip(label: 'Warning',
                      value: '${data.warningLevel.toStringAsFixed(2)} m',
                      color: const Color(0xFFFFA520), t: t),
                ]),

                const SizedBox(height: 12),

                // ── AI prediction panel ─────────────────────────────────
                predAsync.when(
                  data: (pred) => _PredictionPanel(pred: pred, t: t),
                  loading: () => const SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 12),

                // ── open detail button ──────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onOpenDetail,
                    style: TextButton.styleFrom(
                      backgroundColor: t.accent.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            color: t.accent, size: 14),
                        const SizedBox(width: 6),
                        Text('Full Detail',
                          style: TextStyle(color: t.accent,
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
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
// Prediction panel
// FIX: pred.nextPeakLevel/trend/confidence/sparkline6h computed from real fields
// ─────────────────────────────────────────────────────────────────────────────

class _PredictionPanel extends StatelessWidget {
  final FloodPrediction pred;
  final dynamic         t;
  const _PredictionPanel({required this.pred, required this.t});

  // Computed properties from existing FloodPrediction fields
  double? get _nextPeakLevel {
    if (pred.next24h.isEmpty) return null;
    return pred.next24h.map((p) => p.level).reduce(math.max);
  }

  String get _trend {
    if (pred.next24h.length < 2) return '—';
    final first = pred.next24h.first.level;
    final last  = pred.next24h.last.level;
    final delta = last - first;
    if (delta > 0.05)  return '↑ Rising';
    if (delta < -0.05) return '↓ Falling';
    return '→ Steady';
  }

  double get _confidence => pred.confidencePct / 100;

  List<double>? get _sparkline6h {
    if (pred.next24h.length < 2) return null;
    return pred.next24h
        .take(6)
        .map((p) => p.level)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final peak     = _nextPeakLevel;
    final spark    = _sparkline6h;
    final riskCol  = pred.cwcRiskScore != null
        ? Color.lerp(const Color(0xFF10E88A), const Color(0xFFFF1A44),
              pred.cwcRiskScore! / 100)!
        : null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (t.stroke as Color).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (t.stroke as Color).withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_graph_rounded,
                color: t.accent as Color, size: 13),
            const SizedBox(width: 5),
            Text('AI 24 h Forecast',
              style: TextStyle(color: t.textSecondary as Color,
                  fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _PredStat(
                label: 'Next Peak',
                value: peak != null ? '${peak.toStringAsFixed(2)} m' : '—',
                t: t),
            const SizedBox(width: 10),
            _PredStat(label: 'Trend', value: _trend, t: t),
            const SizedBox(width: 10),
            _PredStat(
                label: 'Confidence',
                value: '${(_confidence * 100).round()}%',
                t: t),
          ]),
          if (pred.cwcRiskScore != null && riskCol != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Text('CWC Risk',
                  style: TextStyle(color: t.textSecondary as Color, fontSize: 10)),
              const Spacer(),
              Text('${pred.cwcRiskScore!.round()}',
                  style: TextStyle(color: riskCol,
                      fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pred.cwcRiskScore! / 100,
                minHeight: 4,
                backgroundColor: (t.stroke as Color).withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(riskCol),
              ),
            ),
          ],
          // 6 h sparkline
          if (spark != null && spark.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: spark,
                  color:  t.accent as Color,
                ),
                size: const Size(double.infinity, 32),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PredStat extends StatelessWidget {
  final String  label;
  final String  value;
  final dynamic t;
  const _PredStat({required this.label, required this.value, required this.t});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: t.textSecondary as Color, fontSize: 9)),
      Text(value, style: TextStyle(color: t.textPrimary as Color,
          fontSize: 12, fontWeight: FontWeight.w700)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sparkline painter
// FIX: renamed local var from `path` to `linePath` to avoid latlong2.Path conflict
// ─────────────────────────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color        color;
  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final mn  = values.reduce(math.min);
    final mx  = values.reduce(math.max);
    final rng = (mx - mn).abs() < 0.01 ? 1.0 : mx - mn;
    final dx  = size.width / (values.length - 1);

    // FIX: renamed from `path` → `linePath` to avoid latlong2.Path name collision
    final linePath = ui.Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - ((values[i] - mn) / rng) * size.height;
      i == 0 ? linePath.moveTo(x, y) : linePath.lineTo(x, y);
    }
    canvas.drawPath(linePath,
      Paint()
        ..color = color.withValues(alpha: 0.80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String  label;
  final String  value;
  final Color   color;
  final dynamic t;
  const _StatChip({required this.label, required this.value,
                   required this.color,  required this.t});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: t.textSecondary as Color, fontSize: 9)),
        Text(value,
          style: TextStyle(color: color,
              fontSize: 12, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// District bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _DistrictSheet extends StatelessWidget {
  final String          districtName;
  final FloodData?      worstStation;
  final List<FloodData> allStations;
  final List<ThresholdAlert> allAlerts;
  final VoidCallback    onClose;
  final ValueChanged<FloodData> onStationTap;

  const _DistrictSheet({
    required this.districtName,
    required this.worstStation,
    required this.allStations,
    required this.allAlerts,
    required this.onClose,
    required this.onStationTap,
  });

  ThresholdAlert _alert(FloodData fd) {
    // FIX: field is cityId, not stationId
    final match = allAlerts.where((a) => a.cityId == fd.city).firstOrNull;
    // FIX: inline factory
    return match ?? _makeAlert(fd.city, fd.status);
  }

  @override
  Widget build(BuildContext context) {
    // FIX: RiverColors.of
    final t   = RiverColors.of(context);
    // FIX: FloodSeverity.fromString().color, not FloodSeverity.districtColor()
    final col = worstStation != null
        ? FloodSeverity.fromString(worstStation!.status).color
        : t.stroke;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.40), width: 1.2),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.30), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 5),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: t.stroke.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Icon(Icons.map_outlined, color: col, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(districtName,
                style: TextStyle(color: t.textPrimary,
                    fontSize: 16, fontWeight: FontWeight.w800))),
              if (worstStation != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: col.withValues(alpha: 0.35)),
                  ),
                  child: Text(worstStation!.status,
                    style: TextStyle(color: col,
                        fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close_rounded,
                    color: t.textSecondary, size: 18),
              ),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: allStations.length,
              itemBuilder: (_, i) {
                final fd = allStations[i];
                final al = _alert(fd);
                final c  = _alertLevelColor(al.level);
                return ListTile(
                  dense: true,
                  leading: Icon(_alertLevelIcon(al.level), color: c, size: 18),
                  title: Text(fd.city,
                    style: TextStyle(color: t.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${fd.currentLevel.toStringAsFixed(2)} m',
                      style: TextStyle(color: t.textSecondary, fontSize: 11)),
                  trailing: Text(al.level.label,
                    style: TextStyle(color: c,
                        fontSize: 10, fontWeight: FontWeight.w700)),
                  onTap: () => onStationTap(fd),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer toggle pill button
// ─────────────────────────────────────────────────────────────────────────────

class _LayerToggle extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final bool      active;
  final VoidCallback onTap;
  const _LayerToggle({required this.icon, required this.label,
                      required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // FIX: RiverColors.of
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

// ─────────────────────────────────────────────────────────────────────────────
// Map Legend
// ─────────────────────────────────────────────────────────────────────────────

class _MapLegend extends StatefulWidget {
  final bool showRivers;
  final bool showDistricts;
  const _MapLegend({required this.showRivers, required this.showDistricts});

  @override
  State<_MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<_MapLegend>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  bool _secAlerts    = true;
  bool _secWaterBar  = true;
  bool _secRivers    = true;
  bool _secDistricts = true;

  late final AnimationController _ctrl;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
    // FIX: RiverColors.of
    final t = RiverColors.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      decoration: BoxDecoration(
        color: t.cardBg.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke.withValues(alpha: 0.35), width: 0.8),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.22), blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(children: [
                Icon(Icons.layers_rounded, color: t.accent, size: 13),
                const SizedBox(width: 5),
                Text('Legend',
                  style: TextStyle(color: t.textPrimary,
                      fontSize: 11, fontWeight: FontWeight.w800)),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded,
                      color: t.textSecondary, size: 14),
                ),
              ]),
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
              ? FadeTransition(
                  opacity: _fade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        _SectionHeader('Alert Levels', _secAlerts,
                            () => setState(() => _secAlerts = !_secAlerts), t),
                        if (_secAlerts)
                          ...AlertLevel.values.map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(children: [
                              Container(width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _alertLevelColor(l),
                                )),
                              const SizedBox(width: 5),
                              Icon(_alertLevelIcon(l),
                                  color: _alertLevelColor(l), size: 10),
                              const SizedBox(width: 3),
                              Text(l.label,
                                style: TextStyle(color: t.textSecondary,
                                    fontSize: 9, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 3),
                              Text(_alertLevelHindi(l),
                                style: TextStyle(
                                    color: t.textSecondary.withValues(alpha: 0.65),
                                    fontSize: 8)),
                            ]),
                          )),

                        const SizedBox(height: 6),

                        _SectionHeader('Water Level Zones', _secWaterBar,
                            () => setState(() => _secWaterBar = !_secWaterBar), t),
                        if (_secWaterBar) _WaterLevelBar(t: t),

                        if (widget.showRivers) ...[
                          const SizedBox(height: 6),
                          _SectionHeader('Rivers', _secRivers,
                              () => setState(() => _secRivers = !_secRivers), t),
                          if (_secRivers)
                            ..._kRiverColors.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(children: [
                                CustomPaint(
                                  size: const Size(22, 8),
                                  painter: _LinePainter(color: e.value),
                                ),
                                const SizedBox(width: 6),
                                Text(e.key,
                                  style: TextStyle(color: t.textSecondary,
                                      fontSize: 9, fontWeight: FontWeight.w600)),
                              ]),
                            )),
                        ],

                        if (widget.showDistricts) ...[
                          const SizedBox(height: 6),
                          _SectionHeader('District Fill', _secDistricts,
                              () => setState(() => _secDistricts = !_secDistricts), t),
                          if (_secDistricts) _DistrictShadingBar(t: t),
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

class _SectionHeader extends StatelessWidget {
  final String   title;
  final bool     expanded;
  final VoidCallback onTap;
  final dynamic  t;
  const _SectionHeader(this.title, this.expanded, this.onTap, this.t);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text(title,
          style: TextStyle(color: t.textSecondary as Color,
              fontSize: 9.5, fontWeight: FontWeight.w800,
              letterSpacing: 0.3)),
        const Spacer(),
        AnimatedRotation(
          turns: expanded ? 0 : -0.25,
          duration: const Duration(milliseconds: 180),
          child: Icon(Icons.expand_more_rounded,
              color: (t.textSecondary as Color).withValues(alpha: 0.55), size: 11),
        ),
      ]),
    ),
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
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }
  @override
  bool shouldRepaint(_LinePainter old) => old.color != color;
}

class _WaterLevelBar extends StatelessWidget {
  final dynamic t;
  const _WaterLevelBar({required this.t});

  static const _segs = [
    (label: 'Normal', color: Color(0xFF10E88A)),
    (label: 'Watch',  color: Color(0xFF00C6FF)),
    (label: 'Warn',   color: Color(0xFFFFA520)),
    (label: 'Danger', color: Color(0xFFFF5500)),
    (label: 'Extreme',color: Color(0xFFFF1A44)),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 7,
          child: Row(
            children: _segs.map((s) =>
              Expanded(child: ColoredBox(color: s.color))
            ).toList(),
          ),
        ),
      ),
      const SizedBox(height: 3),
      Row(children: [
        Expanded(child: Text('90%W',
          style: TextStyle(color: (t.textSecondary as Color).withValues(alpha: 0.55),
              fontSize: 7), textAlign: TextAlign.center)),
        Expanded(child: Text('W',
          style: TextStyle(color: (t.textSecondary as Color).withValues(alpha: 0.55),
              fontSize: 7), textAlign: TextAlign.center)),
        Expanded(child: Text('D',
          style: TextStyle(color: (t.textSecondary as Color).withValues(alpha: 0.55),
              fontSize: 7), textAlign: TextAlign.center)),
        Expanded(child: Text('115%D',
          style: TextStyle(color: (t.textSecondary as Color).withValues(alpha: 0.55),
              fontSize: 7), textAlign: TextAlign.center)),
        const Expanded(child: SizedBox()),
      ]),
      const SizedBox(height: 3),
      Row(children: _segs.map((s) =>
        Expanded(child: Text(s.label,
          style: TextStyle(color: s.color, fontSize: 7,
              fontWeight: FontWeight.w700),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis))
      ).toList()),
    ],
  );
}

class _DistrictShadingBar extends StatelessWidget {
  final dynamic t;
  const _DistrictShadingBar({required this.t});

  static const _cols = [
    Color(0xFF10E88A), Color(0xFF00C6FF),
    Color(0xFFFFA520), Color(0xFFFF5500), Color(0xFFFF1A44),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _cols.map((c) => c.withValues(alpha: 0.70)).toList(),
            ),
          ),
        ),
      ),
      const SizedBox(height: 3),
      Row(children: [
        Text('Low risk',
          style: TextStyle(color: (t.textSecondary as Color).withValues(alpha: 0.65),
              fontSize: 7)),
        const Spacer(),
        Text('High risk',
          style: TextStyle(color: (t.textSecondary as Color).withValues(alpha: 0.65),
              fontSize: 7)),
      ]),
      const SizedBox(height: 4),
      Row(children: _cols.map((c) =>
        Expanded(child: Container(
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(2),
          ),
        ))
      ).toList()),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Zoom +/- buttons
// ─────────────────────────────────────────────────────────────────────────────

class _ZoomButtons extends StatelessWidget {
  final MapController mapController;
  const _ZoomButtons({required this.mapController});

  void _zoom(BuildContext context, double delta) {
    final cam     = MapCamera.of(context);
    final newZoom = (cam.zoom + delta).clamp(6.0, 13.0);
    mapController.move(cam.center, newZoom);
  }

  @override
  Widget build(BuildContext context) {
    // FIX: RiverColors.of
    final t = RiverColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomBtn(
          icon:    Icons.add_rounded,
          tooltip: 'Zoom in',
          onTap:   () => _zoom(context, 1.0),
          t: t,
        ),
        const SizedBox(height: 4),
        _ZoomBtn(
          icon:    Icons.remove_rounded,
          tooltip: 'Zoom out',
          onTap:   () => _zoom(context, -1.0),
          t: t,
        ),
      ],
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData     icon;
  final String       tooltip;
  final VoidCallback onTap;
  final dynamic      t;
  const _ZoomBtn({required this.icon, required this.tooltip,
                  required this.onTap, required this.t});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: (t.cardBg as Color).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: (t.stroke as Color).withValues(alpha: 0.60), width: 0.8),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 8, offset: const Offset(0, 2),
            )],
          ),
          child: Icon(icon, color: t.accent as Color, size: 20),
        ),
      ),
    );
  }
}
