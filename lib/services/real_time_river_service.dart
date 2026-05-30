// lib/services/real_time_river_service.dart
//
// OpsFlood — RealTimeRiverService v4.1
//
// Exposes both:
//   • RiverStation    — raw model from /api/stations (stream-based providers)
//   • LiveRiverResult — compat wrapper for river_monitor_screen /
//                       india_rivers_screen  (fetchAll / fetchCity API)
//
// Key change in v4.1: CwcStation.lastUpdated is now String? (ISO-8601) so
// the _shortTime(s.lastUpdated!) calls in both screens compile without error.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/river_station.dart' show DangerClass;

// ─────────────────────────────────────────────────────────────────────────────
// RiverStation  (used by stream-based providers)
// ─────────────────────────────────────────────────────────────────────────────
class RiverStation {
  final String id;
  final String name;
  final String city;
  final String river;
  final String district;
  final String state;
  final double lat;
  final double lon;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final double safeLevel;
  final String   status;      // 'normal' | 'warning' | 'danger'
  final String   trend;       // 'rising' | 'falling' | 'stable'
  final double   pctToDanger; // 0–100
  final String   riskLevel;   // 'LOW' | 'HIGH' | 'CRITICAL'
  final String   dataSource;  // 'WRD_BIHAR_LIVE' | 'WRD_BIHAR_SYNTHETIC' | 'SYNTHETIC'
  final DateTime lastUpdated;
  final double?  discharge;
  final double?  flowRate;

  const RiverStation({
    required this.id,
    required this.name,
    required this.city,
    required this.river,
    required this.district,
    required this.state,
    required this.lat,
    required this.lon,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.safeLevel,
    required this.status,
    required this.trend,
    required this.pctToDanger,
    required this.riskLevel,
    required this.dataSource,
    required this.lastUpdated,
    this.discharge,
    this.flowRate,
  });

  factory RiverStation.fromJson(Map<String, dynamic> j) {
    return RiverStation(
      id:           j['id']            as String? ?? '',
      name:         j['name']          as String? ?? '',
      city:         j['city']          as String? ?? j['name'] as String? ?? '',
      river:        j['river']         as String? ?? '',
      district:     j['district']      as String? ?? '',
      state:        j['state']         as String? ?? 'Bihar',
      lat:          (j['lat']          as num?)?.toDouble() ?? 0.0,
      lon:          (j['lon']          as num?)?.toDouble() ?? 0.0,
      currentLevel: (j['current_level'] as num?)?.toDouble() ?? 0.0,
      dangerLevel:  (j['danger_level']  as num?)?.toDouble() ?? 0.0,
      warningLevel: (j['warning_level'] as num?)?.toDouble() ?? 0.0,
      safeLevel:    (j['safe_level']    as num?)?.toDouble() ?? 0.0,
      status:       j['status']        as String? ?? 'normal',
      trend:        j['trend']         as String? ?? 'stable',
      pctToDanger:  (j['pct_to_danger'] as num?)?.toDouble() ?? 0.0,
      riskLevel:    j['risk_level']    as String? ?? 'LOW',
      dataSource:   j['data_source']   as String? ?? 'UNKNOWN',
      lastUpdated:  j['last_updated'] != null
          ? DateTime.tryParse(j['last_updated'] as String) ?? DateTime.now()
          : DateTime.now(),
      discharge:    (j['discharge']    as num?)?.toDouble(),
      flowRate:     (j['flow_rate']    as num?)?.toDouble(),
    );
  }

  bool get isBiharWrd => dataSource.startsWith('WRD_BIHAR');
  bool get isLive     => dataSource == 'WRD_BIHAR_LIVE';
  bool get isCritical => status == 'danger';
  bool get isWarning  => status == 'warning';
  bool get isNormal   => status == 'normal';

  double get levelRatio =>
      dangerLevel > 0 ? (currentLevel / dangerLevel).clamp(0.0, 1.5) : 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// CwcStation  — used inside LiveRiverResult
//
// lastUpdated is String? (raw ISO-8601 from API) so that _shortTime() in
// river_monitor_screen and india_rivers_screen can accept it directly.
// ─────────────────────────────────────────────────────────────────────────────
class CwcStation {
  final String  city;
  final String  river;
  final String  state;
  final double  current;           // current gauge height (m)
  final double  warning;           // warning level (m)
  final double  danger;            // danger level (m)
  final double  hfl;               // highest flood level (m)
  final String? trend;
  final String? liveStatus;
  final double? rainfallLastHour;
  final double? flowRate;
  final String? lastUpdated;       // ← String? (ISO-8601) — NOT DateTime

  const CwcStation({
    required this.city,
    required this.river,
    required this.state,
    required this.current,
    required this.warning,
    required this.danger,
    required this.hfl,
    this.trend,
    this.liveStatus,
    this.rainfallLastHour,
    this.flowRate,
    this.lastUpdated,
  });

  /// Fraction of HFL reached (0–1).
  double get progressPct => hfl > 0 ? (current / hfl).clamp(0.0, 1.0) : 0.0;

