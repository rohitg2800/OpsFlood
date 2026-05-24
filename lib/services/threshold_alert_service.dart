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
//   - Fires FCM local notifications via FcmService for ≥ warning alerts.
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
const _kPollInterval     = Duration(minutes: 15);
const _kPrefKeyPrefix    = 'threshold_alert_last_';
const _kPrefAlertsJson   = 'threshold_alerts_cache';
const _kMaxCachedAlerts  = 200;
const _kHttpTimeout      = Duration(seconds: 20);

// ─────────────────────────────────────────────────────────────────────────────
// ThresholdAlertService
// ─────────────────────────────────────────────────────────────────────────────
class ThresholdAlertService {
  ThresholdAlertService._();
  static final ThresholdAlertService instance = ThresholdAlertService._();

  // Stream controller — broadcast so multiple widgets can listen
  final _controller = StreamController<List<ThresholdAlert>>.broadcast();
  Stream<List<ThresholdAlert>> get stream => _controller.stream;

  Timer? _timer;
  bool   _running = false;

  // In-memory cache of the most recent alerts (newest first)
  final List<ThresholdAlert> _alerts = [];
  List<ThresholdAlert> get currentAlerts => List.unmodifiable(_alerts);

  // Previous discharge values keyed by cityId for trend detection
  final Map<String, double> _prevValues = {};

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _loadCachedAlerts();
    await _poll(); // immediate first run
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

  // ─── Main poll cycle ──────────────────────────────────────────────────────

  Future<void> _poll() async {
    debugPrint('[ThresholdAlertService] poll started at ${DateTime.now()}');
    final newAlerts = <ThresholdAlert>[];

    // 1. Evaluate all monitored IndiaCity entries via GloFAS discharge
    for (final city in monitoredCities) {
      try {
        final alert = await _evaluateCity(city);
        if (alert != null) newAlerts.add(alert);
      } catch (e) {
        debugPrint('[ThresholdAlertService] city ${city.id}: $e');
      }
    }

    // 2. Evaluate Bihar gauges
    for (final gauge in kBiharGauges) {
      try {
        final alert = await _evaluateBiharGauge(gauge);
        if (alert != null) newAlerts.add(alert);
      } catch (e) {
        debugPrint('[ThresholdAlertService] bihar ${gauge.station}: $e');
      }
    }

    if (newAlerts.isEmpty) {
      debugPrint('[ThresholdAlertService] poll complete — no actionable alerts');
      return;
    }

    // 3. Merge with existing alerts, deduplicate by cityId (keep latest)
    _mergeAlerts(newAlerts);

    // 4. Fire push notifications for new ≥ warning alerts
    for (final alert in newAlerts) {
      if (alert.level.requiresPush) {
        await _notify(alert);
      }
    }

    // 5. Persist to prefs
    await _saveAlertsCache();

    // 6. Broadcast
    _controller.add(currentAlerts);
    debugPrint('[ThresholdAlertService] poll complete — ${newAlerts.length} new alerts');
  }

  // ─── Per-city GloFAS evaluation ───────────────────────────────────────────

  Future<ThresholdAlert?> _evaluateCity(IndiaCity city) async {
    final url = GloFasUrls.discharge(city.lat, city.lon);
    final discharge = await _fetchLatestDischarge(url);
    if (discharge == null) return null;

    final prev = _prevValues[city.id];
    _prevValues[city.id] = discharge;

    // Use GloFAS discharge — convert WRD gauge levels to equivalent discharge
    // if city has dangerLevel > 0; use discharge directly
    return AlertEvaluator.fromCity(
      city:          city,
      currentValue:  discharge,
      previousValue: prev,
      isDischarge:   true,
    );
  }

  // ─── Bihar gauge evaluation ───────────────────────────────────────────────

