// lib/providers/alerts_provider.dart  v2.0
//
// Bridge file: re-exports everything from data_fetch_provider so that
// any existing screen that imports THIS file keeps working unchanged.
//
// Previously this file held a stub AlertItem model and empty providers.
// Now ALL alert logic lives in:
//   lib/services/alert_engine.dart       (rule definitions)
//   lib/providers/data_fetch_provider.dart (Riverpod providers)
// This file simply re-exports the correct symbols and adds any
// legacy-compat aliases that older screens may still reference.
library;

export 'data_fetch_provider.dart'
    show
        alertsProvider,
        criticalAlertsProvider,
        emergencyAlertsProvider,
        warningAlertsProvider,
        alertCountProvider,
        criticalAlertCountProvider,
        stationAlertsProvider,
        sourceStatusProvider,
        dataFetchProvider,
        dataFetchStationsProvider,
        lastFetchTimeProvider2,
        fetchSnapshotKpiProvider;

export '../services/alert_engine.dart'
    show
        FloodAlert,
        AlertSeverity,
        AlertSeverityExt,
        AlertType,
        AlertTypeExt,
        AlertEngine;

export '../services/data_fetch_engine.dart'
    show
        DataFetchEngine,
        DataFetchSnapshot,
        StationReading,
        SourceStatus;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Legacy alias: screens that used "activeAlertsCountProvider" still compile.
final activeAlertsCountProvider = Provider<int>((ref) {
  // delegate to the real counter in data_fetch_provider
  final snap = ref.watch(dataFetchProvider);
  return snap.when(
    data:    (s) {
      // lazy import avoids circular — AlertEngine is a stateless singleton
      final alerts = AlertEngine.instance.evaluate(s);
      return alerts.length;
    },
    loading: () => 0,
    error:   (_, __) => 0,
  );
});
