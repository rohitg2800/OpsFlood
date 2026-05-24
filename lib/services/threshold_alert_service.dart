// lib/services/threshold_alert_service.dart
//
// OpsFlood — ThresholdAlertService
//
// Polls GloFAS discharge + CWC/WRD gauge levels on a timer and emits
// ThresholdAlert events for every monitored station that crosses a threshold.
//
// Architecture:
//   - Runs on a periodic timer (default: every 15 minutes).
//   - Uses AlertEvaluator for stateless threshold logic.
//   - Fires local notifications via FcmService.showAlertNotification().
//   - Exposes a Stream<List<ThresholdAlert>> that AlertsProvider listens to.
//   - Persists last-seen alert levels to SharedPreferences to suppress duplicates.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/india_cities.dart';
import '../data/bihar_rivers.dart';
import '../data/direct_sources.dart';
import '../models/threshold_alert.dart';
import 'alert_evaluator.dart';
import 'fcm_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────
const _kPollInterval    = Duration(minutes: 15);
const _kPrefKeyPrefix   = 'threshold_alert_last_';
const _kPrefAlertsJson  = 'threshold_alerts_cache';
const _kMaxCachedAlerts = 200;
const _kHttpTimeout     = Duration(seconds: 20);

// ─────────────────────────────────────────────────────────────────────────────
// ThresholdAlertService
// ─────────────────────────────────────────────────────────────────────────────
class ThresholdAlertService {
  ThresholdAlertService._();
  static final ThresholdAlertService instance = ThresholdAlertService._();

  final _controller = StreamController<List<ThresholdAlert>>.broadcast();
  Stream<List<ThresholdAlert>> get stream => _controller.stream;

  Timer? _timer;
  bool   _running = false;

  final List<ThresholdAlert> _alerts = [];
  List<ThresholdAlert> get currentAlerts => List.unmodifiable(_alerts);