  Future<ThresholdAlert?> _evaluateBiharGauge(BiharGauge gauge) async {
    // Bihar gauges: use GloFAS discharge at gauge lat/lon as proxy
    final url = GloFasUrls.discharge(gauge.lat, gauge.lon);
    final discharge = await _fetchLatestDischarge(url);
    if (discharge == null) return null;

    final key  = '${gauge.river}_${gauge.station}';
    final prev = _prevValues[key];
    _prevValues[key] = discharge;

    // Scale: compare discharge against gauge danger level proportionally
    // (gauge.dangerLevel is in m MSL; we treat discharge as the primary signal
    //  but still classify against the WRD thresholds after normalisation)
    return AlertEvaluator.fromBiharGauge(
      gauge:         gauge,
      currentValue:  discharge,
      previousValue: prev,
    );
  }

  // ─── HTTP helper — fetch today's river_discharge from GloFAS ─────────────

  Future<double?> _fetchLatestDischarge(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(_kHttpTimeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;
      final values = (daily['river_discharge'] as List?);
      if (values == null || values.isEmpty) return null;
      // Return the most recent non-null value (last element = today/forecast)
      for (int i = values.length - 1; i >= 0; i--) {
        if (values[i] != null) return (values[i] as num).toDouble();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Merge helpers ────────────────────────────────────────────────────────

  void _mergeAlerts(List<ThresholdAlert> incoming) {
    for (final alert in incoming) {
      _alerts.removeWhere((a) => a.cityId == alert.cityId);
      _alerts.insert(0, alert);
    }
    // Sort: extreme > danger > warning > watch; then newest first within level
    _alerts.sort((a, b) {
      final cmp = b.level.index.compareTo(a.level.index);
      return cmp != 0 ? cmp : b.timestamp.compareTo(a.timestamp);
    });
    if (_alerts.length > _kMaxCachedAlerts) {
      _alerts.removeRange(_kMaxCachedAlerts, _alerts.length);
    }
  }

  // ─── Notification ─────────────────────────────────────────────────────────

  Future<void> _notify(ThresholdAlert alert) async {
    final prefs    = await SharedPreferences.getInstance();
    final key      = '$_kPrefKeyPrefix${alert.cityId}';
    final lastSeen = prefs.getString(key);

    // Suppress if same or higher level already notified
    if (lastSeen != null) {
      final lastLevel = AlertLevel.values.firstWhere(
        (l) => l.name == lastSeen,
        orElse: () => AlertLevel.normal,
      );
      if (alert.level.index <= lastLevel.index) return;
    }

    await prefs.setString(key, alert.level.name);

    final title = '${alert.level.label.toUpperCase()} — ${alert.cityName}';
    final body  =
        '${alert.river} at ${alert.currentValue.toStringAsFixed(1)} ${alert.unitLabel}. '
        'Danger level: ${alert.dangerLevel} ${alert.unitLabel}. '
        'Trend: ${alert.trend.name}.';

    await FcmService.instance.showLocalNotification(
      id:    alert.cityId.hashCode.abs(),
      title: title,
      body:  body,
      payload: alert.cityId,
    );
  }

  // ─── Persistence ──────────────────────────────────────────────────────────

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
        final map  = m as Map<String, dynamic>;
        _alerts.add(ThresholdAlert(
          id:           '${map["cityId"]}_cached',
          cityId:       map['cityId'] as String,
          cityName:     map['cityName'] as String,
          state:        map['state'] as String,
          river:        map['river'] as String,
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

  /// Mark all alerts as seen (call when user opens alerts screen)
  Future<void> markAllSeen() async {
    for (int i = 0; i < _alerts.length; i++) {
      _alerts[i] = _alerts[i].copyWith(isNew: false);
    }
    _controller.add(currentAlerts);
    await _saveAlertsCache();
  }

  /// Force an immediate poll outside the timer cycle.
  Future<void> refresh() => _poll();

  /// Count of unread alerts ≥ warning
  int get unreadCount => _alerts.where((a) => a.isNew && a.level.requiresPush).length;
}