  /// Danger class derived from gauge levels.
  DangerClass get dangerClass {
    if (current <= 0)                      return DangerClass.normal;
    if (hfl > 0     && current >= hfl)     return DangerClass.extreme;
    if (danger > 0  && current >= danger)  return DangerClass.severe;
    if (warning > 0 && current >= warning) return DangerClass.aboveNormal;
    return DangerClass.normal;
  }

  /// Risk score 0–100 from CWC levels only.
  double get riskScore {
    if (hfl <= 0) return 0;
    if (warning > 0 && hfl > warning) {
      return ((current - warning) / (hfl - warning) * 100).clamp(0.0, 100.0);
    }
    return (current / hfl * 100).clamp(0.0, 100.0);
  }

  /// Parse lastUpdated string into DateTime (for stale-check logic, etc.).
  DateTime? get lastUpdatedDateTime =>
      lastUpdated != null ? DateTime.tryParse(lastUpdated!) : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveRiverResult  — expected by river_monitor_screen / india_rivers_screen
// ─────────────────────────────────────────────────────────────────────────────
class LiveRiverResult {
  final CwcStation station;
  final String     source;       // data-source label, 'NO_DATA' if unavailable
  final double     confidence;   // 0–1
  final bool       isStale;
  final String?    mlRiskLevel;  // 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL'
  final double?    mlFloodProb;  // 0–1

  const LiveRiverResult({
    required this.station,
    required this.source,
    this.confidence = 1.0,
    this.isStale    = false,
    this.mlRiskLevel,
    this.mlFloodProb,
  });

