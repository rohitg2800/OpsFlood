// lib/services/flood_api.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OpsFlood — Flood API                                                   ║
// ║                                                                          ║
// ║  The ONE file every screen, provider, and service imports for data.    ║
// ║  All methods call OpsClient (which calls the OpsFlood backend).        ║
// ║                                                                          ║
// ║  PRINCIPLE: The app is a DISPLAY layer. The backend is the brain.      ║
// ║  Zero business logic here — just typed wrappers around HTTP calls.     ║
// ╚══════════════════════════════════════════════════════════════════════════╝
library;

import '../config/app_config.dart';
import 'ops_client.dart';

class FloodApi {
  FloodApi._();
  static final FloodApi instance = FloodApi._();

  final _c = OpsClient.instance;

  // ── Health ────────────────────────────────────────────────────────────────
  // Two-phase: fast probe if known warm, slow probe for cold-start.
  Future<Map<String, dynamic>> healthCheck({bool coldStart = false}) =>
      _c.get(
        AppConfig.epHealth,
        timeout: coldStart
            ? AppConfig.coldStartTimeout
            : AppConfig.healthTimeout,
      );

  // ── Prediction (ML inference) ─────────────────────────────────────────────
  // POST /predict — OpsFlood backend ML ensemble
  Future<Map<String, dynamic>> predict(Map<String, dynamic> payload) =>
      _c.post(AppConfig.epPredict, payload);

  // ── Live telemetry (GloFAS discharge — 93 cities) ─────────────────────────
  // Batch — ALL states in ONE call. Filter client-side.
  Future<Map<String, dynamic>> allTelemetry({int limit = 1000}) =>
      _c.get(AppConfig.epLiveTelemetry,
          query: {'all_states': 'true', 'limit': '$limit'});

  // Scoped — only when you genuinely need a single state.
  Future<Map<String, dynamic>> telemetryByState(
    String state, {
    String? station,
    int limit = 50,
  }) {
    final q = <String, String>{'state': state, 'limit': '$limit'};
    if (station != null && station.isNotEmpty) q['station'] = station;
    return _c.get(AppConfig.epLiveTelemetry, query: q);
  }

  // ── Live levels (gauge readings) ──────────────────────────────────────────
  Future<Map<String, dynamic>> allLevels({int limit = 200}) =>
      _c.get(AppConfig.epLiveLevels,
          query: {'all_states': 'true', 'limit': '$limit'});

  Future<Map<String, dynamic>> levelsByState(String state, {int limit = 200}) =>
      _c.get(AppConfig.epLiveLevels,
          query: {'state': state, 'limit': '$limit'});

  // ── Critical alerts ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> criticalAlerts() =>
      _c.get(AppConfig.epCriticalAlerts);

  // ── CWC FFS (flood forecast — per station) ────────────────────────────────
  Future<Map<String, dynamic>> cwcForecast({
    required String city,
    required String state,
  }) =>
      _c.get(AppConfig.epCwcFfs,
          query: {'city': city, 'state': state});

  // ── CWC station registry ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> cwcStations() =>
      _c.get(AppConfig.epCwcStations);

  // ── Reservoir levels (data.gov.in via backend) ────────────────────────────
  Future<Map<String, dynamic>> reservoirLevels(String state) =>
      _c.get(AppConfig.epCwcReservoir,
          query: {'state': state});

  // ── Weather (OpenMeteo via backend) ───────────────────────────────────────
  Future<Map<String, dynamic>> weatherCurrent(String location) =>
      _c.get(AppConfig.epWeatherCurrent,
          query: {'location': location});

  Future<Map<String, dynamic>> weatherForecast(String location) =>
      _c.get(AppConfig.epWeatherForecast,
          query: {'location': location});

  // ── Pipeline (ML feature pre-fill) ────────────────────────────────────────
  Future<Map<String, dynamic>> pipelineFeatures({
    required String state,
    String? station,
  }) {
    final q = <String, String>{'state': state};
    if (station != null && station.isNotEmpty) q['station'] = station;
    return _c.get(AppConfig.epPipelineFeatures, query: q);
  }

  Future<Map<String, dynamic>> pipelineManifest() =>
      _c.get(AppConfig.epPipelineManifest);

  // ── State severity matrix ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> stateSeverity() =>
      _c.get(AppConfig.epStateSeverity);

  Future<Map<String, dynamic>> stateSeverityEntry(String state) =>
      _c.get('${AppConfig.epStateSeverity}/$state');

  // ── Operations ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> triggerIngestion() =>
      _c.post(AppConfig.epIngestionRun, {});

  Future<Map<String, dynamic>> modelMetrics() =>
      _c.get(AppConfig.epModelMetrics);
}
