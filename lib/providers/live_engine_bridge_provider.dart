// lib/providers/live_engine_bridge_provider.dart  v1.0
//
// Bridges BiharLiveEngine → List<RiverStation> for Riverpod consumers.
//
// How it works:
//   1. Listens to BiharLiveEngine.instance.stream (broadcast).
//   2. For every BiharFeedItem of kind riverGauge / barrage / telemetry
//      that carries a numeric value, builds a RiverStation with real
//      current, warning, danger, hfl thresholds from the CWC seed table.
//   3. Exposes liveEngineStationsProvider (List<RiverStation>) — to be
//      consumed as the top priority tier in mergedStationsProvider.
//
// Usage in real_time_river_provider.dart:
//   Add ref.watch(liveEngineStationsProvider) at the top of
//   mergedStationsProvider and let its stations override seeds.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../services/bihar_live_engine.dart';

// ── CWC / WRD threshold seed table ─────────────────────────────────────────────────────────
// warning / danger / hfl in metres.  Sourced from CWC FFEM Bihar bulletin.
// Any station NOT in this table gets auto-thresholds derived from its
// live reading (warning = level × 0.90, danger = level × 0.95, hfl = level × 1.05)
// so it at least renders a non-green colour when elevated.
const Map<String, ({double warning, double danger, double hfl, String river})>
    _kThresholds = {
  // Ganga
  'dighaghat':        (warning: 50.27, danger: 50.60, hfl: 52.32,  river: 'Ganga'),
  'gandhighat':       (warning: 49.68, danger: 50.06, hfl: 51.25,  river: 'Ganga'),
  'hathidah':         (warning: 41.09, danger: 41.79, hfl: 43.24,  river: 'Ganga'),
  'munger':           (warning: 38.37, danger: 39.17, hfl: 40.25,  river: 'Ganga'),
  'kahalgaon':        (warning: 32.84, danger: 33.84, hfl: 35.12,  river: 'Ganga'),
  'bhagalpur':        (warning: 31.17, danger: 32.17, hfl: 33.50,  river: 'Ganga'),
  'buxar':            (warning: 61.59, danger: 62.39, hfl: 64.32,  river: 'Ganga'),
  // Kosi
  'birpur':           (warning: 211.50, danger: 212.40, hfl: 213.90, river: 'Kosi'),
  'baltara':          (warning: 34.80,  danger: 36.00,  hfl: 37.50,  river: 'Kosi'),
  'basua':            (warning: 60.00,  danger: 61.50,  hfl: 63.00,  river: 'Kosi'),
  'kursela':          (warning: 28.00,  danger: 29.00,  hfl: 30.50,  river: 'Kosi'),
  'bhim nagar':       (warning: 70.00,  danger: 71.00,  hfl: 72.50,  river: 'Kosi'),
  'bhimnagar':        (warning: 70.00,  danger: 71.00,  hfl: 72.50,  river: 'Kosi'),
  // Gandak
  'hajipur':          (warning: 56.36, danger: 57.36, hfl: 59.12,  river: 'Gandak'),
  'dumariaghat':      (warning: 73.00, danger: 74.00, hfl: 75.50,  river: 'Gandak'),
  'chatia':           (warning: 65.00, danger: 66.00, hfl: 67.50,  river: 'Gandak'),
  'rewaghat':         (warning: 47.00, danger: 48.00, hfl: 49.50,  river: 'Gandak'),
  // Bagmati
  'benibad':          (warning: 52.95, danger: 53.95, hfl: 55.10,  river: 'Bagmati'),
  'hayaghat':         (warning: 45.45, danger: 46.45, hfl: 47.80,  river: 'Bagmati'),
  'dheng bridge':     (warning: 49.00, danger: 50.00, hfl: 51.50,  river: 'Bagmati'),
  'dhengbridge':      (warning: 49.00, danger: 50.00, hfl: 51.50,  river: 'Bagmati'),
  'runnisaidpur':     (warning: 70.00, danger: 71.00, hfl: 72.50,  river: 'Bagmati'),
  // Burhi Gandak
  'rosera':           (warning: 45.27, danger: 46.27, hfl: 47.80,  river: 'Burhi Gandak'),
  'samastipur':       (warning: 43.00, danger: 44.00, hfl: 45.50,  river: 'Burhi Gandak'),
  'sikandarpur':      (warning: 50.00, danger: 51.00, hfl: 52.50,  river: 'Burhi Gandak'),
  'gaighat':          (warning: 53.00, danger: 54.00, hfl: 55.50,  river: 'Burhi Gandak'),
  // Adhwara / Kamla
  'ekmighat':         (warning: 56.00, danger: 57.00, hfl: 58.50,  river: 'Adhwara'),
  'kamtaul':          (warning: 57.00, danger: 58.00, hfl: 59.50,  river: 'Adhwara'),
  'jhanjharpur':      (warning: 62.00, danger: 63.00, hfl: 64.50,  river: 'Kamla'),
  'jainagar':         (warning: 70.00, danger: 71.00, hfl: 72.50,  river: 'Kamla'),
  'phulparas':        (warning: 69.00, danger: 70.00, hfl: 71.50,  river: 'Kamla'),
  // Ghaghra
  'darauli':          (warning: 62.00, danger: 63.00, hfl: 64.50,  river: 'Ghaghra'),
  'gangpur':          (warning: 68.00, danger: 69.00, hfl: 70.50,  river: 'Ghaghra'),
  'gangpur siswan':   (warning: 68.00, danger: 69.00, hfl: 70.50,  river: 'Ghaghra'),
  // Mahananda
  'dhengraghat':      (warning: 27.00, danger: 28.00, hfl: 29.50,  river: 'Mahananda'),
  // Punpun
  'sripalpur':        (warning: 52.00, danger: 53.00, hfl: 54.50,  river: 'Punpun'),
  // Sonbarsa / Lalbakeya
  'sonbarsa':         (warning: 76.00, danger: 77.00, hfl: 78.50,  river: 'Lakhandei'),
  'lalbakeya':        (warning: 73.00, danger: 74.00, hfl: 75.50,  river: 'Lalbakeya'),
  // Misc
  'naugachia':        (warning: 28.00, danger: 29.00, hfl: 30.50,  river: 'Ganga'),
  'khagaria':         (warning: 37.00, danger: 38.00, hfl: 39.50,  river: 'Burhi Gandak'),
};

