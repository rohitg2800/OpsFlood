// lib/providers/flood_providers.dart
// Riverpod 3.x — RealTimeService is a singleton ChangeNotifier.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_time_service.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
export 'source_policy_provider.dart';

// ── Tick notifier ────────────────────────────────────────────────────────────
class _TickNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state = state + 1;
}

final _tickProvider = NotifierProvider<_TickNotifier, int>(_TickNotifier.new);

// ── Bootstrap provider ───────────────────────────────────────────────────────
final _serviceBootProvider = Provider<RealTimeService>((ref) {
  final service = RealTimeService();
  void onUpdate() => ref.read(_tickProvider.notifier).increment();
  service.addListener(onUpdate);
  ref.onDispose(() => service.removeListener(onUpdate));
  Future.microtask(() => service.startPolling());
  return service;
});

// ── Public providers ─────────────────────────────────────────────────────────

final realTimeProvider = Provider<RealTimeService>((ref) {
  ref.watch(_tickProvider);
  return ref.watch(_serviceBootProvider);
});

/// Alias kept for backward compatibility.
final realTimeServiceProvider = realTimeProvider;

// ── Derived providers ─────────────────────────────────────────────────────────

final lastFetchTimeProvider = Provider<DateTime?>((ref) =>
    ref.watch(realTimeProvider).lastFetchTime);

final isOfflineProvider = Provider<bool>((ref) =>
    !ref.watch(realTimeProvider).isOnline);

final isWakingUpProvider = Provider<bool>((ref) =>
    ref.watch(realTimeProvider).isWakingUp);

final errorMessageProvider = Provider<String?>((ref) =>
    ref.watch(realTimeProvider).error);

final imdAlertsProvider = Provider<List<dynamic>>((ref) =>
    ref.watch(realTimeProvider).imdAlerts);

final ndmaAdvisoriesProvider = Provider<List<dynamic>>((ref) =>
    ref.watch(realTimeProvider).ndmaAdvisories);

final criticalCountProvider = Provider<int>((ref) =>
    ref.watch(realTimeProvider).criticalCount);

// ── THE FIX: use allFloodData so every fetched city appears in Monitors ──────
// Previously liveLevels returned only WRD-gauge-matched cities (hasLiveLevel=true),
// which was almost always 0 because WRD name matching failed for most cities.
// allFloodData returns ALL cities once the fetch cycle has run, with status
// 'ESTIMATED' for cities without a WRD gauge match and actual risk levels
// for matched ones. The card UI already handles 'ESTIMATED' status gracefully.
final liveLevelsProvider = Provider<List<FloodData>>((ref) {
  final rt = ref.watch(realTimeProvider);
  // Prefer live-matched data; fall back to all estimated data if none matched
  final live = rt.liveLevels;         // only hasLiveLevel==true
  if (live.isNotEmpty) return live;
  return rt.allFloodData;             // all cities post-fetch (estimated)
});

final monitoringDataProvider = Provider<MultiLocationMonitoring>((ref) =>
    ref.watch(realTimeProvider).monitoringData);

final monitoredCitiesProvider = Provider<List<String>>((ref) =>
    ref.watch(liveLevelsProvider).map((fd) => fd.city).toList());

// ── Per-city ──────────────────────────────────────────────────────────────────

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
    Provider.family<List<RiverLevelSnapshot>, String>((ref, city) =>
        ref.watch(realTimeProvider).trendForCity(city));

// ── Per-state ──────────────────────────────────────────────────────────────────

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
