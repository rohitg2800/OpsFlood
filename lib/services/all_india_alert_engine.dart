// lib/services/all_india_alert_engine.dart
//
// OpsFlood — AllIndiaAlertEngine (STUBBED)
//
// Removed: was polling /api/live-levels on OpsFlood backend every 5 min
// for all states. Replaced by ThresholdAlertService which calls GloFAS
// directly, and WrdBiharService for Bihar-specific live gauge data.

class AllIndiaAlertEngine {
  /// No-op.
  Future<void> start() async {}

  /// No-op.
  void stop() {}
}
