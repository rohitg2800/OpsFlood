// lib/providers/kosi_birpur_provider.dart
//
// Riverpod providers for Kosi @ Birpur live gauge data.
//
// Usage anywhere in the app:
//
//   // Full reading with discharge, source label, timestamps:
//   final reading = ref.watch(kosiBirpurProvider);
//   reading.when(data: (r) => ..., loading: ..., error: ...);
//
//   // Just the CwcStation (slots into every existing river-monitor widget):
//   final stationAsync = ref.watch(kosiBirpurStationProvider);
//
//   // River-monitor station list now includes Birpur automatically:
//   final allStations = ref.watch(cwcStationsWithBirpurProvider);
//
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/kosi_birpur_service.dart';
import '../services/befiqr_cwc_service.dart';
import 'cwc_provider.dart';

// ── 1. Raw live reading (auto-refresh every 15 min) ──────────────────────────

final kosiBirpurProvider =
    FutureProvider.autoDispose<KosiBirpurReading>((ref) async {
  return KosiBirpurService().fetchLive();
});

// ── 2. As a CwcStation (drop-in for any existing widget) ─────────────────────

final kosiBirpurStationProvider =
    Provider.autoDispose<AsyncValue<CwcStation>>((ref) {
  return ref.watch(kosiBirpurProvider).whenData((r) => r.toCwcStation());
});

// ── 3. Combined: all Bihar CWC stations + live Birpur injected/replaced ─────────
//
// This replaces the static Birpur seed inside cwcStationsProvider
// with the live reading whenever it is available.

final cwcStationsWithBirpurProvider =
    Provider.autoDispose<AsyncValue<List<CwcStation>>>((ref) {
  final allAsync    = ref.watch(cwcStationsProvider);
  final birpurAsync = ref.watch(kosiBirpurStationProvider);

  return allAsync.whenData((allStations) {
    // Remove any static Birpur entry from the seed list
    final filtered = allStations
        .where((s) =>
            !(s.river.toLowerCase().contains('kosi') &&
              s.site.toLowerCase().contains('birpur')))
        .toList();

    // .value returns null when loading or error (Riverpod 3.x — no valueOrNull)
    final liveBirpur = birpurAsync.value;
    if (liveBirpur != null) {
      filtered.add(liveBirpur);
    } else {
      // Re-add the original seed entry
      final seedBirpur = allStations.firstWhere(
        (s) =>
            s.river.toLowerCase().contains('kosi') &&
            s.site.toLowerCase().contains('birpur'),
        orElse: () => CwcStation(
          river:        'Kosi',
          site:         'Birpur',
          currentLevel: 210.80,
          dangerLevel:  kBirpurDangerLevel,
          fetchedAt:    DateTime(2026, 6, 1),
        ),
      );
      filtered.add(seedBirpur);
    }

    // Sort: Kosi stations first, then alphabetical by river
    filtered.sort((a, b) {
      if (a.river == 'Kosi' && b.river != 'Kosi') return -1;
      if (b.river == 'Kosi' && a.river != 'Kosi') return  1;
      final r = a.river.compareTo(b.river);
      return r != 0 ? r : a.site.compareTo(b.site);
    });

    return filtered;
  });
});

// ── 4. Kosi-specific stations only ───────────────────────────────────────────────

final kosiStationsProvider =
    Provider.autoDispose<AsyncValue<List<CwcStation>>>((ref) {
  return ref.watch(cwcStationsWithBirpurProvider).whenData(
        (list) => list
            .where((s) => s.river.toLowerCase().contains('kosi'))
            .toList()
          ..sort((a, b) => a.site.compareTo(b.site)),
      );
});

// ── 5. Birpur status badge data (convenience for dashboard tiles) ─────────────

class BirpurBadge {
  final double   level;
  final double   dangerLevel;
  final String   status;        // 'NORMAL' | 'ELEVATED' | 'WARNING' | 'DANGER'
  final String   source;
  final DateTime observedAt;
  final bool     isStale;       // true if data is >2 hours old

  const BirpurBadge({
    required this.level,
    required this.dangerLevel,
    required this.status,
    required this.source,
    required this.observedAt,
    required this.isStale,
  });

  double get gap          => dangerLevel - level;
  double get fillFraction => (level / dangerLevel).clamp(0.0, 1.1);
}

final birpurBadgeProvider =
    Provider.autoDispose<AsyncValue<BirpurBadge>>((ref) {
  return ref.watch(kosiBirpurProvider).whenData((r) => BirpurBadge(
        level:       r.levelM,
        dangerLevel: r.dangerLevel,
        status:      r.statusLabel,
        source:      r.source,
        observedAt:  r.observedAt,
        isStale:     DateTime.now().difference(r.observedAt).inHours >= 2,
      ));
});
