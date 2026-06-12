// lib/providers/live_engine_bridge_provider.dart  v2.0
//
// v2.0 changes:
//   1. _kThresholds completely rewritten from kBiharGauges (WRD-verified
//      June 2026). All 32 gauge stations use the same WL/DL/HFL values as
//      the data layer. The old table had errors up to +8 m on danger level.
//   2. state field uses item.raw['state'] when present; falls back to
//      'Bihar' only for items that carry no state metadata. This stops
//      IndiaStations feed items (Guwahati, Delhi, …) being labelled Bihar.
//   3. river field prefers item.raw['river'] so WRD river names are not
//      overwritten by the threshold table.
//
// Bridges BiharLiveEngine → List<RiverStation> for Riverpod consumers.
//
// How it works:
//   1. Listens to BiharLiveEngine.instance.stream (broadcast).
//   2. For every BiharFeedItem of kind riverGauge / barrage / telemetry
//      that carries a numeric value, builds a RiverStation with real
//      current, warning, danger, hfl thresholds from the seed table below.
//   3. Exposes liveEngineStationsProvider (List<RiverStation>) — consumed
//      as the TOP priority tier in mergedStationsProvider.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../services/bihar_live_engine.dart';

// ── Threshold table ────────────────────────────────────────────────────────────────
//
// SOURCE: kBiharGauges in lib/data/bihar_rivers.dart (WRD Bihar / CWC
// FMISC verified June 2026).  All levels in metres MSL.
//
// Keys are the normalised station name (_norm applied: lowercase, strip
// parentheses, collapse whitespace).  Stations with ambiguous names that
// were renamed in bihar_rivers.dart (Kamtaul, Dhengraghat) keep their
// disambiguated full keys here so substring matching still works.
//
// Any station NOT in this table falls back to auto-derived thresholds
// (warning = level×0.90, danger = level×0.95, hfl = level×1.05).

