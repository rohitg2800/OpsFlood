/// lib/services/cwc_open_data_service.dart
///
/// Integrates two official Indian government open-data sources:
///
///  1. CWC Flood Forecast System (FFS)  —  https://ffs.india-water.gov.in
///     Real-time flood forecasts & gauge levels for ~600 CWC stations.
///     Fetched via OpsFlood backend proxy to avoid CORS on device.
///
///  2. data.gov.in daily CWC reservoir levels
///     https://www.data.gov.in/resource/daily-data-reservoir-level-central-water-commission-cwc
///     Resource ID: 9ef84268-d588-465a-a308-a864a43d0070
///     Licence: Open Government Data (OGD) Platform India — free public reuse.
///     Also proxied through OpsFlood backend to cache & avoid rate limits.
///
/// IMPORTANT: both sources are fetched through the OpsFlood backend
/// (/api/cwc-ffs, /api/cwc-reservoir) — the device NEVER calls
/// ffs.india-water.gov.in or data.gov.in directly (they block CORS/mobile).
/// The backend scrapes, normalises, and caches the feeds every 15 minutes.
///
/// GAUGE SANITY RULE:
/// Indian river gauge heights are always 0.01 – 200 m (MSL or above datum).
/// Any value outside this is a discharge (m³/s), error code, or wrong-column
/// artifact and is zeroed out → NO_DATA fallback.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';

// ─── Gauge sanity bounds ─────────────────────────────────────────────────────
const double _kGaugeMin = 0.01;
const double _kGaugeMax = 200.0;

double _sanityClamp(double v) => (v < _kGaugeMin || v > _kGaugeMax) ? 0.0 : v;

// ─── Data models ────────────────────────────────────────────────────────────────

/// Live gauge reading from CWC FFS (ffs.india-water.gov.in).
class CwcFfsStation {
  final String stationName;
  final String river;
  final String state;
  final double currentLevelM;      // observed gauge reading in metres
  final double dangerLevelM;       // CWC published danger level
  final double warningLevelM;      // CWC published warning level
  final String alertColour;        // 'red' | 'orange' | 'yellow' | 'green'
  final String trend;              // 'rising' | 'falling' | 'steady'
  final String? forecastText;      // CWC narrative forecast if available
  final DateTime observedAt;

  const CwcFfsStation({
    required this.stationName,
    required this.river,
    required this.state,
    required this.currentLevelM,
    required this.dangerLevelM,
    required this.warningLevelM,
    required this.alertColour,
    required this.trend,
    this.forecastText,
    required this.observedAt,
  });

  /// Derived flood risk label consistent with the rest of the app.
  String get riskLabel {
    if (currentLevelM >= dangerLevelM)  return 'CRITICAL';
    if (currentLevelM >= warningLevelM) return 'SEVERE';
    if (currentLevelM >= warningLevelM * 0.85) return 'MODERATE';
    return 'LOW';
  }

  double get proximityToDanger => dangerLevelM - currentLevelM;

  factory CwcFfsStation.fromJson(Map<String, dynamic> j) => CwcFfsStation(
    stationName:   _s(j['station_name']  ?? j['station'] ?? j['name'] ?? ''),
    river:         _s(j['river']         ?? j['river_name']   ?? ''),
    state:         _s(j['state']         ?? ''),
    // Sanity-clamp the gauge reading — rejects discharge / error values.
    currentLevelM: _sanityClamp(_d(j['current_level'] ?? j['level_m'] ?? j['obs_level'])),
    dangerLevelM:  _d(j['danger_level']  ?? j['hdl'] ?? j['danger']),
    warningLevelM: _d(j['warning_level'] ?? j['wl']  ?? j['warning']),
    alertColour:   _s(j['alert_colour']  ?? j['alert_color'] ?? j['colour'] ?? 'green'),
    trend:         _s(j['trend']         ?? 'steady'),
    forecastText:  j['forecast']?.toString(),
    observedAt:    _dt(j['observed_at']  ?? j['timestamp']),
  );

  static String   _s(dynamic v) => v?.toString() ?? '';
  static double   _d(dynamic v) => (v == null || v == '') ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
  static DateTime _dt(dynamic v) {
    if (v == null) return DateTime.now();
    try { return DateTime.parse(v.toString()); } catch (_) { return DateTime.now(); }
  }
}

/// Daily reservoir level from data.gov.in CWC dataset.
/// Resource: daily-data-reservoir-level-central-water-commission-cwc
/// OGD Platform India licence — open for public reuse.
class CwcReservoirLevel {
  final String reservoirName;
  final String state;
  final String basin;
  final double fullReservoirLevelM;   // FRL in metres
  final double currentLevelM;         // today's level in metres
  final double liveStorageMcm;        // live storage in MCM
  final double liveStoragePct;        // % of total capacity
  final String dataDate;              // YYYY-MM-DD

