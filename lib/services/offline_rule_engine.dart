// lib/services/offline_rule_engine.dart
// OpsFlood — Module 5: Community & Offline
//
// OfflineRuleEngine  (v2 — full rewrite of 525-byte stub)
// ─────────────────────────────────────────────────────────────────────────
// Evaluates CWC/WRD gauge readings against hard-coded threshold rules and
// produces List<FloodAlert> WITHOUT any network dependency.
//
// Design goals:
//   • Pure function — no side effects, easily unit-testable.
//   • Runs inside a background Isolate (no Flutter binding required).
//   • Falls back to this engine when ConnectivityService reports offline.
//   • Mirrors the severity / type taxonomy of AlertEngine to keep the
//     rest of the app oblivious to which engine produced the alert.
//
// Rule hierarchy (highest severity wins per station):
//   1. level ≥ HFL              → emergency  / levelAboveHfl
//   2. level ≥ danger           → critical   / levelAboveDanger
//   3. level ≥ warning          → warning    / levelAboveWarning
//   4. rate-of-rise ≥ 0.30 m/h  → warning    / rapidRise
//   5. 24h rainfall ≥ 100 mm    → warning    / rainfallExtreme
//   6. 24h rainfall ≥ 64.5 mm   → info       / rainfallHeavy

import '../models/station_reading.dart';  // StationReading
import 'alert_engine.dart';               // FloodAlert, AlertSeverity, AlertType

class OfflineRuleEngine {
  OfflineRuleEngine._();
  static final OfflineRuleEngine instance = OfflineRuleEngine._();

  // ── Public entry point ───────────────────────────────────────────────

  /// Evaluate [readings] and return a list of [FloodAlert]s sorted by
  /// descending severity (emergency first).
  List<FloodAlert> evaluate(List<StationReading> readings) {
    final alerts = <FloodAlert>[];

    for (final r in readings) {
      final alert = _evalStation(r);
      if (alert != null) alerts.add(alert);
    }

    // Sort: emergency > critical > warning > info
    alerts.sort((a, b) =>
        _sevOrdinal(b.severity).compareTo(_sevOrdinal(a.severity)));
    return alerts;
  }

  // ── Per-station evaluation ───────────────────────────────────────────

  FloodAlert? _evalStation(StationReading r) {
    final level  = r.currentLevel;
    final hfl    = r.hfl;
    final danger = r.dangerLevel;
    final warn   = r.warningLevel;
    final ror    = r.rateOfRise;     // m/h, may be null
    final rain   = r.rainfall24h;   // mm, may be null

    // — Rule 1: above HFL
    if (level != null && hfl != null && level >= hfl) {
      return _makeAlert(r, AlertSeverity.emergency, AlertType.levelAboveHfl,
          threshold: hfl);
    }

    // — Rule 2: above Danger
    if (level != null && danger != null && level >= danger) {
      return _makeAlert(r, AlertSeverity.critical, AlertType.levelAboveDanger,
          threshold: danger);
    }

    // — Rule 3: above Warning
    if (level != null && warn != null && level >= warn) {
      return _makeAlert(r, AlertSeverity.warning, AlertType.levelAboveWarning,
          threshold: warn);
    }

    // — Rule 4: rapid rise
    if (ror != null && ror >= 0.30) {
      return _makeAlert(r, AlertSeverity.warning, AlertType.rapidRise);
    }

    // — Rule 5: extreme rainfall
    if (rain != null && rain >= 100.0) {
      return _makeAlert(r, AlertSeverity.warning, AlertType.rainfallExtreme);
    }

    // — Rule 6: heavy rainfall
    if (rain != null && rain >= 64.5) {
      return _makeAlert(r, AlertSeverity.info, AlertType.rainfallHeavy);
    }

    return null;
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  FloodAlert _makeAlert(
    StationReading r,
    AlertSeverity  severity,
    AlertType      type, {
    double? threshold,
  }) =>
      FloodAlert(
        id:             '${r.stationId}_offline_${type.name}',
        station:        r.stationName,
        river:          r.river,
        district:       r.district,
        severity:       severity,
        type:           type,
        currentLevel:   r.currentLevel,
        thresholdLevel: threshold,
        rateOfRise:     r.rateOfRise,
        rainfall24h:    r.rainfall24h,
        generatedAt:    DateTime.now(),
        isOffline:      true,
      );

  static int _sevOrdinal(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return 3;
      case AlertSeverity.critical:  return 2;
      case AlertSeverity.warning:   return 1;
      case AlertSeverity.info:      return 0;
    }
  }
}
