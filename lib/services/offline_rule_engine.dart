// lib/services/offline_rule_engine.dart
//
// OpsFlood — OfflineRuleEngine  v1.2
//
// Evaluates flood risk from the last-known in-memory snapshot with ZERO
// network calls, so risk bands never silently reset to SAFE when offline.
//
// Data source (priority order, both in-memory, no I/O):
//   1. AllIndiaAlertEngine().allStations  (most recent live poll)
//   2. Empty list — engine idles gracefully until data arrives
//
// Rule inputs mapped to actual FloodData fields:
//   CWC pct   → derived from currentLevel / dangerLevel / warningLevel
//   GloFAS pct → FloodData.capacityPercent  (0–100)
//   ML pct     → 0.0  (field not yet on FloodData model)
//   staleness  → FloodData.lastUpdated
//
// INTEGRATION (already done in main.dart):
//   await OfflineRuleEngine.instance.init();
//   OfflineRuleEngine.instance.start();
//
// READING in a widget:
//   ValueListenableBuilder<List<RuleResult>>(
//     valueListenable: OfflineRuleEngine.instance.results,
//     builder: (ctx, list, _) { ... },
//   );

library;

import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/flood_data.dart';
import 'all_india_alert_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Risk band
// ─────────────────────────────────────────────────────────────────────────────

enum OfflineRisk { safe, elevated, high, critical }

// ─────────────────────────────────────────────────────────────────────────────
// Per-station result
// ─────────────────────────────────────────────────────────────────────────────

class RuleResult {
  final String      city;
  final String      state;
  final String      river;
  final double      currentLevel;    // metres
  final double      warningLevel;
  final double      dangerLevel;
  final double      capacityPct;     // 0–100, from FloodData.capacityPercent
  final double      riskScore;       // 0–100 composite
  final OfflineRisk risk;
  final DateTime    dataTimestamp;   // FloodData.lastUpdated
  final bool        isStale;         // true if data > 2 h old

  const RuleResult({
    required this.city,
    required this.state,
    required this.river,
    required this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.capacityPct,
    required this.riskScore,
    required this.risk,
    required this.dataTimestamp,
    required this.isStale,
  });

  String get riskLabel => switch (risk) {
    OfflineRisk.safe     => 'SAFE',
    OfflineRisk.elevated => 'ELEVATED',
    OfflineRisk.high     => 'HIGH RISK',
    OfflineRisk.critical => 'CRITICAL',
  };

  Color get riskColor => switch (risk) {
    OfflineRisk.safe     => const Color(0xFF22C55E),
    OfflineRisk.elevated => const Color(0xFFD4A843),
    OfflineRisk.high     => const Color(0xFFF97316),
    OfflineRisk.critical => const Color(0xFFEF4444),
  };

  /// Fraction (0–1.2) of current level vs danger level.
  double get progressFraction =>
      dangerLevel > 0 ? (currentLevel / dangerLevel).clamp(0.0, 1.2) : 0.0;

  @override
  String toString() =>
      'RuleResult($city/$state $riskLabel '
      'score=${riskScore.toStringAsFixed(1)})';
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine singleton
// ─────────────────────────────────────────────────────────────────────────────

class OfflineRuleEngine {
  static final OfflineRuleEngine instance = OfflineRuleEngine._();
  OfflineRuleEngine._();

  // ── Config ────────────────────────────────────────────────────────────
  static const Duration _evalInterval = Duration(minutes: 5);
  static const Duration _staleAfter   = Duration(hours: 2);

  // Score weights — CWC gauge pct (0.45) + capacity pct (0.35) + ML (0.20).
  // ML is always 0 until mlFloodProb is added to FloodData.
  static const double _wCwc  = 0.45;
  static const double _wCap  = 0.35;
  static const double _wMl   = 0.20;

  // Thresholds (match river_monitor_screen.dart v6.1)
  static const double _tCritical = 70;
  static const double _tHigh     = 45;
  static const double _tElevated = 35;

  // ── Public state ─────────────────────────────────────────────────────

  final ValueNotifier<List<RuleResult>> results =
      ValueNotifier<List<RuleResult>>([]);

  DateTime? lastRun;
  String?   lastError;

  // ── Private state ─────────────────────────────────────────────────────

  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  bool   _notifReady = false;
  Timer? _timer;
  final Map<String, OfflineRisk> _prevRisk = {};

  // ── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> init() async => _initNotifications();

  void start() {
    _timer?.cancel();
    evaluate();
    _timer = Timer.periodic(_evalInterval, (_) => evaluate());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Evaluate ──────────────────────────────────────────────────────────────

  Future<void> evaluate() async {
    try {
      final snapshot = AllIndiaAlertEngine().allStations;
      if (snapshot.isEmpty) {
        if (kDebugMode) debugPrint('[OfflineRuleEngine] no cached data yet');
        return;
      }
      _process(snapshot);
    } catch (e, st) {
      lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[OfflineRuleEngine] error: $e');
        debugPrint(st.toString());
      }
    }
  }

  // ── Process ───────────────────────────────────────────────────────────────

  void _process(List<FloodData> snapshot) {
    final now      = DateTime.now();
    final output   = <RuleResult>[];
    final worsened = <RuleResult>[];

    for (final fd in snapshot) {
      final r   = _applyRules(fd, now);
      final key = '${fd.state}|${fd.city}'.toLowerCase();
      output.add(r);
      if (_isWorseThan(r.risk, _prevRisk[key])) worsened.add(r);
      _prevRisk[key] = r.risk;
    }

    output.sort((a, b) {
      final d = b.risk.index - a.risk.index;
      return d != 0 ? d : a.city.compareTo(b.city);
    });

    results.value = output;
    lastRun       = now;
    lastError     = null;

    if (kDebugMode) {
      debugPrint('[OfflineRuleEngine] ${output.length} stations, '
          '${worsened.length} worsened');
    }
    for (final r in worsened) {
      _fireNotification(r);
    }
  }

