// lib/providers/alerts_parent_bridge_provider.dart  v1.0
//
// OpsFlood — Alerts Parent Bridge
//
// WHAT THIS FILE DOES:
//   Creates a single always-on Riverpod Provider that:
//     1. Watches mergedStationsProvider — the ALL STATIONS screen parent,
//        which is the already-deduped, priority-ranked list of RiverStation
//        objects with v4.2-corrected DL/WL from kBiharGauges.
//     2. Converts each RiverStation → StationReading using the same shim
//        already used by AlertEngine.evaluateMerged().
//     3. Calls ActiveAlertController.instance.push(readings) so that
//        LiveAlertBanner and DangerProximityBanner evaluate alerts against
//        exactly the same level and threshold data as every other screen.
//
// WHY:
//   Before this bridge, ActiveAlertController listened to DataFetchEngine
//   directly — a separate pipeline that could carry different (pre-correction)
//   DL values.  This caused live alert banners to fire on wrong thresholds
//   (e.g. Taibpur showing DL 35.65 m in the banner vs 66.00 m on the card).
//
// HOW TO ACTIVATE:
//   Add this one line to main_shell.dart _MainShellState.build(), before
//   the Scaffold:
//
//       ref.watch(alertsParentBridgeProvider);
//
//   The provider keeps itself alive as long as MainShell is mounted.
//   No other changes are needed in any screen.
//
// DATA FLOW AFTER THIS CHANGE:
//
//   kBiharGauges (v4.2 DL/WL master)
//        └─ DataFetchEngine (seed + WRD + CWC + GloFAS enrichment)
//        └─ mergedStationsProvider  ◄── ALL SCREENS READ THIS
//                └─ alertsParentBridgeProvider  (this file)
//                        └─ ActiveAlertController.push()
//                                └─ LiveAlertBanner
//                                └─ DangerProximityBanner
//                └─ alertsProvider  (FloodAlert cards — unchanged)
//                └─ monitors_screen / live_stations_screen / map / etc.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../services/active_alert_controller.dart';
import '../services/data_fetch_engine.dart';
import 'real_time_river_provider.dart';  // exports mergedStationsProvider

// ── RiverStation → StationReading conversion ──────────────────────────────────
//
// Mirrors AlertEngine._riverStationToReading() exactly.
// Kept here so the bridge has no import dependency on alert_engine.dart,
// avoiding circular imports (alert_engine imports data_fetch_engine which
// imports bihar_rivers which is already in the merge chain).
StationReading _toReading(RiverStation s) {
  final district = (s.city.isNotEmpty && s.city != s.station)
      ? s.city
      : s.river;
  return StationReading(
    stationName:  s.station,
    river:        s.river,
    district:     district,
    state:        s.state,
    lat:          s.lat  ?? 0.0,
    lon:          s.lon  ?? 0.0,
    currentLevel: s.current,
    warningLevel: s.warning,
    dangerLevel:  s.danger,
    hfl:          s.hfl,
    progressPct:  s.progressPct * 100,
    riskLabel:    s.riskLabel,
    source:       s.dataSource ?? 'MERGED',
    isLive:       s.isLive,
    fetchedAt:    DateTime.now(),
    // forecast / rainfall / RoR: not available on RiverStation
    // → null → ActiveAlertController skips those branches cleanly
  );
}

// ── alertsParentBridgeProvider ────────────────────────────────────────────────
//
// Side-effect provider: on every mergedStationsProvider rebuild it pushes
// the converted readings into ActiveAlertController.
//
// Returns void — screens must NOT read the return value for UI data.
// They should continue using alertsProvider / mergedStationsProvider directly.
final alertsParentBridgeProvider = Provider<void>((ref) {
  final stations = ref.watch(mergedStationsProvider);

  // Ensure controller is started (idempotent)
  ActiveAlertController.instance.start();

  // Convert and push in one shot — no async, no side-streams
  final readings = stations.map(_toReading).toList();
  ActiveAlertController.instance.push(readings);
});
