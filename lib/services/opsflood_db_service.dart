// lib/services/opsflood_db_service.dart
//
// OpsFlood — Database Service v1.0
//
// WHAT THIS DOES:
//   1. Fetches live data from the OpsFlood backend (opsflood.onrender.com)
//      via OpsClient (the single HTTP layer — no direct HTTP calls here).
//   2. Mirrors every successful fetch into Cloud Firestore so:
//        - Admin dashboard can read historical flood readings.
//        - App shows data even when the backend is cold-starting.
//        - Alert history is preserved for 30 days.
//   3. Provides typed DTOs consumed by RiverMonitorScreen and providers.
//
// FIRESTORE COLLECTIONS:
//   flood_readings/{city}_{yyyyMMddHHmm}   ← gauge readings every 5 min
//   alert_events/{city}_{timestamp}         ← threshold breach events
//   predictions/{city}_{date}               ← ML prediction snapshots
//   station_registry/{city}                 ← static station metadata
//
// OFFLINE BEHAVIOUR:
//   If OpsClient returns an error, falls back to LocalCacheService.
//   Falls back further to Firestore (last known good) if cache is also empty.

library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'local_cache_service.dart';
import 'ops_client.dart';

// ── DTOs ──────────────────────────────────────────────────────────────────────

class DbStation {
  final String city;
  final String state;
  final String river;
  final double lat;
  final double lon;
  final double warningLevel;  // metres MSL
  final double dangerLevel;   // metres MSL
  final double hfl;           // Historical Flood Level metres MSL
  final String cwcStationId;

  const DbStation({
    required this.city,
    required this.state,
    required this.river,
    required this.lat,
    required this.lon,
    required this.warningLevel,
    required this.dangerLevel,
    required this.hfl,
    required this.cwcStationId,
  });

  factory DbStation.fromMap(Map<String, dynamic> m) => DbStation(
        city:         _str(m['city'] ?? m['name'] ?? ''),
        state:        _str(m['state'] ?? ''),
        river:        _str(m['river'] ?? ''),
        lat:          _dbl(m['lat'] ?? m['latitude'] ?? 0),
        lon:          _dbl(m['lon'] ?? m['longitude'] ?? 0),
        warningLevel: _dbl(m['warning_level'] ?? m['warning'] ?? 0),
        dangerLevel:  _dbl(m['danger_level']  ?? m['danger']  ?? 0),
        hfl:          _dbl(m['hfl'] ?? 0),
        cwcStationId: _str(m['cwc_station_id'] ?? m['station_id'] ?? ''),
      );

  Map<String, dynamic> toMap() => {
        'city':           city,
        'state':          state,
        'river':          river,
        'lat':            lat,
        'lon':            lon,
        'warning_level':  warningLevel,
        'danger_level':   dangerLevel,
        'hfl':            hfl,
        'cwc_station_id': cwcStationId,
      };
}

class DbReading {
  final String   city;
  final double   level;        // metres MSL — real gauge reading
  final double?  discharge;    // m³/s from GloFAS or CWC
  final double?  rainfall;     // mm/hr last hour
  final String   source;       // TELEMETRY | LIVE_LEVELS | CWC_FFS | GLOFAS
  final DateTime timestamp;
  final bool     isStale;      // true if from cache, not live

  const DbReading({
    required this.city,
    required this.level,
    this.discharge,
    this.rainfall,
    required this.source,
    required this.timestamp,
    this.isStale = false,
  });

  factory DbReading.fromMap(Map<String, dynamic> m) => DbReading(
        city:      _str(m['city'] ?? ''),
        level:     _dbl(m['level'] ?? m['water_level'] ?? m['gauge'] ?? 0),
        discharge: _dblOpt(m['discharge'] ?? m['flow_rate']),
        rainfall:  _dblOpt(m['rainfall'] ?? m['rainfall_last_hour']),
        source:    _str(m['source'] ?? 'UNKNOWN'),
        timestamp: _dt(m['timestamp'] ?? m['observed_at']),
        isStale:   m['is_stale'] == true,
      );

  Map<String, dynamic> toFirestore() => {
        'city':      city,
        'level':     level,
        'discharge': discharge,
        'rainfall':  rainfall,
        'source':    source,
        'timestamp': Timestamp.fromDate(timestamp),
        'is_stale':  isStale,
      };
}

