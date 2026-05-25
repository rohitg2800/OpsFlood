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

// ── Top-level private helpers used by DTO factory constructors ────────────────
// These must be top-level (or static on each DTO) so factory constructors
// — which run before the enclosing class is instantiated — can call them.

String _str(dynamic v) => (v?.toString() ?? '').trim();

double _dbl(dynamic v) {
  if (v == null) return 0.0;
  if (v is num)  return v.toDouble();
  return double.tryParse(v.toString().trim()) ?? 0.0;
}

double? _dblOpt(dynamic v) => v == null ? null : _dbl(v);

DateTime _dt(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is Timestamp) return v.toDate();
  if (v is DateTime)  return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.now();
}

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

  final FirebaseFirestore _fs     = FirebaseFirestore.instance;
  final OpsClient         _client = OpsClient.instance;
  final LocalCacheService _cache  = LocalCacheService.instance;

  // ── Station registry ────────────────────────────────────────────────────────

  Future<DbResult<DbStation>> getStations() async {
    try {
      final raw = await _client.getStations();
      final list = (raw as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(DbStation.fromMap)
          .toList();
      _mirrorStations(list);
      return DbResult(data: list);
    } catch (e) {
      if (kDebugMode) debugPrint('[OpsFloodDb] getStations failed: $e');
      return DbResult(
        data:      await _firestoreStations(),
        fromCache: true,
        isStale:   true,
        error:     e.toString(),
      );
    }
  }

  Future<List<DbStation>> _firestoreStations() async {
    try {
      final snap = await _fs
          .collection('station_registry')
          .limit(200)
          .get();
      return snap.docs
          .map((d) => DbStation.fromMap(d.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _mirrorStations(List<DbStation> stations) {
    if (!AppConfig.isProduction) return;
    for (final s in stations) {
      _fs
          .collection('station_registry')
          .doc(s.city.toLowerCase().replaceAll(' ', '_'))
          .set(s.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  // ── Live readings ────────────────────────────────────────────────────────────

  Future<DbResult<DbReading>> getReadings({String? city}) async {
    try {
      final raw = city != null
          ? await _client.getCityReadings(city)
          : await _client.getAllReadings();
      final list = (raw as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(DbReading.fromMap)
          .toList();
      _mirrorReadings(list);
      return DbResult(data: list);
    } catch (e) {
      if (kDebugMode) debugPrint('[OpsFloodDb] getReadings failed: $e');
      return DbResult(
        data:      await _firestoreReadings(city: city),
        fromCache: true,
        isStale:   true,
        error:     e.toString(),
      );
    }
  }

  Future<List<DbReading>> _firestoreReadings({String? city}) async {
    try {
      var q = _fs.collection('flood_readings').orderBy('timestamp', descending: true).limit(50);
      if (city != null) {
        q = q.where('city', isEqualTo: city);
      }
      final snap = await q.get();
      return snap.docs.map((d) => DbReading.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  void _mirrorReadings(List<DbReading> readings) {
    if (!AppConfig.isProduction) return;
    for (final r in readings) {
      final id = '${r.city.toLowerCase()}_'
          '${r.timestamp.toUtc().toString().replaceAll(RegExp(r'[:\s.]'), '')}';
      _fs
          .collection('flood_readings')
          .doc(id)
          .set(r.toFirestore(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  // ── Alerts ─────────────────────────────────────────────────────────────────

  Future<DbResult<DbAlert>> getAlerts() async {
    try {
      final raw  = await _client.getCriticalAlerts();
      final list = (raw as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(DbAlert.fromMap)
          .toList();
      _mirrorAlerts(list);
      return DbResult(data: list);
    } catch (e) {
      if (kDebugMode) debugPrint('[OpsFloodDb] getAlerts failed: $e');
      return DbResult(
        data:      await _firestoreAlerts(),
        fromCache: true,
        isStale:   true,
        error:     e.toString(),
      );
    }
  }

  Future<List<DbAlert>> _firestoreAlerts() async {
    try {
      final snap = await _fs
          .collection('alert_events')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();
      return snap.docs.map((d) => DbAlert.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  void _mirrorAlerts(List<DbAlert> alerts) {
    if (!AppConfig.isProduction) return;
    for (final a in alerts) {
      final id = '${a.city.toLowerCase()}_'
          '${a.timestamp.toUtc().millisecondsSinceEpoch}';
      _fs
          .collection('alert_events')
          .doc(id)
          .set(a.toFirestore(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  // ── Predictions ────────────────────────────────────────────────────────────

  Future<DbResult<DbPrediction>> getPredictions({String? city}) async {
    try {
      final raw  = await _client.getPredictions(city: city);
      final list = (raw as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(DbPrediction.fromMap)
          .toList();
      _mirrorPredictions(list);
      return DbResult(data: list);
    } catch (e) {
      if (kDebugMode) debugPrint('[OpsFloodDb] getPredictions failed: $e');
      return DbResult(
        data:      await _firestorePredictions(city: city),
        fromCache: true,
        isStale:   true,
        error:     e.toString(),
      );
    }
  }

  Future<List<DbPrediction>> _firestorePredictions({String? city}) async {
    try {
      var q = _fs.collection('predictions').orderBy('generated_at', descending: true).limit(20);
      if (city != null) {
        q = q.where('city', isEqualTo: city);
      }
      final snap = await q.get();
      return snap.docs.map((d) => DbPrediction.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  void _mirrorPredictions(List<DbPrediction> predictions) {
    if (!AppConfig.isProduction) return;
    for (final p in predictions) {
      final id = '${p.city.toLowerCase()}_'
          '${p.generatedAt.toUtc().toString().substring(0, 10)}';
      _fs
          .collection('predictions')
          .doc(id)
          .set(p.toFirestore(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }
}
