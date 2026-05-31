import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../services/real_time_service.dart';
import '../services/ndma_service.dart' hide EmergencyContact;  // avoid duplicate with flood_data.dart
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

// NOTE: themeModeProvider (StateProvider<ThemeMode>) was removed from here.
// The canonical theme state lives in providers/theme_provider.dart as
// themeNotifierProvider (StateNotifierProvider<ThemeProvider, AppThemeMode>).
// Import theme_provider.dart directly when you need theme state.

final lastFetchTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(realTimeProvider).lastFetchTime;
});

final isOfflineProvider = Provider<bool>((ref) {
  return !ref.watch(realTimeProvider).isOnline;
});

final isWakingUpProvider = Provider<bool>((ref) {
  return ref.watch(realTimeProvider).isWakingUp;
});

final ndmaProvider = FutureProvider.autoDispose<List<EmergencyContact>>((ref) async {
  final svc = NdmaService();
  return svc.fetchEmergencyContacts();
});

final riverMonitoringProvider =
    FutureProvider.autoDispose<List<RiverStation>>((ref) async {
  final svc = ref.watch(realTimeProvider);
  return svc.fetchRiverStations();
});
