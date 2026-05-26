// lib/services/offline_rule_engine.dart
//
// OpsFlood — OfflineRuleEngine (STUBBED)
//
// Removed: was re-evaluating cached OpsFlood backend data offline.
// The app now fetches from the official Bihar WRD portal (live) and
// GloFAS (live), so a stale-cache rule engine is no longer needed.

class OfflineRuleEngine {
  OfflineRuleEngine._();
  static final OfflineRuleEngine instance = OfflineRuleEngine._();

  /// No-op.
  Future<void> init() async {}

  /// No-op.
  void start() {}

  /// No-op.
  void stop() {}
}
