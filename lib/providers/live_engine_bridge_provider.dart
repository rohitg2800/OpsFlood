// lib/providers/live_engine_bridge_provider.dart  v3.0
//
// v3.0 changes (threshold table sync with bihar_rivers.dart v4):
//   FIXED  Jainagar WL 67.50→67.75  DL 68.50→67.75  [BeFIQR RTDAS Jun 2026]
//   FIXED  Benibad HFL 50.01→50.12  [BeFIQR Jun 2026]
//   FIXED  Ekmighat WL 40→45.00  DL 41→46.94  HFL 43→49.52  [RTDAS]
//   FIXED  Sonbarsa WL 76→80.50  DL 77→81.85  HFL 78.50→83.75  [RTDAS Jhim]
//   FIXED  Kamtaul (Adhwara) HFL 53.01→53.05  [BeFIQR]
//   FIXED  Dhengraghat (Mahananda) HFL 38.16→38.20  [BeFIQR]
//   FIXED  Hajipur HFL 51.93→50.93  [BeFIQR]
//   FIXED  Dumariaghat HFL 63.70→64.36  [BeFIQR]
//   ADDED  Runisaidpur, Dubbadhar, Kansar, Kataunjha (Bagmati)
//   ADDED  Lalganj, Khadda (Gandak)
//   ADDED  Vijay Ghat Bridge (Kosi)
//   ADDED  Jhawa (Mahananda)
//   ADDED  Agropatti (Khiroi), Saulighat (Dhaus), Goabari (Lal Bakeya)
//   ADDED  Phulparas (Balan), Laukaha (Bhutahi Balan)
//   ADDED  Dagmara (Khando), Karachin (Kareh)
//
// Bridges BiharLiveEngine → List<RiverStation> for Riverpod consumers.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../services/bihar_live_engine.dart';

