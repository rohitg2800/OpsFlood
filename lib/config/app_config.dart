// lib/config/app_config.dart
// OpsFlood — Single Source of Truth: App Configuration
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
  /// Override at build time: --dart-define=EQUINOX_BH_BASE_URL=https://...
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

  static bool get isProduction     => environment == 'production';
  static bool get isDevelopment    => environment == 'development';
  static bool get isStaging        => environment == 'staging';
  static bool get isLoggingEnabled => debugLogging || !isProduction || kDebugMode;
  static bool get isDebugLogging   => isLoggingEnabled;

  /// How often the app polls the backend for fresh data (seconds).
  /// 0 = use the default defined inside each service.
  static const int pollSeconds = int.fromEnvironment(
    'EQUINOX_BH_POLL_SECONDS', defaultValue: 0,
  );

  static int get healthRetries => 3;
  static int get maxRetries    => 3;
  static String get env        => environment;

  // ── API endpoint paths ────────────────────────────────────────────────
  static String get epHealth           => '$baseUrl/health';
  // FIX: /predict/v2 returns 404 on live backend; use /predict instead
  static String get epPredict          => '$baseUrl/predict';
  static String get epCwcFfs           => '$baseUrl/cwc/ffs';
  static String get epCwcStations      => '$baseUrl/cwc/stations';
  static String get epLiveTelemetry    => '$baseUrl/live/telemetry';
  static String get epLiveLevels       => '$baseUrl/live/levels';
  static String get epCriticalAlerts   => '$baseUrl/alerts/critical';
  static String get epPipelineManifest => '$baseUrl/pipeline/manifest';
  static String get epStateSeverity    => '$baseUrl/state/severity';
  static String get epLiveLevels2      => '$baseUrl/live/levels/v2';
  static String get epWeatherCurrent   => '$baseUrl/weather/current';
  static String get epWeatherForecast  => '$baseUrl/weather/forecast';
  static String get epNdmaAdvisories   => '$baseUrl/ndma/advisories';
  static String get epNdmaContacts     => '$baseUrl/ndma/contacts';

  // ── Named aliases (used by tests + services) ──────────────────────────
  static String get healthEndpoint           => epHealth;
  static String get liveTelemetryEndpoint    => epLiveTelemetry;
  static String get liveLevelsEndpoint       => epLiveLevels;
  static String get criticalAlertsEndpoint   => epCriticalAlerts;
  static String get pipelineManifestEndpoint => epPipelineManifest;
  static String get stateSeverityEndpoint    => epStateSeverity;
  static String get predictLegacyEndpoint    => '$baseUrl/predict';
  static String get weatherCurrentEndpoint   => epWeatherCurrent;
  static String get weatherForecastEndpoint  => epWeatherForecast;

  // ── Timeouts & intervals ──────────────────────────────────────────────
  static const Duration coldStartTimeout = Duration(seconds: 45);
  static const Duration healthTimeout    = Duration(seconds: 10);
  static Duration get requestTimeout     => const Duration(seconds: 15);
  static Duration get realtimeInterval   => const Duration(minutes: 5);
  static Duration get cacheTtl           => const Duration(minutes: 15);
  static Duration get backgroundInterval => const Duration(minutes: 30);
  static Duration get pollingInterval    => const Duration(minutes: 5);
}
