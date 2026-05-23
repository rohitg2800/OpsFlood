// lib/constants/app_config.dart
// Domain: API endpoints, polling config, animation durations

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // ── Backend URLs ─────────────────────────────────────────────────────────
  static String get baseUrl =>
      dotenv.maybeGet('BASE_URL') ?? 'https://opsflood.onrender.com';
  static String get backupBaseUrl => dotenv.maybeGet('BACKUP_URL') ?? '';

  // ── API Endpoints ─────────────────────────────────────────────────────────
  static const String healthEndpoint          = '/health';
  static const String liveTelemetryEndpoint   = '/api/live-telemetry';
  static const String liveLevelsEndpoint      = '/api/live-levels';
  static const String criticalAlertsEndpoint  = '/api/critical-alerts';
  static const String predictLegacyEndpoint   = '/predict/legacy';
  static const String weatherCurrentEndpoint  = '/weather/current';
  static const String weatherForecastEndpoint = '/weather/forecast';

  // ── Polling & retry ───────────────────────────────────────────────────────
  static const Duration pollingInterval = Duration(minutes: 5);
  static const int      maxRetries      = 3;

  // ── Animation ─────────────────────────────────────────────────────────────
  static const Duration shortAnimDuration = Duration(milliseconds: 300);
  static const Duration longAnimDuration  = Duration(milliseconds: 800);
}
