// lib/services/threshold_alert_service.dart
//
// OpsFlood — ThresholdAlertService  (WRD Bihar ONLY)
//
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DATA SOURCE:
//   ONLY kBiharGauges from lib/data/bihar_rivers.dart
//   (WRD Bihar Central Flood Control Cell / CWC FFS)
//
// THRESHOLD LOGIC:
//   Each BiharGauge already carries the official WRD/CWC thresholds in
//   metres MSL (warningLevel, dangerLevel, hfl).  We fetch live gauge
//   height from the backend opsflood API, which scrapes wrdb.befiqr.in /
//   irrigation.befiqr.in, and compare directly in the SAME unit (m MSL).
//   No GloFAS, no return-period math, no unit conversion.
//
//   If the backend returns null for a station we skip it silently.
//
// ARCHITECTURE:
//   • _poll() iterates kBiharGauges, fetches current level from backend,
//     calls AlertEvaluator.fromBiharGauge() → ThresholdAlert.
//   • Alerts at AlertLevel.normal are still included so the screen can
//     show the full network status.
//   • 15-min polling; SharedPreferences cache so last-known values survive
//     app restarts.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bihar_rivers.dart';
import '../models/threshold_alert.dart';
import 'alert_evaluator.dart';
import 'fcm_service.dart';

// ─── Config ───────────────────────────────────────────────────────────────────
const _kPollInterval   = Duration(minutes: 15);
const _kPrefAlertsJson = 'wrd_alerts_cache_v2';
const _kMaxCached      = 200;
const _kHttpTimeout    = Duration(seconds: 20);

/// Backend base URL — the OpsFlood FastAPI server that scrapes WRD Bihar live.
const _kBackendBase = 'https://opsflood.onrender.com';

// ─── ThresholdAlertService ────────────────────────────────────────────────────
class ThresholdAlertService {
  ThresholdAlertService._();
  static final ThresholdAlertService instance = ThresholdAlertService._();

  final _controller = StreamController<List<ThresholdAlert>>.broadcast();
  Stream<List<ThresholdAlert>> get stream => _controller.stream;

  Timer? _timer;
  bool   _running = false;

  final List<ThresholdAlert> _alerts     = [];
  final Map<String, double>  _prevValues = {};