  // ── Rule application (pure, stateless) ─────────────────────────────────────

  RuleResult _applyRules(FloodData fd, DateTime now) {
    final cur  = fd.currentLevel;
    final warn = fd.warningLevel;
    final dang = fd.dangerLevel;
    final safe = fd.safeLevel;

    // ── 1. CWC pct  ────────────────────────────────────────────────────────
    // Measure how far above warningLevel the current level is,
    // as a % of the (dangerLevel − warningLevel) band.
    double cwcPct = 0;
    if (warn > 0 && dang > warn) {
      cwcPct = ((cur - warn) / (dang - warn) * 100).clamp(0.0, 100.0);
    } else if (dang > safe) {
      cwcPct = ((cur - safe) / (dang - safe) * 100).clamp(0.0, 100.0);
    }

    // ── 2. Capacity pct  ───────────────────────────────────────────────────
    // FloodData.capacityPercent = (current-safe)/(danger-safe)*100, clamped 0–100.
    final capPct = fd.capacityPercent.clamp(0.0, 100.0);

    // ── 3. ML pct  ─────────────────────────────────────────────────────────
    // Not yet on FloodData — defaults to 0.  When mlFloodProb is added to
    // the model, replace the 0.0 below with (fd.mlFloodProb * 100).clamp(0,100).
    const double mlPct = 0.0;

    // ── 4. Composite score  ────────────────────────────────────────────────
    final score =
        (_wCwc * cwcPct + _wCap * capPct + _wMl * mlPct)
            .clamp(0.0, 100.0);

    // ── 5. Risk band  ──────────────────────────────────────────────────────
    final risk = score >= _tCritical
        ? OfflineRisk.critical
        : score >= _tHigh
            ? OfflineRisk.high
            : score >= _tElevated
                ? OfflineRisk.elevated
                : OfflineRisk.safe;

    // ── 6. Staleness  ──────────────────────────────────────────────────────
    final isStale = now.difference(fd.lastUpdated) > _staleAfter;

    return RuleResult(
      city:           fd.city,
      state:          fd.state,
      river:          fd.riverName ?? '',
      currentLevel:   cur,
      warningLevel:   warn,
      dangerLevel:    dang,
      capacityPct:    capPct,
      riskScore:      score,
      risk:           risk,
      dataTimestamp:  fd.lastUpdated,
      isStale:        isStale,
    );
  }

  // ── Change detection ───────────────────────────────────────────────────

  bool _isWorseThan(OfflineRisk current, OfflineRisk? prev) =>
      current.index > (prev?.index ?? 0) &&
      current.index >= OfflineRisk.elevated.index;

  // ── Convenience accessors ───────────────────────────────────────────────

  List<RuleResult> get critical =>
      results.value.where((r) => r.risk == OfflineRisk.critical).toList();

  List<RuleResult> get highOrCritical => results.value
      .where((r) =>
          r.risk == OfflineRisk.high || r.risk == OfflineRisk.critical)
      .toList();

  OfflineRisk get worstRisk {
    if (results.value.isEmpty) return OfflineRisk.safe;
    return results.value
        .map((r) => r.risk)
        .reduce((a, b) => a.index >= b.index ? a : b);
  }

  List<RuleResult> forState(String state) =>
      (results.value.where((r) => r.state == state).toList()
        ..sort((a, b) => b.risk.index - a.risk.index));

  OfflineRisk stateRisk(String state) {
    final list = forState(state);
    return list.isEmpty ? OfflineRisk.safe : list.first.risk;
  }

  // ── Notifications ────────────────────────────────────────────────────────

  Future<void> _initNotifications() async {
    if (_notifReady) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings();
    await _notif.initialize(
        const InitializationSettings(android: android, iOS: ios));
    _notifReady = true;
  }

  Future<void> _fireNotification(RuleResult r) async {
    if (!_notifReady) return;
    final isCrit = r.risk == OfflineRisk.critical;
    final title  = isCrit
        ? '\ud83d\udea8 CRITICAL (offline): ${r.city}, ${r.state}'
        : '\u26a0\ufe0f WARNING (offline): ${r.city}, ${r.state}';
    final body = r.currentLevel > 0
        ? 'Cached level ${r.currentLevel.toStringAsFixed(2)} m'
          ' / Danger ${r.dangerLevel.toStringAsFixed(2)} m'
        : 'Elevated risk on ${r.river.isEmpty ? "river" : r.river}';

    final android = AndroidNotificationDetails(
      'flood_offline',
      'Offline Flood Alerts',
      channelDescription:
          'Flood risk evaluated from cached data while device is offline',
      importance:      isCrit ? Importance.max  : Importance.high,
      priority:        isCrit ? Priority.max    : Priority.high,
      color:           isCrit ? const Color(0xFFD32F2F) : const Color(0xFFF57C00),
      icon:            '@mipmap/ic_launcher',
      playSound:       true,
      enableVibration: true,
    );
    const ios = DarwinNotificationDetails(
        presentAlert: true, presentSound: true);

    // +100000 offset keeps IDs separate from AllIndiaAlertEngine notifications.
    await _notif.show(
      r.city.hashCode.abs() + 100000,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }
}