// ── Threshold table ─────────────────────────────────────────────────────────
// SOURCE: bihar_rivers.dart v4 kBiharGauges (BEAMS RTDAS + BeFIQR Jun 2026)
// All levels in metres MSL.
const Map<String, ({double warning, double danger, double hfl, String river})>
    _kThresholds = {

  // ── GANGA (7 stations) ───────────────────────────────────────────────────
  'gandhighat': (warning: 47.50, danger: 48.60, hfl: 50.52, river: 'Ganga'),
  'dighaghat':  (warning: 49.30, danger: 50.45, hfl: 52.52, river: 'Ganga'),
  'hathidah':   (warning: 40.50, danger: 41.76, hfl: 43.52, river: 'Ganga'),
  'munger':     (warning: 38.20, danger: 39.33, hfl: 40.99, river: 'Ganga'),
  'kahalgaon':  (warning: 30.00, danger: 31.09, hfl: 32.87, river: 'Ganga'),
  'bhagalpur':  (warning: 32.50, danger: 33.68, hfl: 34.86, river: 'Ganga'),
  'buxar':      (warning: 59.20, danger: 60.32, hfl: 62.09, river: 'Ganga'),

  // ── KOSI (6 stations) ───────────────────────────────────────────────────
  'birpur':           (warning: 73.70, danger: 74.70, hfl: 76.02, river: 'Kosi'),
  'birpur (cwc)':     (warning: 73.70, danger: 74.70, hfl: 76.02, river: 'Kosi'),
  'basua':            (warning: 46.50, danger: 47.75, hfl: 49.24, river: 'Kosi'),
  'baltara':          (warning: 32.85, danger: 33.85, hfl: 36.40, river: 'Kosi'),
  'kursela':          (warning: 28.80, danger: 30.00, hfl: 32.10, river: 'Kosi'),
  'dumri bridge':     (warning: 32.85, danger: 33.85, hfl: 36.40, river: 'Kosi'),
  'bhim nagar':       (warning: 70.00, danger: 71.00, hfl: 72.50, river: 'Kosi'),
  'bhimnagar':        (warning: 70.00, danger: 71.00, hfl: 72.50, river: 'Kosi'),
  // NEW v3.0
  'vijay ghat bridge':(warning: 29.50, danger: 31.00, hfl: 33.50, river: 'Kosi'),
  'vijayghat':        (warning: 29.50, danger: 31.00, hfl: 33.50, river: 'Kosi'),
  'naugachia':        (warning: 29.50, danger: 31.00, hfl: 33.50, river: 'Ganga'),

  // ── GANDAK (6 stations) ──────────────────────────────────────────────────
  'chatia':      (warning: 68.10, danger: 69.15, hfl: 70.04, river: 'Gandak'),
  'dumariaghat': (warning: 61.10, danger: 62.22, hfl: 64.36, river: 'Gandak'), // FIX HFL
  'rewaghat':    (warning: 53.40, danger: 54.41, hfl: 55.46, river: 'Gandak'),
  'hajipur':     (warning: 49.40, danger: 50.32, hfl: 50.93, river: 'Gandak'), // FIX HFL
  // NEW v3.0
  'lalganj':     (warning: 49.30, danger: 50.50, hfl: 51.83, river: 'Gandak'),
  'khadda':      (warning: 94.50, danger: 96.00, hfl: 97.50, river: 'Gandak'),

  // ── BAGMATI (10 stations) ────────────────────────────────────────────────
  'dheng bridge':          (warning: 70.00, danger: 71.00, hfl: 73.47, river: 'Bagmati'),
  'dhengbridge':           (warning: 70.00, danger: 71.00, hfl: 73.47, river: 'Bagmati'),
  'sonakhan':              (warning: 67.80, danger: 68.80, hfl: 72.05, river: 'Bagmati'),
  'benibad':               (warning: 47.68, danger: 48.68, hfl: 50.12, river: 'Bagmati'), // FIX HFL
  'hayaghat':              (warning: 44.50, danger: 45.72, hfl: 48.96, river: 'Bagmati'),
  'dhengraghat bagmati':   (warning: 34.65, danger: 35.65, hfl: 47.30, river: 'Bagmati'),
  'kamtaul bagmati':       (warning: 49.00, danger: 50.00, hfl: 53.01, river: 'Bagmati'),
  'kamtaul':               (warning: 49.00, danger: 50.00, hfl: 53.01, river: 'Bagmati'),
  'runnisaidpur':          (warning: 52.50, danger: 55.00, hfl: 58.15, river: 'Bagmati'), // NEW
  'runisaidpur':           (warning: 52.50, danger: 55.00, hfl: 58.15, river: 'Bagmati'), // NEW
  'dubbadhar':             (warning: 59.00, danger: 61.28, hfl: 63.75, river: 'Bagmati'), // NEW
  'kansar':                (warning: 57.50, danger: 59.06, hfl: 60.86, river: 'Bagmati'), // NEW
  'kataunjha':             (warning: 52.80, danger: 55.00, hfl: 58.36, river: 'Bagmati'), // NEW

  // ── BURHI GANDAK (5 stations) ────────────────────────────────────────────
  'sikandarpur': (warning: 51.40, danger: 52.53, hfl: 54.29, river: 'Burhi Gandak'),
  'samastipur':  (warning: 44.80, danger: 46.02, hfl: 49.38, river: 'Burhi Gandak'),
  'rosera':      (warning: 41.50, danger: 42.63, hfl: 46.56, river: 'Burhi Gandak'),
  'khagaria':    (warning: 35.40, danger: 36.58, hfl: 39.22, river: 'Burhi Gandak'),
  'gaighat':     (warning: 53.00, danger: 54.00, hfl: 55.50, river: 'Burhi Gandak'),

  // ── GHAGHRA (2 stations) ─────────────────────────────────────────────────
  'darauli':          (warning: 60.50, danger: 61.52, hfl: 63.10, river: 'Ghaghra'),
  'gangpur siswan':   (warning: 63.00, danger: 64.10, hfl: 65.82, river: 'Ghaghra'),
  'gangpur':          (warning: 63.00, danger: 64.10, hfl: 65.82, river: 'Ghaghra'),

  // ── KAMLA (3 stations) ───────────────────────────────────────────────────
  // FIX v3.0: WL 67.50→67.75 DL 68.50→67.75 [BeFIQR RTDAS Jainagar Weir]
  'jainagar':      (warning: 67.75, danger: 67.75, hfl: 71.35, river: 'Kamla'),
  'jhanjharpur':   (warning: 49.50, danger: 50.50, hfl: 53.11, river: 'Kamla'),
  'kamtaul kamla': (warning: 43.00, danger: 44.00, hfl: 45.45, river: 'Kamla'),
  'phulparas':     (warning: 49.50, danger: 50.50, hfl: 53.11, river: 'Kamla'), // legacy key fallback

  // ── MAHANANDA (3 stations) ───────────────────────────────────────────────
  'taibpur':                (warning: 34.65, danger: 35.65, hfl: 38.16, river: 'Mahananda'),
  'dhengraghat mahananda':  (warning: 34.65, danger: 35.65, hfl: 38.20, river: 'Mahananda'), // FIX HFL
  'dhengraghat':            (warning: 34.65, danger: 35.65, hfl: 38.20, river: 'Mahananda'), // FIX HFL
  // NEW v3.0
  'jhawa':                  (warning: 30.00, danger: 31.40, hfl: 34.07, river: 'Mahananda'),

  // ── PUNPUN (1 station) ───────────────────────────────────────────────────
  'sripalpur': (warning: 50.60, danger: 51.83, hfl: 53.91, river: 'Punpun'),

  // ── ADHWARA / DHAUS (2 stations) ─────────────────────────────────────────
  // FIX v3.0: Kamtaul (Adhwara) HFL 53.01→53.05
  'ekmighat':        (warning: 45.00, danger: 46.94, hfl: 49.52, river: 'Khiroi'),   // FIX all three
  'kamtaul adhwara': (warning: 48.00, danger: 50.00, hfl: 53.05, river: 'Adhwara'), // FIX HFL
  // NEW v3.0
  'saulighat':       (warning: 50.00, danger: 52.37, hfl: 55.10, river: 'Dhaus'),

  // ── KHIROI (2 stations) ──────────────────────────────────────────────────
  // NEW v3.0
  'agropatti': (warning: 51.00, danger: 52.75, hfl: 54.53, river: 'Khiroi'),

  // ── JHIM (1 station) ─────────────────────────────────────────────────────
  // FIX v3.0: was Lalbakeya; RTDAS confirms Jhim river
  'sonbarsa':  (warning: 80.50, danger: 81.85, hfl: 83.75, river: 'Jhim'),
  'lalbakeya': (warning: 73.00, danger: 74.00, hfl: 75.50, river: 'Lalbakeya'), // keep legacy key

  // ── LAL BAKEYA (1 station) ───────────────────────────────────────────────
  // NEW v3.0
  'goabari': (warning: 69.50, danger: 71.15, hfl: 73.86, river: 'Lal Bakeya'),

  // ── BALAN (1 station) ────────────────────────────────────────────────────
  // NEW v3.0
  'phulparas balan':  (warning: 59.50, danger: 60.80, hfl: 61.80, river: 'Balan'),

  // ── BHUTAHI BALAN (1 station) ────────────────────────────────────────────
  // NEW v3.0
  'laukaha': (warning: 78.50, danger: 79.80, hfl: 80.80, river: 'Bhutahi Balan'),

  // ── KHANDO (1 station) ───────────────────────────────────────────────────
  // NEW v3.0
  'dagmara': (warning: 60.50, danger: 61.50, hfl: 62.50, river: 'Khando'),

  // ── KAREH (1 station) ────────────────────────────────────────────────────
  // NEW v3.0
  'karachin': (warning: 38.50, danger: 40.00, hfl: 41.90, river: 'Kareh'),
};

// ── helpers ──────────────────────────────────────────────────────────────────

String _norm(String v) => v
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

({double warning, double danger, double hfl, String river})?
    _lookupThreshold(String normName) {
  final exact = _kThresholds[normName];
  if (exact != null) return exact;
  for (final entry in _kThresholds.entries) {
    final k = entry.key;
    if (normName.contains(k) || k.contains(normName)) return entry.value;
  }
  return null;
}

// ── Provider ──────────────────────────────────────────────────────────────────

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

      final rawVal = item.value ?? '';
      final numStr = rawVal.replaceAll(RegExp(r'[^0-9.]'), '');
      final level  = double.tryParse(numStr);
      if (level == null || level <= 0) continue;

      final normName = _norm(item.title);
      final thresh   = _lookupThreshold(normName);

      final warning = thresh?.warning ?? level * 0.90;
      final danger  = thresh?.danger  ?? level * 0.95;
      final hfl     = thresh?.hfl     ?? level * 1.05;

      final river = (item.raw['river'] as String?)?.trim().isNotEmpty == true
          ? item.raw['river'] as String
          : thresh?.river ?? item.subtitle;

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
