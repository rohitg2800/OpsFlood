// lib/services/active_alert_controller.dart
//
// OpsFlood — Active Alert Rules Engine
//
// Sits between DataFetchEngine and the UI alert widgets.
// Converts raw StationReading snapshots into deduplicated, tiered
// AlertItem objects that drive LiveAlertBanner and DangerProximityBanner.
//
// Alert tiers (descending severity):
//   EXTREME  — currentLevel >= hfl                   (above all-time flood)
//   CRITICAL — currentLevel >= dangerLevel            (in danger zone)
//   DANGER   — currentLevel >= warningLevel           (in warning zone)
//   RISING   — live, below WL but RoR >= 0.5 m/h     (rapid rise warning)
//   NORMAL   — no alert (suppressed / cleared)
//
// Rules:
//   1. SEED-source stations NEVER trigger alerts.
//   2. Each station has at most one active AlertItem.
//   3. A station's alert is suppressed for _kSuppressWindow after it was
//      last seen in the same tier, UNLESS the tier escalates.
//   4. Stations that drop to NORMAL and stay there for _kClearWindow
//      are removed from the active set.
//   5. At most _kMaxAlerts items are surfaced to the UI (highest first).
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'data_fetch_engine.dart';

// ── Severity enum (ordered low→high for comparisons) ─────────────────────────
enum AlertSeverity { normal, rising, danger, critical, extreme }

extension AlertSeverityX on AlertSeverity {
  bool operator >(AlertSeverity other) => index > other.index;
  bool operator >=(AlertSeverity other) => index >= other.index;
}

// ── AlertItem ─────────────────────────────────────────────────────────────────
class AlertItem {
  final String        stationKey;     // normalised key for dedup
  final String        stationName;
  final String        river;
  final String        district;
  final AlertSeverity severity;
  final String        message;        // primary banner text
  final String?       subMessage;     // secondary info line
  final double?       rateOfRiseMph;  // m/h, shown as chip when >= 0.3
  final double        currentLevel;
  final double        dangerLevel;
  final double        hfl;
  final bool          aboveHfl;
  final String        source;
  final bool          isLive;
  final DateTime      firstSeenAt;
  final DateTime      lastSeenAt;

  const AlertItem({
    required this.stationKey,
    required this.stationName,
    required this.river,
    required this.district,
    required this.severity,
    required this.message,
    required this.subMessage,
    required this.rateOfRiseMph,
    required this.currentLevel,
    required this.dangerLevel,
    required this.hfl,
    required this.aboveHfl,
    required this.source,
    required this.isLive,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });

  AlertItem copyWithTime(DateTime lastSeen) => AlertItem(
    stationKey:    stationKey,
    stationName:   stationName,
    river:         river,
    district:      district,
    severity:      severity,
    message:       message,
    subMessage:    subMessage,
    rateOfRiseMph: rateOfRiseMph,
    currentLevel:  currentLevel,
    dangerLevel:   dangerLevel,
    hfl:           hfl,
    aboveHfl:      aboveHfl,
    source:        source,
    isLive:        isLive,
    firstSeenAt:   firstSeenAt,
    lastSeenAt:    lastSeen,
  );
}

// ── ActiveAlertController ────────────────────────────────────────────────────
class ActiveAlertController {
  ActiveAlertController._();
  static final instance = ActiveAlertController._();

  // Max simultaneous alerts surfaced to UI
  static const _kMaxAlerts      = 5;
  // How long a station stays suppressed after last seen in same tier
  static const _kSuppressWindow = Duration(minutes: 30);
  // How long after NORMAL before removing from active set
  static const _kClearWindow    = Duration(minutes: 5);
  // Min RoR (m/h) to trigger a RISING alert
  static const _kRorThreshold   = 0.5;
  // Min rainfall (mm) to co-trigger RISING (prevents dry-season false positives)
  static const _kRainThreshold  = 20.0;

  // ── internal state ──────────────────────────────────────────────────────────
  final _activeMap   = <String, AlertItem>{};
  final _normalSince = <String, DateTime>{};     // station → went-normal at
  StreamSubscription<DataFetchSnapshot>? _sub;
  bool _started = false;

  final _ctrl = StreamController<List<AlertItem>>.broadcast();

  /// Live stream of current alert items for the UI.
  Stream<List<AlertItem>> get stream => _ctrl.stream;

  /// Current snapshot (sync read for widgets).
  List<AlertItem> get alerts => _sortedAlerts();

  // ── lifecycle ────────────────────────────────────────────────────────────────
  void start() {
    if (_started) return;
    _started = true;
    _sub = DataFetchEngine.instance.stream.listen(_onSnapshot);
    debugPrint('[AlertCtrl] started');
  }

  void stop() {
    _sub?.cancel();
    _started = false;
    debugPrint('[AlertCtrl] stopped');
  }

