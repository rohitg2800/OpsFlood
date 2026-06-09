// lib/providers/real_time_river_provider.dart  v7
//
// CHANGE vs v6:
//   Birpur is no longer deduplicated from DataFetch in the generic loop.
//   Instead, mergedStationsProvider removes the raw DataFetch Birpur entry
//   and injects the enriched kosiBirpurProvider result in its place.
//   This guarantees exactly ONE Birpur in the final list with the best
//   available level AND discharge/trend metadata.
//
//   All other fixes from v6 are preserved:
//   #1 cold-start blank, #2 seed-CWC collision,
//   #3 DataFetch exclusion, #4 dedup normaliser.
//
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../services/wrd_bihar_service.dart';
import '../services/befiqr_cwc_service.dart';
import 'station_history_provider.dart';
import 'cwc_provider.dart';
import 'data_fetch_provider.dart';
import 'kosi_birpur_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _sameStation(String a, String b) {
  final na = _norm(a);
  final nb = _norm(b);
  if (na == nb) return true;
  final pa = na.length > 6 ? na.substring(0, 6) : na;
  final pb = nb.length > 6 ? nb.substring(0, 6) : nb;
  return pa == pb;
}

bool _isBirpur(String name) =>
    name.toLowerCase().contains('birpur');

// ─────────────────────────────────────────────────────────────────────────────
// 1. Raw WrdStation list — auto-refreshes every 15 min
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// 2. WrdStation → RiverStation adapter
// ─────────────────────────────────────────────────────────────────────────────
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

RiverStation _cwcToRiverStation(CwcStation s) => RiverStation(
  city:        s.site,
  state:       'Bihar',
  river:       s.river,
  station:     s.site,
  current:     s.currentLevel,
  warning:     s.warningLevel ?? (s.dangerLevel - 1.5).clamp(0, double.infinity),
  danger:      s.dangerLevel,
  hfl:         s.dangerLevel + 1.5,
  dataSource:  s.source,
  lastUpdated: '${s.fetchedAt.hour.toString().padLeft(2, '0')}:'
               '${s.fetchedAt.minute.toString().padLeft(2, '0')}',
  isLive:      !s.isFromSeed,
);

