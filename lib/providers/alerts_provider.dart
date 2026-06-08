// lib/providers/alerts_provider.dart
// v3 — fully rewired to mergedStationsProvider
//
// ALL counts, station-alert objects, and summary cards now derive from the
// same WRD+CWC merged pipeline that powers the Map screen. No more
// liveLevelsProvider / FloodData divergence.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import 'real_time_river_provider.dart';

// ─── DangerClass → severity int (higher = worse) ──────────────────────────────
int _severity(DangerClass dc) {
  switch (dc) {
    case DangerClass.extreme:     return 4;
    case DangerClass.severe:      return 3;
    case DangerClass.aboveNormal: return 2;
    default:                      return 1;
  }
}

// ─── FloodAlert model ─────────────────────────────────────────────────────────
class FloodAlert {
  final String id;
  final String title;
  final String message;
  final String severity;   // 'critical' | 'severe' | 'elevated' | 'normal'
  final String source;     // 'CWC_FFEM' | 'WRD_BIHAR_LIVE' | 'IMD' | 'NDMA'
  final String river;
  final String station;
  final String state;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final double progressPct;
  final DateTime issuedAt;

  const FloodAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.source,
    required this.river,
    required this.station,
    required this.state,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.progressPct,
    required this.issuedAt,
  });
}

// ─── Convert RiverStation → FloodAlert ────────────────────────────────────────
FloodAlert _stationToAlert(RiverStation s) {
  final dc = s.dangerClass;
  String sev;
  String title;
  String msg;
  switch (dc) {
    case DangerClass.extreme:
      sev   = 'critical';
      title = '🔴 EXTREME FLOOD — ${s.station}';
      msg   = '${s.station} (${s.river}) is at ${s.current.toStringAsFixed(2)} m, '
              'above HFL ${s.hfl.toStringAsFixed(2)} m. Immediate evacuation advised.';
      break;
    case DangerClass.severe:
      sev   = 'severe';
      title = '🟠 DANGER LEVEL — ${s.station}';
      msg   = '${s.station} (${s.river}) at ${s.current.toStringAsFixed(2)} m '
              'exceeds danger mark ${s.danger.toStringAsFixed(2)} m.';
      break;
    case DangerClass.aboveNormal:
      sev   = 'elevated';
      title = '🟡 WARNING LEVEL — ${s.station}';
      msg   = '${s.station} (${s.river}) at ${s.current.toStringAsFixed(2)} m '
              'above warning level ${s.warning.toStringAsFixed(2)} m.';
      break;
    default:
      sev   = 'normal';
      title = '🟢 NORMAL — ${s.station}';
      msg   = '${s.station} (${s.river}) at ${s.current.toStringAsFixed(2)} m, '
              'within safe range.';
  }
  return FloodAlert(
    id:           '${s.station}_${s.river}'.replaceAll(' ', '_'),
    title:        title,
    message:      msg,
    severity:     sev,
    source:       s.dataSource ?? 'LIVE',
    river:        s.river,
    station:      s.station,
    state:        s.state,
    currentLevel: s.current,
    dangerLevel:  s.danger,
    warningLevel: s.warning,
    progressPct:  s.progressPct,
    issuedAt:     DateTime.now(),
  );
}

// ─── 1. Full alert list sorted by severity ────────────────────────────────────
/// All stations as FloodAlert objects, sorted worst-first.
final stationAlertsProvider = Provider<List<FloodAlert>>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  final alerts   = stations.map(_stationToAlert).toList();
  alerts.sort((a, b) => _severity(_severityToDc(b.severity))
      .compareTo(_severity(_severityToDc(a.severity))));
  return alerts;
});

DangerClass _severityToDc(String s) {
  switch (s) {
    case 'critical': return DangerClass.extreme;
    case 'severe':   return DangerClass.severe;
    case 'elevated': return DangerClass.aboveNormal;
    default:         return DangerClass.normal;
  }
}

// ─── 2. Filtered sub-lists ────────────────────────────────────────────────────

/// Only critical (extreme) alerts.
final criticalAlertsProvider = Provider<List<FloodAlert>>((ref) =>
    ref.watch(stationAlertsProvider)
        .where((a) => a.severity == 'critical')
        .toList());

/// Severe alerts (at danger but below HFL).
final severeAlertsProvider = Provider<List<FloodAlert>>((ref) =>
    ref.watch(stationAlertsProvider)
        .where((a) => a.severity == 'severe')
        .toList());

/// Elevated (above warning) alerts.
final elevatedAlertsProvider = Provider<List<FloodAlert>>((ref) =>
    ref.watch(stationAlertsProvider)
        .where((a) => a.severity == 'elevated')
        .toList());

/// Normal (safe) station alerts.
final normalAlertsProvider = Provider<List<FloodAlert>>((ref) =>
    ref.watch(stationAlertsProvider)
        .where((a) => a.severity == 'normal')
        .toList());

// ─── 3. Count providers (match mergedStationsProvider counts exactly) ─────────

/// Total station count.
final alertTotalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedTotalCountProvider));

/// Critical count (extreme DangerClass).
final alertCriticalCountProvider = Provider<int>((ref) =>
    ref.watch(criticalAlertsProvider).length);

/// Severe count.
final alertSevereCountProvider = Provider<int>((ref) =>
    ref.watch(severeAlertsProvider).length);

/// Elevated count (above warning).
final alertElevatedCountProvider = Provider<int>((ref) =>
    ref.watch(elevatedAlertsProvider).length);

/// Normal / safe count.
final alertNormalCountProvider = Provider<int>((ref) =>
    ref.watch(normalAlertsProvider).length);

/// Combined danger count = critical + severe (used by Alerts screen KPI bar).
final alertDangerCountProvider = Provider<int>((ref) =>
    ref.watch(alertCriticalCountProvider) +
    ref.watch(alertSevereCountProvider));

// ─── 4. Top-alert summary for dashboard / notification banners ───────────────

/// Top 5 worst stations as alert objects.
final topAlertsProvider = Provider<List<FloodAlert>>((ref) =>
    ref.watch(stationAlertsProvider).take(5).toList());

/// Single worst alert (or null if no stations).
final worstAlertProvider = Provider<FloodAlert?>((ref) =>
    ref.watch(stationAlertsProvider).isNotEmpty
        ? ref.watch(stationAlertsProvider).first
        : null);

/// Stations above ANY alert threshold (warning or higher).
final activeAlertsProvider = Provider<List<FloodAlert>>((ref) =>
    ref.watch(stationAlertsProvider)
        .where((a) => a.severity != 'normal')
        .toList());

/// Count of stations above any alert threshold.
final activeAlertCountProvider = Provider<int>((ref) =>
    ref.watch(activeAlertsProvider).length);

// ─── 5. Legacy aliases — kept so existing code compiles without changes ───────
//       These all now delegate to the merged-data providers above.

/// Legacy: total alert count.
@Deprecated('Use alertTotalCountProvider')
final mergedAlertCountProvider = alertTotalCountProvider;

/// Legacy: critical-count alias used by old alerts_screen.
final mergedCriticalAlertsCountProvider = alertCriticalCountProvider;

/// Legacy: elevated-count alias used by old alerts_screen.
final mergedElevatedAlertsCountProvider = alertElevatedCountProvider;
