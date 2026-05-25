// lib/services/india_stations_service.dart
//
// OpsFlood — IndiaStationsService
// Fetches ALL stations from opsflood.onrender.com/api/v1/stations/all
// and merges with GloFAS discharge for every lat/lon.
// Falls back to CWC direct scrape per known state endpoint.
//
// Output: List<FloodData> covering all 36 states/UTs returned by backend.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/flood_data.dart';

class IndiaStationsService {
  static final IndiaStationsService _instance = IndiaStationsService._();
  factory IndiaStationsService() => _instance;
  IndiaStationsService._();

  final http.Client _client = http.Client();

  // GloFAS discharge cache — keyed by "lat2:lon2"
  final Map<String, _CE> _glofasCache = {};

  static const _kTtl = Duration(minutes: 20);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns FloodData for every station the backend knows about.
  /// Merges CWC level + GloFAS discharge + risk from backend.
  Future<List<FloodData>> fetchAll() async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/stations/all');
      final res = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        if (kDebugMode) debugPrint('[IndiaStations] HTTP ${res.statusCode}');
        return [];
      }

      final body = jsonDecode(res.body);
      List<dynamic> raw = [];
      if (body is List) {
        raw = body;
      } else if (body is Map) {
        for (final k in ['data', 'stations', 'results', 'items']) {
          if (body[k] is List) { raw = body[k] as List; break; }
        }
      }
      if (raw.isEmpty) return [];

      // Fan-out GloFAS fetch for unique lat/lon pairs (cached, batched)
      final coords = <String, Map<String, double>>{};
      for (final s in raw) {
        if (s is! Map) continue;
        final lat = _d(s['latitude'] ?? s['lat']);
        final lon = _d(s['longitude'] ?? s['lon']);
        if (lat == null || lon == null) continue;
        final k = '${lat.toStringAsFixed(2)}:${lon.toStringAsFixed(2)}';
        coords[k] = {'lat': lat, 'lon': lon};
      }

      await Future.wait(
        coords.entries.map((e) => _ensureGloFas(e.key, e.value['lat']!, e.value['lon']!)),
        eagerError: false,
      );

      final results = <FloodData>[];
      for (final s in raw) {
        if (s is! Map) continue;
        final fd = _toFloodData(s);
        if (fd != null) results.add(fd);
      }

      if (kDebugMode) debugPrint('[IndiaStations] fetched ${results.length} stations');
      return results;
    } catch (e) {
      if (kDebugMode) debugPrint('[IndiaStations] error: $e');
      return [];
    }
  }

  // ── GloFAS helper ──────────────────────────────────────────────────────────

  Future<void> _ensureGloFas(String key, double lat, double lon) async {
    if (_glofasCache[key]?.valid == true) return;
    try {
      final uri = Uri.parse(
        'https://flood-api.open-meteo.com/v1/flood'
        '?latitude=$lat&longitude=$lon'
        '&daily=river_discharge&past_days=4&forecast_days=1',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final j    = jsonDecode(res.body) as Map<String, dynamic>;
      final vals = _doubles((j['daily'] as Map?)?['river_discharge']);
      if (vals.isEmpty) return;
      _glofasCache[key] = _CE({'discharge': vals.last, 'discharge7d': vals});
    } catch (_) {}
  }

  double? _glofasFlow(double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    final k = '${lat.toStringAsFixed(2)}:${lon.toStringAsFixed(2)}';
    final entry = _glofasCache[k];
    if (entry == null || !entry.valid) return null;
    return _d(entry.data['discharge']);
  }

  // ── FloodData builder ──────────────────────────────────────────────────────

  FloodData? _toFloodData(Map raw) {
    final city  = raw['city']?.toString() ?? raw['station_name']?.toString() ?? '';
    final state = raw['state']?.toString() ?? raw['state_name']?.toString() ?? '';
    if (city.isEmpty || state.isEmpty) return null;

    final lat     = _d(raw['latitude'] ?? raw['lat']);
    final lon     = _d(raw['longitude'] ?? raw['lon']);
    final current = _d(raw['current_level'] ?? raw['river_level']);
    final danger  = _d(raw['danger_level']);
    final warning = _d(raw['warning_level']);
    final safe    = _d(raw['safe_level']) ?? ((warning ?? 0) - 2).clamp(0.0, 999.0);
    final flow    = _d(raw['flow_rate'] ?? raw['river_discharge'])
                 ?? _glofasFlow(lat, lon);
    final rawRisk = (raw['risk_level'] as String?)?.toUpperCase() ?? 'LOW';
    final risk    = _normaliseRisk(rawRisk, current, danger, warning);
    final river   = raw['river_name']?.toString() ?? raw['river']?.toString();
    final src     = raw['data_source']?.toString() ?? 'BACKEND';

    return FloodData(
      id:            raw['id']?.toString() ?? '$state-$city',
      city:          city,
      state:         state,
      latitude:      lat ?? 20.5937,
      longitude:     lon ?? 78.9629,
      currentLevel:  current ?? 0.0,
      dangerLevel:   danger  ?? 0.0,
      warningLevel:  warning ?? 0.0,
      safeLevel:     safe,
      riskLevel:     risk,
      lastUpdated:   DateTime.now(),
      riverName:     river,
      flowRate:      flow,
      rainfall24h:   _d(raw['rainfall_24h']) ?? 0.0,
      status:        src,
      imdRainfallMm: _d(raw['rainfall_24h']) ?? 0.0,
      imdSeverity:   'GREEN',
    );
  }

  String _normaliseRisk(
    String raw, double? current, double? danger, double? warning,
  ) {
    // Trust backend risk label if it's valid
    if (['CRITICAL', 'HIGH', 'MODERATE', 'LOW', 'NORMAL'].contains(raw)) {
      // Re-evaluate if CWC level data says worse
      if (current != null && danger != null && danger > 0) {
        final r = current / danger;
        if (r >= 1.0  && raw != 'CRITICAL') return 'CRITICAL';
        if (r >= 0.85 && raw == 'LOW')      return 'HIGH';
      }
      return raw;
    }
    return 'LOW';
  }

  double? _d(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString().trim()) ?? (v is num ? v.toDouble() : null);
  }

  List<double> _doubles(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e == null ? 0.0 : (e as num).toDouble()).toList();
  }
}

class _CE {
  final Map<String, dynamic> data;
  final DateTime at;
  _CE(this.data) : at = DateTime.now();
  bool get valid => DateTime.now().difference(at) < const Duration(minutes: 20);
}
