// lib/config/env.dart
//
// OpsFlood — Environment variable helpers
//
// Reads compile-time --dart-define values and flutter_dotenv values.
// AppConfig is the canonical source of defaults; this file only adds
// helpers for values NOT in AppConfig (db prefix, feature flags).
//
// Priority order:
//   1. --dart-define at build time (CI / release builds)
//   2. .env file loaded by flutter_dotenv at runtime (dev / local)
//   3. Hardcoded defaults matching AppConfig

library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_config.dart';

class AppEnvironment {
  AppEnvironment._();

  static const bool isProduction = AppConfig.isProduction as bool? ?? true;

  // Never show synthetic / mock data in any build
  static const bool useMockData = false;

  // ── Backend URL ────────────────────────────────────────────────────────────
  // Reads .env BASE_URL at runtime (dotenv), falls back to AppConfig.baseUrl
  // which is wired via --dart-define=OPSFLOOD_BASE_URL at build time.
  static String get apiBaseUrl {
    final dotenvVal = _dot('BASE_URL');
    if (dotenvVal.isNotEmpty) return dotenvVal;
    return AppConfig.baseUrl; // 'https://opsflood.onrender.com'
  }

  // ── Firestore collection prefix ────────────────────────────────────────────
  // Set DB_COLLECTION_PREFIX=staging in .env to isolate staging writes.
  static String get dbCollectionPrefix => _dot('DB_COLLECTION_PREFIX');

  // ── Feature flags ──────────────────────────────────────────────────────────
  // Set ENABLE_FIRESTORE_MIRROR=false in .env to disable Firestore writes
  // (useful for data-saver mode on slow networks).
  static bool get enableFirestoreMirror {
    final v = _dot('ENABLE_FIRESTORE_MIRROR');
    if (v.isEmpty) return true; // on by default
    return v.toLowerCase() != 'false';
  }

  // ── Poll interval override ─────────────────────────────────────────────────
  // Set POLL_SECONDS=120 in .env during dev to reduce API calls.
  static Duration get pollInterval {
    final v = _dot('POLL_SECONDS');
    final s = int.tryParse(v);
    if (s != null && s > 0) return Duration(seconds: s);
    return AppConfig.realtimeInterval;
  }

  // ── API timeout override ────────────────────────────────────────────────────
  static Duration get apiTimeout {
    final v = _dot('API_TIMEOUT');
    final s = int.tryParse(v);
    if (s != null && s > 0) return Duration(seconds: s);
    return AppConfig.requestTimeout;
  }

  // ── Helper: safe dotenv read (empty string if key missing / dotenv not loaded)
  static String _dot(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }
}
