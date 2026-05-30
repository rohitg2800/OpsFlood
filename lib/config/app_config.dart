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
  /// the candidate-list logic. Override via --dart-define=EQUINOX_BH_BACKUP_URL.
  static const String backupUrl = String.fromEnvironment(
    'EQUINOX_BH_BACKUP_URL',
    defaultValue: '',
  );

  /// Optional bearer token for authenticated endpoints.
  static const String apiToken = String.fromEnvironment(
    'EQUINOX_BH_API_TOKEN',
    defaultValue: '',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';

  static bool get isLoggingEnabled =>
      debugLogging || !isProduction || kDebugMode;

  /// How often the app polls the backend for fresh data (seconds).
  /// 0 = use the default defined inside each service.
  static const int pollSeconds = int.fromEnvironment(
    'EQUINOX_BH_POLL_SECONDS', defaultValue: 0,
  );
}
