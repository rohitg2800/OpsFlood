// lib/providers/cwc_provider.dart
// Riverpod providers that expose live CWC Bihar station data
// fetched from irrigation.befiqr.in (via BefiqrCwcService).
// All screens can watch these providers to get real-time river levels.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/befiqr_cwc_service.dart';

// ── raw station list (auto-refreshes every 10 min) ────────────────────────────

final cwcStationsProvider =
    FutureProvider.autoDispose<List<CwcStation>>((ref) async {
  final svc = BefiqrCwcService();
  return svc.fetchStations();
});

// ── top-5 risk stations (used by Dashboard + Prediction widgets) ──────────────

final cwcTopRiskProvider =
    Provider.autoDispose<AsyncValue<List<CwcStation>>>((ref) {
  final stations = ref.watch(cwcStationsProvider);
  return stations.whenData(
    (list) => BefiqrCwcService.topRisk(list, n: 5),
  );
});

// ── stations grouped by river name ───────────────────────────────────────────

final cwcByRiverProvider =
    Provider.autoDispose<AsyncValue<Map<String, List<CwcStation>>>>((ref) {
  final stations = ref.watch(cwcStationsProvider);
  return stations.whenData((list) {
    final map = <String, List<CwcStation>>{};
    for (final s in list) {
      map.putIfAbsent(s.river, () => []).add(s);
    }
    return map;
  });
});

// ── danger-level stations only (above or within 1.5 m of danger) ──────────────

final cwcAlertStationsProvider =
    Provider.autoDispose<AsyncValue<List<CwcStation>>>((ref) {
  final stations = ref.watch(cwcStationsProvider);
  return stations.whenData(
    (list) => list.where((s) => s.isDanger || s.isWarning).toList()
      ..sort((a, b) => a.gap.compareTo(b.gap)),
  );
});

// ── overall Bihar flood risk index (0-100) ────────────────────────────────────
// Average risk score of all stations, weighted by (1/gap).

final biharFloodRiskIndexProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  final stations = ref.watch(cwcStationsProvider);
  return stations.whenData((list) {
    if (list.isEmpty) return 0.0;
    final scores = list.map(BefiqrCwcService.riskScore).toList();
    return scores.reduce((a, b) => a + b) / scores.length;
  });
});
