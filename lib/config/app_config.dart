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

  static const String baseUrl = String.fromEnvironment(
    'EQUINOX_BH_BASE_URL',
    defaultValue: 'https://equinox-bh.onrender.com',
  );

  static const String backupUrl = String.fromEnvironment(
    'EQUINOX_BH_BACKUP_URL',
    defaultValue: '',
  );

  static const String apiToken = String.fromEnvironment(
    'EQUINOX_BH_API_TOKEN',
    defaultValue: '',
  );

  static bool get isProduction  => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging     => environment == 'staging';
  static bool get isLoggingEnabled => debugLogging || !isProduction || kDebugMode;
  static bool get isDebugLogging   => isLoggingEnabled;

  static const int pollSeconds = int.fromEnvironment(
    'EQUINOX_BH_POLL_SECONDS', defaultValue: 0,
  );

  static int get healthRetries => 3;
  static int get maxRetries    => 3;
  static String get env        => environment;

  // ── Standard API endpoint paths ────────────────────────────────────────────────────
  static String get epHealth              => '/health';
  // FIX: /predict/v2 returns 404 on the live backend; use /predict instead
  static String get epPredict             => '/predict';
  static String get epCwcFfs              => '/cwc/ffs';
  static String get epCwcStations         => '/cwc/stations';
  static String get epLiveTelemetry       => '/live/telemetry';
  static String get epLiveLevels          => '/live/levels';
  static String get epCriticalAlerts      => '/alerts/critical';
  static String get epPipelineManifest    => '/pipeline/manifest';
  static String get epStateSeverity       => '/state/severity';
  static String get epLiveLevels2         => '/live/levels/v2';
  static String get epWeatherCurrent      => '/weather/current';
  static String get epWeatherForecast     => '/weather/forecast';
  static String get epNdmaAdvisories      => '/ndma/advisories';
  static String get epNdmaContacts        => '/ndma/contacts';

  // ── Named aliases (used by tests + services) ─────────────────────────────────────
  static String get healthEndpoint            => epHealth;
  static String get liveTelemetryEndpoint     => epLiveTelemetry;
  static String get liveLevelsEndpoint        => epLiveLevels;
  static String get criticalAlertsEndpoint    => epCriticalAlerts;
  static String get pipelineManifestEndpoint  => epPipelineManifest;
  static String get stateSeverityEndpoint     => epStateSeverity;

  /// Aliases expected by test/constants_domain_test.dart
  static String get predictLegacyEndpoint     => '/predict';
  static String get weatherCurrentEndpoint    => epWeatherCurrent;
  static String get weatherForecastEndpoint   => epWeatherForecast;

  // ── Duration / interval aliases ──────────────────────────────────────────────────────
  static const Duration coldStartTimeout  = Duration(seconds: 45);
  static const Duration healthTimeout     = Duration(seconds: 10);
  static Duration get requestTimeout      => const Duration(seconds: 15);
  static Duration get realtimeInterval    => const Duration(minutes: 5);
  static Duration get cacheTtl            => const Duration(minutes: 15);
  static Duration get backgroundInterval  => const Duration(minutes: 30);

  /// How often the app polls — alias for test/constants_domain_test.dart
  static Duration get pollingInterval     => const Duration(minutes: 5);

  /// Animation durations — used by test/constants_domain_test.dart
  static Duration get shortAnimDuration   => const Duration(milliseconds: 200);
  static Duration get longAnimDuration    => const Duration(milliseconds: 600);
}
