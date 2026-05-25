// lib/services/offline_rule_engine.dart
//
// OpsFlood — OfflineRuleEngine  v1.1
//
// PURPOSE:
//   When the device has no internet connection, the app still holds the last
//   fetched river-level snapshots in LocalCacheService and in the in-memory
//   AllIndiaAlertEngine.allStations list.  This engine:
//
//     1. Sources data (no network calls, ever):
//          Primary   — AllIndiaAlertEngine().allStations  (in-memory, fastest)
//          Secondary — LocalCacheService raw JSON entries (survives restarts)
//     2. Applies the same CWC danger-class + GloFAS fill-percent rules that
//        the live engine uses, so risk bands never silently reset to SAFE
//        when the user goes offline.
//     3. Emits ValueNotifier<List<RuleResult>> that any widget or Riverpod
//        provider can watch — no setState boilerplate needed.
//     4. Fires flutter_local_notifications for any station whose risk
//        worsened since the last evaluation, even fully offline.
//     5. Keeps the notification channel separate from the online engine
//        (channel id: flood_offline) so alerts never collide.
//
// INTEGRATION (already done in main.dart):
//   await LocalCacheService.instance.init();   // must come first
//   await OfflineRuleEngine.instance.init();
//   OfflineRuleEngine.instance.start();
//
// READING RESULTS in a widget:
//   ValueListenableBuilder<List<RuleResult>>(
//     valueListenable: OfflineRuleEngine.instance.results,
//     builder: (ctx, list, _) { ... },
//   );

library;

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/flood_data.dart';
import '../models/river_station.dart';   // DangerClass
import 'all_india_alert_engine.dart';
import 'local_cache_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Risk band enum
// ─────────────────────────────────────────────────────────────────────────────

enum OfflineRisk { safe, elevated, high, critical }

// ─────────────────────────────────────────────────────────────────────────────
// Per-station result emitted by the engine
// ─────────────────────────────────────────────────────────────────────────────

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
  final DateTime    cachedAt;       // timestamp of last known data
  final bool        isStale;        // true if data is > 2 h old

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

  double get progressFraction =>
      dangerLevel > 0 ? (currentLevel / dangerLevel).clamp(0.0, 1.2) : 0.0;

  @override
  String toString() =>
      'RuleResult($city/$state risk=$riskLabel '
      'score=${riskScore.toStringAsFixed(1)})';
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine singleton
// ─────────────────────────────────────────────────────────────────────────────

class OfflineRuleEngine {
  static final OfflineRuleEngine instance = OfflineRuleEngine._();
  OfflineRuleEngine._();

  // ── Config constants ────────────────────────────────────────────────────
  static const Duration _evalInterval  = Duration(minutes: 5);
  static const Duration _staleAfter    = Duration(hours: 2);

  // Weights (must match RiskCompute in river_monitor_screen.dart v6.1)
  static const double _wCwc    = 0.45;
  static const double _wGloFas = 0.35;
  static const double _wMl     = 0.20;

  // Thresholds (v6.1 values)
  static const double _tCritical = 70;
  static const double _tHigh     = 45;
  static const double _tElevated = 35;

  // ── Public state ────────────────────────────────────────────────────────

  /// Watch this from any widget or provider.
  final ValueNotifier<List<RuleResult>> results =
      ValueNotifier<List<RuleResult>>([]);

  DateTime? lastRun;
  String?   lastError;

  // ── Private state ─────────────────────────────────────────────────────

  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  bool   _notifReady = false;
  Timer? _timer;

  // previous risk per "state|city" key for change detection
  final Map<String, OfflineRisk> _prevRisk = {};

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Call once after [LocalCacheService.instance.init()] at app startup.
  Future<void> init() async => _initNotifications();

  /// Begin periodic evaluation — also runs immediately.
  void start() {
    _timer?.cancel();
    evaluate();
    _timer = Timer.periodic(_evalInterval, (_) => evaluate());
  }

  /// Stop periodic evaluation (e.g. app paused / widget disposed).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Evaluate ──────────────────────────────────────────────────────────────

