// lib/providers/kosi_birpur_provider.dart  v2.0
//
// ARCHITECTURE CHANGE vs v1.0:
//
//   v1.0: KosiBirpurService was a COMPETING source — it ran its own 5-source
//         race and produced a standalone RiverStation that merged with
//         DataFetchEngine's Birpur entry. Whoever won dedup controlled the
//         final level, discarding the other's metadata.
//
//   v2.0: KosiBirpurService is now an ENRICHMENT LAYER:
//
//         DataFetchEngine  →  best available LEVEL (GloFAS > CWC FFS > SEED)
//         KosiBirpurService →  best available ENRICHMENT (discharge Q, trend,
//                               WRIS hydrograph, rate-of-rise)
//
//         kosiBirpurProvider merges both:
//           • Level from DataFetch (authoritative — GloFAS never goes down)
//           • Discharge + trend overlaid from KosiBirpurService if available
//           • Falls back cleanly: no enrichment is fine, level still shown
//
//         mergedStationsProvider replaces the raw DataFetch Birpur entry
//         with this enriched entry so there is always exactly ONE Birpur.
//
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../services/kosi_birpur_service.dart';
import '../services/befiqr_cwc_service.dart';
import '../services/data_fetch_engine.dart';
import 'cwc_provider.dart';
import 'data_fetch_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. Raw enrichment from KosiBirpurService (discharge, trend, WRIS)
//    Runs independently, does NOT set the canonical level.
//    Returns null if all sources fail — that is OK, level still comes
//    from DataFetch.
// ─────────────────────────────────────────────────────────────────────────────
final _birpurEnrichmentProvider =
    FutureProvider.autoDispose<KosiBirpurReading?>((ref) async {
  try {
    final r = await KosiBirpurService().fetchLive();
    // Only return it if it is a live reading, not a seed
    return r.source == 'SEED' ? null : r;
  } catch (e) {
    debugPrint('[KosiBirpur] enrichment failed: $e');
    return null;
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. kosiBirpurProvider — THE canonical Birpur entry
//
//    Level source priority:
//      1. KosiBirpurService live (BEAMS, WRIS, FFS) — highest precision
//      2. DataFetchEngine Birpur (GloFAS estimated) — always available
//      3. Static seed — last resort
//
//    Enrichment (discharge, trend) comes from KosiBirpurService whenever
//    available, regardless of which level source won.
// ─────────────────────────────────────────────────────────────────────────────
final kosiBirpurProvider =
    FutureProvider.autoDispose<KosiBirpurReading>((ref) async {
  // Run both in parallel — enrichment fetches discharge/trend,
  // DataFetch already has the level from its own cycle.
  final enrichFuture = ref.watch(_birpurEnrichmentProvider.future);
  final dfSnap       = DataFetchEngine.instance.last;

  // Pull the DataFetch level for Birpur out of the last snapshot
  final dfBirpur = dfSnap?.stations.where((s) =>
      s.stationName.toLowerCase().contains('birpur')).firstOrNull;

  final enrich = await enrichFuture;

  // ── Level resolution ─────────────────────────────────────────────
  // Priority: live enrichment level > DataFetch GloFAS > static seed
  final double level;
  final String levelSource;

  if (enrich != null) {
    // KosiBirpurService got a live reading — use its level (AMSL, precise)
    level       = enrich.levelM;
    levelSource = enrich.source;
  } else if (dfBirpur != null && dfBirpur.isLive) {
    // DataFetch has a GloFAS-estimated level — use it
    level       = dfBirpur.currentLevel;
    levelSource = 'GloFAS';
  } else {
    // Both down — fall back to seed
    level       = 210.80;
    levelSource = 'SEED';
  }

  // ── Enrichment overlay ─────────────────────────────────────────────
  final discharge = enrich?.dischargeCumecs ?? dfBirpur?.flowRateCumecs;
  final trend     = enrich?.trend;
  final obsAt     = enrich?.observedAt ??
      dfBirpur?.fetchedAt ?? DateTime.now();

  if (kDebugMode) {
    debugPrint('[KosiBirpur] ✅ level=$level ($levelSource)'
        '${discharge != null ? " Q=${discharge.toStringAsFixed(0)} cumecs" : ""}'
        '${trend != null ? " trend=$trend" : ""}');
  }

  return KosiBirpurReading(
    levelM:          level,
    dangerLevel:     enrich?.dangerLevel  ?? kBirpurDangerLevel,
    warningLevel:    enrich?.warningLevel ?? kBirpurWarningLevel,
    dischargeCumecs: discharge,
    trend:           trend,
    observedAt:      obsAt,
    source:          levelSource,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. As a CwcStation (drop-in for any existing widget)
// ─────────────────────────────────────────────────────────────────────────────
final kosiBirpurStationProvider =
    Provider.autoDispose<AsyncValue<CwcStation>>((ref) {
  return ref.watch(kosiBirpurProvider).whenData((r) => r.toCwcStation());
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. Combined: all Bihar CWC stations + enriched Birpur injected
// ─────────────────────────────────────────────────────────────────────────────
final cwcStationsWithBirpurProvider =
    Provider.autoDispose<AsyncValue<List<CwcStation>>>((ref) {
  final allAsync    = ref.watch(cwcStationsProvider);
  final birpurAsync = ref.watch(kosiBirpurStationProvider);

  return allAsync.whenData((allStations) {
    final filtered = allStations
        .where((s) =>
            !(s.river.toLowerCase().contains('kosi') &&
              s.site.toLowerCase().contains('birpur')))
        .toList();

    final liveBirpur = birpurAsync.value;
    if (liveBirpur != null) {
      filtered.add(liveBirpur);
    } else {
      filtered.add(CwcStation(
        river:        'Kosi',
        site:         'Birpur',
        currentLevel: 210.80,
        dangerLevel:  kBirpurDangerLevel,
        isFromSeed:   true,
        fetchedAt:    DateTime(2026, 6, 1),
      ));
    }

    filtered.sort((a, b) {
      if (a.river == 'Kosi' && b.river != 'Kosi') return -1;
      if (b.river == 'Kosi' && a.river != 'Kosi') return  1;
      final r = a.river.compareTo(b.river);
      return r != 0 ? r : a.site.compareTo(b.site);
    });
    return filtered;
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 5. Kosi-only list
// ─────────────────────────────────────────────────────────────────────────────
final kosiStationsProvider =
    Provider.autoDispose<AsyncValue<List<CwcStation>>>((ref) {
  return ref.watch(cwcStationsWithBirpurProvider).whenData(
    (list) => list
        .where((s) => s.river.toLowerCase().contains('kosi'))
        .toList()
      ..sort((a, b) => a.site.compareTo(b.site)),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 6. BirpurBadge (dashboard tile convenience)
// ─────────────────────────────────────────────────────────────────────────────
class BirpurBadge {
  final double   level;
  final double   dangerLevel;
  final String   status;
  final String   source;
  final DateTime observedAt;
  final bool     isStale;
  final double?  dischargeCumecs;
  final String?  trend;

  const BirpurBadge({
    required this.level,
    required this.dangerLevel,
    required this.status,
    required this.source,
    required this.observedAt,
    required this.isStale,
    this.dischargeCumecs,
    this.trend,
  });

  double get gap          => dangerLevel - level;
  double get fillFraction => (level / dangerLevel).clamp(0.0, 1.1);
}

final birpurBadgeProvider =
    Provider.autoDispose<AsyncValue<BirpurBadge>>((ref) {
  return ref.watch(kosiBirpurProvider).whenData((r) => BirpurBadge(
        level:           r.levelM,
        dangerLevel:     r.dangerLevel,
        status:          r.statusLabel,
        source:          r.source,
        observedAt:      r.observedAt,
        isStale:         DateTime.now().difference(r.observedAt).inHours >= 2,
        dischargeCumecs: r.dischargeCumecs,
        trend:           r.trend,
      ));
});