  final Map<String, double> _prevValues = {};

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _loadCachedAlerts();
    await _poll();
    _timer = Timer.periodic(_kPollInterval, (_) => _poll());
    debugPrint('[ThresholdAlertService] started, polling every $_kPollInterval');
  }

  void stop() {
    _timer?.cancel();
    _timer   = null;
    _running = false;
    debugPrint('[ThresholdAlertService] stopped');
  }

  void dispose() {
    stop();
    _controller.close();
  }

  // ── Main poll cycle ────────────────────────────────────────────────────────

  Future<void> _poll() async {
    debugPrint('[ThresholdAlertService] poll @ ${DateTime.now()}');
    final newAlerts = <ThresholdAlert>[];

    // 1. IndiaCity entries via GloFAS discharge
    for (final city in monitoredCities) {
      try {
        final alert = await _evaluateCity(city);
        if (alert != null) newAlerts.add(alert);
      } catch (e) {
        debugPrint('[ThresholdAlertService] city ${city.id}: $e');
      }
    }

    // 2. Bihar gauges
    for (final gauge in kBiharGauges) {
      try {
        final alert = await _evaluateBiharGauge(gauge);
        if (alert != null) newAlerts.add(alert);
      } catch (e) {
        debugPrint('[ThresholdAlertService] bihar ${gauge.station}: $e');
      }
    }

    if (newAlerts.isEmpty) {
      debugPrint('[ThresholdAlertService] poll done — no actionable alerts');
      return;
    }

    _mergeAlerts(newAlerts);

    for (final alert in newAlerts) {
      if (alert.level.requiresPush) await _notify(alert);
    }

    await _saveAlertsCache();
    _controller.add(currentAlerts);
    debugPrint('[ThresholdAlertService] poll done — ${newAlerts.length} new alerts');
  }

  // ── Per-city GloFAS evaluation ─────────────────────────────────────────────

  Future<ThresholdAlert?> _evaluateCity(IndiaCity city) async {
    final discharge = await _fetchLatestDischarge(
        GloFasUrls.discharge(city.lat, city.lon));
    if (discharge == null) return null;

    final prev = _prevValues[city.id];
    _prevValues[city.id] = discharge;

    return AlertEvaluator.fromCity(
      city:          city,
      currentValue:  discharge,
      previousValue: prev,
      isDischarge:   true,
    );
  }

  // ── Bihar gauge evaluation ─────────────────────────────────────────────────

  Future<ThresholdAlert?> _evaluateBiharGauge(BiharGauge gauge) async {
    final discharge = await _fetchLatestDischarge(
        GloFasUrls.discharge(gauge.lat, gauge.lon));
    if (discharge == null) return null;

    final key  = '${gauge.river}_${gauge.station}';
    final prev = _prevValues[key];
    _prevValues[key] = discharge;

    return AlertEvaluator.fromBiharGauge(
      gauge:         gauge,
      currentValue:  discharge,
      previousValue: prev,
    );
  }

  // ── HTTP helper ────────────────────────────────────────────────────────────

  Future<double?> _fetchLatestDischarge(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(_kHttpTimeout);
      if (response.statusCode != 200) return null;
      final json  = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;
      final values = daily['river_discharge'] as List?;
      if (values == null || values.isEmpty) return null;
      for (int i = values.length - 1; i >= 0; i--) {
        if (values[i] != null) return (values[i] as num).toDouble();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Merge ──────────────────────────────────────────────────────────────────

  void _mergeAlerts(List<ThresholdAlert> incoming) {
    for (final alert in incoming) {
      _alerts.removeWhere((a) => a.cityId == alert.cityId);
      _alerts.insert(0, alert);
    }
    _alerts.sort((a, b) {
      final cmp = b.level.index.compareTo(a.level.index);
      return cmp != 0 ? cmp : b.timestamp.compareTo(a.timestamp);
    });
    if (_alerts.length > _kMaxCachedAlerts) {
      _alerts.removeRange(_kMaxCachedAlerts, _alerts.length);
    }
  }

  // ── Notification via FcmService public API ─────────────────────────────────

  Future<void> _notify(ThresholdAlert alert) async {
    final prefs    = await SharedPreferences.getInstance();
    final key      = '$_kPrefKeyPrefix${alert.cityId}';
    final lastSeen = prefs.getString(key);

    // Suppress if same or higher level was already notified
    if (lastSeen != null) {
      final lastLevel = AlertLevel.values.firstWhere(
        (l) => l.name == lastSeen,
        orElse: () => AlertLevel.normal,
      );
      if (alert.level.index <= lastLevel.index) return;
    }

    await prefs.setString(key, alert.level.name);

    final severity = switch (alert.level) {
      AlertLevel.extreme => 'EXTREME',
      AlertLevel.danger  => 'DANGER',
      _                  => 'WARNING',
    };

    final body =
        '${alert.river} at ${alert.currentValue.toStringAsFixed(1)} ${alert.unitLabel}. '
        'Danger level: ${alert.dangerLevel.toStringAsFixed(1)} ${alert.unitLabel}. '
        'Trend: ${alert.trend.name}.';

    await FcmService.instance.showAlertNotification(
      cityName:     alert.cityName,
      state:        alert.state,
      river:        alert.river,
      severity:     severity,
      currentLevel: alert.currentValue,
      dangerLevel:  alert.dangerLevel,
      message:      body,
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _saveAlertsCache() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final simple = _alerts.take(50).map((a) => {
        'cityId':       a.cityId,
        'cityName':     a.cityName,
        'state':        a.state,
        'river':        a.river,
        'level':        a.level.name,
        'currentValue': a.currentValue,
        'warningLevel': a.warningLevel,
        'dangerLevel':  a.dangerLevel,
        'hfl':          a.hfl,
        'breachMargin': a.breachMargin,
        'fillPercent':  a.fillPercent,
        'timestamp':    a.timestamp.toIso8601String(),
        'isDischarge':  a.isDischarge,
        'trend':        a.trend.name,
      }).toList();
      await prefs.setString(_kPrefAlertsJson, jsonEncode(simple));
    } catch (_) {}
  }

  Future<void> _loadCachedAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kPrefAlertsJson);
      if (raw == null) return;
      final list  = jsonDecode(raw) as List;
      _alerts.clear();
      for (final m in list) {
        final map = m as Map<String, dynamic>;
        _alerts.add(ThresholdAlert(
          id:           '${map["cityId"]}_cached',
          cityId:       map['cityId']   as String,
          cityName:     map['cityName'] as String,
          state:        map['state']    as String,
          river:        map['river']    as String,
          level:        AlertLevel.values.firstWhere(
                          (l) => l.name == map['level'],
                          orElse: () => AlertLevel.normal),
          currentValue: (map['currentValue'] as num).toDouble(),
          warningLevel: (map['warningLevel'] as num).toDouble(),
          dangerLevel:  (map['dangerLevel']  as num).toDouble(),
          hfl:          (map['hfl']          as num).toDouble(),
          breachMargin: (map['breachMargin'] as num).toDouble(),
          fillPercent:  (map['fillPercent']  as num).toDouble(),
          timestamp:    DateTime.parse(map['timestamp'] as String),
          isDischarge:  map['isDischarge'] as bool,
          isNew:        false,
          trend:        TrendDirection.values.firstWhere(
                          (t) => t.name == map['trend'],
                          orElse: () => TrendDirection.steady),
        ));
      }
      debugPrint('[ThresholdAlertService] loaded ${_alerts.length} cached alerts');
    } catch (e) {
      debugPrint('[ThresholdAlertService] cache load failed: $e');
    }
  }

  // ── Public helpers ─────────────────────────────────────────────────────────

  Future<void> markAllSeen() async {
    for (int i = 0; i < _alerts.length; i++) {
      _alerts[i] = _alerts[i].copyWith(isNew: false);
    }
    _controller.add(currentAlerts);
    await _saveAlertsCache();
  }

  Future<void> refresh() => _poll();

  int get unreadCount =>
      _alerts.where((a) => a.isNew && a.level.requiresPush).length;
}
