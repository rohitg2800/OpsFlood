// lib/providers/map_live_index_provider.dart  v1.0
//
// Single source of truth for the Bihar River Map screen.
//
// PROBLEM (v5.3 and earlier):
//   BiharRiverMapScreen watched biharLiveProvider (BiharLiveEngine only).
//   CWC stations, GloFAS stations, and any station not in BiharLiveEngine
//   showed as grey "NO DATA" pins even when mergedStationsProvider had
//   live readings for them.  Birpur in particular showed 0 m / grey
//   because BiharLiveEngine does not carry the Birpur CWC gauge.
//
// SOLUTION:
//   mapLiveIndexProvider builds Map<String, MapStationData> from
//   mergedStationsProvider (all tiers, deduped) as the authoritative
//   level/threshold base, then enriches with optional fields from
//   biharLiveProvider (diff24h, trend, discharge, rainfall) where names
//   fuzzy-match.  Birpur is force-patched from kosiBirpurProvider.
//
// ALSO EXPORTS:
//   mergedSourceStatusProvider — Problem 4 fix.
//   sourceStatusProvider in data_fetch_provider.dart only carries
//   CWC + GloFAS rows.  mergedSourceStatusProvider adds a synthetic WRD
//   row so AlertsScreen _StatusBar shows all three data tiers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../services/alert_engine.dart'; // SourceStatus
import 'bihar_live_provider.dart';
import 'data_fetch_provider.dart';
import 'kosi_birpur_provider.dart';
import 'real_time_river_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MapStationData
//
// Superset of BiharStationData used by BiharRiverMapScreen v5.4.
// Level/threshold fields come from RiverStation (mergedStationsProvider)
// so they always reflect the v4.2-corrected DL/WL/HFL values.
// Enrichment fields (diff24h, trend, discharge, rainfall) are optional —
// populated when BiharLiveEngine has a matching entry.
// ══════════════════════════════════════════════════════════════════════════════

class MapStationData {
  // ── Core (always present, from mergedStationsProvider) ────────────────────
  final String  city;
  final String  river;
  final String  district;
  final String  state;
  final double  currentLevel;   // 0.0 when SEED-suppressed
  final double  dangerLevel;
  final double  warningLevel;
  final double  hfl;
  final String  riskLabel;      // 'CRITICAL' / 'SEVERE' / 'HIGH' / 'NORMAL'
  final String  source;         // dataSource tag from RiverStation
  final String  fetchedAt;      // 'HH:mm' string
  final bool    isLive;

  // ── Enrichment (optional, from BiharLiveEngine) ────────────────────────────
  final double? diff24h;
  final double? forecast24h;
  final String  trend;          // '↑' / '↓' / '→'
  final double? discharge;      // m³/s
  final double? dischargeMean;
  final double? rainfall24h;    // mm

  const MapStationData({
    required this.city,
    required this.river,
    required this.district,
    required this.state,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.hfl,
    required this.riskLabel,
    required this.source,
    required this.fetchedAt,
    required this.isLive,
    this.diff24h,
    this.forecast24h,
    this.trend = '→',
    this.discharge,
    this.dischargeMean,
    this.rainfall24h,
  });

  // ── Convenience booleans (same contract as BiharStationData) ──────────────
  bool get isCritical => riskLabel == 'CRITICAL';
  bool get isSevere   => riskLabel == 'SEVERE';
  bool get isWarning  =>
      riskLabel == 'HIGH' || riskLabel == 'WARNING' || riskLabel == 'MODERATE';
  bool get isSafe     => riskLabel == 'LOW' || riskLabel == 'NORMAL';
  bool get hasNoData  => !isLive || currentLevel <= 0.0;
}

