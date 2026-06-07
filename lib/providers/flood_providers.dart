// lib/providers/flood_providers.dart
// Riverpod 3 — ChangeNotifierProvider is removed.
// We wrap RealTimeService in a Notifier so notifyListeners() drives UI rebuilds.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_time_service.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
export 'source_policy_provider.dart';

// ── Notifier wrapper ──────────────────────────────────────────────────────────
// Riverpod 3 replaced ChangeNotifierProvider with Notifier/NotifierProvider.
// We expose RealTimeService as the state; every time the service calls
// notifyListeners() we call state = state (same object) which triggers
// Riverpod to re-read all downstream Provider<T> that watch realTimeProvider.
class RealTimeNotifier extends Notifier<RealTimeService> {
  @override
  RealTimeService build() {
    final service = RealTimeService();
    // Hook: re-assign state so Riverpod propagates changes to all watchers.
    service.addListener(() => state = service);
    // Start polling after the first frame.
    Future.microtask(() => service.startPolling());
    ref.onDispose(service.dispose);
    return service;
  }
}

final realTimeProvider =
    NotifierProvider<RealTimeNotifier, RealTimeService>(RealTimeNotifier.new);

/// Alias kept for backward compatibility.
final realTimeServiceProvider = realTimeProvider;

// ── Derived providers ─────────────────────────────────────────────────────────

final realTimeProvider = Provider<RealTimeService>((ref) {
  ref.watch(_tickProvider);
  return ref.watch(_serviceBootProvider);
});

/// Alias kept for backward compatibility.
final realTimeServiceProvider = realTimeProvider;

final isWakingUpProvider = Provider<bool>((ref) {
  return ref.watch(realTimeProvider).isWakingUp;
});

final errorMessageProvider = Provider<String?>((ref) {
  return ref.watch(realTimeProvider).error;
});

final isOfflineProvider = Provider<bool>((ref) =>
    !ref.watch(realTimeProvider).isOnline);

final isWakingUpProvider = Provider<bool>((ref) =>
    ref.watch(realTimeProvider).isWakingUp);

final criticalCountProvider = Provider<int>((ref) {
  return ref.watch(realTimeProvider).criticalCount;
});

final imdAlertsProvider = Provider<List<dynamic>>((ref) =>
    ref.watch(realTimeProvider).imdAlerts);

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