  factory LiveRiverResult.fromApiJson(Map<String, dynamic> j) {
    final currentLevel = (j['current_level']  as num?)?.toDouble() ?? 0.0;
    final dangerLevel  = (j['danger_level']   as num?)?.toDouble() ?? 0.0;
    final warningLevel = (j['warning_level']  as num?)?.toDouble() ?? 0.0;
    final hfl          = (j['hfl']            as num?)?.toDouble() ??
                         (j['high_flood_level'] as num?)?.toDouble() ??
                         dangerLevel * 1.15;

    final dataSource     = j['data_source'] as String? ?? 'UNKNOWN';
    final isNoData       = currentLevel <= 0 || dataSource == 'NO_DATA';
    final lastUpdatedStr = j['last_updated'] as String?; // kept as String

    // Stale if last update > 6 hours ago
    final lastUpdatedDt  = lastUpdatedStr != null
        ? DateTime.tryParse(lastUpdatedStr)
        : null;
    final isStale = lastUpdatedDt != null
        ? DateTime.now().difference(lastUpdatedDt).inHours > 6
        : false;

    // ML heuristic from pct_to_danger
    final pctToDanger = (j['pct_to_danger'] as num?)?.toDouble() ?? 0.0;
    final mlFloodProb = (pctToDanger / 100).clamp(0.0, 1.0);
    final mlRiskLevel = pctToDanger >= 90 ? 'CRITICAL'
                      : pctToDanger >= 70 ? 'SEVERE'
                      : pctToDanger >= 40 ? 'MODERATE'
                      : 'LOW';

    final station = CwcStation(
      city:       j['city']  as String? ?? j['name'] as String? ?? '',
      river:      j['river'] as String? ?? '',
      state:      j['state'] as String? ?? 'Bihar',
      current:    currentLevel,
      warning:    warningLevel,
      danger:     dangerLevel,
      hfl:        hfl,
      trend:      j['trend']  as String?,
      liveStatus: isNoData ? null : (j['status'] as String?),
      flowRate:   (j['flow_rate'] as num?)?.toDouble(),
      lastUpdated: lastUpdatedStr,   // ← String?, not DateTime
    );

    return LiveRiverResult(
      station:     station,
      source:      isNoData ? 'NO_DATA' : dataSource,
      confidence:  isNoData ? 0.0 : 0.9,
      isStale:     isStale,
      mlRiskLevel: mlRiskLevel,
      mlFloodProb: mlFloodProb,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RealTimeRiverService
// ─────────────────────────────────────────────────────────────────────────────
class RealTimeRiverService {
  static final RealTimeRiverService _instance = RealTimeRiverService._internal();
  factory RealTimeRiverService() => _instance;
  RealTimeRiverService._internal();

  final http.Client _client = http.Client();

  final _controller = StreamController<List<RiverStation>>.broadcast();
  Stream<List<RiverStation>> get stream => _controller.stream;

  Timer?             _timer;
  List<RiverStation> _lastStations = [];
  bool               _loading      = false;
  DateTime?          _lastFetch;
  String?            _lastError;

  Duration _pollInterval = AppConfig.realtimeInterval;

  List<RiverStation> get stations  => _lastStations;
  bool               get isLoading => _loading;
  DateTime?          get lastFetch => _lastFetch;
  String?            get lastError => _lastError;

  List<RiverStation> get biharStations    => _lastStations.where((s) => s.state == 'Bihar').toList();
  List<RiverStation> get criticalStations => _lastStations.where((s) => s.isCritical).toList();
  List<RiverStation> get warningStations  => _lastStations.where((s) => s.isWarning).toList();

  List<RiverStation> get alertStations =>
      _lastStations.where((s) => !s.isNormal).toList()
        ..sort((a, b) {
          const order = {'danger': 0, 'warning': 1, 'normal': 2};
          return (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
        });

  RiverStation? stationById(String id) =>
      _lastStations.where((s) => s.id == id).firstOrNull;

  RiverStation? stationByCity(String city) {
    final needle = city.trim().toLowerCase();
    return _lastStations
        .where((s) =>
            s.city.toLowerCase() == needle ||
            s.name.toLowerCase().contains(needle))
        .firstOrNull;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  Future<void> start({Duration? pollInterval}) async {
    if (pollInterval != null) _pollInterval = pollInterval;
    _timer?.cancel();
    await fetch();
    _timer = Timer.periodic(_pollInterval, (_) => fetch());
  }

  void stop()    { _timer?.cancel(); _timer = null; }
  void dispose() { stop(); _controller.close(); }

  // ── fetch → List<RiverStation>  (stream path) ─────────────────────────────
  Future<List<RiverStation>> fetch({
    String? state,
    String? river,
    String? district,
    String? status,
  }) async {
    if (_loading) return _lastStations;
    _loading = true;
    try {
      final params = <String, String>{};
      if (state    != null) params['state']    = state;
      if (river    != null) params['river']    = river;
      if (district != null) params['district'] = district;
      if (status   != null) params['status']   = status;

      final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.epLiveTelemetry}')
          .replace(queryParameters: params.isEmpty ? null : params);

      if (kDebugMode) debugPrint('[RiverService] GET $uri');
      final res = await _client.get(uri).timeout(AppConfig.requestTimeout);

      if (res.statusCode == 200) {
        final j   = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = j['data'];
        if (raw is List) {
          final stations = raw
              .cast<Map<String, dynamic>>()
              .map(RiverStation.fromJson)
              .toList();
          _lastStations = stations;
          _lastFetch    = DateTime.now();
          _lastError    = null;
          _controller.add(stations);
          if (kDebugMode) {
            debugPrint('[RiverService] ✓ ${stations.length} stations '
                '| danger=${criticalStations.length} '
                '| warning=${warningStations.length}');
          }
          return stations;
        }
      } else {
        _lastError = 'HTTP ${res.statusCode}';
      }
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) debugPrint('[RiverService] error: $e');
    } finally {
      _loading = false;
    }
    if (_lastStations.isNotEmpty) _controller.add(_lastStations);
    return _lastStations;
  }

  Future<List<RiverStation>> fetchBiharOnly() => fetch(state: 'Bihar');

  // ── fetchAll → List<LiveRiverResult>  (river_monitor / india_rivers) ──────
  Future<List<LiveRiverResult>> fetchAll() async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.epLiveTelemetry}');
      if (kDebugMode) debugPrint('[RiverService] fetchAll → $uri');
      final res = await _client.get(uri).timeout(AppConfig.requestTimeout);
      if (res.statusCode == 200) {
        final j   = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = j['data'];
        if (raw is List) {
          return raw
              .cast<Map<String, dynamic>>()
              .map(LiveRiverResult.fromApiJson)
              .toList();
        }
      }
      throw Exception('fetchAll: HTTP ${res.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('[RiverService] fetchAll error: $e');
      rethrow;
    }
  }

  // ── fetchCity → LiveRiverResult  (river_monitor / india_rivers) ───────────
  Future<LiveRiverResult> fetchCity({
    required String city,
    required String state,
    required String river,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.epLiveTelemetry}')
          .replace(queryParameters: {'city': city, 'state': state});
      if (kDebugMode) debugPrint('[RiverService] fetchCity → $uri');
      final res = await _client.get(uri).timeout(AppConfig.requestTimeout);
      if (res.statusCode == 200) {
        final j   = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = j['data'];
        if (raw is List && raw.isNotEmpty) {
          return LiveRiverResult.fromApiJson(
              raw.cast<Map<String, dynamic>>().first);
        }
        return _noDataResult(city: city, state: state, river: river);
      }
      throw Exception('fetchCity: HTTP ${res.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('[RiverService] fetchCity error: $e');
      return _noDataResult(city: city, state: state, river: river);
    }
  }

  LiveRiverResult _noDataResult({
    required String city,
    required String state,
    required String river,
  }) =>
      LiveRiverResult(
        station: CwcStation(
          city: city, river: river, state: state,
          current: 0, warning: 0, danger: 0, hfl: 0,
        ),
        source:     'NO_DATA',
        confidence: 0.0,
      );

  // ── Summary ───────────────────────────────────────────────────────────────
  Map<String, int> get summary => {
    'total':   _lastStations.length,
    'normal':  _lastStations.where((s) => s.isNormal).length,
    'warning': _lastStations.where((s) => s.isWarning).length,
    'danger':  _lastStations.where((s) => s.isCritical).length,
    'live':    _lastStations.where((s) => s.isLive).length,
    'bihar':   biharStations.length,
  };
}
