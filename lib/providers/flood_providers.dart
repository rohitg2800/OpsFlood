// lib/providers/flood_providers.dart
// Riverpod 3 — single canonical provider set, no duplicates.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_time_service.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
export 'source_policy_provider.dart';

// ── Notifier wrapper ──────────────────────────────────────────────────────────
//
// FIX: RealTimeService is a singleton (factory constructor returns _instance).
// Riverpod uses identical() to decide whether to rebuild: if state is always
// the same object, rebuilds never fire. We fix this by keeping an int
// _version counter and incrementing it every time the service notifies us,
// which forces Riverpod to re-evaluate all dependent providers.
class RealTimeNotifier extends Notifier<RealTimeService> {
  int _version = 0;

  @override
  RealTimeService build() {
    final service = RealTimeService();
    service.addListener(_onServiceChanged);
    Future.microtask(() => service.startPolling());
    ref.onDispose(() {
      service.removeListener(_onServiceChanged);
      service.dispose();
    });
    return service;
  }

  void _onServiceChanged() {
    _version++;
    // Force Riverpod to see a "change" even though the singleton object
    // reference is identical. We do this by calling state = state but
    // using ref.notifyListeners() which bypasses the equality check.
    ref.notifyListeners();
  }
}

final realTimeProvider =
    NotifierProvider<RealTimeNotifier, RealTimeService>(RealTimeNotifier.new);

/// Alias kept for backward compatibility.
final realTimeServiceProvider = realTimeProvider;

// ── Derived providers — status / metadata ────────────────────────────────────

/// True while the service is performing its initial or refresh fetch.
/// Replaces direct `service.isLoading` reads in screens so that only
/// widgets that actually render a loading state rebuild on this flag.
final isLoadingProvider = Provider<bool>((ref) =>
    ref.watch(realTimeProvider).isLoading);

/// The DateTime of the last successful data fetch, or null while loading.
/// Replaces direct `service.lastFetchTime` reads in AppBars / footers.
final lastFetchTimeProvider = Provider<DateTime?>((ref) =>
    ref.watch(realTimeProvider).lastFetchTime);

final isOfflineProvider = Provider<bool>((ref) =>
    !ref.watch(realTimeProvider).isOnline);

final isWakingUpProvider = Provider<bool>((ref) =>
    ref.watch(realTimeProvider).isWakingUp);

final errorMessageProvider = Provider<String?>((ref) =>
    ref.watch(realTimeProvider).error);

final criticalCountProvider = Provider<int>((ref) =>
    ref.watch(realTimeProvider).criticalCount);

// ── Alert providers ───────────────────────────────────────────────────────────

final imdAlertsProvider = Provider<List<dynamic>>((ref) =>
    ref.watch(realTimeProvider).imdAlerts);

/// NDMA advisories — sourced from the same real-time service.
final ndmaAdvisoriesProvider = Provider<List<dynamic>>((ref) =>
    ref.watch(realTimeProvider).ndmaAdvisories);

/// Combined IMD + NDMA alerts in a single list.
/// AlertsScreen watches this one provider instead of two, eliminating the
/// manual list-merge in the widget build method.
final combinedAlertsProvider = Provider<List<dynamic>>((ref) {
  final imd  = ref.watch(imdAlertsProvider);
  final ndma = ref.watch(ndmaAdvisoriesProvider);
  return [...imd, ...ndma];
});

// ── River / station data providers ───────────────────────────────────────────

final liveLevelsProvider = Provider<List<FloodData>>((ref) =>
    ref.watch(realTimeProvider).liveLevels);

final monitoringDataProvider = Provider<MultiLocationMonitoring>((ref) =>
    ref.watch(realTimeProvider).monitoringData);

/// FIX: derive monitored city list from liveLevels (a derived provider
/// that Riverpod knows to re-evaluate when the notifier fires) rather than
/// calling into the service directly with a stale reference.
final monitoredCitiesProvider = Provider<List<String>>((ref) =>
    ref.watch(liveLevelsProvider).map((fd) => fd.city).toList());

// ── Summary count providers — let RiverMonitor drop all in-widget aggregation ─

/// Number of stations currently at CRITICAL risk level.
final criticalStationCountProvider = Provider<int>((ref) =>
    ref.watch(liveLevelsProvider)
        .where((d) => d.riskLevel.toUpperCase() == 'CRITICAL')
        .length);

/// Number of stations currently at SEVERE risk level.
final severeStationCountProvider = Provider<int>((ref) =>
    ref.watch(liveLevelsProvider)
        .where((d) => d.riskLevel.toUpperCase() == 'SEVERE')
        .length);

/// Number of stations NOT in a critical or severe risk level (normal/safe).
final normalStationCountProvider = Provider<int>((ref) {
  final levels = ref.watch(liveLevelsProvider);
  final badCount = levels.where((d) {
    final r = d.riskLevel.toUpperCase();
    return r == 'CRITICAL' || r == 'SEVERE';
  }).length;
  return levels.length - badCount;
});

// ── City-scoped providers (used by CityDetailScreen) ─────────────────────────

final cityDataProvider = Provider.family<FloodData?, String>((ref, cityName) =>
    ref.watch(realTimeProvider).dataForCity(cityName));

final cityTrendProvider =
    Provider.family<List<RiverLevelSnapshot>, String>((ref, cityName) =>
        ref.watch(realTimeProvider).trendForCity(cityName));

final stateImdAlertsProvider =
    Provider.family<List<dynamic>, String>((ref, state) =>
        ref.watch(realTimeProvider).imdAlertsForState(state));

final stateNdmaAdvisoriesProvider =
    Provider.family<List<dynamic>, String>((ref, state) =>
        ref.watch(realTimeProvider).ndmaAdvisoriesForState(state));

final stateEmergencyContactsProvider =
    Provider.family<List<dynamic>, String>((ref, state) =>
        ref.watch(realTimeProvider).emergencyContactsForState(state));
