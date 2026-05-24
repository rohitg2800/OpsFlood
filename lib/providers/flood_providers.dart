import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../services/real_time_service.dart';
import '../services/ndma_service.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';

// Core Service Provider
final realTimeProvider = ChangeNotifierProvider<RealTimeService>((ref) {
  return RealTimeService();
});

// App Settings & Theme Management
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// Telemetry & Status Readouts
final lastFetchTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(realTimeProvider).lastFetchTime;
});

final isOfflineProvider = Provider<bool>((ref) {
  return !ref.watch(realTimeProvider).isOnline;
});

// Alerts & Advisory Hub Data Handlers
final imdAlertsProvider = Provider<List<dynamic>>((ref) {
  return ref.watch(realTimeProvider).imdAlerts;
});

final ndmaAdvisoriesProvider = Provider<List<dynamic>>((ref) {
  return ref.watch(realTimeProvider).ndmaAdvisories;
});

// Explicitly typed provider to clear up the _NdmaContactsCard parameter constraint
final emergencyContactsProvider = Provider<List<EmergencyContact>>((ref) {
  final dynamic rawContacts = ref.watch(realTimeProvider).emergencyContacts;
  if (rawContacts is List<EmergencyContact>) {
    return rawContacts;
  }
  // Safe downcasting fallback to ensure clean compilation
  return List<EmergencyContact>.from(rawContacts ?? []);
});

// Standard Collections Fallbacks
final liveLevelsProvider = Provider<List<FloodData>>((ref) {
  return ref.watch(realTimeProvider).liveLevels;
});

final criticalAlertsProvider = Provider<List<dynamic>>((ref) {
  return ref.watch(realTimeProvider).criticalAlerts;
});

final activeCriticalAlertsProvider = Provider<List<dynamic>>((ref) {
  return ref.watch(realTimeProvider).activeCriticalAlerts;
});