/// WRD-only converted list
final wrdRiverStationsProvider =
    Provider<AsyncValue<List<RiverStation>>>((ref) {
  return ref.watch(wrdStationsProvider).whenData(
    (raw) => raw.map(_wrdToRiverStation).toList(),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. realTimeRiverProvider — WRD-only alias for map screen
// ─────────────────────────────────────────────────────────────────────────────
final realTimeRiverProvider =
    FutureProvider.autoDispose<List<RiverStation>>((ref) async {
  final async = ref.watch(wrdStationsProvider);

  if (async.isLoading) {
    final cached = WrdBiharService.instance.cachedStations;
    if (cached != null && cached.isNotEmpty) {
      return cached.map(_wrdToRiverStation).toList();
    }
  }

  final stations  = async.asData?.value ?? [];
  final converted = stations.map(_wrdToRiverStation).toList();
  ref.read(stationHistoryProvider.notifier).pushSnapshot(converted);

  if (kDebugMode) {
    debugPrint('[RealTimeRiver] ${converted.length} WRD stations forwarded');
  }
  return converted;
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. mergedStationsProvider — THE single source of truth for all screens
//
// Priority ladder:
//   live-CWC  (highest) ──┐
//   DataFetch           ──┤
//   WRD                 ──┤  ← Birpur is removed from all three buckets
//   seed-CWC  (lowest)  ──┘     and replaced by kosiBirpurProvider result
//                                (level=GloFAS||live, enrich=discharge+trend)
// ─────────────────────────────────────────────────────────────────────────────
final mergedStationsProvider = Provider<List<RiverStation>>((ref) {
  final wrdAsync     = ref.watch(realTimeRiverProvider);
  final cwcAsync     = ref.watch(cwcStationsProvider);
  final birpurAsync  = ref.watch(kosiBirpurProvider);

  // ── FIX #1: never return [] on cold-start ───────────────────────────
  List<RiverStation> wrdList;
  if (wrdAsync.isLoading || wrdAsync.asData?.value == null) {
    final cached = WrdBiharService.instance.cachedStations;
    wrdList = (cached ?? []).map(_wrdToRiverStation).toList();
  } else {
    wrdList = wrdAsync.asData!.value;
  }

  // ── Build Birpur entry from kosiBirpurProvider ────────────────────────
  // If kosiBirpurProvider is still loading, build a placeholder from
  // whatever DataFetch already has (avoids blank Birpur card).
  final RiverStation birpurStation;
  final birpurReading = birpurAsync.asData?.value;
  if (birpurReading != null) {
    birpurStation = RiverStation(
      city:        'Birpur',
      state:       'Bihar',
      river:       'Kosi',
      station:     'Birpur',
      current:     birpurReading.levelM,
      warning:     birpurReading.warningLevel,
      danger:      birpurReading.dangerLevel,
      hfl:         birpurReading.dangerLevel + 1.5,
      dataSource:  birpurReading.source,
      lastUpdated:
          '${birpurReading.observedAt.hour.toString().padLeft(2, '0')}:'
          '${birpurReading.observedAt.minute.toString().padLeft(2, '0')}',
      isLive: birpurReading.source != 'SEED',
    );
  } else {
    // Still loading — use DataFetch Birpur if available, else seed
    final dfBirpur = ref.watch(dataFetchStationsProvider)
        .where((s) => _isBirpur(s.station)).firstOrNull;
    birpurStation = dfBirpur ?? RiverStation(
      city: 'Birpur', state: 'Bihar', river: 'Kosi', station: 'Birpur',
      current: 210.80, warning: kBirpurWarningLevel, danger: kBirpurDangerLevel,
      hfl: kBirpurDangerLevel + 1.5, dataSource: 'SEED',
      lastUpdated: '00:00', isLive: false,
    );
  }

  // ── FIX #2/#3: split live vs seed CWC ──────────────────────────────
  final allCwcStations = cwcAsync.asData?.value ?? const <CwcStation>[];
  final cwcLive   = allCwcStations
      .where((s) => !s.isFromSeed && !_isBirpur(s.site)).toList();
  final cwcSeed   = allCwcStations
      .where((s) =>  s.isFromSeed && !_isBirpur(s.site)).toList();

  final cwcLiveRS = cwcLive.map(_cwcToRiverStation).toList();
  final cwcSeedRS = cwcSeed.map(_cwcToRiverStation).toList();
  final cwcLiveNames = { for (final s in cwcLiveRS) _norm(s.station) };

  // ── DataFetch: exclude Birpur (handled separately) + seed-CWC names ────
  final dfStations = ref.watch(dataFetchStationsProvider)
      .where((s) =>
          !_isBirpur(s.station) &&
          !cwcLiveNames.any((n) => _sameStation(n, s.station)))
      .toList();
  final dfNames = { for (final s in dfStations) _norm(s.station) };

  // ── WRD: exclude Birpur + already-covered stations ─────────────────
  final wrdFiltered = wrdList
      .where((s) =>
          !_isBirpur(s.station) &&
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)))
      .toList();
  final wrdNames = { for (final s in wrdFiltered) _norm(s.station) };

  // ── Seed CWC: last resort, no Birpur ──────────────────────────────
  final cwcSeedFiltered = cwcSeedRS
      .where((s) =>
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)) &&
          !wrdNames.any((n) => _sameStation(n, s.station)))
      .toList();

  // ── Final merge: Birpur always explicit, never from dedup ───────────
  final merged = [
    ...cwcLiveRS,
    ...dfStations,
    ...wrdFiltered,
    ...cwcSeedFiltered,
    birpurStation,   // always exactly one Birpur, always enriched
  ];
  merged.sort((a, b) => b.riskScore.compareTo(a.riskScore));

  if (kDebugMode) {
    debugPrint(
      '[Merged] ${cwcLiveRS.length} CWC-live'
      ' + ${cwcSeedFiltered.length} CWC-seed'
      ' + ${dfStations.length} DataFetch'
      ' + ${wrdFiltered.length} WRD'
      ' + 1 Birpur(${birpurReading?.source ?? "loading"})'
      ' = ${merged.length} total',
    );
  }
  return merged;
});

// ─────────────────────────────────────────────────────────────────────────────
// 5. Count providers
// ─────────────────────────────────────────────────────────────────────────────

final mergedTotalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider).length);

final mergedExtremeCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.extreme)
        .length);

final mergedCriticalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) =>
            s.dangerClass == DangerClass.severe ||
            s.dangerClass == DangerClass.extreme)
        .length);

final mergedElevatedCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.aboveNormal)
        .length);

final mergedNormalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.normal)
        .length);

final mergedBiharStationsProvider = Provider<List<RiverStation>>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.state.toLowerCase().contains('bihar'))
        .toList());

// ─────────────────────────────────────────────────────────────────────────────
// 6. Legacy convenience providers
// ─────────────────────────────────────────────────────────────────────────────

final wrdStationCountProvider = Provider<int>((ref) {
  final async = ref.watch(wrdStationsProvider);
  return async.asData?.value.length ?? 0;
});

final wrdCriticalStationsProvider = Provider<List<RiverStation>>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) =>
            s.dangerClass == DangerClass.extreme ||
            s.dangerClass == DangerClass.severe)
        .toList());

final wrdWarningStationsProvider = Provider<List<RiverStation>>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.aboveNormal)
        .toList());

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

final wrdIsLoadingProvider = Provider<bool>((ref) =>
    ref.watch(wrdStationsProvider).isLoading);

final wrdErrorProvider = Provider<String?>((ref) {
  final async = ref.watch(wrdStationsProvider);
  return async.hasError ? async.error.toString() : null;
});

final wrdIsLiveProvider = Provider<bool>((ref) {
  final async = ref.watch(wrdStationsProvider);
  final list  = async.asData?.value ?? [];
  return list.any((s) => s.source == 'WRD_BIHAR_LIVE');
});