class DbAlert {
  final String   city;
  final String   state;
  final String   river;
  final String   level;        // WARNING | DANGER | EXTREME
  final double   currentValue; // m³/s discharge
  final double   threshold;    // the breached threshold value
  final String   trend;        // RISING | FALLING | STEADY
  final DateTime timestamp;
  final bool     isNew;

  const DbAlert({
    required this.city,
    required this.state,
    required this.river,
    required this.level,
    required this.currentValue,
    required this.threshold,
    required this.trend,
    required this.timestamp,
    required this.isNew,
  });

  factory DbAlert.fromMap(Map<String, dynamic> m) => DbAlert(
        city:         _str(m['city'] ?? m['city_name'] ?? ''),
        state:        _str(m['state'] ?? ''),
        river:        _str(m['river'] ?? ''),
        level:        _str(m['level'] ?? m['alert_level'] ?? 'WARNING'),
        currentValue: _dbl(m['current_value'] ?? m['discharge'] ?? 0),
        threshold:    _dbl(m['threshold'] ?? m['danger_level'] ?? 0),
        trend:        _str(m['trend'] ?? 'STEADY'),
        timestamp:    _dt(m['timestamp'] ?? m['detected_at']),
        isNew:        m['is_new'] == true,
      );

  Map<String, dynamic> toFirestore() => {
        'city':          city,
        'state':         state,
        'river':         river,
        'level':         level,
        'current_value': currentValue,
        'threshold':     threshold,
        'trend':         trend,
        'timestamp':     Timestamp.fromDate(timestamp),
        'is_new':        isNew,
      };
}

class DbPrediction {
  final String   city;
  final double   floodProbability;  // 0.0–1.0
  final String   riskLevel;         // SAFE | MODERATE | SEVERE | CRITICAL
  final String   forecastHorizon;   // '24h' | '48h' | '72h'
  final double   confidence;        // 0.0–1.0
  final DateTime generatedAt;

  const DbPrediction({
    required this.city,
    required this.floodProbability,
    required this.riskLevel,
    required this.forecastHorizon,
    required this.confidence,
    required this.generatedAt,
  });

  factory DbPrediction.fromMap(Map<String, dynamic> m) => DbPrediction(
        city:             _str(m['city'] ?? ''),
        floodProbability: _dbl(m['flood_probability'] ?? m['prob'] ?? 0),
        riskLevel:        _str(m['risk_level'] ?? 'SAFE'),
        forecastHorizon:  _str(m['forecast_horizon'] ?? '24h'),
        confidence:       _dbl(m['confidence'] ?? 0),
        generatedAt:      _dt(m['generated_at'] ?? m['timestamp']),
      );

  Map<String, dynamic> toFirestore() => {
        'city':              city,
        'flood_probability': floodProbability,
        'risk_level':        riskLevel,
        'forecast_horizon':  forecastHorizon,
        'confidence':        confidence,
        'generated_at':      Timestamp.fromDate(generatedAt),
      };
}

// ── Typed result wrapper ──────────────────────────────────────────────────────

class DbResult<T> {
  final List<T> data;
  final bool    fromCache;    // true = data is from local cache / Firestore
  final bool    isStale;      // true = cache older than TTL
  final String? error;

  const DbResult({
    required this.data,
    this.fromCache = false,
    this.isStale   = false,
    this.error,
  });

  bool get isOk => error == null;
}

// ── Main service ──────────────────────────────────────────────────────────────

class OpsFloodDbService {
  OpsFloodDbService._();
  static final OpsFloodDbService instance = OpsFloodDbService._();

  final _client = OpsClient.instance;
  final _cache  = LocalCacheService.instance;

