// lib/providers/real_time_river_provider.dart
// v4 — single merged source of truth for ALL screens.
//
// Architecture:
//   WrdBiharService (scrape) ──► wrdStationsProvider  (AsyncNotifier, 15-min auto-refresh)
//                                       │
//                                       ▼
//                              wrdRiverStationsProvider  (WrdStation → RiverStation)
//                                       │
//                                       ▼
//                              realTimeRiverProvider     (WRD-only alias for map merge)
//                                       │
//                         ┌─────────────┴────────────────────────────────────┐
//                         ▼                                                  ▼
//               cwcStationsProvider                                  (other sources)
//                         │
//                         ▼
//              ┌──────────────────────┐
//              │  mergedStationsProvider  ◄─── ALL screens consume this
//              │  (WRD + CWC deduped)  │
//              └──────────────────────┘
//                         │
//          ┌──────────────┼────────────────┐
//          ▼              ▼                ▼
//   mergedCritical  mergedSevere    mergedTotal …
//  (Monitors badge) (Alerts counts) (Dashboard KPIs)
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../services/wrd_bihar_service.dart';
import '../services/befiqr_cwc_service.dart';
import 'station_history_provider.dart';
import 'cwc_provider.dart';

// ── 1. Raw WrdStation list — auto-refreshes every 15 min ──────────────────────
class WrdStationsNotifier extends AsyncNotifier<List<WrdStation>> {
  static const _refreshInterval = Duration(minutes: 15);
  Timer? _timer;

  @override
  Future<List<WrdStation>> build() async {
    ref.onDispose(() => _timer?.cancel());
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

  Future<void> forceRefresh() => _refresh();
}

final wrdStationsProvider =
    AsyncNotifierProvider<WrdStationsNotifier, List<WrdStation>>(
        WrdStationsNotifier.new);

// ── 2. WrdStation → RiverStation adapter ──────────────────────────────────────
//
// FIX: ?? 0.0 fallbacks so nullable WrdStation doubles satisfy
// RiverStation's required non-nullable fields. When thresholds are
// genuinely missing the station degrades to DangerClass.normal.
RiverStation _wrdToRiverStation(WrdStation s) {
  final cur = s.currentLevel ?? 0.0;
  final dl  = s.dangerLevel  ?? 0.0;
  final wl  = s.warningLevel ?? (dl > 0 ? dl - 1.0 : 0.0);
  final hfl = s.hfl          ?? (dl > 0 ? dl + 1.5 : 0.0);

  return RiverStation(
    city:        s.site,
    state:       'Bihar',
    river:       s.river,
    station:     s.site,
    current:     cur,
    warning:     wl,
    danger:      dl,
    hfl:         hfl,
    dataSource:  s.source,
    lastUpdated:
        '${s.fetchedAt.hour.toString().padLeft(2, '0')}:'
        '${s.fetchedAt.minute.toString().padLeft(2, '0')}',
    isLive: s.source == 'WRD_BIHAR_LIVE',
  );
}

// ── CwcStation → RiverStation adapter (kept here to avoid import cycles) ──────
RiverStation _cwcToRiverStation(CwcStation s) => RiverStation(
  city:        s.site,
  state:       'Bihar',
  river:       s.river,
  station:     s.site,
  current:     s.currentLevel,
  warning:     (s.dangerLevel - 1.5).clamp(0, double.infinity),
  danger:      s.dangerLevel,
  hfl:         s.dangerLevel + 1.5,
  dataSource:  'CWC_FFEM',
  lastUpdated: '${s.fetchedAt.hour.toString().padLeft(2, '0')}:'
               '${s.fetchedAt.minute.toString().padLeft(2, '0')}',
  isLive:      true,
);

/// WRD-only converted list (used by realTimeRiverProvider → map merge).
final wrdRiverStationsProvider =
    Provider<AsyncValue<List<RiverStation>>>((ref) {
  return ref.watch(wrdStationsProvider).whenData(
    (raw) => raw.map(_wrdToRiverStation).toList(),
  );
});

// ── 3. realTimeRiverProvider — WRD-only alias for mapStationsProvider ─────────
final realTimeRiverProvider =
    FutureProvider.autoDispose<List<RiverStation>>((ref) async {
  final async = ref.watch(wrdStationsProvider);

  if (async.isLoading) {
    final cached = WrdBiharService.instance.cachedStations;
    if (cached != null && cached.isNotEmpty) {
      return cached.map(_wrdToRiverStation).toList();
    }
  }

  final stations = async.asData?.value ?? [];
  final converted = stations.map(_wrdToRiverStation).toList();

  ref.read(stationHistoryProvider.notifier).pushSnapshot(converted);

  if (kDebugMode) {
    debugPrint('[RealTimeRiver] ${converted.length} WRD stations forwarded');
  }
  return converted;
});

// ── 4. mergedStationsProvider — THE single source of truth for all screens ────
//
// Merges WRD + CWC stations with deduplication by station name.
// When both sources have the same station, CWC wins (it has real
// threshold data; WRD may have null levels that fall back to 0.0).
//
// This is identical logic to mapStationsProvider in map_command_provider.dart
// but WITHOUT the Bihar/national filter — screens can filter themselves.
final mergedStationsProvider = Provider<List<RiverStation>>((ref) {
  final wrdAsync = ref.watch(realTimeRiverProvider);
  final cwcAsync = ref.watch(cwcStationsProvider);

  // CWC stations converted
  final cwcList = (cwcAsync.asData?.value ?? const [])
      .map(_cwcToRiverStation)
      .toList();

  // WRD stations — only include those NOT already covered by CWC
  final cwcNames = {for (final s in cwcList) s.station.toLowerCase()};
  final wrdList  = (wrdAsync.asData?.value ?? const [])
      .where((s) => !cwcNames.contains(s.station.toLowerCase()))
      .toList();

  final merged = [...cwcList, ...wrdList];
  merged.sort((a, b) => b.riskScore.compareTo(a.riskScore));

  if (kDebugMode) {
    debugPrint('[Merged] ${cwcList.length} CWC + ${wrdList.length} WRD-only '
        '= ${merged.length} total stations');
  }
  return merged;
});

// ── 5. Count providers — derived from mergedStations (same for ALL screens) ───

/// Total station count.
final mergedTotalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider).length);

