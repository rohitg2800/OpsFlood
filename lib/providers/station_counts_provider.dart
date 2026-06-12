// lib/providers/station_counts_provider.dart
//
// Derives live Map<FloodSeverity, int> counts from mergedStationsProvider.
// Used by StationStatusStrip on the dashboard.
//
// FloodSeverity bucket mapping (mirrors StationStatusStrip chips):
//   extreme  → current >= danger * 1.15
//   danger   → current >= danger
//   warning  → current >= warning * 1.10
//   watch    → current >= warning * 0.90
//   normal   → otherwise
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/flood_severity.dart';
import 'real_time_river_provider.dart';

// ── Count map ─────────────────────────────────────────────────────────────────

final stationCountsProvider = Provider<Map<FloodSeverity, int>>((ref) {
  final stations = ref.watch(mergedStationsProvider);

  final counts = <FloodSeverity, int>{
    FloodSeverity.normal:  0,
    FloodSeverity.watch:   0,
    FloodSeverity.warning: 0,
    FloodSeverity.danger:  0,
    FloodSeverity.extreme: 0,
  };

  for (final s in stations) {
    final sev = FloodSeverity.fromLevel(s.current, s.warning, s.danger);
    counts[sev] = (counts[sev] ?? 0) + 1;
  }

  return counts;
});

// ── Last-synced helper (earliest lastUpdated string in the merged list) ────────
//
// Returns the most-recent DateTime found across all station.lastUpdated fields,
// or null when no stations are loaded yet.

final stationLastSyncedProvider = Provider<DateTime?>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  if (stations.isEmpty) return null;

  DateTime? latest;
  final now = DateTime.now();
  for (final s in stations) {
    if (s.lastUpdated == null) continue;
    // lastUpdated is stored as 'HH:mm' — combine with today's date.
    final parts = s.lastUpdated!.split(':');
    if (parts.length < 2) continue;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) continue;
    final dt = DateTime(now.year, now.month, now.day, h, m);
    if (latest == null || dt.isAfter(latest)) latest = dt;
  }
  return latest;
});

// ── Loading flag — true while WRD fetch is in flight ─────────────────────────

final stationIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(wrdIsLoadingProvider);
});
