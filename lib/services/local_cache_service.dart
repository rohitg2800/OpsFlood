// lib/services/local_cache_service.dart
// EQUINOX-BH — Persistent key-value cache backed by SharedPreferences.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  SharedPreferences? _prefs;
  bool get isReady => _prefs != null;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (kDebugMode) debugPrint('[LocalCacheService] ready');
    } catch (e) {
      if (kDebugMode) debugPrint('[LocalCacheService] init failed: $e');
      rethrow;
    }
  }

  // ── String ──────────────────────────────────────────────────────────────
  Future<bool> setString(String key, String value) async =>
      _prefs?.setString(key, value) ?? Future.value(false);

  String? getString(String key) => _prefs?.getString(key);

  // ── JSON map ─────────────────────────────────────────────────────────────
  Future<bool> setJson(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));

  Map<String, dynamic>? getJson(String key) {
    final raw = getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // ── Bool ─────────────────────────────────────────────────────────────────
  Future<bool> setBool(String key, {required bool value}) async =>
      _prefs?.setBool(key, value) ?? Future.value(false);

  bool? getBool(String key) => _prefs?.getBool(key);

  // ── Int ──────────────────────────────────────────────────────────────────
  Future<bool> setInt(String key, int value) async =>
      _prefs?.setInt(key, value) ?? Future.value(false);

  int? getInt(String key) => _prefs?.getInt(key);

  // ── Remove / clear ───────────────────────────────────────────────────────
  Future<bool> remove(String key) async =>
      _prefs?.remove(key) ?? Future.value(false);

  Future<bool> clear() async =>
      _prefs?.clear() ?? Future.value(false);

  // ── TTL helper ───────────────────────────────────────────────────────────
  bool isFresh(String timestampKey, Duration maxAge) {
    final raw = getString(timestampKey);
    if (raw == null) return false;
    final ts = DateTime.tryParse(raw);
    if (ts == null) return false;
    return DateTime.now().difference(ts) < maxAge;
  }

  Future<void> setNow(String timestampKey) async {
    await setString(timestampKey, DateTime.now().toIso8601String());
  }
}