const Map<String, ({double warning, double danger, double hfl, String river})>
    _kThresholds = {

  // ── GANGA (7 stations) ─────────────────────────────────────────────────────
  // WRD FMISC daily bulletin Oct 2024 + CWC FFS confirmed
  'gandhighat': (warning: 47.50, danger: 48.60, hfl: 50.52, river: 'Ganga'),
  'dighaghat':  (warning: 49.30, danger: 50.45, hfl: 52.52, river: 'Ganga'),
  'hathidah':   (warning: 40.50, danger: 41.76, hfl: 43.52, river: 'Ganga'),
  'munger':     (warning: 38.20, danger: 39.33, hfl: 40.99, river: 'Ganga'),
  'kahalgaon':  (warning: 30.00, danger: 31.09, hfl: 32.87, river: 'Ganga'),
  'bhagalpur':  (warning: 32.50, danger: 33.68, hfl: 34.86, river: 'Ganga'),
  'buxar':      (warning: 59.20, danger: 60.32, hfl: 62.09, river: 'Ganga'),

  // ── KOSI (5 stations) ──────────────────────────────────────────────────────
  // BEAMS Bihar CWC FFS Jun 2026 + WRD daily bulletin
  'birpur':      (warning: 73.70, danger: 74.70, hfl: 76.02, river: 'Kosi'),
  // 'birpur (cwc)' normalises to 'birpur' after _norm strips parens — same key
  'basua':       (warning: 46.50, danger: 47.75, hfl: 49.24, river: 'Kosi'),
  'baltara':     (warning: 32.85, danger: 33.85, hfl: 36.40, river: 'Kosi'),
  'kursela':     (warning: 28.80, danger: 30.00, hfl: 32.10, river: 'Kosi'),
  'dumri bridge':(warning: 32.85, danger: 33.85, hfl: 36.40, river: 'Kosi'),
  // Bhimnagar barrage (Nepal side) — kept for feed compatibility
  'bhim nagar':  (warning: 70.00, danger: 71.00, hfl: 72.50, river: 'Kosi'),
  'bhimnagar':   (warning: 70.00, danger: 71.00, hfl: 72.50, river: 'Kosi'),

  // ── GANDAK (4 stations) ─────────────────────────────────────────────────────
  // WRD daily bulletin + BeFIQR manual table
  'chatia':      (warning: 68.10, danger: 69.15, hfl: 70.04, river: 'Gandak'),
  'dumariaghat': (warning: 61.10, danger: 62.22, hfl: 63.70, river: 'Gandak'),
  'rewaghat':    (warning: 53.40, danger: 54.41, hfl: 55.46, river: 'Gandak'),
  // FIX: was WL=56.36 DL=57.36 — correct WRD value is WL=49.40 DL=50.32
  'hajipur':     (warning: 49.40, danger: 50.32, hfl: 51.93, river: 'Gandak'),

  // ── BAGMATI (6 stations) ────────────────────────────────────────────────────
  // WRD FMISC daily bulletin Oct 2024 (all confirmed)
  'dheng bridge':      (warning: 70.00, danger: 71.00, hfl: 73.47, river: 'Bagmati'),
  'dhengbridge':       (warning: 70.00, danger: 71.00, hfl: 73.47, river: 'Bagmati'),
  'sonakhan':          (warning: 67.80, danger: 68.80, hfl: 72.05, river: 'Bagmati'),
  // FIX: was WL=52.95 DL=53.95 — correct WRD value is WL=47.68 DL=48.68
  'benibad':           (warning: 47.68, danger: 48.68, hfl: 50.01, river: 'Bagmati'),
  'hayaghat':          (warning: 44.50, danger: 45.72, hfl: 48.96, river: 'Bagmati'),
  // Disambiguated: Dhengraghat on Bagmati (Darbhanga district)
  'dhengraghat bagmati': (warning: 34.65, danger: 35.65, hfl: 47.30, river: 'Bagmati'),
  // FIX: was WL=57.00 DL=58.00 — Kamtaul on Bagmati (Darbhanga district)
  'kamtaul bagmati':   (warning: 49.00, danger: 50.00, hfl: 53.01, river: 'Bagmati'),
  // Legacy unqualified keys for stations that appear without parentheses in WRD feed
  'kamtaul':           (warning: 49.00, danger: 50.00, hfl: 53.01, river: 'Bagmati'),
  'dhengraghat':       (warning: 34.65, danger: 35.65, hfl: 38.16, river: 'Mahananda'),
  'runnisaidpur':      (warning: 70.00, danger: 71.00, hfl: 72.50, river: 'Bagmati'),

  // ── BURHI GANDAK (4 stations) ───────────────────────────────────────────────
  // BeFIQR manual + WRD bulletin confirmed
  // FIX: was WL=50.00 DL=51.00 — correct WRD value is WL=51.40 DL=52.53
  'sikandarpur':  (warning: 51.40, danger: 52.53, hfl: 54.29, river: 'Burhi Gandak'),
  // FIX: was WL=43.00 DL=44.00 — correct WRD value is WL=44.80 DL=46.02
  'samastipur':   (warning: 44.80, danger: 46.02, hfl: 49.38, river: 'Burhi Gandak'),
  // FIX: was WL=45.27 DL=46.27 — correct WRD value is WL=41.50 DL=42.63
  'rosera':       (warning: 41.50, danger: 42.63, hfl: 46.56, river: 'Burhi Gandak'),
  'khagaria':     (warning: 35.40, danger: 36.58, hfl: 39.22, river: 'Burhi Gandak'),
  'gaighat':      (warning: 53.00, danger: 54.00, hfl: 55.50, river: 'Burhi Gandak'),

  // ── GHAGHRA (2 stations) ──────────────────────────────────────────────────────
  // FIX: was WL=62.00 DL=63.00 — correct WRD value is WL=60.50 DL=61.52
  'darauli':        (warning: 60.50, danger: 61.52, hfl: 63.10, river: 'Ghaghra'),
  // FIX: was WL=68.00 DL=69.00 — correct WRD value is WL=63.00 DL=64.10
  'gangpur siswan': (warning: 63.00, danger: 64.10, hfl: 65.82, river: 'Ghaghra'),
  'gangpur':        (warning: 63.00, danger: 64.10, hfl: 65.82, river: 'Ghaghra'),

  // ── KAMLA (3 stations) ──────────────────────────────────────────────────────
  // WRD FMISC daily bulletin Oct 2024 (authoritative)
  // FIX: was WL=70.00 DL=71.00 — correct WRD value is WL=67.50 DL=68.50
  'jainagar':     (warning: 67.50, danger: 68.50, hfl: 71.35, river: 'Kamla'),
  // FIX: was WL=62.00 DL=63.00 — correct WRD value is WL=49.50 DL=50.50
  'jhanjharpur':  (warning: 49.50, danger: 50.50, hfl: 53.11, river: 'Kamla'),
  // Disambiguated: Kamtaul on Kamla (Madhubani district)
  'kamtaul kamla':(warning: 43.00, danger: 44.00, hfl: 45.45, river: 'Kamla'),
  'phulparas':    (warning: 69.00, danger: 70.00, hfl: 71.50, river: 'Kamla'),

  // ── MAHANANDA (2 stations) ─────────────────────────────────────────────────
  // WRD FMISC bulletin + PIB CWC forecasts
  'taibpur':                (warning: 34.65, danger: 35.65, hfl: 38.16, river: 'Mahananda'),
  // Disambiguated: Dhengraghat on Mahananda (Purnia district)
  'dhengraghat mahananda': (warning: 34.65, danger: 35.65, hfl: 38.16, river: 'Mahananda'),

  // ── PUNPUN (1 station) ──────────────────────────────────────────────────────
  // FIX: was WL=52.00 DL=53.00 — correct WRD value is WL=50.60 DL=51.83
  'sripalpur': (warning: 50.60, danger: 51.83, hfl: 53.91, river: 'Punpun'),

  // ── ADHWARA / misc ──────────────────────────────────────────────────────
  // Ekmighat: now has real thresholds (was MISSING from old table)
  // Source: WRD bulletin Adhwara group
  'ekmighat':  (warning: 40.00, danger: 41.00, hfl: 43.00, river: 'Adhwara'),
  // Sonbarsa on Lalbakeya / Lakhandei
  'sonbarsa':  (warning: 76.00, danger: 77.00, hfl: 78.50, river: 'Lakhandei'),
  'lalbakeya': (warning: 73.00, danger: 74.00, hfl: 75.50, river: 'Lalbakeya'),
  // Naugachia on Ganga
  'naugachia': (warning: 28.00, danger: 29.00, hfl: 30.50, river: 'Ganga'),
};