  // ── core processing ──────────────────────────────────────────────────────────
  void _onSnapshot(DataFetchSnapshot snap) {
    if (snap.isLoading || snap.stations.isEmpty) return;
    final now = DateTime.now();

    for (final s in snap.stations) {
      // Rule 1: SEED source never alerts
      if (s.source == 'SEED') continue;

      final key      = _norm(s.stationName);
      final severity = _deriveSeverity(s);

      if (severity == AlertSeverity.normal) {
        // Track when it went normal for clearance
        _normalSince.putIfAbsent(key, () => now);
        final sinceNormal = now.difference(_normalSince[key]!);
        if (sinceNormal >= _kClearWindow) {
          _activeMap.remove(key);
          _normalSince.remove(key);
        }
        continue;
      }

      // Station is alertable — clear any "went normal" timestamp
      _normalSince.remove(key);

      final existing = _activeMap[key];

      // Suppression: same tier, not yet expired
      final isSameTier = existing != null && existing.severity == severity;
      final isExpired  = existing == null ||
          now.difference(existing.lastSeenAt) >= _kSuppressWindow;
      final escalated  = existing != null && severity > existing.severity;

      if (isSameTier && !isExpired && !escalated) {
        // Just update timestamp, no re-fire
        _activeMap[key] = existing.copyWithTime(now);
        continue;
      }

      // Build new AlertItem
      _activeMap[key] = _buildAlert(s, severity, now,
          firstSeen: existing?.firstSeenAt ?? now);
    }

    _emit();
  }

  void _emit() {
    if (!_ctrl.isClosed) _ctrl.add(_sortedAlerts());
  }

  List<AlertItem> _sortedAlerts() {
    final all = _activeMap.values.toList()
      ..sort((a, b) {
        // Sort by severity desc, then by (currentLevel / dangerLevel) desc
        final sc = b.severity.index.compareTo(a.severity.index);
        if (sc != 0) return sc;
        final ap = a.dangerLevel > 0 ? a.currentLevel / a.dangerLevel : 0.0;
        final bp = b.dangerLevel > 0 ? b.currentLevel / b.dangerLevel : 0.0;
        return bp.compareTo(ap);
      });
    return all.take(_kMaxAlerts).toList();
  }

  // ── severity derivation ──────────────────────────────────────────────────────
  AlertSeverity _deriveSeverity(StationReading s) {
    if (!s.isLive) return AlertSeverity.normal; // non-live never alerts
    if (s.currentLevel >= s.hfl)          return AlertSeverity.extreme;
    if (s.currentLevel >= s.dangerLevel)  return AlertSeverity.critical;
    if (s.currentLevel >= s.warningLevel) return AlertSeverity.danger;
    // RISING: below WL but rapid rise + rainfall co-trigger
    final ror  = s.rateOfRiseMph ?? 0.0;
    final rain = s.rainfall24hMm ?? 0.0;
    if (ror >= _kRorThreshold && rain >= _kRainThreshold) {
      return AlertSeverity.rising;
    }
    return AlertSeverity.normal;
  }

  // ── alert item builder ───────────────────────────────────────────────────────
  AlertItem _buildAlert(
    StationReading s,
    AlertSeverity  severity,
    DateTime       now, {
    required DateTime firstSeen,
  }) {
    final key = _norm(s.stationName);

    // Primary message
    final tierLabel = switch (severity) {
      AlertSeverity.extreme  => '🚨 ABOVE HFL',
      AlertSeverity.critical => '🔴 CRITICAL',
      AlertSeverity.danger   => '🟠 DANGER',
      AlertSeverity.rising   => '⚡ RAPID RISE',
      AlertSeverity.normal   => 'NORMAL',
    };
    final message = '$tierLabel — ${s.stationName} (${s.river})';

    // Sub-message: level info
    final aboveDl = (s.currentLevel - s.dangerLevel);
    final sub = switch (severity) {
      AlertSeverity.extreme  =>
          '${s.currentLevel.toStringAsFixed(2)} m — '
          '${(s.currentLevel - s.hfl).abs().toStringAsFixed(2)} m above HFL',
      AlertSeverity.critical =>
          '${s.currentLevel.toStringAsFixed(2)} m — '
          '+${aboveDl.toStringAsFixed(2)} m above danger (${s.dangerLevel.toStringAsFixed(2)} m)',
      AlertSeverity.danger   =>
          '${s.currentLevel.toStringAsFixed(2)} m — '
          'DL ${s.dangerLevel.toStringAsFixed(2)} m · WL ${s.warningLevel.toStringAsFixed(2)} m',
      AlertSeverity.rising   =>
          'Rising at ${(s.rateOfRiseMph ?? 0).toStringAsFixed(2)} m/h · '
          '${(s.rainfall24hMm ?? 0).toStringAsFixed(0)} mm rain/24h',
      AlertSeverity.normal   => '',
    };

    return AlertItem(
      stationKey:    key,
      stationName:   s.stationName,
      river:         s.river,
      district:      s.district,
      severity:      severity,
      message:       message,
      subMessage:    sub.isNotEmpty ? sub : null,
      rateOfRiseMph: s.rateOfRiseMph,
      currentLevel:  s.currentLevel,
      dangerLevel:   s.dangerLevel,
      hfl:           s.hfl,
      aboveHfl:      s.currentLevel >= s.hfl,
      source:        s.source,
      isLive:        s.isLive,
      firstSeenAt:   firstSeen,
      lastSeenAt:    now,
    );
  }

  static String _norm(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
