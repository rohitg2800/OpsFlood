import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  // Per-request timeout: 12 s (was 30 s).
  static const Duration _timeout      = Duration(seconds: 12);
  static const int      _maxRetries   = 3;
  static const Duration _retryBackoff = Duration(seconds: 2);

  List<String> get _baseCandidates => <String>[
        AppConstants.baseUrl,
        AppConstants.backupBaseUrl,
      ];

  Future<Map<String, dynamic>> _get(String path) =>
      _request(method: 'GET', path: path);

  Future<Map<String, dynamic>> _post(
          String path, Map<String, dynamic> body) =>
      _request(method: 'POST', path: path, body: body);

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    Object? lastError;

    for (final base in _baseCandidates) {
      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        try {
          final uri = Uri.parse('$base$path');
          late final http.Response res;

          if (method == 'POST') {
            res = await _client
                .post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(body ?? <String, dynamic>{}),
                )
                .timeout(_timeout);
          } else {
            res = await _client.get(uri).timeout(_timeout);
          }

          if (res.statusCode < 200 || res.statusCode >= 300) {
            lastError = 'HTTP ${res.statusCode}';
            if (res.statusCode >= 400 && res.statusCode < 500) break;
            if (attempt < _maxRetries) {
              await Future<void>.delayed(_retryBackoff * attempt);
            }
            continue;
          }

          final parsedBody = _safeDecode(res.body);
          return _normalizeSuccess(parsedBody, base, path);
        } on TimeoutException {
          lastError = 'Request timed out after ${_timeout.inSeconds}s';
          if (attempt == _maxRetries) break;
          await Future<void>.delayed(_retryBackoff);
        } catch (e) {
          lastError = e;
          if (attempt == _maxRetries) break;
          await Future<void>.delayed(_retryBackoff);
        }
      }
    }

    return {
      'status': 'error',
      'error':  lastError?.toString() ?? 'Unknown API error',
      'data':   <dynamic>[],
    };
  }

  dynamic _safeDecode(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(raw);
    } catch (_) {
      return <String, dynamic>{'raw': raw};
    }
  }

  Map<String, dynamic> _normalizeSuccess(
      dynamic payload, String base, String path) {
    if (payload is Map<String, dynamic>) {
      if (payload.containsKey('data')) {
        return {
          ...payload,
          'status': payload['status'] ?? 'success',
          'source': '$base$path',
        };
      }
      if (payload.containsKey('records')) {
        return {
          ...payload,
          'status': payload['status'] ?? 'success',
          'data':   payload['records'],
          'source': '$base$path',
        };
      }
      return {
        ...payload,
        'status': payload['status'] ?? 'success',
        'data':   payload['data'] ?? payload,
        'source': '$base$path',
      };
    }
    if (payload is List) {
      return {'status': 'success', 'data': payload, 'source': '$base$path'};
    }
    return {'status': 'success', 'data': payload, 'source': '$base$path'};
  }

  // ── Health ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> checkHealth() =>
      _get(AppConstants.healthEndpoint);

  // ── Dashboard / live data ────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardData() => _get(
        '${AppConstants.liveTelemetryEndpoint}?state=Maharashtra&station=Kolhapur&limit=12',
      );

  Future<Map<String, dynamic>> getLiveLevels() =>
      _get(AppConstants.liveLevelsEndpoint);

  Future<Map<String, dynamic>> getLiveLevelsByCity(String city) => _get(
      '${AppConstants.liveLevelsEndpoint}?city=${Uri.encodeComponent(city)}');

  Future<Map<String, dynamic>> getCriticalAlerts() =>
      _get(AppConstants.criticalAlertsEndpoint);

  Future<Map<String, dynamic>> getCriticalAlertsByState(String state) => _get(
      '${AppConstants.criticalAlertsEndpoint}?state=${Uri.encodeComponent(state)}');

  /// Returns all CWC stations currently above warning level.
  /// Routes through the backend (/api/live-telemetry) — never calls CWC
  /// directly from the phone (CORS-blocked on Android/iOS).
  /// The backend already scrapes, parses, and normalises the CWC JSON feed.
  Future<Map<String, dynamic>> getAllCwcStations() =>
      _get('${AppConstants.liveTelemetryEndpoint}?limit=200&all_states=true');

  Future<Map<String, dynamic>> getLiveTelemetry({
    String state   = 'Maharashtra',
    String station = 'Kolhapur',
    int    limit   = 15,
  }) =>
      _get(
        '${AppConstants.liveTelemetryEndpoint}'
        '?state=${Uri.encodeComponent(state)}'
        '&station=${Uri.encodeComponent(station)}'
        '&limit=$limit',
      );

  // ── Model ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getModelMetrics() => _get('/model-metrics');

  // ── Prediction ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> predict(Map<String, dynamic> input) =>
      _post(AppConstants.predictLegacyEndpoint, input);

  Future<Map<String, dynamic>> predictV2(Map<String, dynamic> input) =>
      _post('/predict/v2', input);

  // ── History ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getPredictionHistory({
    String? state,
    int     limit = 20,
  }) {
    final params = <String>['limit=$limit'];
    if (state != null && state.isNotEmpty) {
      params.add('state=${Uri.encodeComponent(state)}');
    }
    return _get('/prediction-history?${params.join("&")}');
  }

  // ── Weather ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getWeather(String city) => _get(
      '${AppConstants.weatherCurrentEndpoint}?city=${Uri.encodeComponent(city)}');

  Future<Map<String, dynamic>> getWeatherByCoords(double lat, double lon) =>
      _get('${AppConstants.weatherCurrentEndpoint}?lat=$lat&lon=$lon');

  Future<Map<String, dynamic>> getForecast(String city) => _get(
      '${AppConstants.weatherForecastEndpoint}?city=${Uri.encodeComponent(city)}');

  Future<Map<String, dynamic>> getHistoricalLogs({
    String city  = 'Kolhapur',
    int    limit = 24,
  }) =>
      _get('/historical-logs?city=${Uri.encodeComponent(city)}&limit=$limit');

  // ── Audit / telemetry snapshots ─────────────────────────────────────
  Future<Map<String, dynamic>> getAuditLogs({int limit = 50}) =>
      _get('/audit-logs?limit=$limit');

  Future<Map<String, dynamic>> getTelemetrySnapshots({
    String? state,
    String? station,
    int     limit = 50,
  }) {
    final params = ['limit=$limit'];
    if (state   != null) params.add('state=${Uri.encodeComponent(state)}');
    if (station != null) params.add('station=${Uri.encodeComponent(station)}');
    return _get('/telemetry-snapshots?${params.join("&")}');
  }
}