// ── Name normalisation (mirrors map screen _norm) ─────────────────────────────
String _normKey(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[()_\-]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// ── RiskLabel from DangerClass ────────────────────────────────────────────────
String _riskLabelFromDangerClass(DangerClass dc) {
  switch (dc) {
    case DangerClass.extreme:     return 'CRITICAL';
    case DangerClass.severe:      return 'SEVERE';
    case DangerClass.aboveNormal: return 'HIGH';
    default:                      return 'NORMAL';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// mapLiveIndexProvider
// ══════════════════════════════════════════════════════════════════════════════

final mapLiveIndexProvider =
    Provider<Map<String, MapStationData>>((ref) {
  final merged       = ref.watch(mergedStationsProvider);
  final biharAsync   = ref.watch(biharLiveProvider);
  final birpurAsync  = ref.watch(kosiBirpurProvider);

  // ── Build enrichment lookup from BiharLiveEngine ─────────────────────────
  final Map<String, BiharStationData> liveEnrich = {};
  final liveState = biharAsync.asData?.value;
  if (liveState != null) {
    for (final s in liveState.stations) {
      liveEnrich[_normKey(s.city)] = s;
    }
  }

  // ── Birpur enrichment from kosiBirpurProvider ────────────────────────────
  final birpurReading = birpurAsync.asData?.value;

  // ── Build index from mergedStationsProvider ───────────────────────────────
  final index = <String, MapStationData>{};

  for (final s in merged) {
    final key     = _normKey(s.station);
    final enrich  = liveEnrich[key];

    // For Birpur, prefer kosiBirpurProvider for discharge/trend
    final isBirpur = s.station.toLowerCase().contains('birpur');

    final diff24h      = isBirpur ? null                 : enrich?.diff24h;
    final forecast24h  = isBirpur ? null                 : enrich?.forecast24h;
    final trend        = isBirpur
        ? (birpurReading?.trend ?? enrich?.trend ?? '→')
        : (enrich?.trend ?? '→');
    final discharge    = isBirpur
        ? (birpurReading?.dischargeCumecs ?? enrich?.discharge)
        : enrich?.discharge;
    final dischargeMean = enrich?.dischargeMean;
    final rainfall24h  = enrich?.rainfall24h;

    index[key] = MapStationData(
      city:          s.station,
      river:         s.river,
      district:      '', // BiharGauge has district — resolved in screen
      state:         s.state,
      currentLevel:  s.current,
      dangerLevel:   s.danger,
      warningLevel:  s.warning,
      hfl:           s.hfl,
      riskLabel:     _riskLabelFromDangerClass(s.dangerClass),
      source:        s.dataSource ?? s.isLive ? 'LIVE' : 'SEED',
      fetchedAt:     s.lastUpdated ?? '--:--',
      isLive:        s.isLive && s.current > 0.0,
      diff24h:       diff24h,
      forecast24h:   forecast24h,
      trend:         trend,
      discharge:     discharge,
      dischargeMean: dischargeMean,
      rainfall24h:   rainfall24h,
    );
  }

  return index;
});

// ══════════════════════════════════════════════════════════════════════════════
// mergedSourceStatusProvider  (Problem 4 fix)
//
// sourceStatusProvider (data_fetch_provider.dart) only contains rows from
// DataFetchEngine (CWC + GloFAS).  WRD Bihar is never in it, so the
// AlertsScreen _StatusBar showed an incomplete source picture.
//
// This provider adds a synthetic WRD row and re-exports the combined list.
// AlertsScreen should watch mergedSourceStatusProvider instead of
// sourceStatusProvider.
// ══════════════════════════════════════════════════════════════════════════════

final mergedSourceStatusProvider = Provider<List<SourceStatus>>((ref) {
  // CWC + GloFAS rows from DataFetchEngine
  final dfSources = ref.watch(sourceStatusProvider);

  // WRD tier
  final wrdAsync    = ref.watch(wrdStationsProvider);
  final wrdStations = wrdAsync.asData?.value ?? [];
  final wrdLive     = wrdStations.where((s) => s.source == 'WRD_BIHAR_LIVE').length;
  final wrdHealthy  = !wrdAsync.hasError && wrdStations.isNotEmpty;

  final wrdRow = SourceStatus(
    name:         'WRD Bihar',
    healthy:      wrdHealthy,
    stationCount: wrdLive,
    isFromSeed:   wrdLive == 0,
  );

  // Deduplicate: drop any existing 'wrd' row DataFetchEngine may have added
  final filtered = dfSources
      .where((s) => !s.name.toLowerCase().contains('wrd'))
      .toList();

  return [wrdRow, ...filtered];
});
