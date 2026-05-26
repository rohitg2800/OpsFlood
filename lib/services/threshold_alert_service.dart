// lib/services/threshold_alert_service.dart
//
// OpsFlood — ThresholdAlertService  (Option B — pure discharge comparison)
//
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// WHY OPTION B?
//   The GloFAS flood API returns river_discharge in m³/s.
//   CWC/WRD thresholds are gauge heights in metres MSL.
//   Comparing m³/s against metres is a unit mismatch that produced nonsense
//   alert levels and fill-bar values.
//
//   Option B fixes this by fetching GloFAS statistical return-period
//   discharge thresholds for every monitored city:
//
//     river_discharge_return_period_2  (m³/s) → watch boundary
//     river_discharge_return_period_5  (m³/s) → warning level
//     river_discharge_return_period_20 (m³/s) → danger level
//
//   These come from the SAME flood-api.open-meteo.com endpoint, so units
//   always match live discharge perfectly.
//
// ARCHITECTURE:
//   • _ReturnPeriodThresholds fetched once per city per session (or on
//     forceRefresh).  Cached in _rpCache.  Serialised to SharedPreferences
//     so they survive app restarts without an extra API call.
//   • _poll() → _evaluateCity() / _evaluateBiharGauge() both:
//       1. Ensure thresholds are loaded (_ensureThresholds).
//       2. Fetch latest discharge.
//       3. Call AlertEvaluator.fromDischarge() — all values in m³/s.
//   • AlertEvaluator is unchanged; fromDischarge() was already correct.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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

// ─── Config ───────────────────────────────────────────────────────────────────
const _kPollInterval    = Duration(minutes: 15);
const _kPrefKeyPrefix   = 'threshold_alert_last_';
const _kPrefAlertsJson  = 'threshold_alerts_cache';
const _kPrefRpJson      = 'threshold_rp_cache';      // return-period cache
const _kMaxCachedAlerts = 200;
const _kHttpTimeout     = Duration(seconds: 20);

// ─── Return-period thresholds (all m³/s) ─────────────────────────────────────
class _Rp {
  final double watch;    // 2-yr return period
  final double warning;  // 5-yr return period
  final double danger;   // 20-yr return period

  const _Rp({required this.watch, required this.warning, required this.danger});

  /// HFL proxy: 1.5× the 20-yr level (GloFAS doesn't publish 100-yr directly).
  double get hfl => danger * 1.5;

  Map<String, dynamic> toJson() =>
      {'watch': watch, 'warning': warning, 'danger': danger};

  factory _Rp.fromJson(Map<String, dynamic> j) => _Rp(
        watch:   (j['watch']   as num).toDouble(),
        warning: (j['warning'] as num).toDouble(),
        danger:  (j['danger']  as num).toDouble(),
      );
}

// ─── ThresholdAlertService ────────────────────────────────────────────────────
class ThresholdAlertService {
  ThresholdAlertService._();
  static final ThresholdAlertService instance = ThresholdAlertService._();

  final _controller = StreamController<List<ThresholdAlert>>.broadcast();
  Stream<List<ThresholdAlert>> get stream => _controller.stream;

  Timer? _timer;
  bool   _running = false;

  final List<ThresholdAlert>  _alerts   = [];
  List<ThresholdAlert> get currentAlerts => List.unmodifiable(_alerts);

  final Map<String, double> _prevValues = {};
  final Map<String, _Rp>   _rpCache    = {};   // key = city/gauge id

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _loadCachedAlerts();
    await _loadRpCache();
    await _poll();
    _timer = Timer.periodic(_kPollInterval, (_) => _poll());
    debugPrint('[ThresholdAlertService] started (Option B — discharge vs return-period)');
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

  // ── Main poll cycle ────────────────────────────────────────────────────────

  Future<void> _poll() async {
    debugPrint('[ThresholdAlertService] poll @ ${DateTime.now()}');
    final newAlerts = <ThresholdAlert>[];

    // kIndiaCities replaces the old pan-India monitoredCities list.
    for (final city in kIndiaCities) {
      try {
        final alert = await _evaluateCity(city);
        if (alert != null) newAlerts.add(alert);
      } catch (e) {
        debugPrint('[ThresholdAlertService] city ${city.id}: $e');
      }
    }

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
    await _saveRpCache();
    _controller.add(currentAlerts);
    debugPrint('[ThresholdAlertService] poll done — ${newAlerts.length} new alerts');
  }

  // ── Per-city evaluation (IndiaCity) ───────────────────────────────────────

  Future<ThresholdAlert?> _evaluateCity(IndiaCity city) async {
    // 1. Ensure return-period thresholds are loaded for this city.
    final rp = await _ensureThresholds(
      id:  city.id,
      lat: city.lat,
      lon: city.lon,
    );
    if (rp == null) return null;

    // 2. Fetch latest live discharge.
    final discharge = await _fetchLatestDischarge(
        GloFasUrls.discharge(city.lat, city.lon));
    if (discharge == null) return null;

    final prev = _prevValues[city.id];
    _prevValues[city.id] = discharge;

    // 3. Evaluate — all values in m³/s.
    return AlertEvaluator.fromDischarge(
      cityId:           city.id,
      cityName:         city.name,
      state:            city.state,
      river:            city.river,
      dischargeM3s:     discharge,
      warningDischarge: rp.warning,
      dangerDischarge:  rp.danger,
      hflDischarge:     rp.hfl,
      previousDischarge: prev,
    );
  }

