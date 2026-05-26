import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../services/real_time_service.dart';
import '../services/ndma_service.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
// Source policy provider — re-exported so screens import one file.
export 'source_policy_provider.dart';

final realTimeProvider = ChangeNotifierProvider<RealTimeService>((ref) {
  final service = RealTimeService();
  
  // Guard initialization sequence by deferring it out of the build pass layout window
  Future.microtask(() => service.startPolling());
  
  return service;
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

final lastFetchTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(realTimeProvider).lastFetchTime;
});

final isOfflineProvider = Provider<bool>((ref) {
  return !ref.watch(realTimeProvider).isOnline;
});

final imdAlertsProvider = Provider<List<dynamic>>((ref) {
  return ref.watch(realTimeProvider).imdAlerts;
});

final ndmaAdvisoriesProvider = Provider<List<dynamic>>((ref) {
  return ref.watch(realTimeProvider).ndmaAdvisories;
});

final emergencyContactsProvider = Provider<List<EmergencyContact>>((ref) {
  final dynamic rawContacts = ref.watch(realTimeProvider).emergencyContacts;
  if (rawContacts is List<EmergencyContact>) {
    return rawContacts;
  }
  return List<EmergencyContact>.from(rawContacts ?? []);
});

final liveLevelsProvider = Provider<List<FloodData>>((ref) {
  return ref.watch(realTimeProvider).liveLevels;
});

final criticalAlertsProvider = Provider<List<dynamic>>((ref) {
  return ref.watch(realTimeProvider).criticalAlerts;
});

final activeCriticalAlertsProvider = Provider<List<dynamic>>((ref) {
  return ref.watch(realTimeProvider).activeCriticalAlerts;
});
