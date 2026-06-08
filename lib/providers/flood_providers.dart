// lib/providers/flood_providers.dart
// v5 — added realTimeProvider, criticalCountProvider, isWakingUpProvider
//
// All KPI values that DashboardScreen, OverviewCard, and any widget
// consuming FloodData now come from the same WRD+CWC merged pipeline.
// The old liveLevelsProvider / FloodData types are kept as thin wrappers
// so existing widget code compiles without renaming every call site.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../models/river_station.dart';
import '../services/real_time_service.dart';
import 'real_time_river_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// realTimeProvider — ChangeNotifierProvider wrapping the singleton RealTimeService
// Used by DashboardScreen for: service.isLoading, service.lastFetchTime,
// service.isWakingUp, service.criticalCount, service.refreshData()
// ─────────────────────────────────────────────────────────────────────────────

final realTimeProvider = ChangeNotifierProvider<RealTimeService>(
  (ref) => RealTimeService(),
);

// ─────────────────────────────────────────────────────────────────────────────
// criticalCountProvider — alias used by DashboardScreen
// Maps to mergedCriticalCountProvider (stations at/above danger level)
// ─────────────────────────────────────────────────────────────────────────────

final criticalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedCriticalCountProvider));

// ─────────────────────────────────────────────────────────────────────────────
// isWakingUpProvider — true while the initial WRD fetch is in-flight
// and the station list is still empty ("cold start" / server wake-up).
// ─────────────────────────────────────────────────────────────────────────────

final isWakingUpProvider = Provider<bool>((ref) {
  final loading  = ref.watch(wrdIsLoadingProvider);
  final hasData  = ref.watch(mergedStationsProvider).isNotEmpty;
  return loading && !hasData;
});

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
// Helper: RiverStation → FloodData
// Used by liveLevelsProvider so RiverMonitorScreen compiles unchanged.
// ─────────────────────────────────────────────────────────────────────────────

FloodData _riverStationToFloodData(RiverStation s) {
  String riskLevel;
  switch (s.dangerClass) {
    case DangerClass.extreme:     riskLevel = 'CRITICAL'; break;
    case DangerClass.severe:      riskLevel = 'SEVERE';   break;
    case DangerClass.aboveNormal: riskLevel = 'MODERATE'; break;
    default:                      riskLevel = 'LOW';      break;
  }
  final cap = s.danger > 0
      ? (s.current / s.danger * 100).clamp(0.0, 100.0)
      : 0.0;
  return FloodData(
    city:                s.station,
    district:            '',
    state:               s.state,
    riverName:           s.river,
    currentLevel:        s.current,
    warningLevel:        s.warning,
    dangerLevel:         s.danger,
    safeLevel:           s.warning * 0.75,
    capacityPercent:     cap,
    riskLevel:           riskLevel,
    status:              s.isLive ? 'LIVE' : 'ESTIMATED',
    effectiveRainfallMm: 0.0,
    lastUpdated:         DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Legacy: liveLevelsProvider shim — returns List<FloodData> for RiverMonitorScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Returns merged stations as List<FloodData> so RiverMonitorScreen compiles
/// without any changes.
final liveLevelsProvider = Provider<List<FloodData>>((ref) =>
    ref.watch(mergedStationsProvider)
        .map(_riverStationToFloodData)
        .toList());

// ─────────────────────────────────────────────────────────────────────────────
// Loading / offline / timestamp providers — used by RiverMonitorScreen
// ─────────────────────────────────────────────────────────────────────────────

/// True while the WRD fetch is in-flight and no cached data exists yet.
final isLoadingProvider = Provider<bool>((ref) =>
    ref.watch(wrdIsLoadingProvider) && ref.watch(mergedStationsProvider).isEmpty);

/// True when the last WRD fetch failed (no network / scrape error).
final isOfflineProvider = Provider<bool>((ref) =>
    ref.watch(wrdErrorProvider) != null);

/// Timestamp of the most-recently updated station, or null when no data yet.
final lastFetchTimeProvider = Provider<DateTime?>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  if (stations.isEmpty) return null;
  final raw = stations.first.lastUpdated;
  if (raw == null || raw.isEmpty) return DateTime.now();
  final parts = raw.split(':');
  if (parts.length < 2) return DateTime.now();
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, h, m);
});

// ─────────────────────────────────────────────────────────────────────────────
// IMD / NDMA alert providers — used by AlertsScreen
// ─────────────────────────────────────────────────────────────────────────────

final imdAlertsProvider = Provider<List<Map<String, dynamic>>>((ref) => const []);
final ndmaAdvisoriesProvider = Provider<List<Map<String, dynamic>>>((ref) => const []);
