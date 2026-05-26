// lib/services/api_service.dart
//
// LEGACY COMPATIBILITY SHIM — do not add new methods here.
//
// All methods are @Deprecated. Migrate callers to FloodApi directly:
//   import 'flood_api.dart';
//   final data = await FloodApi.instance.allTelemetry();
//
// This file will be removed once all screens are migrated.

library;

import 'flood_api.dart';
export 'flood_api.dart' show FloodApi;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _api = FloodApi.instance;

  @Deprecated('Use FloodApi.instance.healthCheck() directly')
  Future<Map<String, dynamic>> checkHealth() => _api.healthCheck(coldStart: true);

  @Deprecated('Use FloodApi.instance.allTelemetry() directly')
  Future<Map<String, dynamic>> getAllLiveTelemetry({int limit = 1000}) => _api.allTelemetry(limit: limit);

  @Deprecated('Use FloodApi.instance.allLevels() directly')
  Future<Map<String, dynamic>> getAllLiveLevels({int limit = 200}) => _api.allLevels(limit: limit);

  @Deprecated('Use FloodApi.instance.telemetryByState() directly')
  Future<Map<String, dynamic>> getLiveTelemetry({String? state, String? station, int limit = 10}) =>
      _api.telemetryByState(state ?? 'Maharashtra', station: station, limit: limit);

  @Deprecated('Use FloodApi.instance.levelsByState() or allLevels() directly')
  Future<Map<String, dynamic>> getLiveLevels({String? state, int limit = 200}) =>
      state != null ? _api.levelsByState(state, limit: limit) : _api.allLevels(limit: limit);

  @Deprecated('Use FloodApi.instance.telemetryByState() directly')
  Future<Map<String, dynamic>> getDashboardData({String? state, int limit = 10}) =>
      _api.telemetryByState(state ?? 'Maharashtra', limit: limit);

  @Deprecated('Use FloodApi.instance.criticalAlerts() directly')
  Future<Map<String, dynamic>> getCriticalAlerts() => _api.criticalAlerts();

  @Deprecated('Use FloodApi.instance.predict() directly')
  Future<Map<String, dynamic>> predict(Map<String, dynamic> input) => _api.predict(input);

  @Deprecated('Use FloodApi.instance.predict() directly')
  Future<Map<String, dynamic>> predictFlood(Map<String, dynamic> input) => _api.predict(input);

  @Deprecated('Use FloodApi.instance.cwcForecast() directly')
  Future<Map<String, dynamic>> getFloodForecast({required String city, required String state}) =>
      _api.cwcForecast(city: city, state: state);

  @Deprecated('Use FloodApi.instance.reservoirLevels() directly')
  Future<Map<String, dynamic>> getReservoirLevels({required String state}) => _api.reservoirLevels(state);

  @Deprecated('Use FloodApi.instance.weatherCurrent() directly')
  Future<Map<String, dynamic>> getWeatherCurrent({required String location}) => _api.weatherCurrent(location);

  @Deprecated('Use FloodApi.instance.weatherForecast() directly')
  Future<Map<String, dynamic>> getWeatherForecast({required String location}) => _api.weatherForecast(location);

  @Deprecated('Use FloodApi.instance.pipelineFeatures() directly')
  Future<Map<String, dynamic>> getPipelineFeatures({required String state, String? station}) =>
      _api.pipelineFeatures(state: state, station: station);

  @Deprecated('Use FloodApi.instance.stateSeverity() directly')
  Future<Map<String, dynamic>> getStateSeverityMatrix() => _api.stateSeverity();

  @Deprecated('Use FloodApi.instance.stateSeverityEntry() directly')
  Future<Map<String, dynamic>> getStateSeverityEntry(String s) => _api.stateSeverityEntry(s);

  @Deprecated('Use FloodApi.instance.pipelineManifest() directly')
  Future<Map<String, dynamic>> getPipelineManifest() => _api.pipelineManifest();

  @Deprecated('Use FloodApi.instance.triggerIngestion() directly')
  Future<Map<String, dynamic>> triggerIngestion() => _api.triggerIngestion();

  @Deprecated('Use FloodApi.instance.cwcStations() directly')
  Future<Map<String, dynamic>> getAllCwcStations() => _api.cwcStations();

  @Deprecated('Use FloodApi.instance.modelMetrics() directly')
  Future<Map<String, dynamic>> getModelMetrics() => _api.modelMetrics();

  @Deprecated('Use FloodApi.instance.telemetryByState() directly')
  Future<Map<String, dynamic>> getCwcProxiedTelemetry({required String state, required String station, int limit = 6}) =>
      _api.telemetryByState(state, station: station, limit: limit);
}