  // ── Per-gauge evaluation (BiharGauge) ─────────────────────────────────────

  Future<ThresholdAlert?> _evaluateBiharGauge(BiharGauge gauge) async {
    final id = '${gauge.river.toLowerCase().replaceAll(' ', '_')}_'
               '${gauge.station.toLowerCase().replaceAll(' ', '_')}';

    final rp = await _ensureThresholds(
      id:  id,
      lat: gauge.lat,
      lon: gauge.lon,
    );
    if (rp == null) return null;

    final discharge = await _fetchLatestDischarge(
        GloFasUrls.discharge(gauge.lat, gauge.lon));
    if (discharge == null) return null;

    final prev = _prevValues[id];
    _prevValues[id] = discharge;

    return AlertEvaluator.fromDischarge(
      cityId:           id,
      cityName:         gauge.station,
      state:            'Bihar',
      river:            gauge.river,
      dischargeM3s:     discharge,
      warningDischarge: rp.warning,
      dangerDischarge:  rp.danger,
      hflDischarge:     rp.hfl,
      previousDischarge: prev,
    );
  }

  // ── Return-period loader ───────────────────────────────────────────────────

  Future<_Rp?> _ensureThresholds({
    required String id,
    required double lat,
    required double lon,
  }) async {
    if (_rpCache.containsKey(id)) return _rpCache[id];
    return _fetchReturnPeriods(id: id, lat: lat, lon: lon);
  }

  Future<_Rp?> _fetchReturnPeriods({
    required String id,
    required double lat,
    required double lon,
  }) async {
    try {
      final res = await http
          .get(Uri.parse(GloFasUrls.returnPeriods(lat, lon)))
          .timeout(_kHttpTimeout);
      if (res.statusCode != 200) return null;

      final body  = jsonDecode(res.body) as Map<String, dynamic>;
      final daily = body['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      double _first(String key) {
        final list = daily[key] as List?;
        if (list == null || list.isEmpty || list.first == null) return 0.0;
        return (list.first as num).toDouble();
      }

      final rp2  = _first('river_discharge_return_period_2');
      final rp5  = _first('river_discharge_return_period_5');
      final rp20 = _first('river_discharge_return_period_20');

      if (rp2 <= 0 || rp5 <= 0 || rp20 <= 0) return null;
      if (!(rp2 <= rp5 && rp5 <= rp20)) return null;

      final rp = _Rp(watch: rp2, warning: rp5, danger: rp20);
      _rpCache[id] = rp;
      debugPrint('[ThresholdAlertService] RP $id — '
          'watch=${rp2.toStringAsFixed(0)} '
          'warn=${rp5.toStringAsFixed(0)} '
          'danger=${rp20.toStringAsFixed(0)} m³/s');
      return rp;
    } catch (e) {
      debugPrint('[ThresholdAlertService] RP fetch failed for $id: $e');
      return null;
    }
  }

  // ── Discharge fetcher ──────────────────────────────────────────────────────

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

  // ── Notification ───────────────────────────────────────────────────────────

  Future<void> _notify(ThresholdAlert alert) async {
    final prefs    = await SharedPreferences.getInstance();
    final key      = '$_kPrefKeyPrefix${alert.cityId}';
    final lastSeen = prefs.getString(key);

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
        '${alert.river} discharge at '
        '${alert.currentValue.toStringAsFixed(0)} m³/s. '
        'Danger threshold: '
        '${alert.dangerLevel.toStringAsFixed(0)} m³/s. '
        'Trend: ${alert.trend.name}.';

    await FcmService.instance.showAlertNotification(
      cityName:     alert.cityName,
      state:        alert.state,
      river:        alert.river,
      severity:     severity,
      currentLevel: alert.currentLevel,
      dangerLevel:  alert.dangerLevel,
      message:      body,
    );
  }

  // ── Persistence — alerts ───────────────────────────────────────────────────

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
        'isDischarge':  true,
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
          isDischarge:  true,
          isNew:        false,
          trend:        TrendDirection.values.firstWhere(
                          (t) => t.name == map['trend'],
                          orElse: () => TrendDirection.steady),
        ));
      }
      debugPrint('[ThresholdAlertService] loaded ${_alerts.length} cached alerts');
    } catch (e) {
      debugPrint('[ThresholdAlertService] alert cache load failed: $e');
    }
  }

  // ── Persistence — return-period cache ─────────────────────────────────────

  Future<void> _saveRpCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map   = _rpCache.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_kPrefRpJson, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _loadRpCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kPrefRpJson);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        _rpCache[entry.key] = _Rp.fromJson(entry.value as Map<String, dynamic>);
      }
      debugPrint('[ThresholdAlertService] loaded ${_rpCache.length} cached return-period entries');
    } catch (e) {
      debugPrint('[ThresholdAlertService] RP cache load failed: $e');
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

  Future<void> refresh() async {
    _rpCache.clear();
    await _poll();
  }

  int get unreadCount =>
      _alerts.where((a) => a.isNew && a.level.requiresPush).length;
}