  const CwcReservoirLevel({
    required this.reservoirName,
    required this.state,
    required this.basin,
    required this.fullReservoirLevelM,
    required this.currentLevelM,
    required this.liveStorageMcm,
    required this.liveStoragePct,
    required this.dataDate,
  });

  /// Maps the % fill to the same risk labels used across the app.
  String get riskLabel {
    if (liveStoragePct >= AppConstants.criticalThreshold) return 'CRITICAL';
    if (liveStoragePct >= AppConstants.highThreshold)     return 'SEVERE';
    if (liveStoragePct >= AppConstants.moderateThreshold) return 'MODERATE';
    return 'LOW';
  }

  factory CwcReservoirLevel.fromJson(Map<String, dynamic> j) {
    final frl  = _d(j['full_reservoir_level_m'] ?? j['frl'] ?? j['FRL']);
    // Sanity-clamp reservoir current level — rejects MCM/discharge values.
    final curr = _sanityClamp(_d(j['current_level_m'] ?? j['current_level'] ?? j['wl'] ?? j['water_level']));
    final cap  = _d(j['total_capacity_mcm'] ?? j['total_capacity'] ?? j['gross_capacity']);
    final live = _d(j['live_storage_mcm']   ?? j['live_storage']);
    final pct  = cap > 0 ? (live / cap * 100).clamp(0.0, 100.0) : 0.0;

    return CwcReservoirLevel(
      reservoirName:      _s(j['reservoir_name'] ?? j['name'] ?? j['project_name'] ?? ''),
      state:              _s(j['state'] ?? j['State'] ?? ''),
      basin:              _s(j['basin'] ?? j['river_basin'] ?? ''),
      fullReservoirLevelM: frl,
      currentLevelM:      curr,
      liveStorageMcm:     live,
      liveStoragePct:     pct,
      dataDate:           _s(j['date'] ?? j['report_date'] ?? j['data_date'] ?? ''),
    );
  }

  static String _s(dynamic v) => v?.toString() ?? '';
  static double _d(dynamic v) => (v == null || v == '') ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
}

// ─── FFS Service ────────────────────────────────────────────────────────────────

/// Fetches live CWC FFS flood forecasts via OpsFlood backend proxy.
/// Source: https://ffs.india-water.gov.in
/// The backend polls FFS every 15 min and normalises the HTML table
/// into JSON. This class just consumes that normalised feed.
class CwcFfsService {
  CwcFfsService._();
  static final CwcFfsService instance = CwcFfsService._();

  final http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 14);

  // Backend proxy endpoints (OpsFlood normalises FFS HTML → JSON)
  static const String _ffsAllEndpoint    = '/api/cwc-ffs';          // all stations
  static const String _ffsStateEndpoint  = '/api/cwc-ffs/state';    // ?state=
  static const String _ffsCityEndpoint   = '/api/cwc-ffs/station';  // ?name=

  /// Fetch all stations currently in alert (above warning level).
  Future<List<CwcFfsStation>> fetchAllAlertStations() =>
      _fetch('$_ffsAllEndpoint?alert_only=true');

  /// Fetch all FFS stations for a given state.
  Future<List<CwcFfsStation>> fetchByState(String state) =>
      _fetch('$_ffsStateEndpoint?state=${Uri.encodeComponent(state)}');

  /// Fetch a single station by name (fuzzy match on backend).
  Future<CwcFfsStation?> fetchByStation(String stationName) async {
    final list = await _fetch(
        '$_ffsCityEndpoint?name=${Uri.encodeComponent(stationName)}');
    return list.isEmpty ? null : list.first;
  }

  /// Get live gauge level for a station (for predict.dart compatibility).
  Future<double?> getLiveRiverLevel(String stationName) async {
    final s = await fetchByStation(stationName);
    return s?.currentLevelM;
  }

  Future<List<CwcFfsStation>> _fetch(String path) async {
    for (final base in [AppConstants.baseUrl, AppConstants.backupBaseUrl]) {
      try {
        final res = await _client
            .get(Uri.parse('$base$path'))
            .timeout(_timeout);
        if (res.statusCode != 200) continue;
        final body = jsonDecode(res.body);
        final List<dynamic> items;
        if (body is Map && body.containsKey('data')) {
          items = body['data'] as List? ?? [];
        } else if (body is List) {
          items = body;
        } else {
          continue;
        }
        return items
            .whereType<Map<String, dynamic>>()
            .map(CwcFfsStation.fromJson)
            .toList();
      } catch (_) {
        continue;
      }
    }
    return [];
  }
}

