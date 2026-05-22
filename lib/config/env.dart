// OpsFlood — Environment Configuration
// ─────────────────────────────────────────────────────────────────────────────
// P2: Replace hardcoded URLs in constants.dart with --dart-define overrides.
//
// Usage:
//   flutter run  --dart-define=OPSFLOOD_BASE_URL=https://opsflood.onrender.com
//   flutter build apk --dart-define=OPSFLOOD_BASE_URL=https://opsflood.onrender.com
//                     --dart-define=OPSFLOOD_ENV=production
//
// When --dart-define is NOT provided, the defaults below are used,
// so existing `flutter run` with no flags still works.
// ─────────────────────────────────────────────────────────────────────────────
library;

class Env {
  Env._();

  // ── URLs ──────────────────────────────────────────────────────────────────
  /// Primary OpsFlood backend base URL.
  /// Override: --dart-define=OPSFLOOD_BASE_URL=https://your-backend.com
  static const baseUrl = String.fromEnvironment(
    'OPSFLOOD_BASE_URL',
    defaultValue: 'https://opsflood.onrender.com',
  );

  /// Backup backend (cold-start failover).
  /// Override: --dart-define=OPSFLOOD_BACKUP_URL=https://backup.onrender.com
  static const backupUrl = String.fromEnvironment(
    'OPSFLOOD_BACKUP_URL',
    defaultValue: 'https://opsflood-backup.onrender.com',
  );

  // ── Environment name ──────────────────────────────────────────────────────
  /// 'development' | 'staging' | 'production'
  /// Override: --dart-define=OPSFLOOD_ENV=production
  static const env = String.fromEnvironment(
    'OPSFLOOD_ENV',
    defaultValue: 'development',
  );

  static bool get isProduction  => env == 'production';
  static bool get isStaging     => env == 'staging';
  static bool get isDevelopment => env == 'development';

  // ── Feature flags ─────────────────────────────────────────────────────────
  /// Enable verbose debug logging in release builds.
  /// --dart-define=OPSFLOOD_DEBUG_LOGGING=true
  static const debugLogging = bool.fromEnvironment(
    'OPSFLOOD_DEBUG_LOGGING',
    defaultValue: false,
  );

  // ── Polling interval ──────────────────────────────────────────────────────
  /// Polling interval in seconds (default 60).
  /// --dart-define=OPSFLOOD_POLL_SECONDS=30
  static const pollSeconds = int.fromEnvironment(
    'OPSFLOOD_POLL_SECONDS',
    defaultValue: 60,
  );

  static Duration get pollingInterval => Duration(seconds: pollSeconds);
}
