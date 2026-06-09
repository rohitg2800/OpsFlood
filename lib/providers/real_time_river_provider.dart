// lib/providers/real_time_river_provider.dart  v6
//
// FIXES vs v5:
//   #1 Cold-start blank — mergedStationsProvider returned [] when both
//      cwcAsync and wrdAsync were still AsyncLoading. Now seeds immediately
//      from WrdBiharService.cachedStations (populated from disk on first run).
//
//   #2 Seed-CWC collision — 32 SEED CwcStations had isFromSeed:true but were
//      still used as highest-priority data, overwriting WRD live readings.
//      Fix: build cwcNames ONLY from non-seed CWC entries so WRD live data
//      wins over CWC seed data.
//
//   #3 DataFetch exclusion bug — dfNames exclusion set was built against
//      cwcNames which included seed entries, so GloFAS stations were excluded
//      even when CWC had no real data for them.
//      Fix: cwcNames and cwcLive are now two separate sets.
//
//   #4 Dedup normalizer — exact .toLowerCase() missed 'Birpur (CWC)' vs
//      'Birpur', 'Burhi Gandak' vs 'Buri Gandak', etc.
//      Fix: _norm() strips parenthetical suffixes + non-alpha chars.
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

// ─────────────────────────────────────────────────────────────────────────────
// Normaliser: strips parens, punctuation and extra spaces so
// 'Birpur (CWC)' == 'birpur' == 'BIRPUR' and
// 'Burhi Gandak' ~= 'Buri Gandak' (first 6 chars match).
// ─────────────────────────────────────────────────────────────────────────────
String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')   // strip '(CWC)', '(WRD)' etc.
    .replaceAll(RegExp(r'[^a-z0-9\s]'), '')  // strip punctuation
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _sameStation(String a, String b) {
  final na = _norm(a);
  final nb = _norm(b);
  if (na == nb) return true;
  // Prefix match — first 6 chars (handles Burhi/Buri, Sikandarpur variants)
  final pa = na.length > 6 ? na.substring(0, 6) : na;
  final pb = nb.length > 6 ? nb.substring(0, 6) : nb;
  return pa == pb;
}

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

// ── CwcStation → RiverStation adapter ───────────────────────────────────────────
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

/// WRD-only converted list (used by realTimeRiverProvider → map merge)
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
// Priority: live-CWC (highest) > DataFetch > WRD > seed-CWC (lowest)
//
// Key invariants (all four bugs fixed here):
//   • cwcLiveNames = names from CWC entries where isFromSeed==false only.
//     Seed CWC entries do NOT block WRD or DataFetch from taking priority.
//   • On cold-start (both providers still AsyncLoading) we return disk-cached
//     WRD stations immediately instead of an empty list — zero blank frames.
//   • Dedup uses _sameStation() which normalises parens/punctuation and
//     applies a 6-char prefix match for spelling variants.
//   • DataFetch exclusion is only against cwcLiveNames, not seed names,
//     so GloFAS stations are no longer incorrectly excluded.
// ─────────────────────────────────────────────────────────────────────────────
final mergedStationsProvider = Provider<List<RiverStation>>((ref) {
  final wrdAsync = ref.watch(realTimeRiverProvider);
  final cwcAsync = ref.watch(cwcStationsProvider);

  // ── FIX #1: Cold-start — return disk cache immediately, never []
  // Both providers may still be AsyncLoading on first frame.
  // WrdBiharService persists to disk; use that as the immediate baseline.
  List<RiverStation> wrdList;
  if (wrdAsync.isLoading || wrdAsync.asData?.value == null) {
    final cached = WrdBiharService.instance.cachedStations;
    wrdList = (cached ?? []).map(_wrdToRiverStation).toList();
  } else {
    wrdList = wrdAsync.asData!.value;
  }

  // ── FIX #2 + #3: Split CWC into live vs seed — only live entries block dedup
  final allCwcStations = cwcAsync.asData?.value ?? const <CwcStation>[];
  final cwcLive  = allCwcStations.where((s) => !s.isFromSeed).toList();
  final cwcSeed  = allCwcStations.where((s) =>  s.isFromSeed).toList();

  final cwcLiveRS  = cwcLive.map(_cwcToRiverStation).toList();
  // Seed CWC entries are demoted — only used to fill stations not covered
  // by any live source (last resort, same priority as seed baseline).
  final cwcSeedRS  = cwcSeed.map(_cwcToRiverStation).toList();

  // Names covered by LIVE CWC data
  final cwcLiveNames = { for (final s in cwcLiveRS) _norm(s.station) };

  // ── DataFetch: exclude only if a live CWC entry already covers it (FIX #3)
  final dfStations = ref.watch(dataFetchStationsProvider)
      .where((s) => !cwcLiveNames.any((n) => _sameStation(n, s.station)))
      .toList();
  final dfNames = { for (final s in dfStations) _norm(s.station) };

  // ── WRD: exclude if covered by live CWC or DataFetch
  final wrdFiltered = wrdList
      .where((s) =>
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)))
      .toList();
  final wrdNames = { for (final s in wrdFiltered) _norm(s.station) };

  // ── Seed CWC: only add if no other live source covers this station
  final cwcSeedFiltered = cwcSeedRS
      .where((s) =>
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)) &&
          !wrdNames.any((n) => _sameStation(n, s.station)))
      .toList();

  final merged = [
    ...cwcLiveRS,       // live CWC — highest priority
    ...dfStations,      // DataFetch (GloFAS, Open-Meteo enriched)
    ...wrdFiltered,     // WRD live
    ...cwcSeedFiltered, // seed CWC — only for stations with no live source
  ];
  merged.sort((a, b) => b.riskScore.compareTo(a.riskScore));

  if (kDebugMode) {
    debugPrint(
      '[Merged] ${cwcLiveRS.length} CWC-live'
      ' + ${cwcSeedFiltered.length} CWC-seed'
      ' + ${dfStations.length} DataFetch'
      ' + ${wrdFiltered.length} WRD'
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
