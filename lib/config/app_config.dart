// lib/config/app_config.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OpsFlood — Single Source of Truth: App Configuration                  ║
// ║                                                                          ║
// ║  ALL network settings, timeouts, endpoints, feature flags live here.   ║
// ║  NOTHING is hardcoded anywhere else in the app.                         ║
// ║                                                                          ║
// ║  Override at build time via --dart-define:                              ║
// ║    flutter run --dart-define=OPSFLOOD_BASE_URL=http://localhost:8000    ║
// ║    flutter build apk --dart-define=OPSFLOOD_ENV=production              ║
// ╚══════════════════════════════════════════════════════════════════════════╝
library;

class AppConfig {
  AppConfig._();

  // ── Environment ──────────────────────────────────────────────────────────
  static const String env = String.fromEnvironment(
    'OPSFLOOD_ENV', defaultValue: 'production',
  );
  static bool get isProduction  => env == 'production';
  static bool get isDevelopment => env == 'development';
  static bool get isDebugLogging => bool.fromEnvironment(
    'OPSFLOOD_DEBUG_LOGGING', defaultValue: false,
  );

  // ── Primary backend ───────────────────────────────────────────────────────
  // SINGLE entry point. Every API call in the app goes to this URL.
  // The OpsFlood backend proxies ALL external data (CWC, GloFAS, IMD, NDMA).
  // The Flutter app NEVER calls any external service directly.
  static const String baseUrl = String.fromEnvironment(
    'OPSFLOOD_BASE_URL',
    defaultValue: 'https://opsflood.onrender.com',
  );

  // ── Timeouts ─────────────────────────────────────────────────────────────
  // 65s: covers Render free-tier cold-start (~50s) + 15s buffer.
  static const Duration requestTimeout    = Duration(seconds: 65);
  // 10s: fast health probe after backend is known-warm.
  static const Duration healthTimeout     = Duration(seconds: 10);
  // 65s: first health probe on app open (backend may be cold).
  static const Duration coldStartTimeout  = Duration(seconds: 65);

  // ── Retry policy ─────────────────────────────────────────────────────────
  static const int    maxRetries           = 3;
  static const int    healthRetries        = 2;     // auto-retry health on timeout
  static const Duration retryBackoff       = Duration(seconds: 2);
  static const Duration serverOverloadWait = Duration(seconds: 5); // per attempt for 503

  // ── Polling intervals ─────────────────────────────────────────────────────
  // realtimeInterval  — river/dashboard screens (cancel on dispose)
  // backgroundInterval— Android background service (battery-safe)
  static const int    _pollSecondsOverride = int.fromEnvironment(
    'OPSFLOOD_POLL_SECONDS', defaultValue: 0,
  );
  static Duration get realtimeInterval =>
      _pollSecondsOverride > 0
          ? Duration(seconds: _pollSecondsOverride)
          : const Duration(seconds: 45);
  static const Duration backgroundInterval = Duration(minutes: 5);

  // ── Client-side cache TTL ─────────────────────────────────────────────────
  static const Duration cacheTtl = Duration(minutes: 5);

  // ── Endpoints (relative paths) ────────────────────────────────────────────
  // All paths are relative to baseUrl. No absolute URLs anywhere else.
  static const String epHealth           = '/health';
  static const String epPredict          = '/predict';              // ML inference
  static const String epLiveTelemetry    = '/api/live-telemetry';   // GloFAS discharge
  static const String epLiveLevels       = '/api/live-levels';      // gauge levels
  static const String epCriticalAlerts   = '/api/critical-alerts';  // severity filter
  static const String epCwcFfs           = '/api/cwc-ffs/station';  // CWC FFS proxy
  static const String epCwcStations      = '/api/cwc-stations';     // station registry
  static const String epCwcReservoir     = '/api/cwc-reservoir/state'; // reservoir
  static const String epWeatherCurrent   = '/weather/current';      // OpenMeteo current
  static const String epWeatherForecast  = '/weather/forecast';     // OpenMeteo forecast
  static const String epPipelineFeatures = '/api/pipeline/features'; // ML pre-fill
  static const String epPipelineManifest = '/api/pipeline/manifest';
  static const String epStateSeverity    = '/api/state-severity';
  static const String epIngestionRun     = '/ingestion/run';
  static const String epModelMetrics     = '/model-metrics';
}
