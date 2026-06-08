// lib/providers/flood_providers.dart
// Riverpod 3 — single canonical provider set, no duplicates.
//
// 2026-06-08 additions:
//   • isLoadingProvider     — isolates loading state so screens don't
//                             need to watch the full service object.
//   • lastFetchTimeProvider — isolates last-updated timestamp.
//   • combinedAlertsProvider — merged IMD + NDMA list ready for
//                              AlertsScreen to consume.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_time_service.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
export 'source_policy_provider.dart';

// ── Notifier wrapper ──────────────────────────────────────────────────────────
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
    ref.notifyListeners();
  }
}

final realTimeProvider =
    NotifierProvider<RealTimeNotifier, RealTimeService>(RealTimeNotifier.new);

/// Alias kept for backward compatibility.
final realTimeServiceProvider = realTimeProvider;

// ── Core derived providers ────────────────────────────────────────────────────

final isOfflineProvider = Provider<bool>((ref) =>
    !ref.watch(realTimeProvider).isOnline);

final isWakingUpProvider = Provider<bool>((ref) =>
    ref.watch(realTimeProvider).isWakingUp);

/// NEW: isolates loading flag so screens don't watch the whole service.
final isLoadingProvider = Provider<bool>((ref) =>
    ref.watch(realTimeProvider).isLoading);

/// NEW: isolates last-fetch timestamp so screens don't watch the whole service.
final lastFetchTimeProvider = Provider<DateTime?>((ref) =>
    ref.watch(realTimeProvider).lastFetchTime);

final errorMessageProvider = Provider<String?>((ref) =>
    ref.watch(realTimeProvider).error);

final criticalCountProvider = Provider<int>((ref) =>
    ref.watch(realTimeProvider).criticalCount);

final imdAlertsProvider = Provider<List<dynamic>>((ref) =>
    ref.watch(realTimeProvider).imdAlerts);

/// NDMA advisories — sourced from the same real-time service.
final ndmaAdvisoriesProvider = Provider<List<dynamic>>((ref) =>
    ref.watch(realTimeProvider).ndmaAdvisories);

/// NEW: merged IMD + NDMA alerts list consumed directly by AlertsScreen.
final combinedAlertsProvider = Provider<List<dynamic>>((ref) {
  final imd  = ref.watch(imdAlertsProvider);
  final ndma = ref.watch(ndmaAdvisoriesProvider);
  return [...imd, ...ndma];
});

final liveLevelsProvider = Provider<List<FloodData>>((ref) =>
    ref.watch(realTimeProvider).liveLevels);

final monitoringDataProvider = Provider<MultiLocationMonitoring>((ref) =>
    ref.watch(realTimeProvider).monitoringData);

final monitoredCitiesProvider = Provider<List<String>>((ref) =>
    ref.watch(liveLevelsProvider).map((fd) => fd.city).toList());

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