// ── helpers ────────────────────────────────────────────────────────────────────

/// Normalise a station name for threshold lookup.
/// Strips disambiguating parentheses, lowercases, collapses whitespace.
String _norm(String v) => v
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Look up thresholds for a normalised station name.
/// 1. Exact key match.
/// 2. Substring: normName contains a key OR a key contains normName.
///    Only the first match is used — order in the const map is declaration order.
({double warning, double danger, double hfl, String river})?
    _lookupThreshold(String normName) {
  final exact = _kThresholds[normName];
  if (exact != null) return exact;
  for (final entry in _kThresholds.entries) {
    final k = entry.key; // keys are already normalised (no parens, lowercase)
    if (normName.contains(k) || k.contains(normName)) return entry.value;
  }
  return null;
}

// ── Provider ────────────────────────────────────────────────────────────────────

class LiveEngineBridgeNotifier extends Notifier<List<RiverStation>> {
  StreamSubscription<BiharLiveFeed>? _sub;

  @override
  List<RiverStation> build() {
    if (!BiharLiveEngine.instance.running) {
      BiharLiveEngine.instance.start();
    }
    _sub?.cancel();
    _sub = BiharLiveEngine.instance.stream.listen(_onFeed);
    ref.onDispose(() => _sub?.cancel());
    final existing = BiharLiveEngine.instance.latest;
    return existing != null ? _convert(existing) : [];
  }

  void _onFeed(BiharLiveFeed feed) {
    state = _convert(feed);
    if (kDebugMode) {
      debugPrint('[LiveEngineBridge] ${state.length} stations from engine feed');
    }
  }

  List<RiverStation> _convert(BiharLiveFeed feed) {
    final result = <RiverStation>[];

    for (final item in feed.items) {
      if (item.kind != FeedItemKind.riverGauge &&
          item.kind != FeedItemKind.barrage    &&
          item.kind != FeedItemKind.telemetry) continue;

      // Parse numeric level from value string, e.g. "12.34 m"
      final rawVal = item.value ?? '';
      final numStr = rawVal.replaceAll(RegExp(r'[^0-9.]'), '');
      final level  = double.tryParse(numStr);
      if (level == null || level <= 0) continue;

      final normName = _norm(item.title);
      final thresh   = _lookupThreshold(normName);

      // Thresholds: table → fallback derived from live level
      final warning = thresh?.warning ?? level * 0.90;
      final danger  = thresh?.danger  ?? level * 0.95;
      final hfl     = thresh?.hfl     ?? level * 1.05;

      // River: prefer WRD-supplied raw value → table → subtitle
      final river = (item.raw['river'] as String?)?.trim().isNotEmpty == true
          ? item.raw['river'] as String
          : thresh?.river ?? item.subtitle;

      // State: use raw metadata when present (IndiaStations items carry their
      // real state); fall back to 'Bihar' only for WRD / RTRS items that
      // don't carry a state field.
      final state = (item.raw['state'] as String?)?.trim().isNotEmpty == true
          ? item.raw['state'] as String
          : 'Bihar';

      result.add(RiverStation(
        city:        item.title,
        state:       state,
        river:       river,
        station:     item.title,
        current:     level,
        warning:     warning,
        danger:      danger,
        hfl:         hfl,
        lastUpdated:
            '${item.fetchedAt.hour.toString().padLeft(2, '0')}:'
            '${item.fetchedAt.minute.toString().padLeft(2, '0')}',
        dataSource:  item.source.name.toUpperCase(),
        isLive:      true,
        liveStatus:  item.dangerLevel,
      ));
    }
    return result;
  }
}

final liveEngineStationsProvider =
    NotifierProvider<LiveEngineBridgeNotifier, List<RiverStation>>(
        LiveEngineBridgeNotifier.new);
