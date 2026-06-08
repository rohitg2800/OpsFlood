// lib/providers/flood_providers.dart
// v3 — bridged to mergedStationsProvider
//
// All KPI values that DashboardScreen, OverviewCard, and any widget
// consuming FloodData now come from the same WRD+CWC merged pipeline.
// The old liveLevelsProvider / FloodData types are kept as thin wrappers
// so existing widget code compiles without renaming every call site.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import 'real_time_river_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FloodSummary — a simple value object for dashboard KPI cards.
// Replaces the old FloodData model on the happy-path render.
// ─────────────────────────────────────────────────────────────────────────────

class FloodSummary {
  final int    totalStations;
  final int    criticalCount;   // extreme DangerClass
  final int    severeCount;     // severe DangerClass
  final int    elevatedCount;   // aboveNormal
  final int    normalCount;
  final double avgProgressPct;  // mean of s.progressPct across all stations
  final double maxLevel;        // highest current reading
  final String maxLevelStation; // station name for highest reading
  final String dataSource;      // 'CWC+WRD' | 'WRD' | 'loading'
  final DateTime updatedAt;

  const FloodSummary({
    required this.totalStations,
    required this.criticalCount,
    required this.severeCount,
    required this.elevatedCount,
    required this.normalCount,
    required this.avgProgressPct,
    required this.maxLevel,
    required this.maxLevelStation,
    required this.dataSource,
    required this.updatedAt,
  });

  // Quick helpers
  int    get dangerCount   => criticalCount + severeCount;
  int    get alertCount    => criticalCount + severeCount + elevatedCount;
  double get dangerPercent => totalStations == 0 ? 0 : dangerCount / totalStations * 100;
  double get alertPercent  => totalStations == 0 ? 0 : alertCount  / totalStations * 100;
}

// ─────────────────────────────────────────────────────────────────────────────
// floodSummaryProvider  ← the canonical dashboard KPI source
// ─────────────────────────────────────────────────────────────────────────────

final floodSummaryProvider = Provider<FloodSummary>((ref) {
  final stations = ref.watch(mergedStationsProvider);

  if (stations.isEmpty) {
    return FloodSummary(
      totalStations: 0, criticalCount: 0, severeCount: 0,
      elevatedCount: 0, normalCount: 0,
      avgProgressPct: 0, maxLevel: 0, maxLevelStation: '—',
      dataSource: 'loading', updatedAt: DateTime.now(),
    );
  }

  int critical = 0, severe = 0, elevated = 0, normal = 0;
  double totalPct = 0, maxLvl = 0;
  String maxStn = stations.first.station;

  for (final s in stations) {
    switch (s.dangerClass) {
      case DangerClass.extreme:     critical++;  break;
      case DangerClass.severe:      severe++;    break;
      case DangerClass.aboveNormal: elevated++;  break;
      default:                      normal++;    break;
    }
    totalPct += s.progressPct;
    if (s.current > maxLvl) { maxLvl = s.current; maxStn = s.station; }
  }

  final hasCwc = stations.any((s) => s.dataSource?.contains('CWC') ?? false);

  return FloodSummary(
    totalStations:    stations.length,
    criticalCount:    critical,
    severeCount:      severe,
    elevatedCount:    elevated,
    normalCount:      normal,
    avgProgressPct:   totalPct / stations.length,
    maxLevel:         maxLvl,
    maxLevelStation:  maxStn,
    dataSource:       hasCwc ? 'CWC+WRD' : 'WRD',
    updatedAt:        DateTime.now(),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Thin scalar providers — used directly by DashboardScreen KPI tiles
// ─────────────────────────────────────────────────────────────────────────────

final floodTotalStationsProvider    = Provider<int>((ref) => ref.watch(floodSummaryProvider).totalStations);
final floodCriticalCountProvider    = Provider<int>((ref) => ref.watch(floodSummaryProvider).criticalCount);
final floodSevereCountProvider      = Provider<int>((ref) => ref.watch(floodSummaryProvider).severeCount);
final floodElevatedCountProvider    = Provider<int>((ref) => ref.watch(floodSummaryProvider).elevatedCount);
final floodNormalCountProvider      = Provider<int>((ref) => ref.watch(floodSummaryProvider).normalCount);
final floodDangerCountProvider      = Provider<int>((ref) => ref.watch(floodSummaryProvider).dangerCount);
final floodAlertCountProvider       = Provider<int>((ref) => ref.watch(floodSummaryProvider).alertCount);
final floodAvgProgressPctProvider   = Provider<double>((ref) => ref.watch(floodSummaryProvider).avgProgressPct);
final floodMaxLevelProvider         = Provider<double>((ref) => ref.watch(floodSummaryProvider).maxLevel);
final floodMaxLevelStationProvider  = Provider<String>((ref) => ref.watch(floodSummaryProvider).maxLevelStation);
final floodDataSourceProvider       = Provider<String>((ref) => ref.watch(floodSummaryProvider).dataSource);

// ─────────────────────────────────────────────────────────────────────────────
// Legacy: liveLevelsProvider shim
// Old code that did `ref.watch(liveLevelsProvider)` returns a List<RiverStation>
// (same type as mergedStationsProvider) so widget code compiles unchanged.
// ─────────────────────────────────────────────────────────────────────────────

/// @Deprecated — use mergedStationsProvider directly.
/// Kept as alias so DashboardScreen and any widget referencing
/// liveLevelsProvider still compiles without modification.
final liveLevelsProvider = Provider<List<RiverStation>>((ref) =>
    ref.watch(mergedStationsProvider));