String _norm(String v) => v
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// ── Provider ──────────────────────────────────────────────────────────────────────────

class LiveEngineBridgeNotifier
    extends Notifier<List<RiverStation>> {
  StreamSubscription<BiharLiveFeed>? _sub;

  @override
  List<RiverStation> build() {
    // Start the engine if not already running
    if (!BiharLiveEngine.instance.running) {
      BiharLiveEngine.instance.start();
    }

    // Subscribe to the broadcast stream
    _sub?.cancel();
    _sub = BiharLiveEngine.instance.stream.listen(_onFeed);
    ref.onDispose(() => _sub?.cancel());

    // Seed from whatever is already cached
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

      // Look up thresholds — try exact then substring
      var thresh = _kThresholds[normName];
      if (thresh == null) {
        for (final entry in _kThresholds.entries) {
          final k = _norm(entry.key);
          if (normName.contains(k) || k.contains(normName)) {
            thresh = entry.value;
            break;
          }
        }
      }

      // Derive fallback thresholds from the live level itself
      final warning = thresh?.warning ?? level * 0.90;
      final danger  = thresh?.danger  ?? level * 0.95;
      final hfl     = thresh?.hfl     ?? level * 1.05;
      final river   = thresh?.river   ??
                      item.raw['river']?.toString() ??
                      item.subtitle;

      result.add(RiverStation(
        city:        item.title,
        state:       'Bihar',
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
