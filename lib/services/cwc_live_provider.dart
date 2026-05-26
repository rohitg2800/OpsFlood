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
//   3. Show reading.currentLevelM, reading.riskLabel, reading.alertColour.
//   4. For ML prediction, pass reading.currentLevelM to PredictionService.

library;

import 'cwc_direct_service.dart';
import '../constants.dart';
export 'cwc_direct_service.dart' show CwcLiveReading, CwcDataSource;

class CwcLiveProvider {
  CwcLiveProvider._();
  static final CwcLiveProvider instance = CwcLiveProvider._();

  final _service = CwcDirectService.instance;

  /// Fetches the best available live reading for a given city.
  /// Maps directly from AppConstants.monitoredCities entry.
  Future<CwcLiveReading> getReading({
    required String city,
    required String state,
    required String river,
    double warningLevel = AppConstants.defaultWarningLevel,
    double dangerLevel  = AppConstants.defaultDangerLevel,
  }) =>
      _service.getLiveReading(
        city:         city,
        state:        state,
        river:        river,
        warningLevel: warningLevel,
        dangerLevel:  dangerLevel,
      );

  /// Bulk fetch all monitored cities.
  Future<List<CwcLiveReading>> getAllReadings() =>
      _service.getAllLiveReadings();

  /// Only cities currently at SEVERE or CRITICAL level.
  Future<List<CwcLiveReading>> getActiveAlerts() =>
      _service.getActiveAlerts();

  /// Force refresh (called on pull-to-refresh).
  Future<List<CwcLiveReading>> refresh() =>
      _service.forceRefresh();

  /// Convenience: get reading from a monitoredCities map entry.
  Future<CwcLiveReading> getReadingFromMap(Map<String, dynamic> mc) =>
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
