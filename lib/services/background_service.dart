// lib/services/background_service.dart
//
// OpsFlood — Background Service (STUBBED)
//
// All Workmanager periodic tasks removed. The app fetches live data
// directly from the official Bihar WRD portal (WrdBiharService) and
// GloFAS on-demand. No background polling is needed.

class BackgroundService {
  BackgroundService._();

  /// No-op — background tasks removed.
  static Future<void> init() async {}

  /// No-op.
  static Future<void> cancel() async {}
}