  // Firestore is optional — null if Firebase not initialised yet
  FirebaseFirestore? get _fs {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // Firestore collection prefix (empty string = production)
  static const String _prefix =
      String.fromEnvironment('DB_COLLECTION_PREFIX', defaultValue: '');

  String _col(String name) =>
      _prefix.isEmpty ? name : '${_prefix}_$name';

  // ────────────────────────────────────────────────────────────────────────────
  // STATIONS
  // ────────────────────────────────────────────────────────────────────────────

  /// Fetch all CWC station registry entries.
  /// Mirrors to Firestore collection `station_registry`.
  Future<DbResult<DbStation>> fetchStations() async {
    const path = AppConfig.epCwcStations;
    final raw  = await _client.get(path);

    if (_isOk(raw)) {
      final list   = _asList(raw);
      final result = list.map((e) => DbStation.fromMap(e)).toList();
      await _cache.write(path, jsonEncode(list));
      _mirrorStations(result); // fire-and-forget
      return DbResult(data: result);
    }

    // Fallback 1: local cache
    final cached = await _cache.read(path);
    if (cached.value != null) {
      final list   = (jsonDecode(cached.value!) as List).cast<Map<String, dynamic>>();
      return DbResult(
        data:      list.map((e) => DbStation.fromMap(e)).toList(),
        fromCache: true,
        isStale:   cached.isStale,
      );
    }

    // Fallback 2: Firestore
    final fs = _fs;
    if (fs != null) {
      try {
        final snap = await fs
            .collection(_col('station_registry'))
            .limit(200)
            .get();
        final result = snap.docs
            .map((d) => DbStation.fromMap(d.data()))
            .toList();
        if (result.isNotEmpty) {
          return DbResult(data: result, fromCache: true, isStale: true);
        }
      } catch (e) {
        _log('Firestore station fallback failed: $e');
      }
    }

    return DbResult(data: const [], error: raw['error']?.toString());
  }

  // ────────────────────────────────────────────────────────────────────────────
  // LIVE TELEMETRY READINGS
  // ────────────────────────────────────────────────────────────────────────────

  /// Fetch live telemetry for all monitored stations.
  /// Mirrors each reading to Firestore `flood_readings`.
  Future<DbResult<DbReading>> fetchLiveTelemetry() async {
    const path = AppConfig.epLiveTelemetry;
    final raw  = await _client.get(path);

    if (_isOk(raw)) {
      final list    = _asList(raw);
      final result  = list.map((e) => DbReading.fromMap(e)).toList();
      await _cache.write(path, jsonEncode(list));
      _mirrorReadings(result); // fire-and-forget
      return DbResult(data: result);
    }

    final cached = await _cache.read(path);
    if (cached.value != null) {
      final list = (jsonDecode(cached.value!) as List).cast<Map<String, dynamic>>();
      return DbResult(
        data:      list.map((e) => DbReading.fromMap(e)).toList(),
        fromCache: true,
        isStale:   cached.isStale,
      );
    }

    return DbResult(data: const [], error: raw['error']?.toString());
  }

  /// Fetch live reading for a single city.
  Future<DbResult<DbReading>> fetchCityReading({
    required String city,
    required String state,
    required String river,
  }) async {
    final path = '${AppConfig.epLiveTelemetry}?city=${Uri.encodeComponent(city)}';
    final raw  = await _client.get(
      AppConfig.epLiveTelemetry,
      query: {'city': city, 'state': state, 'river': river},
    );

    if (_isOk(raw)) {
      final list   = _asList(raw);
      final result = list.map((e) => DbReading.fromMap(e)).toList();
      if (result.isNotEmpty) {
        await _cache.write(path, jsonEncode(list));
        _mirrorReadings(result);
      }
      return DbResult(data: result);
    }

    final cached = await _cache.read(path);
    if (cached.value != null) {
      final list = (jsonDecode(cached.value!) as List).cast<Map<String, dynamic>>();
      return DbResult(
        data:      list.map((e) => DbReading.fromMap(e)).toList(),
        fromCache: true,
        isStale:   cached.isStale,
      );
    }

    return DbResult(data: const [], error: raw['error']?.toString());
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CRITICAL ALERTS
  // ────────────────────────────────────────────────────────────────────────────

  /// Fetch active threshold breach alerts.
  /// Mirrors new alerts to Firestore `alert_events`.
  Future<DbResult<DbAlert>> fetchAlerts() async {
    const path = AppConfig.epCriticalAlerts;
    final raw  = await _client.get(path);

    if (_isOk(raw)) {
      final list   = _asList(raw);
      final result = list.map((e) => DbAlert.fromMap(e)).toList();
      await _cache.write(path, jsonEncode(list));
      _mirrorAlerts(result);
      return DbResult(data: result);
    }

    final cached = await _cache.read(path);
    if (cached.value != null) {
      final list = (jsonDecode(cached.value!) as List).cast<Map<String, dynamic>>();
      return DbResult(
        data:      list.map((e) => DbAlert.fromMap(e)).toList(),
        fromCache: true,
        isStale:   cached.isStale,
      );
    }

    return DbResult(data: const [], error: raw['error']?.toString());
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ML PREDICTIONS
  // ────────────────────────────────────────────────────────────────────────────

  /// Fetch ML flood predictions for a given city from the /predict endpoint.
  Future<DbResult<DbPrediction>> fetchPrediction({
    required String city,
    required double gaugeLevel,
    required double rainfall,
    required double discharge,
  }) async {
    const path = AppConfig.epPredict;
    final raw  = await _client.post(path, {
      'city':        city,
      'gauge_level': gaugeLevel,
      'rainfall':    rainfall,
      'discharge':   discharge,
    });

    if (_isOk(raw)) {
      // /predict returns a single prediction object, not a list
      final obj    = raw.containsKey('data') && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final result = DbPrediction.fromMap({...obj, 'city': city});
      final cacheKey = '$path?city=$city';
      await _cache.write(cacheKey, jsonEncode([obj]));
      _mirrorPrediction(result);
      return DbResult(data: [result]);
    }

    return DbResult(data: const [], error: raw['error']?.toString());
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PIPELINE FEATURES (for admin / debugging)
  // ────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchPipelineManifest() async {
    final raw = await _client.get(AppConfig.epPipelineManifest);
    return _isOk(raw) ? raw : {};
  }

  Future<Map<String, dynamic>> fetchStateSeverity() async {
    const path = AppConfig.epStateSeverity;
    final raw  = await _client.get(path);
    if (_isOk(raw)) {
      await _cache.write(path, jsonEncode(raw));
      return raw;
    }
    final cached = await _cache.read(path);
    if (cached.value != null) {
      return jsonDecode(cached.value!) as Map<String, dynamic>;
    }
    return {};
  }

  // ────────────────────────────────────────────────────────────────────────────
  // FIRESTORE MIRROR (fire-and-forget helpers)
  // ────────────────────────────────────────────────────────────────────────────

  void _mirrorStations(List<DbStation> stations) {
    final fs = _fs;
    if (fs == null) return;
    final col = fs.collection(_col('station_registry'));
    for (final s in stations) {
      if (s.city.isEmpty) continue;
      col.doc(s.city.toLowerCase().replaceAll(' ', '_'))
          .set(s.toMap(), SetOptions(merge: true))
          .catchError((e) => _log('Firestore station write failed: $e'));
    }
  }

  void _mirrorReadings(List<DbReading> readings) {
    final fs = _fs;
    if (fs == null) return;
    final col = fs.collection(_col('flood_readings'));
    for (final r in readings) {
      if (r.city.isEmpty || r.isStale) continue;
      final docId =
          '${r.city.toLowerCase().replaceAll(' ', '_')}_'
          '${r.timestamp.toUtc().toIso8601String().replaceAll(':', '').replaceAll('.', '_').substring(0, 15)}';
      col.doc(docId)
          .set(r.toFirestore(), SetOptions(merge: true))
          .catchError((e) => _log('Firestore reading write failed: $e'));
    }
  }

  void _mirrorAlerts(List<DbAlert> alerts) {
    final fs = _fs;
    if (fs == null) return;
    final col = fs.collection(_col('alert_events'));
    for (final a in alerts) {
      if (a.city.isEmpty) continue;
      final docId =
          '${a.city.toLowerCase().replaceAll(' ', '_')}_'
          '${a.timestamp.millisecondsSinceEpoch}';
      col.doc(docId)
          .set(a.toFirestore(), SetOptions(merge: true))
          .catchError((e) => _log('Firestore alert write failed: $e'));
    }
  }

  void _mirrorPrediction(DbPrediction p) {
    final fs = _fs;
    if (fs == null) return;
    final col = fs.collection(_col('predictions'));
    final docId =
        '${p.city.toLowerCase().replaceAll(' ', '_')}_'
        '${p.generatedAt.toUtc().toIso8601String().substring(0, 10)}';
    col.doc(docId)
        .set(p.toFirestore(), SetOptions(merge: true))
        .catchError((e) => _log('Firestore prediction write failed: $e'));
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────────────────────────────────

  bool _isOk(Map<String, dynamic> raw) =>
      raw['status'] != 'error' && raw['error'] == null;

  List<Map<String, dynamic>> _asList(Map<String, dynamic> raw) {
    final d = raw['data'] ?? raw['results'] ?? raw['stations'] ?? raw;
    if (d is List) return d.whereType<Map<String, dynamic>>().toList();
    if (d is Map<String, dynamic>) return [d];
    return [];
  }

  static String _str(dynamic v) => v?.toString() ?? '';
  static double _dbl(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  static double? _dblOpt(dynamic v) => v == null ? null : _dbl(v);
  static DateTime _dt(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  void _log(String msg) => debugPrint('[OpsFloodDb] $msg');
}
