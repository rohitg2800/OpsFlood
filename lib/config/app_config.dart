// lib/config/app_config.dart
// OpsFlood — Single Source of Truth: App Configuration
library;

class AppConfig {
  AppConfig._();

  static const String env = String.fromEnvironment(
    'OPSFLOOD_ENV', defaultValue: 'development',
  );
  static bool get isProduction  => env == 'production';
  static bool get isDevelopment => env == 'development';

  static const bool isDebugLogging = bool.fromEnvironment(
    'OPSFLOOD_DEBUG_LOGGING', defaultValue: true,
  );

  // ── Primary backend ───────────────────────────────────────────────────────
  //
  //  On Android emulator, 127.0.0.1 resolves to the EMULATOR itself, not the
  //  host Mac.  Use 10.0.2.2 to reach Mac localhost from the emulator.
  //  On a physical Android device use the Mac's LAN IP (e.g. 192.168.x.x:8000).
  //
  //  Override at build time:
  //    flutter run --dart-define=OPSFLOOD_BASE_URL=http://10.0.2.2:8000
  //    flutter run --dart-define=OPSFLOOD_BASE_URL=http://192.168.1.42:8000
  //
  static const String baseUrl = String.fromEnvironment(
    'OPSFLOOD_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',   // Android emulator → Mac localhost
  );

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const Duration requestTimeout   = Duration(seconds: 20);
  static const Duration healthTimeout    = Duration(seconds: 8);
  static const Duration coldStartTimeout = Duration(seconds: 20);

  // ── Retry policy ──────────────────────────────────────────────────────────
  static const int      maxRetries         = 2;
  static const int      healthRetries      = 1;
  static const Duration retryBackoff       = Duration(seconds: 1);
  static const Duration serverOverloadWait = Duration(seconds: 3);

  // ── Polling ───────────────────────────────────────────────────────────────
  static const int _pollSecondsOverride = int.fromEnvironment(
    'OPSFLOOD_POLL_SECONDS', defaultValue: 0,
  );
  static Duration get realtimeInterval =>
      _pollSecondsOverride > 0
          ? Duration(seconds: _pollSecondsOverride)
          : const Duration(seconds: 45);
  static const Duration backgroundInterval = Duration(minutes: 5);

  // ── Cache ──────────────────────────────────────────────────────────────────
  static const Duration cacheTtl = Duration(minutes: 5);

  // ── Endpoints ─────────────────────────────────────────────────────────────
  static const String epHealth           = '/health';
  static const String epPredict          = '/api/predict';
  static const String epLiveTelemetry    = '/api/stations';
  static const String epLiveLevels       = '/api/stations';
  static const String epCriticalAlerts   = '/api/critical-alerts';
  static const String epCwcFfs           = '/api/cwc-ffs';
  static const String epCwcStations      = '/api/stations';
  static const String epCwcReservoir     = '/api/cwc-reservoir';
  static const String epWeatherCurrent   = '/api/weather/current';
  static const String epWeatherForecast  = '/api/weather/forecast';
  static const String epPipelineFeatures = '/api/pipeline/features';
  static const String epPipelineManifest = '/api/pipeline/manifest';
  static const String epStateSeverity    = '/api/state-severity';
  static const String epIngestionRun     = '/api/ingestion/run';
  static const String epModelMetrics     = '/api/model-metrics';
}
