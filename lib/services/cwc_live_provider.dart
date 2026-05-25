// lib/services/cwc_live_provider.dart
//
// Central provider that wires CwcDirectService into the rest of the app.
// Screens call CwcLiveProvider.instance.getReading(city, state, river, ...)
// and get back real CWC data — no simulation, no hardcoded levels.
//
// Integration guide:
//   1. In your DashboardScreen / HomeScreen, import this file.
//   2. Call: final reading = await CwcLiveProvider.instance
//              .getReading(city: mc['city'], state: mc['state'], ...);
//   3. Show reading.level, reading.danger, and derive riskLabel from them.
//   4. For ML prediction, pass reading.level to PredictionService.

library;

import '../data/india_cities.dart';
import 'cwc_direct_service.dart';
import '../constants.dart';

// ── Alias: expose CwcReading as CwcLiveReading for backwards compat ───────────
typedef CwcLiveReading = CwcReading;

// Re-export so callers can reference CwcDataSource without extra imports.
export 'cwc_direct_service.dart' show CwcReading, CwcDataSource;

class CwcLiveProvider {
  CwcLiveProvider._();
  static final CwcLiveProvider instance = CwcLiveProvider._();

  final _service = CwcDirectService.instance;

  // ── City lookup helpers ───────────────────────────────────────────────────

  IndiaCity? _findCity({
    required String city,
    required String state,
    required String river,
    double warningLevel = AppConstants.defaultWarningLevel,
    double dangerLevel  = AppConstants.defaultDangerLevel,
  }) {
    // Try to find from IndiaCities registry first
    try {
      return IndiaCities.all.firstWhere(
        (c) => c.name.toLowerCase() == city.toLowerCase(),
      );
    } catch (_) {}
    // Fall back to building a minimal IndiaCity from the supplied parameters
    return IndiaCity(
      id:           city.toLowerCase().replaceAll(' ', '_'),
      name:         city,
      state:        state,
      river:        river,
      lat:          0,
      lon:          0,
      warningLevel: warningLevel,
      dangerLevel:  dangerLevel,
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetches the best available live reading for a given city.
  /// Returns null when no source could provide a valid gauge reading.
  Future<CwcReading?> getReading({
    required String city,
    required String state,
    required String river,
    double warningLevel = AppConstants.defaultWarningLevel,
    double dangerLevel  = AppConstants.defaultDangerLevel,
  }) {
    final ic = _findCity(
      city: city, state: state, river: river,
      warningLevel: warningLevel, dangerLevel: dangerLevel,
    )!;
    return _service.fetch(ic);
  }

  /// Bulk fetch all monitored cities.
  Future<List<CwcReading>> getAllReadings() async {
    final futures = AppConstants.monitoredCities.map((mc) {
      final ic = _findCity(
        city:         mc['city']  as String,
        state:        mc['state'] as String,
        river:        mc['river'] as String,
        warningLevel: _fp(mc['warning_level']),
        dangerLevel:  _fp(mc['danger_level']),
      )!;
      return _service.fetch(ic);
    });
    final results = await Future.wait(futures);
    return results.whereType<CwcReading>().toList();
  }

  /// Only cities currently at SEVERE or CRITICAL level
  /// (current >= danger_level).
  Future<List<CwcReading>> getActiveAlerts() async {
    final all = await getAllReadings();
    return all.where((r) => r.level >= r.danger).toList();
  }

  /// Force-clear the cache then re-fetch all cities.
  Future<List<CwcReading>> forceRefresh() {
    _service.clearCache();
    return getAllReadings();
  }

  /// Convenience: get reading from a monitoredCities map entry.
  Future<CwcReading?> getReadingFromMap(Map<String, dynamic> mc) =>
      getReading(
        city:         mc['city']          as String,
        state:        mc['state']         as String,
        river:        mc['river']         as String,
        warningLevel: _fp(mc['warning_level']),
        dangerLevel:  _fp(mc['danger_level']),
      );

  static double _fp(dynamic v) =>
      v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
}
