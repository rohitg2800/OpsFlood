// lib/services/real_time_service.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OpsFlood — LAYER 6: RealTimeService                                  ║
// ║                                                                          ║
// ║  ChangeNotifier so existing Riverpod providers compile unchanged.      ║
// ║  Internally delegates to LiveFetchEngine (5-source parallel) and       ║
// ║  MlInferenceService (/predict POST with real features).                ║
// ║                                                                          ║
// ║  Full old API surface preserved:                                       ║
// ║    liveLevels, criticalAlerts, activeCriticalAlerts, criticalCount      ║
// ║    isLoading, isOnline, isUsingFallback, isUsingCache, isWakingUp       ║
// ║    lastFetchTime, error, monitoringData                                 ║
// ║    imdAlerts, ndmaAdvisories, emergencyContacts                         ║
// ║    startPolling(), stopPolling(), refreshData()                         ║
// ║    dataForCity(), trendForCity(), imdAlertsForState()                   ║
// ║    ndmaAdvisoriesForState(), emergencyContactsForState()                ║
// ╚══════════════════════════════════════════════════════════════════════════╝
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../data/india_cities.dart';
import '../models/flood_data.dart';
import '../services/imd_service.dart';
import '../services/ndma_service.dart';
import 'live_fetch_engine.dart';
import 'ml_inference.dart';

// ─── Minimal MultiLocationMonitoring stand-in ────────────────────────────────────
// Kept here so monitoringData getter has a concrete type without importing
// a separate file. Screens only use criticalCount / highRiskCount.
class MultiLocationMonitoring {
  final List<FloodData> cities;
  final int criticalCount;
  final int highRiskCount;
  final DateTime updatedAt;

  const MultiLocationMonitoring({
    required this.cities,
    required this.criticalCount,
    required this.highRiskCount,
    required this.updatedAt,
  });
}

// ─── RealTimeService ──────────────────────────────────────────────────────────────────

class RealTimeService extends ChangeNotifier {
  // ── engines (singletons, no extra HTTP clients created) ───────────────────
  final _engine    = LiveFetchEngine.instance;
  final _inference = MlInferenceService.instance;
  final _imd       = ImdService.instance;

  // ── polling state ───────────────────────────────────────────────────────
  Timer? _timer;
  bool _fetching = false;

  // ── current city (default Guwahati — highest NE flood risk) ────────────
  IndiaCity _city = kIndiaCities.first;

  // ── last snapshot (null before first fetch) ──────────────────────────
  LiveSnapshot?     _snap;
  InferenceResult?  _result;

  // ── derived lists ─────────────────────────────────────────────────────
  List<FloodData>       _liveLevels      = [];
  List<FloodAlert>      _criticalAlerts  = [];
  List<ImdAlert>        _imdAlerts       = [];
  List<NdmaAdvisory>    _ndmaAdvisories  = [];
  List<EmergencyContact> _emergencyContacts = [];

  // ── status flags ───────────────────────────────═══════════════════════
  bool      _isLoading       = false;
  bool      _isOnline        = false;
  bool      _isWakingUp      = false;
  String?   _error;
  DateTime? _lastFetchTime;

  // ── Read-only getters (old API surface) ──────────────────────────────────────

  List<FloodData>        get liveLevels         => List.unmodifiable(_liveLevels);
  List<FloodAlert>       get criticalAlerts      => List.unmodifiable(_criticalAlerts);
  List<FloodAlert>       get activeCriticalAlerts=> _criticalAlerts.where((a) => !a.resolved).toList();
  int                    get criticalCount       => activeCriticalAlerts.length;

  bool      get isLoading        => _isLoading;
  bool      get isOnline         => _isOnline;
  bool      get isUsingFallback  => _snap != null && (_snap!.healthySourceCount < 3);
  bool      get isUsingCache     => false; // direct-fetch: no cache layer
  bool      get isWakingUp       => _isWakingUp;
  String?   get error            => _error;
  DateTime? get lastFetchTime    => _lastFetchTime;

