// lib/providers/flood_providers.dart
// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider layer for Equinox Flood.
//
// DESIGN PRINCIPLES
// ────────────────
// 1. RealTimeService singleton is NOT replaced — it owns the polling loop,
//    cache, notification dispatch, and IMD/NDMA enrichment pipeline.
//    Riverpod wraps it via a ChangeNotifierProvider so every widget that
//    does ref.watch(realTimeProvider) rebuilds only on notifyListeners().
//
// 2. Derived providers are "select" slices — widgets that only care about
//    live levels, or only alerts, or only IMD data get granular rebuilds
//    (zero overhead for unrelated state changes).
//
// 3. ThemeProvider singleton is similarly wrapped.  The legacy
//    ListenableBuilder pattern in main.dart is replaced by ref.watch(themeProvider).
//
// 4. All providers are global constants — compatible with both
//    ConsumerWidget and Consumer (no context gymnastics).
//
// USAGE IN SCREENS
// ─────────────────
//   // Extend ConsumerWidget instead of StatelessWidget
//   class HomeScreen extends ConsumerWidget {
//     @override
//     Widget build(BuildContext context, WidgetRef ref) {
//       // Full service (rebuilds on every notifyListeners)
//       final rts = ref.watch(realTimeProvider);
//
//       // Granular slice (rebuilds ONLY when liveLevels list changes)
//       final levels = ref.watch(liveLevelsProvider);
//
//       // Async refresh on button tap
//       ref.read(realTimeProvider).refreshData();
//     }
//   }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import '../services/imd_service.dart';
import '../services/ndma_service.dart';
import '../services/real_time_service.dart';
import 'theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CORE SERVICE PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// Root provider for the entire RealTimeService.
/// ChangeNotifierProvider automatically subscribes to notifyListeners(),
/// so ref.watch(realTimeProvider) rebuilds whenever any service state changes.
///
/// This is a singleton-backed provider: RealTimeService() always returns
/// the same instance regardless of how many times the provider is read.
final realTimeProvider = ChangeNotifierProvider<RealTimeService>(
  (ref) => RealTimeService(),
  name: 'realTimeProvider',
);

// ─────────────────────────────────────────────────────────────────────────────
// DERIVED "SELECT" PROVIDERS — granular rebuilds
// ─────────────────────────────────────────────────────────────────────────────
// Each derived provider reads a slice of RealTimeService.
// Riverpod only rebuilds widgets that watch a specific slice when THAT
// specific slice changes — preventing unnecessary rebuilds across screens.

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
// PASS 4 — IMD + NDMA PROVIDERS
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

/// Whether any active IMD RED or ORANGE alerts exist right now.
final hasActiveImdWarningProvider = Provider<bool>(
  (ref) {
    final alerts = ref.watch(imdAlertsProvider);
    return alerts.any(
      (a) => a.severity == 'RED' || a.severity == 'ORANGE',
    );
  },
  name: 'hasActiveImdWarningProvider',
);

// ─────────────────────────────────────────────────────────────────────────────
// PER-CITY PROVIDER FAMILY
// ─────────────────────────────────────────────────────────────────────────────

/// Returns FloodData for a specific city name (case-insensitive).
/// City detail screens use this instead of searching liveLevels manually.
///
/// Usage:
///   final data = ref.watch(cityDataProvider('Patna'));
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
final stateEmergencyContactsProvider =
    Provider.family<List<EmergencyContact>, String>(
  (ref, state) =>
      ref.watch(realTimeProvider).emergencyContactsForState(state),
  name: 'stateEmergencyContactsProvider',
);

/// River trend history for a specific city (24-hr snapshots).
final cityTrendProvider =
    Provider.family<List<dynamic>, String>(
  (ref, cityName) =>
      ref.watch(realTimeProvider).trendForCity(cityName),
  name: 'cityTrendProvider',
);

// ─────────────────────────────────────────────────────────────────────────────
// THEME PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// ThemeProvider wrapped in a ChangeNotifierProvider.
/// main.dart replaces ListenableBuilder + ThemeProvider() singleton calls
/// with ref.watch(themeProvider).mode / .label / .icon.
final themeProvider = ChangeNotifierProvider<ThemeProvider>(
  (ref) => ThemeProvider(),
  name: 'themeProvider',
);

/// ThemeMode only — MaterialApp.themeMode slice.
final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(themeProvider).mode,
  name: 'themeModeProvider',
);
