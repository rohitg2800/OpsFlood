// lib/services/offline_rule_engine.dart
//
// OpsFlood — OfflineRuleEngine  v1.0
//
// PURPOSE:
//   When the device has no internet connection, the app still holds the last
//   fetched river-level snapshots in LocalCacheService.  This engine:
//     1. Reads that cached snapshot entirely in-memory — zero network calls.
//     2. Applies the same CWC danger-class + GloFAS fill-percent rules that
//        the live engine uses, so the displayed risk band never silently
//        "resets" to SAFE just because the user went offline.
//     3. Emits a [ValueNotifier<List<RuleResult>>] that the UI / Riverpod
//        providers can watch.
//     4. Fires flutter_local_notifications for any station whose risk
//        worsened since the last evaluation — even fully offline.
//     5. Exposes [AllIndiaAlertEngine.allStations] as a convenient
//        [List<FloodData>] so existing widgets need zero changes.
//
// INTEGRATION (add once to main.dart or wherever you init services):
//   await OfflineRuleEngine.instance.init();
//   OfflineRuleEngine.instance.start();   // starts periodic evaluation
//
// The engine is intentionally decoupled from network code so it can run
// inside a WorkManager background task without triggering any HTTP calls.

library;

import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/flood_data.dart';
import '../models/river_station.dart';   // DangerClass
import 'local_cache_service.dart';
import 'all_india_alert_engine.dart';    // to re-use allStations after sync

// ─────────────────────────────────────────────────────────────────────────────
// Rule result — one per cached station
// ─────────────────────────────────────────────────────────────────────────────

enum OfflineRisk { safe, elevated, high, critical }

class RuleResult {
  final String      city;
  final String      state;
  final String      river;
  final double      currentLevel;   // metres  (CWC gauge)
  final double      warningLevel;
  final double      dangerLevel;
  final double      hfl;
  final DangerClass dangerClass;    // CWC classification
  final double      gloFasFill;     // 0–100 % of GloFAS threshold
  final double      riskScore;      // 0–100 composite
  final OfflineRisk risk;
  final DateTime    cachedAt;       // when data was last fetched
  final bool        isStale;        // true if cache > 2 h old

  const RuleResult({
    required this.city,
    required this.state,
    required this.river,
    required this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.hfl,
    required this.dangerClass,
    required this.gloFasFill,
    required this.riskScore,
    required this.risk,
    required this.cachedAt,
    required this.isStale,
  });

  /// Human-readable label for the offline risk band.
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

  /// Progress fraction (0–1) of current level vs danger level.
  double get progressFraction =>
      dangerLevel > 0 ? (currentLevel / dangerLevel).clamp(0.0, 1.2) : 0.0;

  @override
  String toString() =>
      'RuleResult($city/$state risk=$riskLabel score=${riskScore.toStringAsFixed(1)})';
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine
// ─────────────────────────────────────────────────────────────────────────────

class OfflineRuleEngine {
  // Singleton
  static final OfflineRuleEngine instance = OfflineRuleEngine._();
  OfflineRuleEngine._();

  // ── Config ────────────────────────────────────────────────────────────────

  /// How often to re-evaluate cached data even if no new fetch arrived.
  static const Duration _evalInterval = Duration(minutes: 5);

  /// Cache entries older than this are flagged [RuleResult.isStale].
  static const Duration _staleThreshold = Duration(hours: 2);

  // Composite score weights — must match RiskCompute in river_monitor_screen.
  static const double _wCwc    = 0.45;
  static const double _wGloFas = 0.35;
  static const double _wMl     = 0.20;

  // Risk-band thresholds (v6.1 values)
  static const double _tCritical = 70;
  static const double _tHigh     = 45;
  static const double _tElevated = 35;

  // ── State ─────────────────────────────────────────────────────────────────

  /// Watch this from UI / providers.  Updated after every evaluation pass.
  final ValueNotifier<List<RuleResult>> results =
      ValueNotifier<List<RuleResult>>([]);

  /// Last time the engine ran an evaluation pass.
  DateTime? lastRun;