  List<ImdAlert>         get imdAlerts          => List.unmodifiable(_imdAlerts);
  List<NdmaAdvisory>     get ndmaAdvisories      => List.unmodifiable(_ndmaAdvisories);
  List<EmergencyContact> get emergencyContacts   => List.unmodifiable(_emergencyContacts);

  MultiLocationMonitoring get monitoringData => MultiLocationMonitoring(
    cities:       _liveLevels,
    criticalCount: criticalCount,
    highRiskCount: _liveLevels.where((d) => d.riskLevel == 'HIGH').length,
    updatedAt:    _lastFetchTime ?? DateTime.now(),
  );

  // ── Per-city helpers ──────────────────────────────────────────────────────────

  FloodData? dataForCity(String cityName) {
    final lc = cityName.toLowerCase();
    for (final d in _liveLevels) {
      if (d.city.toLowerCase() == lc) return d;
    }
    return null;
  }

  List<double> trendForCity(String cityName) =>
      _snap?.river.discharge7d ?? [];

  List<ImdAlert> imdAlertsForState(String state) =>
      _imdAlerts.where((a) => a.state == state).toList();

  List<NdmaAdvisory> ndmaAdvisoriesForState(String state) =>
      _ndmaAdvisories.where((a) => a.state == state).toList();

  List<EmergencyContact> emergencyContactsForState(String state) =>
      _emergencyContacts.where((c) => c.state == state).toList();

  // ── Polling control ───────────────────────────────────────────────────────────

