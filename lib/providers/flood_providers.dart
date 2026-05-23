// lib/providers/flood_providers.dart
// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider layer for OpsFlood / Equinox.
//
// DESIGN PRINCIPLES
// ─────────────────
// 1. RealTimeService singleton owns the main polling loop, cache,
//    notification dispatch, and IMD/NDMA enrichment pipeline.
//
// 2. RealTimeRiverService singleton owns the 5-source CWC cascade cache.
//    ALL screens share the same instance via liveRiverProvider — no
//    duplicate HTTP calls, live data appears everywhere at the same time.
//
// 3. Derived providers are "select" slices for granular widget rebuilds.
//
// 4. FCM alerts are surfaced via fcmAlertStreamProvider so any screen can
//    listen without importing FcmService directly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import '../services/fcm_service.dart';
import '../services/imd_service.dart';
import '../services/ndma_service.dart';
import '../services/real_time_river_service.dart';
import '../services/real_time_service.dart';
import 'theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CORE SERVICE PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Root provider for RealTimeService (IMD/NDMA enrichment + polling loop).
final realTimeProvider = ChangeNotifierProvider<RealTimeService>(
  (ref) => RealTimeService(),
  name: 'realTimeProvider',
);

/// Root provider for RealTimeRiverService (5-source CWC cascade).
/// All screens share this singleton — Stations tab, India Map, All Places.
final liveRiverProvider = ChangeNotifierProvider<RealTimeRiverService>(
  (ref) => RealTimeRiverService.instance,
  name: 'liveRiverProvider',
);

/// Stream of FCM flood alerts — widgets can use ref.listen / StreamProvider.
final fcmAlertStreamProvider = StreamProvider<FcmFloodAlert>(
  (ref) => FcmService.instance.alertStream,
  name: 'fcmAlertStreamProvider',
);

// ─────────────────────────────────────────────────────────────────────────────
// DERIVED — RealTimeService slices
// ─────────────────────────────────────────────────────────────────────────────

/// List of all fused + IMD-enriched FloodData items, sorted by capacity.
final liveLevelsProvider = Provider<List<FloodData>>(
  (ref) => ref.watch(realTimeProvider).liveLevels,
  name: 'liveLevelsProvider',
);

/// Only the currently active critical alerts.
final criticalAlertsProvider = Provider<List<FloodAlert>>(
  (ref) => ref.watch(realTimeProvider).criticalAlerts,
  name: 'criticalAlertsProvider',
);

/// Active CRITICAL-severity alerts only (no resolved/warning ones).
final activeCriticalAlertsProvider = Provider<List<FloodAlert>>(
  (ref) => ref.watch(realTimeProvider).activeCriticalAlerts,
  name: 'activeCriticalAlertsProvider',
);

/// How many cities are currently at critical capacity.
final criticalCountProvider = Provider<int>(
  (ref) => ref.watch(realTimeProvider).criticalCount,
  name: 'criticalCountProvider',
);

/// True when RealTimeService is actively fetching data.
final isLoadingProvider = Provider<bool>(
  (ref) => ref.watch(realTimeProvider).isLoading,
  name: 'isLoadingProvider',
);

/// True when device is offline.
final isOfflineProvider = Provider<bool>(
  (ref) => !ref.watch(realTimeProvider).isOnline,
  name: 'isOfflineProvider',
);

/// True when showing fallback/estimated data instead of live data.
final isUsingFallbackProvider = Provider<bool>(
  (ref) => ref.watch(realTimeProvider).isUsingFallback,
  name: 'isUsingFallbackProvider',
);

/// True when the backend is in wake-up phase (cold start on Render).
final isWakingUpProvider = Provider<bool>(
  (ref) => ref.watch(realTimeProvider).isWakingUp,
  name: 'isWakingUpProvider',
);

/// Last successful fetch timestamp.
final lastFetchTimeProvider = Provider<DateTime?>(
  (ref) => ref.watch(realTimeProvider).lastFetchTime,
  name: 'lastFetchTimeProvider',
);

/// Current error message (null when healthy).
final errorMessageProvider = Provider<String?>(
  (ref) => ref.watch(realTimeProvider).error,
  name: 'errorMessageProvider',
);

/// Full MultiLocationMonitoring model (for map screen / monitoring widgets).
final monitoringDataProvider = Provider(
  (ref) => ref.watch(realTimeProvider).monitoringData,
  name: 'monitoringDataProvider',
);

// ─────────────────────────────────────────────────────────────────────────────
// DERIVED — RealTimeRiverService slices
// ─────────────────────────────────────────────────────────────────────────────