  /// Non-null only when an unexpected error occurred during evaluation.
  String? lastError;

  final LocalCacheService _cache  = LocalCacheService();
  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();

  bool   _notifReady = false;
  Timer? _timer;

  /// Previous risk per station key — used to detect worsening.
  final Map<String, OfflineRisk> _prevRisk = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Call once at app startup, before [start].
  Future<void> init() async {
    await _initNotifications();
  }

  /// Begin periodic offline evaluation.
  void start() {
    _timer?.cancel();
    evaluate(); // run immediately
    _timer = Timer.periodic(_evalInterval, (_) => evaluate());
  }

  /// Stop the periodic timer (e.g. when the screen is not visible).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Core evaluation pass ──────────────────────────────────────────────────

  /// Evaluate all cached stations synchronously (no await on network).
  /// Safe to call at any time — will never throw; errors land in [lastError].
  Future<void> evaluate() async {
    try {
      final snapshot = await _cache.loadAll();  // returns List<FloodData>
      if (snapshot.isEmpty) {
        // Nothing in cache yet — try pulling from the live engine's in-memory
        // list as a fallback (works when app just launched with connectivity).
        final liveList = AllIndiaAlertEngine().allStations;
        if (liveList.isEmpty) return;
        _processSnapshot(liveList);
        return;
      }
      _processSnapshot(snapshot);
    } catch (e, st) {
      lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[OfflineRuleEngine] evaluate() error: $e');
        debugPrint(st.toString());
      }
    }
  }

  void _processSnapshot(List<FloodData> snapshot) {
    final now      = DateTime.now();
    final output   = <RuleResult>[];
    final worsened = <RuleResult>[];

    for (final fd in snapshot) {
      final result = _applyRules(fd, now);
      output.add(result);

      final key  = '${fd.state}|${fd.city}'.toLowerCase();
      final prev = _prevRisk[key];
      if (_isWorseThan(result.risk, prev)) {
        worsened.add(result);
      }
      _prevRisk[key] = result.risk;
    }

    // Sort: critical → high → elevated → safe, then alphabetically.
    output.sort((a, b) {
      final diff = b.risk.index - a.risk.index;
      return diff != 0 ? diff : a.city.compareTo(b.city);
    });

    results.value = output;
    lastRun       = now;
    lastError     = null;

    if (kDebugMode) {
      debugPrint('[OfflineRuleEngine] ${output.length} stations evaluated '
          '(${worsened.length} worsened)');
    }

    // Fire notifications outside the synchronous path.
    for (final r in worsened) {
      _fireNotification(r);
    }
  }

  // ── Rule application ──────────────────────────────────────────────────────

  /// Stateless, pure function — applies CWC + GloFAS rules to one [FloodData].
  RuleResult _applyRules(FloodData fd, DateTime now) {
    // ── 1. CWC danger-class pct  ──────────────────────────────────────────
    double cwcPct = 0;
    final cur  = fd.currentLevel;
    final warn = fd.warningLevel;
    final hfl  = fd.hfl;
    final dang = fd.dangerLevel;

    if (warn > 0 && hfl > warn) {
      cwcPct = ((cur - warn) / (hfl - warn) * 100).clamp(0.0, 100.0);
    } else if (hfl > 0) {
      cwcPct = (cur / hfl * 100).clamp(0.0, 100.0);
    }

    // ── 2. GloFAS fill pct  ───────────────────────────────────────────────
    // FloodData stores this as fillPercent (0–100) when available.
    final gloFasPct = (fd.fillPercent ?? 0.0).clamp(0.0, 100.0);

    // ── 3. ML probability pct  ───────────────────────────────────────────
    final mlPct = ((fd.mlFloodProb ?? 0.0) * 100).clamp(0.0, 100.0);

    // ── 4. Composite score  ──────────────────────────────────────────────
    final score =
        (_wCwc * cwcPct + _wGloFas * gloFasPct + _wMl * mlPct)
            .clamp(0.0, 100.0);

    // ── 5. Risk band  ────────────────────────────────────────────────────
    final risk = score >= _tCritical
        ? OfflineRisk.critical
        : score >= _tHigh
            ? OfflineRisk.high
            : score >= _tElevated
                ? OfflineRisk.elevated
                : OfflineRisk.safe;

    // ── 6. DangerClass from CWC thresholds  ──────────────────────────────
    final dc = _cwcDangerClass(cur, warn, dang, hfl);

    // ── 7. Staleness check  ──────────────────────────────────────────────
    final cachedAt  = fd.cachedAt ?? now;
    final isStale   = now.difference(cachedAt) > _staleThreshold;

    return RuleResult(
      city:         fd.city,
      state:        fd.state,
      river:        fd.riverName ?? '',
      currentLevel: cur,
      warningLevel: warn,
      dangerLevel:  dang,
      hfl:          hfl,
      dangerClass:  dc,
      gloFasFill:   gloFasPct,
      riskScore:    score,
      risk:         risk,
      cachedAt:     cachedAt,
      isStale:      isStale,
    );
  }

