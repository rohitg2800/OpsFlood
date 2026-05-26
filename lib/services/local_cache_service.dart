// lib/services/local_cache_service.dart
//
// OpsFlood — Local Cache Service v1.0
//
// SharedPreferences-backed offline cache.
// Keyed by API path. TTL = AppConfig.cacheTtl (default 5 min).
// Stale-while-revalidate: returns stale data with isStale=true
// instead of throwing, so UI never shows empty on reconnect.
//
// Auto-purges entries older than 24 h to keep storage lean.

library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class CacheEntry {
  final String? value;   // JSON string, null if not found
  final bool    isStale; // true if older than AppConfig.cacheTtl

  const CacheEntry({required this.value, required this.isStale});
}

class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  // Internal prefix for all keys so we don't collide with other prefs
  static const String _kPrefix    = 'opsflood_cache__';
  static const String _kTsPrefix  = 'opsflood_ts__';
  static const Duration _purgeTtl = Duration(hours: 24);

  SharedPreferences? _prefs;

  // Call once from main() after WidgetsFlutterBinding.ensureInitialized()
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _purgeExpired(); // fire-and-forget
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> write(String path, String jsonValue) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final key   = _kPrefix  + _sanitise(path);
    final tsKey = _kTsPrefix + _sanitise(path);
    await Future.wait([
      prefs.setString(key,   jsonValue),
      prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch),
    ]);
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<CacheEntry> read(String path) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final key   = _kPrefix  + _sanitise(path);
    final tsKey = _kTsPrefix + _sanitise(path);

    final value = prefs.getString(key);
    if (value == null) return const CacheEntry(value: null, isStale: false);

    final tsMs   = prefs.getInt(tsKey) ?? 0;
    final age    = DateTime.now().millisecondsSinceEpoch - tsMs;
    final isStale = age > AppConfig.cacheTtl.inMilliseconds;

    return CacheEntry(value: value, isStale: isStale);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(String path) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final key   = _kPrefix  + _sanitise(path);
    final tsKey = _kTsPrefix + _sanitise(path);
    await Future.wait([prefs.remove(key), prefs.remove(tsKey)]);
  }

  Future<void> clearAll() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final keys  = prefs.getKeys()
        .where((k) => k.startsWith(_kPrefix) || k.startsWith(_kTsPrefix))
        .toList();
    for (final k in keys) await prefs.remove(k);
    debugPrint('[LocalCache] Cleared ${keys.length} entries');
  }

  // ── Auto-purge entries older than 24 h ────────────────────────────────────

  void _purgeExpired() async {
    try {
      final prefs    = _prefs ?? await SharedPreferences.getInstance();
      final now      = DateTime.now().millisecondsSinceEpoch;
      final tsKeys   = prefs.getKeys()
          .where((k) => k.startsWith(_kTsPrefix))
          .toList();
      int purged = 0;
      for (final tsKey in tsKeys) {
        final tsMs = prefs.getInt(tsKey) ?? 0;
        if (now - tsMs > _purgeTtl.inMilliseconds) {
          final dataKey = _kPrefix + tsKey.substring(_kTsPrefix.length);
          await Future.wait([prefs.remove(tsKey), prefs.remove(dataKey)]);
          purged++;
        }
      }
      if (purged > 0) debugPrint('[LocalCache] Purged $purged stale entries');
    } catch (e) {
      debugPrint('[LocalCache] Purge error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _sanitise(String path) =>
      path.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
}