/// All LiveRiverResult items from the last fetchAll() call.
final liveRiverResultsProvider = Provider<List<LiveRiverResult>>(
  (ref) => ref.watch(liveRiverProvider).lastResults,
  name: 'liveRiverResultsProvider',
);

/// LiveRiverResult for a specific city name (case-insensitive).
final cityLiveRiverProvider = Provider.family<LiveRiverResult?, String>(
  (ref, cityName) {
    final lc      = cityName.toLowerCase();
    final results = ref.watch(liveRiverResultsProvider);
    for (final r in results) {
      if (r.station.city.toLowerCase() == lc) return r;
    }
    return null;
  },
  name: 'cityLiveRiverProvider',
);

/// True when at least one city has real (non-NO_DATA) live river data.
final hasLiveRiverDataProvider = Provider<bool>(
  (ref) => ref.watch(liveRiverResultsProvider).any((r) => r.source != 'NO_DATA'),
  name: 'hasLiveRiverDataProvider',
);

/// Count of cities with real live data vs total monitored.
final liveRiverCoverageProvider = Provider<({int live, int total})>(
  (ref) {
    final results = ref.watch(liveRiverResultsProvider);
    return (
      live:  results.where((r) => r.source != 'NO_DATA').length,
      total: results.length,
    );
  },
  name: 'liveRiverCoverageProvider',
);

// ─────────────────────────────────────────────────────────────────────────────
// IMD + NDMA PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// All IMD alerts across every monitored state.
final imdAlertsProvider = Provider<List<ImdAlert>>(
  (ref) => ref.watch(realTimeProvider).imdAlerts,
  name: 'imdAlertsProvider',
);

/// NDMA advisories across every monitored state.
final ndmaAdvisoriesProvider = Provider<List<NdmaAdvisory>>(
  (ref) => ref.watch(realTimeProvider).ndmaAdvisories,
  name: 'ndmaAdvisoriesProvider',
);

/// NDRF + SDRF emergency contacts.
final emergencyContactsProvider = Provider<List<EmergencyContact>>(
  (ref) => ref.watch(realTimeProvider).emergencyContacts,
  name: 'emergencyContactsProvider',
);

/// True when any active IMD RED or ORANGE alert exists right now.
final hasActiveImdWarningProvider = Provider<bool>(
  (ref) {
    final alerts = ref.watch(imdAlertsProvider);
    return alerts.any((a) => a.severity == 'RED' || a.severity == 'ORANGE');
  },
  name: 'hasActiveImdWarningProvider',
);

// ─────────────────────────────────────────────────────────────────────────────
// PER-CITY PROVIDERS — RealTimeService family
// ─────────────────────────────────────────────────────────────────────────────

/// Returns FloodData for a specific city name (case-insensitive).
final cityDataProvider = Provider.family<FloodData?, String>(
  (ref, cityName) => ref.watch(realTimeProvider).dataForCity(cityName),
  name: 'cityDataProvider',
);

/// IMD alerts for a specific state.
final stateImdAlertsProvider = Provider.family<List<ImdAlert>, String>(
  (ref, state) => ref.watch(realTimeProvider).imdAlertsForState(state),
  name: 'stateImdAlertsProvider',
);

/// NDMA advisories for a specific state.
final stateNdmaAdvisoriesProvider = Provider.family<List<NdmaAdvisory>, String>(
  (ref, state) => ref.watch(realTimeProvider).ndmaAdvisoriesForState(state),
  name: 'stateNdmaAdvisoriesProvider',
);

/// Emergency contacts (NDRF/SDRF) for a specific state.
final stateEmergencyContactsProvider = Provider.family<List<EmergencyContact>, String>(
  (ref, state) => ref.watch(realTimeProvider).emergencyContactsForState(state),
  name: 'stateEmergencyContactsProvider',
);

/// River trend history for a specific city (24-hr snapshots).
final cityTrendProvider = Provider.family<List<dynamic>, String>(
  (ref, cityName) => ref.watch(realTimeProvider).trendForCity(cityName),
  name: 'cityTrendProvider',
);

// ─────────────────────────────────────────────────────────────────────────────
// THEME PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// ThemeProvider wrapped in a ChangeNotifierProvider.
final themeProvider = ChangeNotifierProvider<ThemeProvider>(
  (ref) => ThemeProvider(),
  name: 'themeProvider',
);

/// ThemeMode only — MaterialApp.themeMode slice.
final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(themeProvider).mode,
  name: 'themeModeProvider',
);
