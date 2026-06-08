// lib/providers/map_command_provider.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/cwc_provider.dart';   // cwcStationsProvider, biharGeoJsonProvider
import '../services/befiqr_cwc_service.dart'; // CwcStation

// ─── View-mode toggle ────────────────────────────────────────────────────────
enum MapViewMode { bihar, national }

final mapViewModeProvider =
    StateProvider<MapViewMode>((_) => MapViewMode.bihar);

// ─── Selected station (popup) ────────────────────────────────────────────────
final mapSelectedStationProvider =
    StateProvider<RiverStation?>((_) => null);

// ─── Sync metadata ───────────────────────────────────────────────────────────
class SyncMeta {
  final DateTime? cwcUpdated;
  final DateTime? wrdUpdated;
  final DateTime? gloFasUpdated;

  const SyncMeta({
    this.cwcUpdated,
    this.wrdUpdated,
    this.gloFasUpdated,
  });

  String get freshnessLabel {
    final times = <DateTime>[
      if (cwcUpdated    != null) cwcUpdated!,
      if (wrdUpdated    != null) wrdUpdated!,
      if (gloFasUpdated != null) gloFasUpdated!,
    ];
    if (times.isEmpty) return 'No data yet';
    times.sort();
    final diff = DateTime.now().difference(times.last);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
    if (diff.inHours   < 24)  return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  String labelFor(String source) {
    switch (source) {
      case 'CWC_FFEM':  return cwcUpdated    == null ? '—' : _fmt(cwcUpdated!);
      case 'WRD_BIHAR': return wrdUpdated    == null ? '—' : _fmt(wrdUpdated!);
      case 'GLOFAS':    return gloFasUpdated == null ? '—' : _fmt(gloFasUpdated!);
      default: return '—';
    }
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}  '
      '${t.day}/${t.month}';
}

final mapSyncMetaProvider =
    StateProvider<SyncMeta>((_) => const SyncMeta());

// ─── CwcStation → RiverStation adapter ──────────────────────────────────────
// CwcStation has no lat/lng or state field; we derive state='Bihar' and
// city from site name.  Warning level is approximated as danger - 1.5 m.
extension CwcStationAdapter on CwcStation {
  RiverStation toRiverStation() => RiverStation(
    city:    site,            // best proxy for city
    state:   'Bihar',
    river:   river,
    station: site,
    current: currentLevel,
    warning: (dangerLevel - 1.5).clamp(0, double.infinity),
    danger:  dangerLevel,
    hfl:     dangerLevel + 1.5,
    dataSource:  'CWC_FFEM',
    lastUpdated: '${fetchedAt.hour.toString().padLeft(2,'0')}:'
                 '${fetchedAt.minute.toString().padLeft(2,'0')}',
    isLive:  true,
  );
}

// ─── Merged + filtered station list ─────────────────────────────────────────
// Watches both realTimeRiverProvider (national CWC/WRD) and
// cwcStationsProvider (Bihar CWC).  Recomputes automatically on any change.
final mapStationsProvider = Provider<List<RiverStation>>((ref) {
  final rtAsync  = ref.watch(realTimeRiverProvider);
  final cwcAsync = ref.watch(cwcStationsProvider);   // List<CwcStation>
  final mode     = ref.watch(mapViewModeProvider);

  final List<RiverStation> all = [
    ...rtAsync.asData?.value ?? const [],
    // Convert CwcStation → RiverStation via extension
    ...(cwcAsync.asData?.value ?? const [])
        .map((s) => s.toRiverStation()),
  ];

  // Deduplicate by station name
  final seen   = <String>{};
  final unique = all.where((s) => seen.add(s.station)).toList();

  // Filter
  final filtered = mode == MapViewMode.bihar
      ? unique.where((s) => s.state.toLowerCase().contains('bihar')).toList()
      : unique;

  // Sort highest risk first
  filtered.sort((a, b) => b.riskScore.compareTo(a.riskScore));
  return filtered;
});

// ─── District risk map (for heatmap layer) ───────────────────────────────────
// Maps district/city name (lowercase) → worst DangerClass from all stations.
final biharDistrictRiskProvider = Provider<Map<String, DangerClass>>((ref) {
  final stations = ref.watch(mapStationsProvider);
  final map = <String, DangerClass>{};
  for (final s in stations) {
    if (!s.state.toLowerCase().contains('bihar')) continue;
    final key      = s.city.toLowerCase();
    final existing = map[key];
    if (existing == null || s.dangerClass.index > existing.index) {
      map[key] = s.dangerClass;
    }
  }
  return map;
});

// ─── Re-export biharGeoJsonProvider from cwc_provider ───────────────────────
// So map_screen.dart only needs to import map_command_provider.dart.
export 'cwc_provider.dart' show biharGeoJsonProvider;
