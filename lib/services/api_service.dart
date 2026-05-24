// lib/services/api_service.dart
//
// LEGACY COMPATIBILITY SHIM — do not add new methods here.
//
// All screens that still import ApiService will continue to work.
// New code should import FloodApi directly:
//   import 'flood_api.dart';
//   final data = await FloodApi.instance.allTelemetry();

library;

import 'flood_api.dart';
export 'flood_api.dart' show FloodApi;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _api = FloodApi.instance;

  Future<Map<String, dynamic>> checkHealth()          => _api.healthCheck(coldStart: true);
  Future<Map<String, dynamic>> getAllLiveTelemetry({int limit = 1000}) => _api.allTelemetry(limit: limit);
  Future<Map<String, dynamic>> getAllLiveLevels({int limit = 200})     => _api.allLevels(limit: limit);
  Future<Map<String, dynamic>> getLiveTelemetry({String? state, String? station, int limit = 10}) =>
      _api.telemetryByState(state ?? 'Maharashtra', station: station, limit: limit);
  Future<Map<String, dynamic>> getLiveLevels({String? state, int limit = 200}) =>
      state != null ? _api.levelsByState(state, limit: limit) : _api.allLevels(limit: limit);
  Future<Map<String, dynamic>> getDashboardData({String? state, int limit = 10}) =>
      _api.telemetryByState(state ?? 'Maharashtra', limit: limit);
  Future<Map<String, dynamic>> getCriticalAlerts()    => _api.criticalAlerts();
  Future<Map<String, dynamic>> predict(Map<String, dynamic> input) => _api.predict(input);
  Future<Map<String, dynamic>> predictFlood(Map<String, dynamic> input) => _api.predict(input);
  Future<Map<String, dynamic>> getFloodForecast({required String city, required String state}) =>
      _api.cwcForecast(city: city, state: state);
  Future<Map<String, dynamic>> getReservoirLevels({required String state}) => _api.reservoirLevels(state);
  Future<Map<String, dynamic>> getWeatherCurrent({required String location})  => _api.weatherCurrent(location);
  Future<Map<String, dynamic>> getWeatherForecast({required String location}) => _api.weatherForecast(location);
  Future<Map<String, dynamic>> getPipelineFeatures({required String state, String? station}) =>
      _api.pipelineFeatures(state: state, station: station);
  Future<Map<String, dynamic>> getStateSeverityMatrix()         => _api.stateSeverity();
  Future<Map<String, dynamic>> getStateSeverityEntry(String s)  => _api.stateSeverityEntry(s);
  Future<Map<String, dynamic>> getPipelineManifest()            => _api.pipelineManifest();
  Future<Map<String, dynamic>> triggerIngestion()               => _api.triggerIngestion();
  Future<Map<String, dynamic>> getAllCwcStations()              => _api.cwcStations();
  Future<Map<String, dynamic>> getModelMetrics()                => _api.modelMetrics();
  Future<Map<String, dynamic>> getCwcProxiedTelemetry({required String state, required String station, int limit = 6}) =>
      _api.telemetryByState(state, station: station, limit: limit);
}
