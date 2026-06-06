// lib/providers/flood_providers.dart
// Riverpod 3 — RealTimeNotifier wraps the singleton correctly.
// Fix: ref.invalidateSelf() forces rebuild when RealTimeService notifies
//      (same object reference would be skipped by Riverpod identity check).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_time_service.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
export 'source_policy_provider.dart';

// ── Notifier wrapper ──────────────────────────────────────────────────────────
class RealTimeNotifier extends Notifier<RealTimeService> {
  @override
  RealTimeService build() {
    final service = RealTimeService();
    // Use invalidateSelf() so Riverpod re-runs build() on every data update.
    // Assigning state = service (same singleton object) is silently ignored
    // by Riverpod's identity check — invalidateSelf() bypasses that.
    service.addListener(_onServiceChange);
    ref.onDispose(() {
      service.removeListener(_onServiceChange);
      // Do NOT call service.dispose() here — it is a singleton used app-wide.
    });
    Future.microtask(() => service.startPolling());
    return service;
  }

  void _onServiceChange() => ref.invalidateSelf();
}

final realTimeProvider =
    NotifierProvider<RealTimeNotifier, RealTimeService>(RealTimeNotifier.new);

/// Alias kept for backward compatibility.
final realTimeServiceProvider = realTimeProvider;

// ── Derived providers ─────────────────────────────────────────────────────────

final lastFetchTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(realTimeProvider).lastFetchTime;
});

final isOfflineProvider = Provider<bool>((ref) {
  return !ref.watch(realTimeProvider).isOnline;
});

final isWakingUpProvider = Provider<bool>((ref) {
  return ref.watch(realTimeProvider).isWakingUp;
});

final errorMessageProvider = Provider<String?>((ref) {
  return ref.watch(realTimeProvider).error;
});

final imdAlertsProvider = Provider<List<dynamic>>((ref) {
  return ref.watch(realTimeProvider).imdAlerts;
});

final ndmaAdvisoriesProvider = Provider<List<dynamic>>((ref) {
  return ref.watch(realTimeProvider).ndmaAdvisories;
});

final criticalCountProvider = Provider<int>((ref) {
  return ref.watch(realTimeProvider).criticalCount;
});

final liveLevelsProvider = Provider<List<FloodData>>((ref) {
  return ref.watch(realTimeProvider).liveLevels;
});

final monitoringDataProvider = Provider<MultiLocationMonitoring>((ref) {
  return ref.watch(realTimeProvider).monitoringData;
});

final monitoredCitiesProvider = Provider<List<String>>((ref) {
  return ref
      .watch(realTimeProvider)
      .liveLevels
      .map((fd) => fd.city)
      .toList();
});

// ── Per-city providers (used by CityDetailScreen) ─────────────────────────────

/// Returns the live [FloodData] for a specific city, or null if not found.
final cityDataProvider = Provider.family<FloodData?, String>((ref, city) {
  return ref
      .watch(liveLevelsProvider)
      .cast<FloodData?>()
      .firstWhere(
        (fd) => fd!.city.toLowerCase() == city.toLowerCase(),
        orElse: () => null,
      );
});

/// Returns the 24-hr trend snapshots for a city from RealTimeService.
final cityTrendProvider =
    Provider.family<List<RiverLevelSnapshot>, String>((ref, city) {
  return ref.watch(realTimeProvider).trendForCity(city);
});

// ── Per-state providers ────────────────────────────────────────────────────────

/// IMD alerts filtered to a specific state name.
final stateImdAlertsProvider =
    Provider.family<List<dynamic>, String>((ref, stateName) {
  final all = ref.watch(imdAlertsProvider);
  if (stateName.isEmpty) return all;
  return all.where((a) {
    final s = (a.state as String? ?? '').toLowerCase();
    return s.isEmpty || s.contains(stateName.toLowerCase());
  }).toList();
});

/// NDMA advisories filtered to a specific state name.
final stateNdmaAdvisoriesProvider =
    Provider.family<List<dynamic>, String>((ref, stateName) {
  final all = ref.watch(ndmaAdvisoriesProvider);
  if (stateName.isEmpty) return all;
  return all.where((a) {
    final s = (a.state as String? ?? '').toLowerCase();
    return s.isEmpty || s.contains(stateName.toLowerCase());
  }).toList();
});

/// Emergency contacts for a specific state.
final stateEmergencyContactsProvider =
    Provider.family<List<dynamic>, String>((ref, stateName) {
  try {
    return ref.watch(realTimeProvider).emergencyContactsForState(stateName);
  } catch (_) {
    return const [];
  }
});

/// Live FloodData list for a specific state (used by StateMatrixScreen).
final stateLiveLevelsProvider =
    Provider.family<List<FloodData>, String>((ref, stateName) {
  return ref
      .watch(liveLevelsProvider)
      .where((fd) =>
          fd.state.toLowerCase().contains(stateName.toLowerCase()))
      .toList();
});