  Future<void> startPolling() async {
    _timer?.cancel();
    await _fetch();
    _timer = Timer.periodic(AppConfig.realtimeInterval, (_) => _fetch());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refreshData() async => _fetch();

  // ── Internal fetch pipeline ───────────────────────────────────────────────────

  Future<void> _fetch() async {
    if (_fetching) return; // debounce
    _fetching = true;

    _isLoading  = true;
    _isWakingUp = !_isOnline && _snap == null;
    notifyListeners();

    try {
      // Step 1 — 5-source parallel fetch
      final snap = await _engine.fetchCity(_city);
      _snap = snap;

      // Step 2 — ML inference
      final result = await _inference.infer(snap);
      _result = result;

      // Step 3 — build FloodData from snapshot
      _liveLevels = _buildFloodData(snap, result);

      // Step 4 — build FloodAlerts from inference result
      _criticalAlerts = _buildAlerts(snap, result);

      // Step 5 — fetch IMD alerts for this city's state
      _imdAlerts = await _imd.getAlerts(state: _city.state);

      // NDMA / emergency contacts: populated from NdmaService if it exists,
      // otherwise remains empty (screens handle empty list gracefully)
      try {
        _ndmaAdvisories   = await NdmaService.instance.getAdvisories(state: _city.state);
        _emergencyContacts = await NdmaService.instance.getEmergencyContacts(state: _city.state);
      } catch (_) {
        // NdmaService unavailable — keep previous or empty
      }

      _isOnline       = true;
      _isWakingUp     = false;
      _error          = null;
      _lastFetchTime  = DateTime.now();

      if (AppConfig.isDebugLogging) {
        debugPrint(
          '[RealTimeService] ${_city.name} → '
          '${result.label} (${(result.probability * 100).toStringAsFixed(1)}%) '
          '| sources: ${snap.healthySourceCount}/5'
        );
      }
    } catch (e) {
      _isOnline   = false;
      _isWakingUp = false;
      _error      = e.toString();
      if (AppConfig.isDebugLogging) {
        debugPrint('[RealTimeService] fetch error: $e');
      }
    } finally {
      _isLoading = false;
      _fetching  = false;
      notifyListeners();
    }
  }

  // ── FloodData builder ─────────────────────────────────────────────────────
  List<FloodData> _buildFloodData(LiveSnapshot snap, InferenceResult result) {
    final city = snap.city;
    final w    = snap.weather;
    final r    = snap.river;
    final cwc  = snap.cwc;

    // Derive level values from CWC (if available) or GloFAS discharge proxy
    final dangerLevel  = cwc.dangerLevel  ?? 10.0;
    final warningLevel = cwc.warningLevel ?? dangerLevel * 0.75;
    final safeLevel    = (warningLevel - 2.0).clamp(0.0, double.infinity);
    final currentLevel = cwc.currentLevel ?? _dischargeToLevel(r.dischargeM3s ?? 0);

    final riskLabel = _normalizeRisk(result.label);

    return [
      FloodData(
        id:           '${city.id}-live',
        city:         city.name,
        state:        city.state,
        latitude:     city.lat,
        longitude:    city.lon,
        currentLevel: currentLevel,
        dangerLevel:  dangerLevel,
        warningLevel: warningLevel,
        safeLevel:    safeLevel,
        riskLevel:    riskLabel,
        lastUpdated:  snap.fetchedAt,
        riverName:    city.river,
        flowRate:     r.dischargeM3s,
        rainfall24h:  w.precipitationMm,
        status:       snap.healthySourceCount >= 3 ? 'Live' : 'Partial',
        imdRainfallMm: w.hourlyPrecip.take(24).fold(0.0, (a, b) => a + b),
        imdSeverity:  _probToImdSeverity(result.probability),
      ),
    ];
  }

  // ── FloodAlert builder ────────────────────────────────────────────────────
  List<FloodAlert> _buildAlerts(LiveSnapshot snap, InferenceResult result) {
    // Only surface an alert if ML says HIGH or EXTREME
    if (result.risk == FloodRisk.low || result.risk == FloodRisk.medium) {
      return [];
    }
    final severity = result.risk == FloodRisk.extreme ? 'CRITICAL' : 'HIGH';
    final city     = snap.city;
    return [
      FloodAlert(
        id:        '${city.id}-${snap.fetchedAt.millisecondsSinceEpoch}',
        city:      city.name,
        state:     city.state,
        severity:  severity,
        title:     '$severity Flood Risk — ${city.name}',
        message:   'ML ensemble: ${(result.probability * 100).toStringAsFixed(1)}% '
                   'flood probability. '
                   '${snap.healthySourceCount}/5 live sources active.',
        timestamp: snap.fetchedAt,
        resolved:  false,
        riverName: city.river,
        currentLevel: snap.cwc.currentLevel,
        dangerLevel:  snap.cwc.dangerLevel,
        recommendation: severity == 'CRITICAL'
            ? 'Evacuate low-lying areas immediately.'
            : 'Monitor water levels closely. Be prepared to evacuate.',
      ),
    ];
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Approximate river level proxy from GloFAS discharge (m³/s → metres).
  /// Large rivers: ~1 m per 200 m³/s. Good enough for fallback display.
  static double _dischargeToLevel(double m3s) => (m3s / 200.0).clamp(0.0, 20.0);

  static String _normalizeRisk(String label) {
    final u = label.toUpperCase();
    if (u.contains('EXTREME') || u.contains('CRITICAL')) return 'CRITICAL';
    if (u.contains('HIGH'))   return 'HIGH';
    if (u.contains('MED'))    return 'MODERATE';
    return 'LOW';
  }

  static String _probToImdSeverity(double prob) {
    if (prob >= 0.80) return 'RED';
    if (prob >= 0.60) return 'ORANGE';
    if (prob >= 0.40) return 'YELLOW';
    return 'GREEN';
  }

  // ── City switching ────────────────────────────────────────────────────────────

  void setCity(IndiaCity city) {
    _city = city;
    _fetch();
  }

  void setCityById(String id) {
    final c = cityById(id);
    if (c != null) setCity(c);
  }

  IndiaCity get currentCity => _city;

  // ── Raw snapshot access (for screens that want the full data) ─────────────────

  LiveSnapshot?    get lastSnapshot  => _snap;
  InferenceResult? get lastInference => _result;

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
