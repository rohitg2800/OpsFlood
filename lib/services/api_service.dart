import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  // 60 s — sized to survive Render free-tier cold-start (~50 s).
  static const Duration _timeout      = Duration(seconds: 60);
  static const int      _maxRetries   = 2;
  static const Duration _retryBackoff = Duration(seconds: 2);

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

          if (res.statusCode < 200 || res.statusCode >= 300) {
            lastError = 'HTTP \${res.statusCode}';
            if (res.statusCode >= 400 && res.statusCode < 500) break;
            if (attempt < _maxRetries) {
              await Future<void>.delayed(_retryBackoff * attempt);
            }
            continue;
          }

          final parsedBody = _safeDecode(res.body);
          return _normalizeSuccess(parsedBody, base, path);
        } on TimeoutException {
          lastError = 'Request timed out after \${_timeout.inSeconds}s';
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

  // ── Named endpoint helpers ──────────────────────────────────────────────

  Future<Map<String, dynamic>> checkHealth() =>
      _get(AppConstants.healthEndpoint);

  // FIX: getLiveTelemetry was defaulting to state=Maharashtra and a limit of 10,
  // returning data for one state only. getAllLiveTelemetry now fetches without a
  // state filter so all monitored states are covered in a single call.
  Future<Map<String, dynamic>> getAllLiveTelemetry({int limit = 100}) =>
      _get('\${AppConstants.liveTelemetryEndpoint}?limit=\$limit');

  // FIX: added optional 'station' param — cwc_direct_service._fromTelemetry
  // passes station: city to narrow the telemetry result to a single gauge.
  Future<Map<String, dynamic>> getLiveTelemetry({
    String? state,
    String? station,
    int limit = 10,
  }) {
    final qs = StringBuffer(
        '\${AppConstants.liveTelemetryEndpoint}?state=\${state ?? "Maharashtra"}&limit=\$limit');
    if (station != null && station.isNotEmpty) {
      qs.write('&station=\${Uri.encodeComponent(station)}');
    }
    return _get(qs.toString());
  }

  // FIX: getDashboardData was called by real_time_river_service SOURCE 1 path
  // but never defined. Aliased to getLiveTelemetry — same endpoint, same data.
  Future<Map<String, dynamic>> getDashboardData({
    String? state,
    int limit = 10,
  }) =>
      getLiveTelemetry(state: state, limit: limit);

  // FIX: getLiveLevels was defaulting to state=Maharashtra and a limit of 20.
  // getAllLiveLevels fetches without a state filter so all states are covered.
  Future<Map<String, dynamic>> getAllLiveLevels({int limit = 100}) =>
      _get('\${AppConstants.liveLevelsEndpoint}?limit=\$limit');

  Future<Map<String, dynamic>> getLiveLevels({String? state, int limit = 20}) =>
      _get('\${AppConstants.liveLevelsEndpoint}?state=\${state ?? "Maharashtra"}&limit=\$limit');

  // FIX: getLiveLevelsByCity was called by cwc_direct_service SOURCE C but
  // never defined. Routes to /api/live-levels?city=X.
  Future<Map<String, dynamic>> getLiveLevelsByCity(String city) =>
      _get('\${AppConstants.liveLevelsEndpoint}?city=\${Uri.encodeComponent(city)}');

  Future<Map<String, dynamic>> getCriticalAlerts() =>
      _get(AppConstants.criticalAlertsEndpoint);

  // FIX: predict() was called by real_time_river_service _buildResult but
  // never defined — predictFlood() was the existing method. Added predict()
  // as a direct alias so callers compile without renaming every call site.
  Future<Map<String, dynamic>> predict(Map<String, dynamic> input) =>
      predictFlood(input);

  Future<Map<String, dynamic>> predictFlood(Map<String, dynamic> input) =>
      _post('/predict/v2', input);

  // FIX: getFloodForecast was called by both real_time_river_service SOURCE 3
  // and cwc_direct_service SOURCE A but never defined. Routes to the CWC FFS
  // per-station endpoint /api/cwc-ffs/station?city=X&state=Y.
  Future<Map<String, dynamic>> getFloodForecast({
    required String city,
    required String state,
  }) =>
      _get('/api/cwc-ffs/station?city=\${Uri.encodeComponent(city)}&state=\${Uri.encodeComponent(state)}');

  // FIX: getReservoirLevels was called by real_time_river_service SOURCE 4
  // and cwc_direct_service SOURCE D but never defined. Routes to the CWC
  // reservoir endpoint /api/cwc-reservoir/state?state=X.
  Future<Map<String, dynamic>> getReservoirLevels({required String state}) =>
      _get('/api/cwc-reservoir/state?state=\${Uri.encodeComponent(state)}');

  Future<Map<String, dynamic>> getWeatherCurrent({required String location}) =>
      _get('\${AppConstants.weatherCurrentEndpoint}?location=\$location');

  Future<Map<String, dynamic>> getWeatherForecast({required String location}) =>
      _get('\${AppConstants.weatherForecastEndpoint}?location=\$location');

  // ── Pipeline endpoints ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPipelineFeatures({
    required String state,
    String? station,
  }) {
    final qs = StringBuffer('state=\${Uri.encodeComponent(state)}');
    if (station != null && station.isNotEmpty) {
      qs.write('&station=\${Uri.encodeComponent(station)}');
    }
    return _get('/api/pipeline/features?\$qs');
  }

  Future<Map<String, dynamic>> getStateSeverityMatrix() =>
      _get('/api/state-severity');

  Future<Map<String, dynamic>> getStateSeverityEntry(String state) =>
      _get('/api/state-severity/\${Uri.encodeComponent(state)}');

  Future<Map<String, dynamic>> getPipelineManifest() =>
      _get('/api/pipeline/manifest');

  Future<Map<String, dynamic>> triggerIngestion() =>
      _post('/ingestion/run', {});

  // ── CWC stations (used by predict.dart _fetchLiveLevel) ─────────────────
  Future<Map<String, dynamic>> getAllCwcStations() =>
      _get('/api/cwc-stations');

  // ── Model quality ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getModelMetrics() =>
      _get('/model-metrics');
}
