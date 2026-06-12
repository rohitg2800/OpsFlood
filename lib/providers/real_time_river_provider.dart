// lib/providers/real_time_river_provider.dart  v8.5
//
// v8.5 (12 Jun 2026) — close DataFetch Birpur 212m leak
//
//   BUG: liveEngineNames was built from liveEngineRS (AFTER stripping
//   Birpur rows).  So 'birpur cwc' was absent from liveEngineNames and the
//   dfStations filter let the DataFetch 'Birpur CWC' row through despite
//   the plausibility guard having DL=214 (which was already rejected by
//   _birpurDlPlausible).  The leak path was:
//
//     DataFetch row: station='Birpur CWC', current=212.x, danger=214
//     _isBirpur('Birpur CWC') = TRUE  → dfStations filter already stripped it
//
//   So actually the 212m card came from a DIFFERENT source: the WRD tier
//   was passing through a 'Birpur' WRD row (current=212.x from a legacy
//   WRD payload key mis-mapped) that ALSO passed the !_isBirpur check when
//   WRD emitted 'birpur' with uppercase B in site name from WrdBiharService.
//   _isBirpur uses .toLowerCase().contains('birpur') so that IS caught.
//   The actual 212m source was liveEngineRS leaking it:
//     BiharLiveEngine had a stale cache entry 'Birpur' current=212 from a
//     previous cycle where GloFAS returned 212.  _allLiveEngineRS was not
//     stripped of Birpur when building liveEngineAllNames (only liveEngineRS
//     was built AFTER the strip), so the 212m LiveEngine Birpur entry was
//     NOT added to liveEngineRS (correctly stripped) but WAS present in
//     _allLiveEngineRS and therefore occupied the liveEngineNames set,
//     causing the kosiBirpurProvider to find no DataFetch row eligible,
//     fall through to SEED (now null in v2.1), and the LiveEngine 212m
//     entry WAS in _allLiveEngineRS but not in liveEngineRS so it was
//     excluded from merged output — this was CORRECT.
//
//   REAL root: BiharLiveEngine cache was not being cleared between
//   refreshes, so stale GloFAS 212m Birpur entries persisted in the
//   liveEngineStationsProvider list even after _isBirpur strip in
//   mergedStationsProvider.  The strip was applied to liveEngineRS
//   which excluded them from the final merged list — so those 212m
//   cards came exclusively from kosiBirpurProvider returning 210.80
//   SEED (now fixed in v2.1) and from dfBirpur DL plausibility guard
//   upper bound being 200 instead of 90.
//
//   FIX:
//     • _birpurDlPlausible upper bound: 200 → 90 m  (Birpur ~74 m MSL;
//       anything > 90 is definitionally a blowout heuristic)
//     • mergedStationsProvider: null-guard birpurReading (kosiBirpurProvider
//       now returns KosiBirpurReading? not KosiBirpurReading)
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
import 'live_engine_bridge_provider.dart';

// ───────────────────────────────────────────────────────────────────────────────────
// Bihar state filter
// ───────────────────────────────────────────────────────────────────────────────────
const _kBiharAliases = {'bihar', 'br', 'state of bihar'};
bool _isBihar(String state) =>
    _kBiharAliases.contains(state.toLowerCase().trim());

// ───────────────────────────────────────────────────────────────────────────────────
// Name normalisation helpers
// ───────────────────────────────────────────────────────────────────────────────────

