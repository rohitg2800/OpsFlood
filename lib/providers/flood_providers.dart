import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../services/real_time_service.dart';
import '../services/ndma_service.dart' hide EmergencyContact; // avoid duplicate with flood_data.dart
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
// Source policy provider — re-exported so screens import one file.
export 'source_policy_provider.dart';

final realTimeProvider = ChangeNotifierProvider<RealTimeService>((ref) {
  final service = RealTimeService();
  Future.microtask(() => service.startPolling());
  return service;
});

/// Alias kept for backward compatibility with screens using the old name.
final realTimeServiceProvider = realTimeProvider;

// NOTE: themeModeProvider was removed from here.
// The canonical provider is in providers/theme_provider.dart:
//   final themeModeProvider = StateNotifierProvider<..., AppThemeMode>(...)
// Import theme_provider.dart directly when you need theme or AppThemeMode state.

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

/// List of city names that currently have live FloodData.
final monitoredCitiesProvider = Provider<List<String>>((ref) {
  return ref
      .watch(realTimeProvider)
      .liveLevels
      .map((fd) => fd.city)
      .toList();
});