  /// Run one evaluation pass.  Never throws — errors go to [lastError].
  Future<void> evaluate() async {
    try {
      final snapshot = _resolveSnapshot();
      if (snapshot.isEmpty) {
        if (kDebugMode) debugPrint('[OfflineRuleEngine] no data to evaluate');
        return;
      }
      _process(snapshot);
    } catch (e, st) {
      lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[OfflineRuleEngine] evaluate error: $e');
        debugPrint(st.toString());
      }
    }
  }

  // ── Data source resolution ──────────────────────────────────────────────────

  /// Returns a deduplicated list of [FloodData] from the best available
  /// source, with zero network calls.
  ///
  /// Priority:
  ///   1. [AllIndiaAlertEngine().allStations] — already in memory.
  ///   2. Raw JSON entries in [LocalCacheService] — survives app restarts.
  List<FloodData> _resolveSnapshot() {
    // Primary: live engine's in-memory list
    final live = AllIndiaAlertEngine().allStations;
    if (live.isNotEmpty) return live;

    // Secondary: walk all cache keys and try to deserialise FloodData.
    // LocalCacheService stores raw JSON strings keyed by arbitrary API paths.
    // We attempt FloodData.fromJson() on every entry and collect what parses.
    final cache  = LocalCacheService.instance;
    final prefs  = cache.prefsSync; // see note below
    if (prefs == null) return [];

    final out = <String, FloodData>{};
    for (final rawKey in prefs.getKeys()) {
      if (!rawKey.startsWith('opsflood_cache__')) continue;
      final jsonStr = prefs.getString(rawKey);
      if (jsonStr == null || jsonStr.isEmpty) continue;
      try {
        final decoded = jsonDecode(jsonStr);
        // Cache entries may be a List or a single Map.
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              try {
                final fd = FloodData.fromJson(item);
                out['${fd.state}|${fd.city}'.toLowerCase()] = fd;
              } catch (_) {}
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          try {
            final fd = FloodData.fromJson(decoded);
            out['${fd.state}|${fd.city}'.toLowerCase()] = fd;
          } catch (_) {}
        }
      } catch (_) {
        // Not a FloodData JSON entry — skip silently.
      }
    }
    return out.values.toList();
  }

  // ── Process snapshot ────────────────────────────────────────────────────────

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

    // critical → high → elevated → safe, then A–Z
    output.sort((a, b) {
      final d = b.risk.index - a.risk.index;
      return d != 0 ? d : a.city.compareTo(b.city);
    });

    results.value = output;
    lastRun       = now;
    lastError     = null;

    if (kDebugMode) {
      debugPrint('[OfflineRuleEngine] ${output.length} evaluated, '
          '${worsened.length} worsened');
    }
    for (final r in worsened) {
      _fireNotification(r);
    }
  }

  // ── Rule application (pure, stateless) ──────────────────────────────────────

  RuleResult _applyRules(FloodData fd, DateTime now) {
    final cur  = fd.currentLevel;
    final warn = fd.warningLevel;
    final hfl  = fd.hfl;
    final dang = fd.dangerLevel;

    // 1. CWC pct
    double cwcPct = 0;
    if (warn > 0 && hfl > warn) {
      cwcPct = ((cur - warn) / (hfl - warn) * 100).clamp(0.0, 100.0);
    } else if (hfl > 0) {
      cwcPct = (cur / hfl * 100).clamp(0.0, 100.0);
    }

    // 2. GloFAS pct (stored in FloodData.fillPercent by ThresholdAlertService)
    final gloFasPct = (fd.fillPercent ?? 0.0).clamp(0.0, 100.0);

    // 3. ML pct
    final mlPct = ((fd.mlFloodProb ?? 0.0) * 100).clamp(0.0, 100.0);

    // 4. Composite
    final score =
        (_wCwc * cwcPct + _wGloFas * gloFasPct + _wMl * mlPct)
            .clamp(0.0, 100.0);

    // 5. Band
    final risk = score >= _tCritical
        ? OfflineRisk.critical
        : score >= _tHigh
            ? OfflineRisk.high
            : score >= _tElevated
                ? OfflineRisk.elevated
                : OfflineRisk.safe;

    // 6. CWC danger class
    final dc = _dangerClass(cur, warn, dang, hfl);

    // 7. Staleness
    final cachedAt = fd.cachedAt ?? now;
    final isStale  = now.difference(cachedAt) > _staleAfter;

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

  DangerClass _dangerClass(
      double cur, double warn, double dang, double hfl) {
    if (hfl > 0 && cur >= hfl)  return DangerClass.extreme;
    if (dang > 0 && cur >= dang) return DangerClass.severe;
    if (warn > 0 && cur >= warn) return DangerClass.aboveNormal;
    return DangerClass.normal;
  }

  bool _isWorseThan(OfflineRisk current, OfflineRisk? prev) =>
      current.index > (prev?.index ?? 0) &&
      current.index >= OfflineRisk.elevated.index;

  // ── Convenience accessors ─────────────────────────────────────────────────

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

  // ── Notifications ─────────────────────────────────────────────────────────

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

    await _notif.show(
      r.city.hashCode.abs() + 100000, // offset avoids collision with online engine
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }
}
