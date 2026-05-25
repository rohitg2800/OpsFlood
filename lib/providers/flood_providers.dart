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

/// Whether the backend is cold-starting (Render spin-up).
final isWakingUpProvider = Provider<bool>((ref) {
  return ref.watch(realTimeProvider).isWakingUp;
});

/// Latest error message from the fetch engine (null = no error).
final errorMessageProvider = Provider<String?>((ref) {
  return ref.watch(realTimeProvider).error;
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

// ── City-scoped providers (used by CityDetailScreen) ───────────────────────

/// Latest [FloodData] for a specific city. Returns null when the city has
/// not been loaded yet.
final cityDataProvider = Provider.family<FloodData?, String>((ref, city) {
  return ref.watch(realTimeProvider).dataForCity(city);
});

/// 24-hr level history snapshots for a specific city.
final cityTrendProvider =
    Provider.family<List<RiverLevelSnapshot>, String>((ref, city) {
  return ref.watch(realTimeProvider).trendForCity(city);
});

/// Active IMD weather alerts for a given state name.
final stateImdAlertsProvider =
    Provider.family<List<dynamic>, String>((ref, state) {
  return ref.watch(realTimeProvider).imdAlertsForState(state);
});

/// NDMA advisories for a given state name.
final stateNdmaAdvisoriesProvider =
    Provider.family<List<dynamic>, String>((ref, state) {
  return ref.watch(realTimeProvider).ndmaAdvisoriesForState(state);
});

/// State-specific emergency contacts.
final stateEmergencyContactsProvider =
    Provider.family<List<dynamic>, String>((ref, state) {
  return ref.watch(realTimeProvider).emergencyContactsForState(state);
});
