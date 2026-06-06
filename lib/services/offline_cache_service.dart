import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves issue #26: Offline Data Access with Local Caching
/// Uses SharedPreferences for lightweight caching until Drift is wired in.
/// Drift integration (full SQLite ORM) is scaffolded in local_database.dart
class OfflineCacheService {
  static final OfflineCacheService _instance =
      OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  static const Duration _cacheTtl = Duration(minutes: 5);
  static const Duration _maxCacheAge = Duration(days: 7);

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      debugPrint('Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
    });
    await _pruneExpiredCache();
  }

  Future<void> cacheData(
      String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = jsonEncode({
      'data': data,
      'cached_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString('cache_$key', entry);
  }

  Future<void> cacheList(
      String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = jsonEncode({
      'data': data,
      'cached_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString('cache_$key', entry);
  }

  Future<Map<String, dynamic>?> getCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_$key');
    if (raw == null) return null;
    final entry = jsonDecode(raw) as Map<String, dynamic>;
    final cachedAt = DateTime.parse(entry['cached_at']);
    if (DateTime.now().difference(cachedAt) > _cacheTtl && _isOnline) {
      return null; // stale when online; use fresh data
    }
    return entry['data'] as Map<String, dynamic>?;
  }

  Future<List<Map<String, dynamic>>?> getCachedList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_$key');
    if (raw == null) return null;
    final entry = jsonDecode(raw) as Map<String, dynamic>;
    final cachedAt = DateTime.parse(entry['cached_at']);
    if (DateTime.now().difference(cachedAt) > _cacheTtl && _isOnline) {
      return null;
    }
    final list = entry['data'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<DateTime?> getLastSyncTime(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_$key');
    if (raw == null) return null;
    final entry = jsonDecode(raw) as Map<String, dynamic>;
    return DateTime.parse(entry['cached_at']);
  }

  Future<void> _pruneExpiredCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_'));
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final entry = jsonDecode(raw) as Map<String, dynamic>;
        final cachedAt = DateTime.parse(entry['cached_at']);
        if (DateTime.now().difference(cachedAt) > _maxCacheAge) {
          await prefs.remove(key);
          debugPrint('Cache pruned: $key');
        }
      } catch (_) {
        await prefs.remove(key);
      }
    }
  }

  Stream<bool> get connectivityStream =>
      _connectivity.onConnectivityChanged
          .map((result) => result != ConnectivityResult.none);
}
