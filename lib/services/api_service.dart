import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  // Sized to survive Render free-tier cold-start (~50 s).
  static const Duration _timeout    = Duration(seconds: 60);
  static const int      _maxRetries = 3;

  List<String> get _baseCandidates => [
    AppConstants.baseUrl,
    if (AppConstants.backupBaseUrl.isNotEmpty) AppConstants.backupBaseUrl,
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

          if (res.statusCode >= 200 && res.statusCode < 300) {
            return _normalizeSuccess(_safeDecode(res.body), base, path);
          }

          // 404 — endpoint does not exist, no point retrying this base.
          if (res.statusCode == 404) {
            lastError = 'Endpoint not found (404): $base$path';
            break;
          }

          // 503 — server overloaded. Exponential backoff: 5s, 10s, 20s.
          if (res.statusCode == 503) {
            lastError = 'Server overloaded (503) — attempt $attempt';
            if (attempt < _maxRetries) {
              await Future<void>.delayed(Duration(seconds: 5 * attempt));
            }
            continue;
          }

          // Other 4xx — fast-fail, no retry.
          if (res.statusCode >= 400 && res.statusCode < 500) {
            lastError = 'Client error (${res.statusCode}): $base$path';
            break;
          }

          // 5xx (except 503) — standard 2s backoff.
          lastError = 'Server error (${res.statusCode})';
          if (attempt < _maxRetries) {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        } on TimeoutException {
          lastError = 'Timed out after ${_timeout.inSeconds}s';
          if (attempt < _maxRetries) {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          lastError = e;
          if (attempt < _maxRetries) {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        }
      }
    }

    return {
      'status': 'error',
      'error':  lastError?.toString() ?? 'Unknown API error',
      'data':   <dynamic>[],
    };
  }

  dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  Map<String, dynamic> _normalizeSuccess(
      dynamic parsed, String base, String path) {
    if (parsed is Map<String, dynamic>) return parsed;
    return {'status': 'success', 'data': parsed};
  }

  // ── Health ────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> checkHealth() =>
      _get(AppConstants.healthEndpoint);

  // ── BATCH endpoints — always fetch all states in ONE request ─────────────────
  // Use these everywhere. Never loop getLiveLevelsByCity() per city.

  /// Single bulk call for telemetry — all states, up to [limit] records.
  Future<Map<String, dynamic>> getAllLiveTelemetry({int limit = 1000}) {
    final ep = AppConstants.liveTelemetryEndpoint;
    return _get('$ep?all_states=true&limit=$limit');
  }

  /// Single bulk call for levels — all states, up to [limit] records.
  Future<Map<String, dynamic>> getAllLiveLevels({int limit = 200}) {
    final ep = AppConstants.liveLevelsEndpoint;
    return _get('$ep?all_states=true&limit=$limit');
  }

  // ── Scoped helpers (used only when a single state/city is needed) ──────────

  Future<Map<String, dynamic>> getLiveTelemetry({
    String? state,
    String? station,
    int limit = 10,
  }) {
    final ep = AppConstants.liveTelemetryEndpoint;
    final st = state ?? 'Maharashtra';
    final qs = StringBuffer('$ep?state=$st&limit=$limit');
    if (station != null && station.isNotEmpty) {
      qs.write('&station=${Uri.encodeComponent(station)}');
    }
    return _get(qs.toString());
  }

  /// Batch-first: if no [state] given, fetches all states in one call.
  /// Pass a state only when you genuinely need a single state.
  Future<Map<String, dynamic>> getLiveLevels({String? state, int limit = 200}) {
    final ep = AppConstants.liveLevelsEndpoint;
    if (state != null && state.isNotEmpty) {
      return _get('$ep?state=${Uri.encodeComponent(state)}&limit=$limit');
    }
    return _get('$ep?all_states=true&limit=$limit');
  }

  // NOTE: getLiveLevelsByCity is intentionally NOT exposed as a public method.
  // Callers must use getAllLiveLevels() and filter client-side to avoid
  // firing one HTTP request per city ("chatty API" pattern).

  Future<Map<String, dynamic>> getDashboardData({
    String? state,
    int limit = 10,
  }) =>
      getLiveTelemetry(state: state, limit: limit);

  Future<Map<String, dynamic>> getCriticalAlerts() =>
      _get(AppConstants.criticalAlertsEndpoint);

  Future<Map<String, dynamic>> predict(Map<String, dynamic> input) =>
      predictFlood(input);

  Future<Map<String, dynamic>> predictFlood(Map<String, dynamic> input) =>
      _post('/predict/v2', input);

  Future<Map<String, dynamic>> getFloodForecast({
    required String city,
    required String state,
  }) =>
      _get('/api/cwc-ffs/station'
          '?city=${Uri.encodeComponent(city)}'
          '&state=${Uri.encodeComponent(state)}');

  Future<Map<String, dynamic>> getReservoirLevels({required String state}) =>
      _get('/api/cwc-reservoir/state?state=${Uri.encodeComponent(state)}');

  Future<Map<String, dynamic>> getWeatherCurrent({required String location}) {
    final ep = AppConstants.weatherCurrentEndpoint;
    return _get('$ep?location=$location');
  }

  Future<Map<String, dynamic>> getWeatherForecast({required String location}) {
    final ep = AppConstants.weatherForecastEndpoint;
    return _get('$ep?location=$location');
  }

  // ── Pipeline endpoints ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getPipelineFeatures({
    required String state,
    String? station,
  }) {
    final qs = StringBuffer('state=${Uri.encodeComponent(state)}');
    if (station != null && station.isNotEmpty) {
      qs.write('&station=${Uri.encodeComponent(station)}');
    }
    return _get('/api/pipeline/features?$qs');
  }

  Future<Map<String, dynamic>> getStateSeverityMatrix() =>
      _get('/api/state-severity');

  Future<Map<String, dynamic>> getStateSeverityEntry(String state) =>
      _get('/api/state-severity/${Uri.encodeComponent(state)}');

  Future<Map<String, dynamic>> getPipelineManifest() =>
      _get('/api/pipeline/manifest');

  Future<Map<String, dynamic>> triggerIngestion() =>
      _post('/ingestion/run', {});

  // ── CWC stations ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAllCwcStations() =>
      _get('/api/cwc-stations');

  // ── Model quality ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getModelMetrics() =>
      _get('/model-metrics');
}
