// lib/services/cached_flood_api.dart
//
// OpsFlood — Cache-Aware FloodApi Wrapper
//
// Wraps every FloodApi call with LocalCacheService.
// Strategy: stale-while-revalidate
//   • If a fresh cache entry exists (≤ 5 min old) → return it immediately.
//   • If no entry exists                          → fetch, cache, return.
//   • If entry is stale (> 5 min old)             → return stale immediately
//     AND kick off a background refresh so the next call gets fresh data.
//
// This means:
//   • The 45-second polling loop will hit cache on most ticks (no wasted calls).
//   • Background refreshes fire only when data is actually stale.
//   • The UI never shows empty while reconnecting (isStale data is still shown).
//
// Usage (replace FloodApi.instance calls in providers):
//   final data = await CachedFloodApi.instance.allTelemetry();

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'flood_api.dart';
import 'local_cache_service.dart';

class CachedFloodApi {
  CachedFloodApi._();
  static final CachedFloodApi instance = CachedFloodApi._();

  final _api   = FloodApi.instance;
  final _cache = LocalCacheService.instance;

  // ── Generic cache-aware GET wrapper ───────────────────────────────────────

  Future<Map<String, dynamic>> _cached(
    String cacheKey,
    Future<Map<String, dynamic>> Function() fetcher, {
    bool bypassCache = false,
  }) async {
    if (!bypassCache) {
      final entry = await _cache.read(cacheKey);

      if (entry.value != null && !entry.isStale) {
        // Fresh hit — return immediately, no network call
        _log('cache HIT  $cacheKey');
        return _decode(entry.value!);
      }

      if (entry.value != null && entry.isStale) {
        // Stale hit — return old data NOW, refresh in background
        _log('cache STALE $cacheKey — revalidating in background');
        _revalidate(cacheKey, fetcher);
        return _decode(entry.value!);
      }
    }

    // Cache miss or bypass — fetch, store, return
    _log('cache MISS  $cacheKey');
    return _fetchAndStore(cacheKey, fetcher);
  }

  Future<Map<String, dynamic>> _fetchAndStore(
    String cacheKey,
    Future<Map<String, dynamic>> Function() fetcher,
  ) async {
    final result = await fetcher();
    if (result['status'] != 'error') {
      await _cache.write(cacheKey, jsonEncode(result));
    }
    return result;
  }

  // Fire-and-forget background revalidation — errors are swallowed
  void _revalidate(
    String cacheKey,
    Future<Map<String, dynamic>> Function() fetcher,
  ) {
    _fetchAndStore(cacheKey, fetcher).catchError((e) {
      _log('revalidation error for $cacheKey: $e');
      return <String, dynamic>{'status': 'error', 'error': '$e'};
    });
  }

  // ── Public API (mirrors FloodApi) ──────────────────────────────────────────

  Future<Map<String, dynamic>> allTelemetry({int limit = 1000}) =>
      _cached('live_telemetry_all_$limit',
          () => _api.allTelemetry(limit: limit));

  Future<Map<String, dynamic>> telemetryByState(
    String state, {
    String? station,
    int limit = 50,
  }) =>
      _cached('live_telemetry_${state}_${station ?? ''}_$limit',
          () => _api.telemetryByState(state, station: station, limit: limit));

  Future<Map<String, dynamic>> allLevels({int limit = 200}) =>
      _cached('live_levels_all_$limit',
          () => _api.allLevels(limit: limit));

  Future<Map<String, dynamic>> levelsByState(String state, {int limit = 200}) =>
      _cached('live_levels_${state}_$limit',
          () => _api.levelsByState(state, limit: limit));

  Future<Map<String, dynamic>> criticalAlerts() =>
      _cached('critical_alerts', () => _api.criticalAlerts());

  Future<Map<String, dynamic>> cwcForecast({
    required String city,
    required String state,
  }) =>
      _cached('cwc_ffs_${city}_$state',
          () => _api.cwcForecast(city: city, state: state));

  Future<Map<String, dynamic>> cwcStations() =>
      _cached('cwc_stations', () => _api.cwcStations());

  Future<Map<String, dynamic>> reservoirLevels(String state) =>
      _cached('cwc_reservoir_$state',
          () => _api.reservoirLevels(state));

  Future<Map<String, dynamic>> weatherCurrent(String location) =>
      _cached('weather_current_$location',
          () => _api.weatherCurrent(location));

  Future<Map<String, dynamic>> weatherForecast(String location) =>
      _cached('weather_forecast_$location',
          () => _api.weatherForecast(location));

  Future<Map<String, dynamic>> pipelineFeatures({
    required String state,
    String? station,
  }) =>
      _cached('pipeline_features_${state}_${station ?? ''}',
          () => _api.pipelineFeatures(state: state, station: station));

  Future<Map<String, dynamic>> stateSeverity() =>
      _cached('state_severity', () => _api.stateSeverity());

  // Non-cacheable: predict and trigger are POST/side-effect calls
  Future<Map<String, dynamic>> predict(Map<String, dynamic> payload) =>
      _api.predict(payload);

  Future<Map<String, dynamic>> triggerIngestion() =>
      _api.triggerIngestion();

  /// Force-invalidate a specific cache key (e.g. after manual refresh)
  Future<void> invalidate(String cacheKey) => _cache.delete(cacheKey);

  /// Clear the entire cache (e.g. on logout or settings reset)
  Future<void> clearAll() => _cache.clearAll();

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _decode(String json) {
    try {
      final parsed = jsonDecode(json);
      return parsed is Map<String, dynamic>
          ? parsed
          : {'status': 'success', 'data': parsed};
    } catch (_) {
      return {'status': 'error', 'error': 'Cache decode failed'};
    }
  }

  void _log(String msg) {
    if (AppConfig.isDebugLogging || !AppConfig.isProduction) {
      debugPrint('[CachedFloodApi] $msg');
    }
  }
}
