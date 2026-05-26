// lib/config/app_config.dart
//
// OpsFlood Bihar — AppConfig (v3.0 Bihar-only)
//
// All app-wide configuration. Edit only this file to tune:
//   - API base URL
//   - Poll intervals
//   - Cache TTL
//   - App identity
library;

class AppConfig {
  AppConfig._();

  // ── App identity ──────────────────────────────────────────────────────────
  static const String appName        = 'OpsFlood Bihar';
  static const String appVersion     = '2.0.0';
  static const String defaultState   = 'Bihar';
  static const String defaultDistrict = 'Patna';

  // ── API ───────────────────────────────────────────────────────────────────
  // Set via --dart-define=OPSFLOOD_BASE_URL=https://... at build time.
  // Falls back to production URL.
  static const String baseUrl = String.fromEnvironment(
    'OPSFLOOD_BASE_URL',
    defaultValue: 'https://opsflood-backend.onrender.com',
  );

  // ── WRD Bihar scrape endpoint ─────────────────────────────────────────────
  // Live table: https://irrigation.befiqr.in/state/table/rivers
  // This is fetched directly by WrdBiharService; listed here for reference.
  static const String wrdBiharUrl = 'https://irrigation.befiqr.in/state/table/rivers';

  // ── Poll intervals ────────────────────────────────────────────────────────
  // WRD Bihar updates its bulletin every 30 min during flood season.
  // 3-minute app poll catches the update promptly without hammering the server.
  static const Duration realtimeInterval = Duration(minutes: 3);

  // ── Cache TTL ─────────────────────────────────────────────────────────────
  // Weather (open-meteo) and GloFAS tiles cached for 5 min.
  // WRD Bihar readings cached inside WrdBiharService (10 min).
  static const Duration cacheTtl = Duration(minutes: 5);

  // ── HTTP timeouts ─────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Flood thresholds (m MSL ratios) ───────────────────────────────────────
  static const double criticalRatio  = 1.00; // at or above danger level
  static const double highRatio      = 0.85; // 85% of danger level
  static const double moderateRatio  = 0.70; // 70% of danger level

  // ── Notification channels ─────────────────────────────────────────────────
  static const String alertChannelId   = 'bihar_flood_alerts';
  static const String alertChannelName = 'Bihar Flood Alerts';
}
