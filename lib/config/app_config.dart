// lib/config/app_config.dart
//
// OpsFlood — Single Source of Truth: App Configuration
//
// ALL bool.fromEnvironment / String.fromEnvironment calls MUST be const.
// Override at build time via:
//   flutter run --dart-define=OPSFLOOD_BASE_URL=http://localhost:8000
//   flutter build apk --dart-define=OPSFLOOD_ENV=production
library;

class AppConfig {
  AppConfig._();

  // ── Environment ────────────────────────────────────────────────────────────────────
  static const String env = String.fromEnvironment(
    'OPSFLOOD_ENV', defaultValue: 'production',
  );
  static bool get isProduction  => env == 'production';
  static bool get isDevelopment => env == 'development';

  // MUST remain const — bool.fromEnvironment is only valid as a const expression
  static const bool isDebugLogging = bool.fromEnvironment(
    'OPSFLOOD_DEBUG_LOGGING', defaultValue: false,
  );

  // ── Primary backend ───────────────────────────────────────────────────────────
  static const String baseUrl = String.fromEnvironment(
    'OPSFLOOD_BASE_URL',
    defaultValue: 'https://opsflood.onrender.com',
  );

  // ── Timeouts ──────────────────────────────────────────────────────────────────
  static const Duration requestTimeout   = Duration(seconds: 65);
  static const Duration healthTimeout    = Duration(seconds: 10);
  static const Duration coldStartTimeout = Duration(seconds: 65);

  // ── Retry policy ────────────────────────────────────────────────────────────────
  static const int      maxRetries           = 3;
  static const int      healthRetries        = 2;
  static const Duration retryBackoff         = Duration(seconds: 2);
  static const Duration serverOverloadWait   = Duration(seconds: 5);

  // ── Polling ────────────────────────────────────────────────────────────────────
  static const int _pollSecondsOverride = int.fromEnvironment(
    'OPSFLOOD_POLL_SECONDS', defaultValue: 0,
  );
  // Non-const getter is fine; only the fromEnvironment call itself must be const
  static Duration get realtimeInterval =>
      _pollSecondsOverride > 0
          ? Duration(seconds: _pollSecondsOverride)
          : const Duration(seconds: 45);
  static const Duration backgroundInterval = Duration(minutes: 5);

  // ── Cache ──────────────────────────────────────────────────────────────────────────
  static const Duration cacheTtl = Duration(minutes: 5);

  // ── Endpoints ───────────────────────────────────────────────────────────────────
  static const String epHealth           = '/health';
  static const String epPredict          = '/predict';
  static const String epLiveTelemetry    = '/api/live-telemetry';
  static const String epLiveLevels       = '/api/live-levels';
  static const String epCriticalAlerts   = '/api/critical-alerts';
  static const String epCwcFfs           = '/api/cwc-ffs/station';
  static const String epCwcStations      = '/api/cwc-stations';
  static const String epCwcReservoir     = '/api/cwc-reservoir/state';
  static const String epWeatherCurrent   = '/weather/current';
  static const String epWeatherForecast  = '/weather/forecast';
  static const String epPipelineFeatures = '/api/pipeline/features';
  static const String epPipelineManifest = '/api/pipeline/manifest';
  static const String epStateSeverity    = '/api/state-severity';
  static const String epIngestionRun     = '/ingestion/run';
  static const String epModelMetrics     = '/model-metrics';
}
