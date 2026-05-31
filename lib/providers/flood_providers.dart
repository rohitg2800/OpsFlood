import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../services/real_time_service.dart';
import '../services/ndma_service.dart' hide EmergencyContact;
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
export 'source_policy_provider.dart';

// RealTimeService is a ChangeNotifier — must use ChangeNotifierProvider
// so Riverpod listens to notifyListeners() and rebuilds dependent widgets.
final realTimeProvider = ChangeNotifierProvider<RealTimeService>((ref) {
  final service = RealTimeService();
  Future.microtask(() => service.startPolling());
  ref.onDispose(service.dispose);
  return service;
});

/// Alias kept for backward compatibility.
final realTimeServiceProvider = realTimeProvider;

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
