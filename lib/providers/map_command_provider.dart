// lib/providers/map_command_provider.dart
// Riverpod v3 — StateProvider was removed; use NotifierProvider instead.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/cwc_provider.dart';
import '../services/befiqr_cwc_service.dart';

// Export must come before all declarations (Dart directive rule)
export 'cwc_provider.dart' show biharGeoJsonProvider;

// ─── View-mode toggle ─────────────────────────────────────────────────────────
enum MapViewMode { bihar, national }

class MapViewModeNotifier extends Notifier<MapViewMode> {
  @override
  MapViewMode build() => MapViewMode.bihar;
}

final mapViewModeProvider =
    NotifierProvider<MapViewModeNotifier, MapViewMode>(
        MapViewModeNotifier.new);

// ─── Selected station (popup) ─────────────────────────────────────────────────
class SelectedStationNotifier extends Notifier<RiverStation?> {
  @override
  RiverStation? build() => null;
}

final mapSelectedStationProvider =
    NotifierProvider<SelectedStationNotifier, RiverStation?>(
        SelectedStationNotifier.new);

// ─── Sync metadata ────────────────────────────────────────────────────────────
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

class SyncMetaNotifier extends Notifier<SyncMeta> {
  @override
  SyncMeta build() => const SyncMeta();
}

final mapSyncMetaProvider =
    NotifierProvider<SyncMetaNotifier, SyncMeta>(SyncMetaNotifier.new);

// ─── CwcStation → RiverStation adapter ───────────────────────────────────────
extension CwcStationAdapter on CwcStation {
  RiverStation toRiverStation() => RiverStation(
    city:    site,
    state:   'Bihar',
    river:   river,
    station: site,
    current: currentLevel,
    warning: (dangerLevel - 1.5).clamp(0, double.infinity),
    danger:  dangerLevel,
    hfl:     dangerLevel + 1.5,
    dataSource:  'CWC_FFEM',
    lastUpdated: '${fetchedAt.hour.toString().padLeft(2, '0')}:'
                 '${fetchedAt.minute.toString().padLeft(2, '0')}',
    isLive:  true,
  );
}

// ─── Merged + filtered station list ──────────────────────────────────────────
final mapStationsProvider = Provider<List<RiverStation>>((ref) {
  final rtAsync  = ref.watch(realTimeRiverProvider);
  final cwcAsync = ref.watch(cwcStationsProvider);
  final mode     = ref.watch(mapViewModeProvider);

  final List<RiverStation> all = [
    ...rtAsync.asData?.value ?? const [],
    ...(cwcAsync.asData?.value ?? const [])
        .map((s) => s.toRiverStation()),
  ];

  final seen   = <String>{};
  final unique = all.where((s) => seen.add(s.station)).toList();

  final filtered = mode == MapViewMode.bihar
      ? unique.where((s) => s.state.toLowerCase().contains('bihar')).toList()
      : unique;

  filtered.sort((a, b) => b.riskScore.compareTo(a.riskScore));
  return filtered;
});

// ─── District risk map (for heatmap layer) ────────────────────────────────────
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
