// lib/providers/real_time_river_provider.dart
// v3 — WRD Bihar is now the LIVE parent source for all screens.
//
// Architecture:
//   WrdBiharService (scrape) ──► wrdStationsProvider  (AsyncNotifier, 15-min auto-refresh)
//                                       │
//                                       ▼
//                              wrdRiverStationsProvider  (WrdStation → RiverStation)
//                                       │
//                                       ▼
//                              realTimeRiverProvider     (alias consumed by mapStationsProvider)
//                                       │
//                               ┌───────┴──────────────────────────────┐
//                               ▼                                      ▼
//                         MapScreen                          Dashboard / Alerts /
//                     (mapStationsProvider                  RiverMonitor / Weather
//                      = WRD + CWC merged)                  (all watch wrdRiverStationsProvider)
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../services/wrd_bihar_service.dart';
import 'station_history_provider.dart';

// ── 1. Raw WrdStation list — auto-refreshes every 15 min ──────────────────────
//
// AsyncNotifier so UI can show loading/error/data states cleanly.
class WrdStationsNotifier extends AsyncNotifier<List<WrdStation>> {
  static const _refreshInterval = Duration(minutes: 15);
  Timer? _timer;

  @override
  Future<List<WrdStation>> build() async {
    // Cancel any previous timer when provider is rebuilt / disposed
    ref.onDispose(() => _timer?.cancel());

    // Schedule background refresh
    _timer = Timer.periodic(_refreshInterval, (_) => _refresh());

    return _doFetch();
  }

  Future<List<WrdStation>> _doFetch() =>
      WrdBiharService.instance.fetch();

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => WrdBiharService.instance.fetch(forceRefresh: true));
  }

  /// Called by pull-to-refresh / manual refresh buttons anywhere in the app.
  Future<void> forceRefresh() => _refresh();
}

/// Single live list of raw WrdStation objects.
/// Watch this when you need district / site / danger-level raw values.
final wrdStationsProvider =
    AsyncNotifierProvider<WrdStationsNotifier, List<WrdStation>>(
        WrdStationsNotifier.new);

// ── 2. WrdStation → RiverStation adapter ─────────────────────────────────────
//
// RiverStation is the shared model used by map markers, dashboard tiles,
// alert logic, and risk calculations.
RiverStation _wrdToRiverStation(WrdStation s) {
  final cur = s.currentLevel;
  final dl  = s.dangerLevel;
  final wl  = s.warningLevel ?? (dl != null ? dl - 1.0 : null);
  final hfl = s.hfl ?? (dl != null ? dl + 1.5 : null);

  return RiverStation(
    city:        s.site,
    state:       'Bihar',
    river:       s.river,
    station:     s.site,
    current:     cur,
    warning:     wl,
    danger:      dl,
    hfl:         hfl,
    dataSource:  s.source,   // 'WRD_BIHAR_LIVE' or 'WRD_BIHAR_DISK'
    lastUpdated:
        '${s.fetchedAt.hour.toString().padLeft(2, '0')}:'
        '${s.fetchedAt.minute.toString().padLeft(2, '0')}',
    isLive: s.source == 'WRD_BIHAR_LIVE',
  );
}

/// Derived: WrdStation list converted to RiverStation list.
/// All screens that show river level cards should watch THIS provider.
final wrdRiverStationsProvider =
    Provider<AsyncValue<List<RiverStation>>>((ref) {
  return ref.watch(wrdStationsProvider).whenData(
    (raw) => raw.map(_wrdToRiverStation).toList(),
  );
});

// ── 3. realTimeRiverProvider — canonical alias consumed by mapStationsProvider ─
//
// mapStationsProvider (map_command_provider.dart) already watches
// realTimeRiverProvider and merges it with CWC stations.
// We simply forward the converted WRD list here so the map picks it up
// without any change to map_command_provider.dart.
final realTimeRiverProvider =
    FutureProvider.autoDispose<List<RiverStation>>((ref) async {
  final async = ref.watch(wrdStationsProvider);

  // While loading, return last known data from in-memory cache so the
  // map/dashboard don't flash empty.
  if (async.isLoading) {
    final cached = WrdBiharService.instance.cachedStations;
    if (cached != null && cached.isNotEmpty) {
      return cached.map(_wrdToRiverStation).toList();
    }
  }

  final stations = async.asData?.value ?? [];
  final converted = stations.map(_wrdToRiverStation).toList();

  // Push into history store for trend charts
  ref.read(stationHistoryProvider.notifier).pushSnapshot(converted);

  if (kDebugMode) {
    debugPrint('[RealTimeRiver] ${converted.length} WRD stations forwarded to map');
  }
  return converted;
});

// ── 4. Convenience derived providers (used by non-map screens) ────────────────

/// Total station count (live badge on dashboard header).
final wrdStationCountProvider = Provider<int>((ref) {
  final async = ref.watch(wrdStationsProvider);
  return async.asData?.value.length ?? 0;
});

/// Stations currently AT or ABOVE danger level.
final wrdCriticalStationsProvider = Provider<List<RiverStation>>((ref) {
  final async = ref.watch(wrdRiverStationsProvider);
  final list  = async.asData?.value ?? [];
  return list
      .where((s) =>
          s.dangerClass == DangerClass.extreme ||
          s.dangerClass == DangerClass.severe)
      .toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
});

/// Stations currently above WARNING but below danger level.
final wrdWarningStationsProvider = Provider<List<RiverStation>>((ref) {
  final async = ref.watch(wrdRiverStationsProvider);
  final list  = async.asData?.value ?? [];
  return list
      .where((s) => s.dangerClass == DangerClass.high)
      .toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
});

/// Stations grouped by river name — used by RiverMonitorScreen.
final wrdByRiverProvider = Provider<Map<String, List<RiverStation>>>((ref) {
  final async = ref.watch(wrdRiverStationsProvider);
  final list  = async.asData?.value ?? [];
  final map   = <String, List<RiverStation>>{};
  for (final s in list) {
    map.putIfAbsent(s.river, () => []).add(s);
  }
  // Sort each river's stations by risk score descending
  for (final v in map.values) {
    v.sort((a, b) => b.riskScore.compareTo(a.riskScore));
  }
  return map;
});

/// Is the WRD fetch currently in-flight?
final wrdIsLoadingProvider = Provider<bool>((ref) =>
    ref.watch(wrdStationsProvider).isLoading);

/// Last fetch error message (null = no error).
final wrdErrorProvider = Provider<String?>((ref) {
  final async = ref.watch(wrdStationsProvider);
  return async.hasError ? async.error.toString() : null;
});

/// Whether latest data is from live scrape vs disk cache.
final wrdIsLiveProvider = Provider<bool>((ref) {
  final async = ref.watch(wrdStationsProvider);
  final list  = async.asData?.value ?? [];
  return list.any((s) => s.source == 'WRD_BIHAR_LIVE');
});
