// lib/providers/real_time_river_provider.dart  v8.0
//
// v8: liveEngineStationsProvider injected as the TOP priority tier so
//     BiharLiveEngine's real-time readings override any seed current=0 values.
//     This makes map markers and district polygons colour-correct.
//
// Priority ladder (highest → lowest):
//   ❸ LiveEngine  (BiharLiveEngine feed, updated every 15 min)
//   ❷ live-CWC    (CWC FFEM BEFIQR scraper)
//   ❶ DataFetch   (backend API)
//   ❵ WRD Bihar
//   ❴ seed-CWC    (static fallback)
//   Birpur always explicit via kosiBirpurProvider
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
import 'live_engine_bridge_provider.dart';   // ★ NEW

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

const double _kBirpurWarning = 211.50;
const double _kBirpurDanger  = 212.40;
const double _kBirpurHfl     = _kBirpurDanger + 1.5; // 213.90

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
// Priority ladder (v8):
//   ❸ LiveEngine  (BiharLiveEngine broadcast, highest fidelity)  ★ NEW
//   ❷ live-CWC   (CWC FFEM BEFIQR scraper)
//   ❶ DataFetch  (backend API)
//   ❵ WRD Bihar
//   ❴ seed-CWC   (static fallback, lowest)
//   Birpur always explicit via kosiBirpurProvider
// ─────────────────────────────────────────────────────────────────────────────
final mergedStationsProvider = Provider<List<RiverStation>>((ref) {
  // ★ Tier 0 — BiharLiveEngine stations (real-time, highest priority)
  final liveEngineRS  = ref.watch(liveEngineStationsProvider);
  final liveEngineNames = { for (final s in liveEngineRS) _norm(s.station) };

  final wrdAsync     = ref.watch(realTimeRiverProvider);
  final cwcAsync     = ref.watch(cwcStationsProvider);
  final birpurAsync  = ref.watch(kosiBirpurProvider);

  // ── FIX #1: never return [] on cold-start ────────────────────────
  List<RiverStation> wrdList;
  if (wrdAsync.isLoading || wrdAsync.asData?.value == null) {
    final cached = WrdBiharService.instance.cachedStations;
    wrdList = (cached ?? []).map(_wrdToRiverStation).toList();
  } else {
    wrdList = wrdAsync.asData!.value;
  }

  // ── Build Birpur entry from kosiBirpurProvider ─────────────────────
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
    final dfBirpur = ref.watch(dataFetchStationsProvider)
        .where((s) => _isBirpur(s.station)).firstOrNull;
    birpurStation = dfBirpur ?? RiverStation(
      city: 'Birpur', state: 'Bihar', river: 'Kosi', station: 'Birpur',
      current:     210.80,
      warning:     _kBirpurWarning,
      danger:      _kBirpurDanger,
      hfl:         _kBirpurHfl,
      dataSource: 'SEED',
      lastUpdated: '00:00',
      isLive: false,
    );
  }

  // ── live vs seed CWC ─────────────────────────────────────────────────
  final allCwcStations = cwcAsync.asData?.value ?? const <CwcStation>[];
  final cwcLive   = allCwcStations
      .where((s) => !s.isFromSeed && !_isBirpur(s.site)).toList();
  final cwcSeed   = allCwcStations
      .where((s) =>  s.isFromSeed && !_isBirpur(s.site)).toList();

  final cwcLiveRS = cwcLive.map(_cwcToRiverStation).toList();
  final cwcSeedRS = cwcSeed.map(_cwcToRiverStation).toList();
  final cwcLiveNames = { for (final s in cwcLiveRS) _norm(s.station) };

  // DataFetch: exclude LiveEngine + Birpur + seed-CWC names
  final dfStations = ref.watch(dataFetchStationsProvider)
      .where((s) =>
          !_isBirpur(s.station) &&
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&   // ★ NEW
          !cwcLiveNames.any((n) => _sameStation(n, s.station)))
      .toList();
  final dfNames = { for (final s in dfStations) _norm(s.station) };

  // WRD: exclude LiveEngine + Birpur + already-covered stations
  final wrdFiltered = wrdList
      .where((s) =>
          !_isBirpur(s.station) &&
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&   // ★ NEW
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)))
      .toList();
  final wrdNames = { for (final s in wrdFiltered) _norm(s.station) };

  // Seed CWC: last resort
  final cwcSeedFiltered = cwcSeedRS
      .where((s) =>
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&   // ★ NEW
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)) &&
          !wrdNames.any((n) => _sameStation(n, s.station)))
      .toList();

  // ── Final merge ──────────────────────────────────────────────────────────────
  final merged = [
    ...liveEngineRS,         // ★ Tier 0 — always on top
    ...cwcLiveRS,
    ...dfStations,
    ...wrdFiltered,
    ...cwcSeedFiltered,
    birpurStation,
  ];
  merged.sort((a, b) => b.riskScore.compareTo(a.riskScore));

  if (kDebugMode) {
    debugPrint(
      '[Merged v8] ${liveEngineRS.length} LiveEngine'
      ' + ${cwcLiveRS.length} CWC-live'
      ' + ${cwcSeedFiltered.length} CWC-seed'
      ' + ${dfStations.length} DataFetch'
      ' + ${wrdFiltered.length} WRD'
      ' + 1 Birpur'
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
