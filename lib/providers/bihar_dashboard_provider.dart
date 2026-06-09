// lib/providers/bihar_dashboard_provider.dart
//
// Derives dashboard-level KPI scalars from biharLiveProvider so the
// DashboardScreen can display Bihar-specific live data without touching
// the existing liveLevelsProvider / FloodData pipeline.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bihar_live_provider.dart';

// ── Derived scalars ──────────────────────────────────────────────────────────

/// Total WRD Bihar stations that returned live data this fetch.
final biharStationCountProvider = Provider<int>((ref) {
  return ref
      .watch(biharLiveProvider)
      .maybeWhen(data: (s) => s.stations.length, orElse: () => 0);
});

/// Number of stations at CRITICAL or DANGER risk.
final biharCriticalCountProvider = Provider<int>((ref) {
  return ref.watch(biharLiveProvider).maybeWhen(
        data: (s) => s.stations.where((st) => st.isCritical).length,
        orElse: () => 0,
      );
});

/// Number of stations at WARNING or HIGH risk.
final biharWarningCountProvider = Provider<int>((ref) {
  return ref.watch(biharLiveProvider).maybeWhen(
        data: (s) => s.stations.where((st) => st.isWarning).length,
        orElse: () => 0,
      );
});

/// Average 24h rainfall (mm) across all Bihar stations that have data.
final biharAvgRainfallProvider = Provider<double?>((ref) {
  return ref.watch(biharLiveProvider).maybeWhen(
        data: (s) {
          final vals = s.stations
              .where((st) => st.rainfall24h != null)
              .map((st) => st.rainfall24h!)
              .toList();
          if (vals.isEmpty) return null;
          return vals.reduce((a, b) => a + b) / vals.length;
        },
        orElse: () => null,
      );
});

/// Average GloFAS river discharge (m³/s) across all Bihar stations.
final biharAvgDischargeProvider = Provider<double?>((ref) {
  return ref.watch(biharLiveProvider).maybeWhen(
        data: (s) {
          final vals = s.stations
              .where((st) => st.discharge != null)
              .map((st) => st.discharge!)
              .toList();
          if (vals.isEmpty) return null;
          return vals.reduce((a, b) => a + b) / vals.length;
        },
        orElse: () => null,
      );
});

/// Top 3 stations by risk (critical first, then warning) for dashboard preview.
final biharTopAlertsProvider = Provider<List<BiharStationData>>((ref) {
  return ref.watch(biharLiveProvider).maybeWhen(
        data: (s) => s.stations
            .where((st) => st.isCritical || st.isWarning)
            .take(3)
            .toList(),
        orElse: () => [],
      );
});

/// True while biharLiveProvider is loading.
final biharIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(biharLiveProvider).isLoading;
});