  // ── CWC danger class (pure) ───────────────────────────────────────────────

  DangerClass _cwcDangerClass(
      double cur, double warn, double dang, double hfl) {
    // Extreme: at or above HFL
    if (hfl > 0 && cur >= hfl) return DangerClass.extreme;
    // Severe:  at or above Danger level but below HFL
    if (dang > 0 && cur >= dang) return DangerClass.severe;
    // Above Normal: at or above Warning but below Danger
    if (warn > 0 && cur >= warn) return DangerClass.aboveNormal;
    return DangerClass.normal;
  }

  // ── Change detection ─────────────────────────────────────────────────────

  bool _isWorseThan(OfflineRisk current, OfflineRisk? previous) {
    final c = current.index;
    final p = previous?.index ?? 0;
    return c > p && c >= OfflineRisk.elevated.index;
  }

  // ── Convenience accessors ─────────────────────────────────────────────────

  /// All stations currently at CRITICAL risk.
  List<RuleResult> get critical =>
      results.value.where((r) => r.risk == OfflineRisk.critical).toList();

  /// All stations at HIGH or CRITICAL risk.
  List<RuleResult> get highOrCritical => results.value
      .where((r) =>
          r.risk == OfflineRisk.high || r.risk == OfflineRisk.critical)
      .toList();

  /// Worst risk band currently observed across all cached stations.
  OfflineRisk get worstRisk {
    if (results.value.isEmpty) return OfflineRisk.safe;
    return results.value
        .map((r) => r.risk)
        .reduce((a, b) => a.index >= b.index ? a : b);
  }

  /// Stations for a given state, sorted by descending risk.
  List<RuleResult> forState(String state) => results.value
      .where((r) => r.state == state)
      .toList()
    ..sort((a, b) => b.risk.index - a.risk.index);

  /// Worst risk band for a given state.
  OfflineRisk stateRisk(String state) {
    final list = forState(state);
    if (list.isEmpty) return OfflineRisk.safe;
    return list.first.risk;
  }

  // ── Notifications  ────────────────────────────────────────────────────────

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
        ? 'Cached level ${r.currentLevel.toStringAsFixed(2)} m '
          '/ Danger ${r.dangerLevel.toStringAsFixed(2)} m'
        : 'Elevated risk on ${r.river.isEmpty ? "river" : r.river}';

    final android = AndroidNotificationDetails(
      'flood_offline',
      'Offline Flood Alerts',
      channelDescription:
          'Flood risk alerts evaluated from cached data while offline',
      importance:      isCrit ? Importance.max  : Importance.high,
      priority:        isCrit ? Priority.max    : Priority.high,
      color:           isCrit ? const Color(0xFFD32F2F) : const Color(0xFFF57C00),
      icon:            '@mipmap/ic_launcher',
      playSound:       true,
      enableVibration: true,
    );
    const ios = DarwinNotificationDetails(
        presentAlert: true, presentSound: true);

    await _notif.show(
      // Use a distinct ID space from the online engine (offset +100000).
      r.city.hashCode.abs() + 100000,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }
}