  List<ThresholdAlert> get currentAlerts => List.unmodifiable(_alerts);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _loadCache();
    await _poll();
    _timer = Timer.periodic(_kPollInterval, (_) => _poll());
    debugPrint('[TAS] started — WRD Bihar only, ${kBiharGauges.length} gauges');
  }

  void stop() {
    _timer?.cancel();
    _timer   = null;
    _running = false;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  // ── Poll ───────────────────────────────────────────────────────────────────

  Future<void> _poll() async {
    debugPrint('[TAS] poll @ ${DateTime.now()}');

    // Fetch all station data from backend in ONE call.
    final Map<String, double> liveMap = await _fetchAllStations();

    final newAlerts = <ThresholdAlert>[];

    for (final gauge in kBiharGauges) {
      final id = _gaugeId(gauge);
      final level = liveMap[gauge.station] ?? liveMap[id];
      if (level == null) continue;

      final prev = _prevValues[id];
      _prevValues[id] = level;

      final alert = AlertEvaluator.fromBiharGauge(
        gauge:         gauge,
        currentValue:  level,
        previousValue: prev,
      );
      if (alert != null) newAlerts.add(alert);
    }

    if (newAlerts.isEmpty) {
      debugPrint('[TAS] poll done — no data from backend');
      return;
    }

    _mergeAlerts(newAlerts);

    for (final alert in newAlerts) {
      if (alert.level.requiresPush) await _notify(alert);
    }

    await _saveCache();
    _controller.add(currentAlerts);
    debugPrint('[TAS] poll done — ${newAlerts.length} gauges updated');
  }

  // ── Backend fetch: GET /stations ───────────────────────────────────────────
  //
  // The backend returns a list of station objects:
  //   { "name": "Gandhighat", "current_level": 47.82, ... }
  //
  // We build a name→level map.  If the backend is down, returns {}.

  Future<Map<String, double>> _fetchAllStations() async {
    try {
      final res = await http
          .get(Uri.parse('$_kBackendBase/stations'))
          .timeout(_kHttpTimeout);
      if (res.statusCode != 200) return {};
      final body = jsonDecode(res.body);
      final list = body is List ? body : (body['stations'] as List? ?? []);
      final map  = <String, double>{};
      for (final item in list) {
        if (item is! Map) continue;
        final name  = item['name']?.toString().trim();
        final level = item['current_level'];
        if (name != null && name.isNotEmpty && level != null) {
          map[name] = (level as num).toDouble();
        }
      }
      debugPrint('[TAS] backend returned ${map.length} stations');
      return map;
    } catch (e) {
      debugPrint('[TAS] backend fetch error: $e');
      return {};
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _gaugeId(BiharGauge g) =>
      '${g.river.toLowerCase().replaceAll(' ', '_')}_'
      '${g.station.toLowerCase().replaceAll(' ', '_')}';

  void _mergeAlerts(List<ThresholdAlert> incoming) {
    for (final alert in incoming) {
      _alerts.removeWhere((a) => a.cityId == alert.cityId);
      _alerts.insert(0, alert);
    }
    _alerts.sort((a, b) {
      final cmp = b.level.index.compareTo(a.level.index);
      return cmp != 0 ? cmp : b.timestamp.compareTo(a.timestamp);
    });
    if (_alerts.length > _kMaxCached) {
      _alerts.removeRange(_kMaxCached, _alerts.length);
    }
  }

  // ── FCM notification ───────────────────────────────────────────────────────

  Future<void> _notify(ThresholdAlert alert) async {
    final prefs    = await SharedPreferences.getInstance();
    final key      = 'wrd_last_${alert.cityId}';
    final lastSeen = prefs.getString(key);
    if (lastSeen != null) {
      final lastLevel = AlertLevel.values.firstWhere(
        (l) => l.name == lastSeen, orElse: () => AlertLevel.normal);
      if (alert.level.index <= lastLevel.index) return;
    }
    await prefs.setString(key, alert.level.name);

    final severity = switch (alert.level) {
      AlertLevel.extreme => 'EXTREME',
      AlertLevel.danger  => 'DANGER',
      _                  => 'WARNING',
    };
    final body =
        '${alert.river} at ${alert.cityName}: '
        '${alert.currentValue.toStringAsFixed(2)} m MSL. '
        'Danger: ${alert.dangerLevel.toStringAsFixed(2)} m. '
        'Trend: ${alert.trend.name}.';

    await FcmService.instance.showAlertNotification(
      cityName:     alert.cityName,
      state:        'Bihar',
      river:        alert.river,
      severity:     severity,
      currentLevel: alert.currentValue,
      dangerLevel:  alert.dangerLevel,
      message:      body,
    );
  }

  // ── SharedPreferences cache ────────────────────────────────────────────────

  Future<void> _saveCache() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final simple = _alerts.take(60).map((a) => {
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
        'isDischarge':  false,
        'trend':        a.trend.name,
      }).toList();
      await prefs.setString(_kPrefAlertsJson, jsonEncode(simple));
    } catch (_) {}
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kPrefAlertsJson);
      if (raw == null) return;
      final list  = jsonDecode(raw) as List;
      _alerts.clear();
      for (final m in list) {
        final map = m as Map<String, dynamic>;
        _alerts.add(ThresholdAlert(
          id:           '${map['cityId']}_cached',
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
          isDischarge:  false,
          isNew:        false,
          trend:        TrendDirection.values.firstWhere(
                          (t) => t.name == map['trend'],
                          orElse: () => TrendDirection.steady),
        ));
      }
      debugPrint('[TAS] loaded ${_alerts.length} cached WRD alerts');
    } catch (e) {
      debugPrint('[TAS] cache load failed: $e');
    }
  }

  // ── Public helpers ─────────────────────────────────────────────────────────

  Future<void> markAllSeen() async {
    for (int i = 0; i < _alerts.length; i++) {
      _alerts[i] = _alerts[i].copyWith(isNew: false);
    }
    _controller.add(currentAlerts);
    await _saveCache();
  }

  Future<void> refresh() async {
    _prevValues.clear();
    await _poll();
  }

  int get unreadCount =>
      _alerts.where((a) => a.isNew && a.level.requiresPush).length;
}