/// Stations AT or ABOVE HFL — extreme danger.
final mergedExtremeCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.extreme)
        .length);

/// Stations AT or ABOVE danger level (severe + extreme).
final mergedCriticalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) =>
            s.dangerClass == DangerClass.severe ||
            s.dangerClass == DangerClass.extreme)
        .length);

/// Stations above warning but below danger.
final mergedElevatedCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.aboveNormal)
        .length);

/// Normal stations.
final mergedNormalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.normal)
        .length);

/// Bihar-only subset (for Monitors / Alerts screens).
final mergedBiharStationsProvider = Provider<List<RiverStation>>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.state.toLowerCase().contains('bihar'))
        .toList());

// ── 6. Legacy convenience providers (keep for backward compat) ────────────────

/// Total WRD station count (raw, before merge).
final wrdStationCountProvider = Provider<int>((ref) {
  final async = ref.watch(wrdStationsProvider);
  return async.asData?.value.length ?? 0;
});

/// Stations currently AT or ABOVE danger level (merged source).
// FIX: renamed from wrdCriticalStationsProvider — now uses merged data.
final wrdCriticalStationsProvider = Provider<List<RiverStation>>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) =>
            s.dangerClass == DangerClass.extreme ||
            s.dangerClass == DangerClass.severe)
        .toList());

/// Stations above WARNING but below danger (merged source).
// FIX: was DangerClass.high (non-existent) → DangerClass.aboveNormal.
// FIX: now uses merged data instead of WRD-only.
final wrdWarningStationsProvider = Provider<List<RiverStation>>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.aboveNormal)
        .toList());

/// Stations grouped by river — used by RiverMonitorScreen.
final wrdByRiverProvider = Provider<Map<String, List<RiverStation>>>((ref) {
  final list = ref.watch(mergedStationsProvider);
  final map  = <String, List<RiverStation>>{};
  for (final s in list) {
    map.putIfAbsent(s.river, () => []).add(s);
  }
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
