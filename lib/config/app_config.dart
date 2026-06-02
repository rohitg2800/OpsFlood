// lib/config/app_config.dart
// EQUINOX-BH — Single Source of Truth: App Configuration
//
// Usage:
//   flutter run --dart-define=EQUINOX_BH_BASE_URL=http://localhost:8000
//   flutter build apk --dart-define=EQUINOX_BH_ENV=production

import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String environment = String.fromEnvironment(
    'EQUINOX_BH_ENV', defaultValue: 'production',
  );

  static const bool debugLogging = bool.fromEnvironment(
    'EQUINOX_BH_DEBUG_LOGGING', defaultValue: false,
  );

  /// Primary backend URL.
  static const String baseUrl = String.fromEnvironment(
    'EQUINOX_BH_BASE_URL',
    defaultValue: 'https://equinox-bh.onrender.com',
  );

  /// Fallback / backup backend URL for resilience.
  static const String backupUrl = String.fromEnvironment(
    'EQUINOX_BH_BACKUP_URL',
    defaultValue: '',
  );

  /// Optional bearer token for authenticated endpoints.
  static const String apiToken = String.fromEnvironment(
    'EQUINOX_BH_API_TOKEN',
    defaultValue: '',
  );

  static bool get isProduction  => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging     => environment == 'staging';

  static bool get isLoggingEnabled =>
      debugLogging || !isProduction || kDebugMode;

  static bool get isDebugLogging => isLoggingEnabled;

  /// How often the app polls the backend for fresh data (seconds).
  static const int pollSeconds = int.fromEnvironment(
    'EQUINOX_BH_POLL_SECONDS', defaultValue: 0,
  );

  static int get healthRetries => 3;

  // ── Standard API endpoint paths ─────────────────────────────────────────

  static String get epHealth   => '$baseUrl/health';
  static String get epPredict  => '$baseUrl/predict/v2';

  // ── Extended endpoint paths ────────────────────────────────────────────

  static String get epCwcFfs            => '$baseUrl/cwc/ffs';
  static String get epCwcStations       => '$baseUrl/cwc/stations';
  static String get epLiveTelemetry     => '$baseUrl/live/telemetry';
  static String get epLiveLevels        => '$baseUrl/live/levels';
  static String get epCriticalAlerts    => '$baseUrl/alerts/critical';
  static String get epPipelineManifest  => '$baseUrl/pipeline/manifest';
  static String get epStateSeverity     => '$baseUrl/state/severity';
  static String get epLiveLevels2       => '$baseUrl/live/levels/v2';

  // ── Timeouts ──────────────────────────────────────────────────────────

  static const Duration coldStartTimeout = Duration(seconds: 45);
  static const Duration healthTimeout    = Duration(seconds: 10);
}