// ─── data.gov.in Reservoir Service ───────────────────────────────────────────────────

/// Fetches daily CWC reservoir levels from data.gov.in via OpsFlood backend.
///
/// Source dataset:
///   https://www.data.gov.in/resource/daily-data-reservoir-level-central-water-commission-cwc
///   Resource ID: 9ef84268-d588-465a-a308-a864a43d0070
///   Licence: Open Government Data (OGD) Platform India
///   Fields: reservoir_name, state, basin, FRL, current_level, live_storage_mcm
///
/// The OpsFlood backend calls the data.gov.in API daily and caches results
/// to avoid rate-limiting (data.gov.in allows ~1000 req/day per API key).
class DataGovCwcService {
  DataGovCwcService._();
  static final DataGovCwcService instance = DataGovCwcService._();

  final http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 14);

  // Backend cache endpoints for the data.gov.in reservoir dataset
  static const String _allEndpoint   = '/api/cwc-reservoir';         // all reservoirs
  static const String _stateEndpoint = '/api/cwc-reservoir/state';   // ?state=
  static const String _nameEndpoint  = '/api/cwc-reservoir/search';  // ?name=

  /// All reservoirs (nationwide).
  Future<List<CwcReservoirLevel>> fetchAll() => _fetch(_allEndpoint);

  /// All reservoirs in a given state.
  Future<List<CwcReservoirLevel>> fetchByState(String state) =>
      _fetch('$_stateEndpoint?state=${Uri.encodeComponent(state)}');

  /// Search by reservoir / project name (fuzzy).
  Future<List<CwcReservoirLevel>> searchByName(String name) =>
      _fetch('$_nameEndpoint?name=${Uri.encodeComponent(name)}');

  /// Returns the top N reservoirs at critical fill (>=85%) sorted descending.
  Future<List<CwcReservoirLevel>> fetchCriticalReservoirs({int limit = 20}) =>
      _fetch('$_allEndpoint?min_pct=85&limit=$limit&sort=pct_desc');

  Future<List<CwcReservoirLevel>> _fetch(String path) async {
    for (final base in [AppConstants.baseUrl, AppConstants.backupBaseUrl]) {
      try {
        final res = await _client
            .get(Uri.parse('$base$path'))
            .timeout(_timeout);
        if (res.statusCode != 200) continue;
        final body = jsonDecode(res.body);
        final List<dynamic> items;
        if (body is Map && body.containsKey('data')) {
          items = body['data'] as List? ?? [];
        } else if (body is List) {
          items = body;
        } else {
          continue;
        }
        return items
            .whereType<Map<String, dynamic>>()
            .map(CwcReservoirLevel.fromJson)
            .toList();
      } catch (_) {
        continue;
      }
    }
    return [];
  }
}

// ─── Unified facade ──────────────────────────────────────────────────────────────────

/// Single entry point for all CWC open-data queries.
/// Resolution order for live river levels:
///   1. CWC FFS (most current, real-time, river gauge)
///   2. data.gov.in reservoir dataset (daily, reservoir fill)
///   3. OpsFlood backend live-telemetry (always available)
class CwcOpenDataService {
  CwcOpenDataService._();
  static final CwcOpenDataService instance = CwcOpenDataService._();

  final _ffs  = CwcFfsService.instance;
  final _dgov = DataGovCwcService.instance;

  /// Best available live river level for a named station.
  /// Returns null only if all three sources fail.
  Future<double?> getLiveRiverLevel(String stationName) async {
    // 1. Try CWC FFS (real-time gauge)
    final ffsLevel = await _ffs.getLiveRiverLevel(stationName);
    if (ffsLevel != null && ffsLevel > 0) return ffsLevel;

    // 2. Try data.gov.in reservoir dataset (nearest match by name)
    try {
      final reservoirs = await _dgov.searchByName(stationName);
      if (reservoirs.isNotEmpty && reservoirs.first.currentLevelM > 0) {
        return reservoirs.first.currentLevelM;
      }
    } catch (_) {}

    return null;
  }

  /// All stations currently in flood alert (above warning level).
  Future<List<CwcFfsStation>> getActiveAlerts() =>
      _ffs.fetchAllAlertStations();

  /// State-level FFS stations.
  Future<List<CwcFfsStation>> getStateFfsStations(String state) =>
      _ffs.fetchByState(state);

  /// State-level reservoir fill data (data.gov.in).
  Future<List<CwcReservoirLevel>> getStateReservoirs(String state) =>
      _dgov.fetchByState(state);

  /// Top reservoirs at critical fill nationwide.
  Future<List<CwcReservoirLevel>> getCriticalReservoirs({int limit = 20}) =>
      _dgov.fetchCriticalReservoirs(limit: limit);
}
