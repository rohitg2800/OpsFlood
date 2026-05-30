// lib/services/real_time_river_service.dart
//
// OpsFlood — RealTimeRiverService v3
//
// Previously embedded a full hardcoded Bihar station list and computed
// synthetic levels locally.  Now it:
//   1. Calls GET /api/stations on startup and every _pollInterval.
//   2. Emits RiverStation objects parsed from the API response.
//   3. Falls back to the last successful response if the backend is
//      unreachable (no more hardcoded data).
//
// The backend at /api/stations already scrapes wrdb.bih.nic.in and
// falls back to deterministic synthetic levels automatically.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
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
  final String status;       // 'normal' | 'warning' | 'danger'
  final String trend;        // 'rising' | 'falling' | 'stable'
  final double pctToDanger;  // 0–100
  final String riskLevel;    // 'LOW' | 'HIGH' | 'CRITICAL'
  final String dataSource;   // 'WRD_BIHAR_LIVE' | 'WRD_BIHAR_SYNTHETIC' | 'SYNTHETIC'
  final DateTime lastUpdated;
  final double? discharge;
  final double? flowRate;

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
      id:           j['id']           as String? ?? '',
      name:         j['name']         as String? ?? '',
      city:         j['city']         as String? ?? j['name'] as String? ?? '',
      river:        j['river']        as String? ?? '',
      district:     j['district']     as String? ?? '',
      state:        j['state']        as String? ?? 'Bihar',
      lat:          (j['lat']         as num?)?.toDouble() ?? 0.0,
      lon:          (j['lon']         as num?)?.toDouble() ?? 0.0,
      currentLevel: (j['current_level'] as num?)?.toDouble() ?? 0.0,
      dangerLevel:  (j['danger_level']  as num?)?.toDouble() ?? 0.0,
      warningLevel: (j['warning_level'] as num?)?.toDouble() ?? 0.0,
      safeLevel:    (j['safe_level']    as num?)?.toDouble() ?? 0.0,
      status:       j['status']       as String? ?? 'normal',
      trend:        j['trend']        as String? ?? 'stable',
      pctToDanger:  (j['pct_to_danger'] as num?)?.toDouble() ?? 0.0,
      riskLevel:    j['risk_level']   as String? ?? 'LOW',
      dataSource:   j['data_source']  as String? ?? 'UNKNOWN',
      lastUpdated:  j['last_updated'] != null
          ? DateTime.tryParse(j['last_updated'] as String) ?? DateTime.now()
          : DateTime.now(),
      discharge:    (j['discharge']   as num?)?.toDouble(),
      flowRate:     (j['flow_rate']   as num?)?.toDouble(),
    );
  }

  bool get isBiharWrd  => dataSource.startsWith('WRD_BIHAR');
  bool get isLive      => dataSource == 'WRD_BIHAR_LIVE';
  bool get isCritical  => status == 'danger';
  bool get isWarning   => status == 'warning';
  bool get isNormal    => status == 'normal';

  /// Percentage of danger level (0.0–1.0)
  double get levelRatio =>
      dangerLevel > 0 ? (currentLevel / dangerLevel).clamp(0.0, 1.5) : 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────
class RealTimeRiverService {
  static final RealTimeRiverService _instance = RealTimeRiverService._internal();
  factory RealTimeRiverService() => _instance;
  RealTimeRiverService._internal();

  final http.Client _client = http.Client();

  // Stream controller — UI subscribes to this
  final _controller = StreamController<List<RiverStation>>.broadcast();
  Stream<List<RiverStation>> get stream => _controller.stream;

  Timer?               _timer;
  List<RiverStation>   _lastStations  = [];
  bool                 _loading       = false;
  DateTime?            _lastFetch;
  String?              _lastError;

  // Poll interval — matches AppConfig but can be overridden for testing
  Duration _pollInterval = AppConfig.realtimeInterval;

  List<RiverStation> get stations  => _lastStations;
  bool               get isLoading => _loading;
  DateTime?          get lastFetch => _lastFetch;
  String?            get lastError => _lastError;

  // Filtered views
  List<RiverStation> get biharStations =>
      _lastStations.where((s) => s.state == 'Bihar').toList();

  List<RiverStation> get criticalStations =>
      _lastStations.where((s) => s.isCritical).toList();

  List<RiverStation> get warningStations =>
      _lastStations.where((s) => s.isWarning).toList();

  List<RiverStation> get alertStations =>
      _lastStations.where((s) => !s.isNormal).toList()
        ..sort((a, b) {
          final order = {'danger': 0, 'warning': 1, 'normal': 2};
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

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  Future<void> start({Duration? pollInterval}) async {
    if (pollInterval != null) _pollInterval = pollInterval;
    _timer?.cancel();
    await fetch();
    _timer = Timer.periodic(_pollInterval, (_) => fetch());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  // ── Fetch from /api/stations ──────────────────────────────────────────────────
  Future<List<RiverStation>> fetch({
    String? state,
    String? river,
    String? district,
    String? status,
  }) async {
    if (_loading) return _lastStations;
    _loading = true;

    try {
      // Build URL — /api/stations maps to AppConfig.epLiveTelemetry
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
                '| warning=${warningStations.length} '
                '| live=${stations.where((s) => s.isLive).length}');
          }
          return stations;
        }
      } else {
        _lastError = 'HTTP ${res.statusCode}';
        if (kDebugMode) debugPrint('[RiverService] HTTP ${res.statusCode}');
      }
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) debugPrint('[RiverService] error: $e');
    } finally {
      _loading = false;
    }

    // Return last known good data on failure (no synthetic fallback here —
    // the backend already has its own deterministic fallback).
    if (_lastStations.isNotEmpty) {
      _controller.add(_lastStations);
    }
    return _lastStations;
  }

  // ── Fetch Bihar WRD only ──────────────────────────────────────────────────────
  Future<List<RiverStation>> fetchBiharOnly() =>
      fetch(state: 'Bihar');

  // ── Summary stats ─────────────────────────────────────────────────────────────
  Map<String, int> get summary => {
    'total':   _lastStations.length,
    'normal':  _lastStations.where((s) => s.isNormal).length,
    'warning': _lastStations.where((s) => s.isWarning).length,
    'danger':  _lastStations.where((s) => s.isCritical).length,
    'live':    _lastStations.where((s) => s.isLive).length,
    'bihar':   biharStations.length,
  };
}
