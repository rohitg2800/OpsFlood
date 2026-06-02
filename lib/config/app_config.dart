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
  /// Override at build time: --dart-define=EQUINOX_BH_BASE_URL=https://...
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

  /// How often the app polls the backend for fresh data (seconds).
  /// 0 = use the default defined inside each service.
  static const int pollSeconds = int.fromEnvironment(
    'EQUINOX_BH_POLL_SECONDS', defaultValue: 0,
  );

  // ── API endpoint paths ─────────────────────────────────────────────────────

  /// Health-check endpoint — GET /health
  static String get epHealth  => '$baseUrl/health';

  /// ML prediction endpoint — POST /predict/v2
  static String get epPredict => '$baseUrl/predict/v2';

  // ── Timeouts ───────────────────────────────────────────────────────────────

  /// Timeout for a cold-start wake-up health check (Render spins down on idle).
  static const Duration coldStartTimeout = Duration(seconds: 45);

  /// Timeout for a normal (warm) health check.
  static const Duration healthTimeout = Duration(seconds: 10);
}
