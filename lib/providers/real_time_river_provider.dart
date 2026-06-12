// lib/providers/real_time_river_provider.dart  v8.2
//
// v8.2 fix (P0 #3):
//   • _sameStation() 6-char prefix fallback REMOVED.
//     Root cause: _norm() strips parentheses, so 'Kamtaul (Bagmati)' and
//     'Kamtaul (Kamla)' both normalised to 'kamtaul', then the 6-char
//     prefix 'kamtau' matched — one of each pair was silently dropped.
//   • New helpers:
//       _normBase(s)  — strips parens (old _norm behaviour, used for
//                         threshold/Bihar-gate logic)
//       _normFull(s)  — keeps the '(River)' qualifier, lowercases only
//   • _sameStation(a, b):
//       Both have qualifier → compare _normFull (qualified names are
//       distinct across rivers).
//       Otherwise → _normBase exact match only (no prefix shortcut).
//   • liveEngineNames Set and all dedup filters now key on _normFull
//     so BiharLiveEngine's qualified names don't alias plain WRD names.
//
// v8.1 fix:
//   • Bihar-only guard added to dfStations filter.
//
// v8.0: liveEngineStationsProvider injected as TOP priority tier.
//
// Priority ladder (highest → lowest):
//   ✳ LiveEngine  (BiharLiveEngine feed, updated every 15 min)
//   ✲ live-CWC    (CWC FFEM BEFIQR scraper)
//   ✱ DataFetch   (backend API) ← Bihar-filtered ★ v8.1
//   ▕ WRD Bihar
//   ▔ seed-CWC    (static fallback)
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
import 'live_engine_bridge_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bihar state filter
// ─────────────────────────────────────────────────────────────────────────────
const _kBiharAliases = {'bihar', 'br', 'state of bihar'};
bool _isBihar(String state) =>
    _kBiharAliases.contains(state.toLowerCase().trim());

// ─────────────────────────────────────────────────────────────────────────────
// Name normalisation helpers
// ─────────────────────────────────────────────────────────────────────────────

/// _normBase: strips parenthesised qualifiers, lowercases, collapses
/// whitespace.  Used for Bihar-gate logic and threshold lookups.
/// Example: 'Kamtaul (Bagmati)' → 'kamtaul'
String _normBase(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// _normFull: keeps the parenthesised qualifier, lowercases only.
/// Used for dedup key sets so disambiguated names stay distinct.
/// Example: 'Kamtaul (Bagmati)' → 'kamtaul (bagmati)'
String _normFull(String s) => s.toLowerCase().trim();

/// _norm kept for any callers that imported it indirectly (alias of _normBase).
String _norm(String s) => _normBase(s);

/// Returns true when two station names refer to the same physical gauge.
///
/// Rules (in order):
///   1. If BOTH names contain a '(' qualifier, compare _normFull.
///      'kamtaul (bagmati)' ≠ 'kamtaul (kamla)' → false  ✓
///      'kamtaul (bagmati)' == 'kamtaul (bagmati)' → true  ✓
///   2. Otherwise compare _normBase exact match.
///      'kamtaul' == 'kamtaul' → true  (legacy feed, no qualifier)  ✓
///      'dighaghat' == 'dighaghat' → true  ✓
///      'dighaghat' == 'gandhighat' → false  ✓
///
/// The 6-char prefix fallback has been REMOVED — it was the source of
/// false-positive dedup that silently dropped one station from every
/// disambiguated pair (Kamtaul, Dhengraghat, …).
bool _sameStation(String a, String b) {
  final hasQualA = a.contains('(');
  final hasQualB = b.contains('(');
  if (hasQualA && hasQualB) {
    // Both have river qualifiers — must match including the qualifier.
    return _normFull(a) == _normFull(b);
  }
  // At least one name has no qualifier — fall back to base-name exact match.
  return _normBase(a) == _normBase(b);
}

bool _isBirpur(String name) =>
    name.toLowerCase().contains('birpur');

const double _kBirpurWarning = 73.70;  // WRD-verified Jun 2026
const double _kBirpurDanger  = 74.70;
const double _kBirpurHfl     = 76.02;

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
// Priority ladder (v8.2):
//   ✳ LiveEngine  (BiharLiveEngine broadcast, highest fidelity)
//   ✲ live-CWC   (CWC FFEM BEFIQR scraper)
//   ✱ DataFetch  (backend API) ← Bihar-only filter ★ v8.1
//   ▕ WRD Bihar
//   ▔ seed-CWC   (static fallback, lowest)
//   Birpur always explicit via kosiBirpurProvider
// ─────────────────────────────────────────────────────────────────────────────
final mergedStationsProvider = Provider<List<RiverStation>>((ref) {
  // Tier 0 — BiharLiveEngine stations (real-time, highest priority)
  // Key set uses _normFull so 'kamtaul (bagmati)' and 'kamtaul (kamla)'
  // are stored as DISTINCT keys.
  final liveEngineRS    = ref.watch(liveEngineStationsProvider);
  final liveEngineNames = { for (final s in liveEngineRS) _normFull(s.station) };

  final wrdAsync    = ref.watch(realTimeRiverProvider);
  final cwcAsync    = ref.watch(cwcStationsProvider);
  final birpurAsync = ref.watch(kosiBirpurProvider);

  // Never return [] on cold-start — use WRD cache
  List<RiverStation> wrdList;
  if (wrdAsync.isLoading || wrdAsync.asData?.value == null) {
    final cached = WrdBiharService.instance.cachedStations;
    wrdList = (cached ?? []).map(_wrdToRiverStation).toList();
  } else {
    wrdList = wrdAsync.asData!.value;
  }

  // Build Birpur entry from kosiBirpurProvider
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
      dataSource:  'SEED',
      lastUpdated: '00:00',
      isLive: false,
    );
  }

  // Live vs seed CWC
  final allCwcStations = cwcAsync.asData?.value ?? const <CwcStation>[];
  final cwcLive = allCwcStations
      .where((s) => !s.isFromSeed && !_isBirpur(s.site)).toList();
  final cwcSeed = allCwcStations
      .where((s) =>  s.isFromSeed && !_isBirpur(s.site)).toList();

  final cwcLiveRS    = cwcLive.map(_cwcToRiverStation).toList();
  final cwcSeedRS    = cwcSeed.map(_cwcToRiverStation).toList();
  final cwcLiveNames = { for (final s in cwcLiveRS) _normFull(s.station) };

  // DataFetch: Bihar-only + exclude LiveEngine + Birpur + live-CWC
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
      '[Merged v8.2] dropped ${allDfStations.length - dfStations.length} '
      'non-Bihar/duplicate stations from DataFetch tier',
    );
  }

  final dfNames = { for (final s in dfStations) _normFull(s.station) };

  // WRD: exclude LiveEngine + Birpur + already-covered stations
  final wrdFiltered = wrdList
      .where((s) =>
          !_isBirpur(s.station) &&
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)))
      .toList();
  final wrdNames = { for (final s in wrdFiltered) _normFull(s.station) };

  // Seed CWC: last resort
  final cwcSeedFiltered = cwcSeedRS
      .where((s) =>
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)) &&
          !wrdNames.any((n) => _sameStation(n, s.station)))
      .toList();

  // Final merge
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
      '[Merged v8.2] ${liveEngineRS.length} LiveEngine'
      ' + ${cwcLiveRS.length} CWC-live'
      ' + ${cwcSeedFiltered.length} CWC-seed'
      ' + ${dfStations.length} DataFetch(Bihar)'
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
