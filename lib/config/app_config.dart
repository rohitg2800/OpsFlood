// lib/config/app_config.dart
//
// OpsFlood Bihar — AppConfig (v3.1 Bihar-only)
//
// Single source of truth for every app-wide configuration constant.
// Add --dart-define=OPSFLOOD_BASE_URL=https://... at build time to
// override the default production URL.
library;

class AppConfig {
  AppConfig._();

  // ── App identity ──────────────────────────────────────────────────────────
  static const String appName         = 'OpsFlood Bihar';
  static const String appVersion      = '2.0.0';
  static const String defaultState    = 'Bihar';
  static const String defaultDistrict = 'Patna';

  // ── API base URL ──────────────────────────────────────────────────────────
  static const String baseUrl = String.fromEnvironment(
    'OPSFLOOD_BASE_URL',
    defaultValue: 'https://opsflood-backend.onrender.com',
  );

  // ── WRD Bihar scrape endpoint ─────────────────────────────────────────────
  static const String wrdBiharUrl =
      'https://irrigation.befiqr.in/state/table/rivers';

  // ── API endpoints ─────────────────────────────────────────────────────────
  static const String epHealth           = '/health';
  static const String epPredict          = '/predict';
  static const String epLiveTelemetry    = '/live/telemetry';
  static const String epLiveLevels       = '/live/levels';
  static const String epCriticalAlerts   = '/alerts/critical';
  static const String epCwcFfs           = '/cwc/ffs';
  static const String epCwcStations      = '/cwc/stations';
  static const String epCwcReservoir     = '/cwc/reservoir';
  static const String epWeatherCurrent   = '/weather/current';
  static const String epWeatherForecast  = '/weather/forecast';
  static const String epPipelineFeatures = '/pipeline/features';
  static const String epPipelineManifest = '/pipeline/manifest';
  static const String epStateSeverity    = '/severity/state';
  static const String epIngestionRun     = '/pipeline/ingest';
  static const String epModelMetrics     = '/model/metrics';
  static const String epNdmaAdvisories   = '/ndma/advisories';
  static const String epNdmaContacts     = '/ndma/contacts';

  // ── Authentication ────────────────────────────────────────────────────────
  // Set via --dart-define=OPSFLOOD_API_TOKEN=... at build time.
  static const String apiToken = String.fromEnvironment(
    'OPSFLOOD_API_TOKEN',
    defaultValue: '',
  );

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const Duration connectTimeout    = Duration(seconds: 15);
  static const Duration receiveTimeout    = Duration(seconds: 30);
  static const Duration requestTimeout    = Duration(seconds: 20);
  static const Duration healthTimeout     = Duration(seconds: 10);
  static const Duration coldStartTimeout  = Duration(seconds: 45);

  // ── Polling intervals ─────────────────────────────────────────────────────
  // WRD Bihar publishes bulletins every 30 min during flood season.
  // 3-minute realtime poll catches updates promptly.
  static const Duration realtimeInterval    = Duration(minutes: 3);
  static const Duration backgroundInterval  = Duration(minutes: 15);

  // ── Cache TTL ─────────────────────────────────────────────────────────────
  // Weather (open-meteo) and GloFAS tiles cached for 5 min.
  // WRD Bihar readings cached inside WrdBiharService (10 min).
  static const Duration cacheTtl = Duration(minutes: 5);

  // ── Retry config ──────────────────────────────────────────────────────────
  static const int      maxRetries        = 3;
  static const Duration retryBackoff      = Duration(seconds: 2);
  static const Duration serverOverloadWait = Duration(seconds: 10);

  // ── Flood thresholds (danger-level ratios) ────────────────────────────────
  static const double criticalRatio  = 1.00;
  static const double highRatio      = 0.85;
  static const double moderateRatio  = 0.70;

  // ── Notification channels ─────────────────────────────────────────────────
  static const String alertChannelId   = 'bihar_flood_alerts';
  static const String alertChannelName = 'Bihar Flood Alerts';

  // ── Debug / env flags ─────────────────────────────────────────────────────
  static const bool isProduction = bool.fromEnvironment(
    'dart.vm.product',
    defaultValue: false,
  );
  static const bool isDebugLogging = !isProduction;
}
