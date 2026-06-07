// lib/providers/flood_providers.dart
// Riverpod 3 — single canonical provider set, no duplicates.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_time_service.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
export 'source_policy_provider.dart';

// ── Notifier wrapper ───────────────────────────────────────────────────────────────────────
class RealTimeNotifier extends Notifier<RealTimeService> {
  @override
  RealTimeService build() {
    final service = RealTimeService();
    service.addListener(() => state = service);
    Future.microtask(() => service.startPolling());
    ref.onDispose(service.dispose);
    return service;
  }
}

final realTimeProvider =
    NotifierProvider<RealTimeNotifier, RealTimeService>(RealTimeNotifier.new);

/// Alias kept for backward compatibility.
final realTimeServiceProvider = realTimeProvider;

// ── Derived providers ─────────────────────────────────────────────────────────────────

final isOfflineProvider = Provider<bool>((ref) =>
    !ref.watch(realTimeProvider).isOnline);

final isWakingUpProvider = Provider<bool>((ref) =>
    ref.watch(realTimeProvider).isWakingUp);

final errorMessageProvider = Provider<String?>((ref) =>
    ref.watch(realTimeProvider).error);

final criticalCountProvider = Provider<int>((ref) =>
    ref.watch(realTimeProvider).criticalCount);

final imdAlertsProvider = Provider<List<dynamic>>((ref) =>
    ref.watch(realTimeProvider).imdAlerts);

/// NDMA advisories — sourced from the same real-time service.
final ndmaAdvisoriesProvider = Provider<List<dynamic>>((ref) =>
    ref.watch(realTimeProvider).ndmaAdvisories);

final liveLevelsProvider = Provider<List<FloodData>>((ref) =>
    ref.watch(realTimeProvider).liveLevels);

final monitoringDataProvider = Provider<MultiLocationMonitoring>((ref) =>
    ref.watch(realTimeProvider).monitoringData);

final monitoredCitiesProvider = Provider<List<String>>((ref) =>
    ref.watch(realTimeProvider).liveLevels.map((fd) => fd.city).toList());
