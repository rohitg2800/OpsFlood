// lib/providers/map_command_provider.dart
// ═══════════════════════════════════════════════════════════════════════════
// Riverpod state layer for the Command-Center map screen.
//
// Providers:
//   mapViewModeProvider     — Bihar | National toggle
//   mapSelectedStationProvider — currently tapped station (for popup)
//   mapSyncMetaProvider     — per-source last-updated timestamps
//   mapStationsProvider     — derived: filtered + sorted station list
//   biharDistrictRiskProvider — derived: district-name → DangerClass map
// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import 'real_time_river_provider.dart';
import 'cwc_provider.dart';

// ─── View-mode toggle ─────────────────────────────────────────────────────
enum MapViewMode { bihar, national }

final mapViewModeProvider =
    StateProvider<MapViewMode>((_) => MapViewMode.bihar);

// ─── Selected station (popup) ─────────────────────────────────────────────
final mapSelectedStationProvider =
    StateProvider<RiverStation?>((_) => null);

// ─── Sync-meta: last-updated per source ───────────────────────────────────
class SyncMeta {
  final DateTime? cwcUpdated;
  final DateTime? wrdUpdated;
  final DateTime? gloFasUpdated;

  const SyncMeta({
    this.cwcUpdated,
    this.wrdUpdated,
    this.gloFasUpdated,
  });

  /// Human-readable "freshest" label for the banner.
  String get freshnessLabel {
    final times = <DateTime>[
      if (cwcUpdated   != null) cwcUpdated!,
      if (wrdUpdated   != null) wrdUpdated!,
      if (gloFasUpdated != null) gloFasUpdated!,
    ];
    if (times.isEmpty) return 'No data yet';
    times.sort();
    final latest = times.last;
    final diff = DateTime.now().difference(latest);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
    if (diff.inHours   < 24)  return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  /// Per-source labels for the legend drawer.
  String labelFor(String source) {
    switch (source) {
      case 'CWC_FFEM': return cwcUpdated == null   ? '—' : _fmt(cwcUpdated!);
      case 'WRD_BIHAR': return wrdUpdated == null  ? '—' : _fmt(wrdUpdated!);
      case 'GLOFAS':   return gloFasUpdated == null ? '—' : _fmt(gloFasUpdated!);
      default: return '—';
    }
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}  '
      '${t.day}/${t.month}';
}

final mapSyncMetaProvider =
    StateProvider<SyncMeta>((_) => const SyncMeta());

// ─── Merged station list ───────────────────────────────────────────────────
// Combines realTimeRiverProvider (CWC/national) with cwcProvider (Bihar CWC).
// Falls back to empty list if providers are still loading / errored.
final mapStationsProvider = Provider<List<RiverStation>>((ref) {
  final rtAsync  = ref.watch(realTimeRiverProvider);
  final cwcAsync = ref.watch(cwcStationsProvider);
  final mode     = ref.watch(mapViewModeProvider);

  final List<RiverStation> all = [
    ...rtAsync.asData?.value  ?? const [],
    ...cwcAsync.asData?.value ?? const [],
  ];

  // Deduplicate by station name
  final seen = <String>{};
  final unique = all.where((s) => seen.add(s.station)).toList();

  // Filter by view-mode
  final filtered = mode == MapViewMode.bihar
      ? unique.where((s) => s.state.toLowerCase().contains('bihar')).toList()
      : unique;

  // Sort critical → extreme first
  filtered.sort((a, b) => b.riskScore.compareTo(a.riskScore));
  return filtered;
});

// ─── District risk map (for GeoJSON heatmap layer) ─────────────────────────
// Maps district name (lowercase) → highest DangerClass found in that district.
final biharDistrictRiskProvider = Provider<Map<String, DangerClass>>((ref) {
  final stations = ref.watch(mapStationsProvider);
  final Map<String, DangerClass> riskMap = {};
  for (final s in stations) {
    if (!s.state.toLowerCase().contains('bihar')) continue;
    final key = s.city.toLowerCase();
    final existing = riskMap[key];
    if (existing == null || s.dangerClass.index > existing.index) {
      riskMap[key] = s.dangerClass;
    }
  }
  return riskMap;
});

// ─── CWC stations as RiverStation ─────────────────────────────────────────
// Thin adapter so cwcProvider data flows into the unified station list.
// cwcStationsProvider must be defined in cwc_provider.dart.
// If it doesn't exist yet, we provide a safe empty fallback here.
final cwcStationsProvider =
    FutureProvider.autoDispose<List<RiverStation>>((ref) async {
  try {
    // Attempt to read from existing cwc provider — adjust import if needed.
    // ignore: avoid_dynamic_calls
    final cwcRef = ref.watch(cwcLiveStationsProvider);
    return cwcRef.asData?.value
            ?.map((e) => e.toRiverStation())
            .toList() ??
        const [];
  } catch (_) {
    return const [];
  }
});