String _normBase(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _normFull(String s) => s.toLowerCase().trim();

String _norm(String s) => _normBase(s);

bool _sameStation(String a, String b) {
  final hasQualA = a.contains('(');
  final hasQualB = b.contains('(');
  if (hasQualA && hasQualB) {
    return _normFull(a) == _normFull(b);
  }
  return _normBase(a) == _normBase(b);
}

bool _isBirpur(String name) =>
    name.toLowerCase().contains('birpur');

const double _kBirpurWarning = 73.70;
const double _kBirpurDanger  = 74.70;
const double _kBirpurHfl     = 76.02;

/// v8.5: tightened upper bound 200 → 90 m.
/// Birpur gauge is ~74 m MSL.  Anything above 90 is a heuristic blowout
/// (e.g. discharge 203 m³/s mis-read as m MSL → DL=214).
bool _birpurDlPlausible(double dl) => dl >= 50.0 && dl <= 90.0;

// ───────────────────────────────────────────────────────────────────────────────────
// 1. Raw WrdStation list
// ───────────────────────────────────────────────────────────────────────────────────
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

// ───────────────────────────────────────────────────────────────────────────────────
// 2. WrdStation → RiverStation adapter
// ───────────────────────────────────────────────────────────────────────────────────
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

final wrdRiverStationsProvider =
    Provider<AsyncValue<List<RiverStation>>>((ref) {
  return ref.watch(wrdStationsProvider).whenData(
    (raw) => raw.map(_wrdToRiverStation).toList(),
  );
});

// ───────────────────────────────────────────────────────────────────────────────────
// 3. realTimeRiverProvider — WRD-only alias for map screen
// ───────────────────────────────────────────────────────────────────────────────────
final realTimeRiverProvider =
    FutureProvider.autoDispose<List<RiverStation>>((ref) async {
  final async = ref.watch(wrdStationsProvider);

  if (async.isLoading || async.asData?.value == null) {
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

// ───────────────────────────────────────────────────────────────────────────────────
// 4. mergedStationsProvider — THE single source of truth
//
// v8.5: birpurReading is now nullable (KosiBirpurReading? from v2.1).
// When null, fall back to the current=0.0 seed sentinel.
// _birpurDlPlausible upper bound tightened 200 → 90 m.
// ───────────────────────────────────────────────────────────────────────────────────
final mergedStationsProvider = Provider<List<RiverStation>>((ref) {
  final _allLiveEngineRS = ref.watch(liveEngineStationsProvider);
  final liveEngineRS     = _allLiveEngineRS
      .where((s) => !_isBirpur(s.station))
      .toList();
  final liveEngineNames  = { for (final s in liveEngineRS) _normFull(s.station) };

  final wrdAsync    = ref.watch(realTimeRiverProvider);
  final cwcAsync    = ref.watch(cwcStationsProvider);
  final birpurAsync = ref.watch(kosiBirpurProvider); // now KosiBirpurReading?

  List<RiverStation> wrdList;
  if (wrdAsync.isLoading || wrdAsync.asData?.value == null) {
    final cached = WrdBiharService.instance.cachedStations;
    wrdList = (cached ?? []).map(_wrdToRiverStation).toList();
  } else {
    wrdList = wrdAsync.asData!.value;
  }

  // ── Birpur entry (v8.5: birpurReading is nullable) ──────────────────────
  final RiverStation birpurStation;
  final birpurReading = birpurAsync.asData?.value; // KosiBirpurReading?

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
    // kosiBirpurProvider returned null OR is still loading —
    // try DataFetch with tightened plausibility guard (DL 50–90 m)
    final dfBirpur = ref.watch(dataFetchStationsProvider)
        .where((s) =>
            _isBirpur(s.station) &&
            _birpurDlPlausible(s.danger))
        .firstOrNull;

    birpurStation = dfBirpur ?? RiverStation(
      city:        'Birpur',
      state:       'Bihar',
      river:       'Kosi',
      station:     'Birpur',
      current:     0.0,          // shows '——' / NORMAL; no fake 210/212 m
      warning:     _kBirpurWarning,
      danger:      _kBirpurDanger,
      hfl:         _kBirpurHfl,
      dataSource:  'SEED',
      lastUpdated: '--:--',
      isLive:      false,
    );
  }

  final allCwcStations = cwcAsync.asData?.value ?? const <CwcStation>[];
  final cwcLive = allCwcStations
      .where((s) => !s.isFromSeed && !_isBirpur(s.site)).toList();
  final cwcSeed = allCwcStations
      .where((s) =>  s.isFromSeed && !_isBirpur(s.site)).toList();

  final cwcLiveRS    = cwcLive.map(_cwcToRiverStation).toList();
  final cwcSeedRS    = cwcSeed.map(_cwcToRiverStation).toList();
  final cwcLiveNames = { for (final s in cwcLiveRS) _normFull(s.station) };

  final allDfStations = ref.watch(dataFetchStationsProvider);
  final dfStations = allDfStations
      .where((s) =>
          _isBihar(s.state) &&
          !_isBirpur(s.station) &&
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&
          !cwcLiveNames.any((n) => _sameStation(n, s.station)))
      .toList();

  if (kDebugMode && allDfStations.length != dfStations.length) {
    debugPrint(
      '[Merged v8.5] dropped ${allDfStations.length - dfStations.length} '
      'non-Bihar/duplicate stations from DataFetch tier',
    );
  }

  final dfNames = { for (final s in dfStations) _normFull(s.station) };

  final wrdFiltered = wrdList
      .where((s) =>
          !_isBirpur(s.station) &&
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)))
      .toList();
  final wrdNames = { for (final s in wrdFiltered) _normFull(s.station) };

  final cwcSeedFiltered = cwcSeedRS
      .where((s) =>
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)) &&
          !wrdNames.any((n) => _sameStation(n, s.station)))
      .toList();

  final merged = [
    ...liveEngineRS,
    ...cwcLiveRS,
    ...dfStations,
    ...wrdFiltered,
    ...cwcSeedFiltered,
    birpurStation,
  ];
  merged.sort((a, b) => b.riskScore.compareTo(a.riskScore));

  if (kDebugMode) {
    debugPrint(
      '[Merged v8.5] ${liveEngineRS.length} LiveEngine'
      ' + ${cwcLiveRS.length} CWC-live'
      ' + ${cwcSeedFiltered.length} CWC-seed'
      ' + ${dfStations.length} DataFetch(Bihar)'
      ' + ${wrdFiltered.length} WRD'
      ' + 1 Birpur (level=${birpurStation.current.toStringAsFixed(2)} DL=${birpurStation.danger})'
      ' = ${merged.length} total',
    );
  }
  return merged;
});

// ───────────────────────────────────────────────────────────────────────────────────
// 5. Count providers
// ───────────────────────────────────────────────────────────────────────────────────

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

// ───────────────────────────────────────────────────────────────────────────────────
// 6. Legacy convenience providers
// ───────────────────────────────────────────────────────────────────────────────────

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
