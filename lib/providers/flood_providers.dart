// lib/providers/flood_providers.dart
// Riverpod 3 — stable RealTimeNotifier.
//
// Problem: RealTimeService is a singleton (factory => _instance).
//   • state = service  → Riverpod identity check skips rebuild (same ref)
//   • invalidateSelf() → re-runs build(), re-adds listener + re-starts polling
//
// Solution: wrap in a plain ChangeNotifierProvider so Riverpod owns
// the ChangeNotifier lifecycle directly and fires rebuilds on every
// notifyListeners() automatically — no custom Notifier needed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_time_service.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
export 'source_policy_provider.dart';

// ── Core provider ─────────────────────────────────────────────────────────────
// ChangeNotifierProvider listens to notifyListeners() automatically.
// RealTimeService is a singleton so we get the same instance every time,
// and Riverpod will rebuild all watchers on each notifyListeners() call.
final realTimeProvider =
    ChangeNotifierProvider<RealTimeService>((_) {
  final service = RealTimeService();
  // startPolling is idempotent — safe to call; engine guards against double-start
  Future.microtask(() => service.startPolling());
  return service;
});

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

// ── Per-city providers ────────────────────────────────────────────────────────

final cityDataProvider = Provider.family<FloodData?, String>((ref, city) {
  return ref
      .watch(liveLevelsProvider)
      .cast<FloodData?>()
      .firstWhere(
        (fd) => fd!.city.toLowerCase() == city.toLowerCase(),
        orElse: () => null,
      );
});

final cityTrendProvider =
    Provider.family<List<RiverLevelSnapshot>, String>((ref, city) {
  return ref.watch(realTimeProvider).trendForCity(city);
});

// ── Per-state providers ───────────────────────────────────────────────────────

final stateImdAlertsProvider =
    Provider.family<List<dynamic>, String>((ref, stateName) {
  final all = ref.watch(imdAlertsProvider);
  if (stateName.isEmpty) return all;
  return all.where((a) {
    final s = (a.state as String? ?? '').toLowerCase();
    return s.isEmpty || s.contains(stateName.toLowerCase());
  }).toList();
});

final stateNdmaAdvisoriesProvider =
    Provider.family<List<dynamic>, String>((ref, stateName) {
  final all = ref.watch(ndmaAdvisoriesProvider);
  if (stateName.isEmpty) return all;
  return all.where((a) {
    final s = (a.state as String? ?? '').toLowerCase();
    return s.isEmpty || s.contains(stateName.toLowerCase());
  }).toList();
});

final stateEmergencyContactsProvider =
    Provider.family<List<dynamic>, String>((ref, stateName) {
  try {
    return ref.watch(realTimeProvider).emergencyContactsForState(stateName);
  } catch (_) {
    return const [];
  }
});

final stateLiveLevelsProvider =
    Provider.family<List<FloodData>, String>((ref, stateName) {
  return ref
      .watch(liveLevelsProvider)
      .where((fd) =>
          fd.state.toLowerCase().contains(stateName.toLowerCase()))
      .toList();
});
