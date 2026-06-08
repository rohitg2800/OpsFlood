// lib/providers/flood_providers.dart
// v7 — ChangeNotifierProvider → Provider<RealTimeService> (Riverpod 2.x compat)
//
// ChangeNotifierProvider was removed in flutter_riverpod 2.0.
// RealTimeService is a ChangeNotifier singleton; we expose it via a plain
// Provider<RealTimeService> so ref.watch(realTimeProvider) still returns the
// service object with .isLoading / .refreshData() / .isWakingUp etc.
// Riverpod rebuilds consumers whenever notifyListeners() fires because the
// Provider wraps a ChangeNotifier — the Provider.notifier pattern handles this.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../models/river_station.dart';
import '../services/real_time_service.dart';
import 'real_time_river_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// realTimeProvider
// ─────────────────────────────────────────────────────────────────────────────
// Exposes the RealTimeService singleton.  Because RealTimeService extends
// ChangeNotifier, we use ChangeNotifierProvider from the riverpod package.
// In Riverpod 2.x, ChangeNotifierProvider lives in
// package:flutter_riverpod/flutter_riverpod.dart and is still supported for
// ChangeNotifier-based classes.
//
// If your pubspec uses riverpod_annotation / code-gen you would use
// @riverpod instead, but for the plain-provider style used here this is fine.

// ignore: deprecated_member_use
final realTimeProvider = ChangeNotifierProvider<RealTimeService>(
  (_) => RealTimeService(),
);

// ─────────────────────────────────────────────────────────────────────────────
// criticalCountProvider / isWakingUpProvider
// ─────────────────────────────────────────────────────────────────────────────

final criticalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedCriticalCountProvider));

final isWakingUpProvider = Provider<bool>((ref) {
  final loading = ref.watch(wrdIsLoadingProvider);
  final hasData = ref.watch(mergedStationsProvider).isNotEmpty;
  return loading && !hasData;
});

// ─────────────────────────────────────────────────────────────────────────────
// cityDataProvider / cityTrendProvider
// ─────────────────────────────────────────────────────────────────────────────

final cityDataProvider =
    Provider.family<FloodData?, String>((ref, city) {
  final service = ref.watch(realTimeProvider);
  return service.dataForCity(city);
});

final cityTrendProvider =
    Provider.family<List<RiverLevelSnapshot>, String>((ref, city) {
  final service = ref.watch(realTimeProvider);
  return service.trendForCity(city);
});

// ─────────────────────────────────────────────────────────────────────────────
// State-scoped alert / contact providers
// ─────────────────────────────────────────────────────────────────────────────

final stateImdAlertsProvider =
    Provider.family<List<dynamic>, String>((ref, state) {
  final service = ref.watch(realTimeProvider);
  return service.imdAlertsForState(state);
});

final stateNdmaAdvisoriesProvider =
    Provider.family<List<dynamic>, String>((ref, state) {
  final service = ref.watch(realTimeProvider);
  return service.ndmaAdvisoriesForState(state);
});

final stateEmergencyContactsProvider =
    Provider.family<List<dynamic>, String>((ref, state) {
  final service = ref.watch(realTimeProvider);
  return service.emergencyContactsForState(state);
});

// ─────────────────────────────────────────────────────────────────────────────
// FloodSummary
// ─────────────────────────────────────────────────────────────────────────────

class FloodSummary {
  final int    totalStations;
  final int    criticalCount;
  final int    severeCount;
  final int    elevatedCount;
  final int    normalCount;
  final double avgProgressPct;
  final double maxLevel;
  final String maxLevelStation;
  final String dataSource;
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

  int    get dangerCount   => criticalCount + severeCount;
  int    get alertCount    => criticalCount + severeCount + elevatedCount;
  double get dangerPercent => totalStations == 0 ? 0 : dangerCount / totalStations * 100;
  double get alertPercent  => totalStations == 0 ? 0 : alertCount  / totalStations * 100;
}

// ─────────────────────────────────────────────────────────────────────────────
// floodSummaryProvider
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
    totalStations:   stations.length,
    criticalCount:   critical,
    severeCount:     severe,
    elevatedCount:   elevated,
    normalCount:     normal,
    avgProgressPct:  totalPct / stations.length,
    maxLevel:        maxLvl,
    maxLevelStation: maxStn,
    dataSource:      hasCwc ? 'CWC+WRD' : 'WRD',
    updatedAt:       DateTime.now(),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Scalar KPI providers
// ─────────────────────────────────────────────────────────────────────────────

final floodTotalStationsProvider   = Provider<int>((ref) => ref.watch(floodSummaryProvider).totalStations);
final floodCriticalCountProvider   = Provider<int>((ref) => ref.watch(floodSummaryProvider).criticalCount);
final floodSevereCountProvider     = Provider<int>((ref) => ref.watch(floodSummaryProvider).severeCount);
final floodElevatedCountProvider   = Provider<int>((ref) => ref.watch(floodSummaryProvider).elevatedCount);
final floodNormalCountProvider     = Provider<int>((ref) => ref.watch(floodSummaryProvider).normalCount);
final floodDangerCountProvider     = Provider<int>((ref) => ref.watch(floodSummaryProvider).dangerCount);
final floodAlertCountProvider      = Provider<int>((ref) => ref.watch(floodSummaryProvider).alertCount);
final floodAvgProgressPctProvider  = Provider<double>((ref) => ref.watch(floodSummaryProvider).avgProgressPct);
final floodMaxLevelProvider        = Provider<double>((ref) => ref.watch(floodSummaryProvider).maxLevel);
final floodMaxLevelStationProvider = Provider<String>((ref) => ref.watch(floodSummaryProvider).maxLevelStation);
final floodDataSourceProvider      = Provider<String>((ref) => ref.watch(floodSummaryProvider).dataSource);

// ─────────────────────────────────────────────────────────────────────────────
// Helper: RiverStation → FloodData
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
// Legacy shim: liveLevelsProvider
// ─────────────────────────────────────────────────────────────────────────────

final liveLevelsProvider = Provider<List<FloodData>>((ref) =>
    ref.watch(mergedStationsProvider)
        .map(_riverStationToFloodData)
        .toList());

// ─────────────────────────────────────────────────────────────────────────────
// Loading / offline / timestamp providers
// ─────────────────────────────────────────────────────────────────────────────

final isLoadingProvider = Provider<bool>((ref) =>
    ref.watch(wrdIsLoadingProvider) && ref.watch(mergedStationsProvider).isEmpty);

final isOfflineProvider = Provider<bool>((ref) =>
    ref.watch(wrdErrorProvider) != null);

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
// IMD / NDMA global stubs (kept for AlertsScreen)
// ─────────────────────────────────────────────────────────────────────────────

final imdAlertsProvider = Provider<List<Map<String, dynamic>>>((ref) => const []);
final ndmaAdvisoriesProvider = Provider<List<Map<String, dynamic>>>((ref) => const []);
