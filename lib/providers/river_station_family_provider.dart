// lib/providers/river_station_family_provider.dart
//
// Replaces the hardcoded per-station provider pattern (e.g. kosi_birpur_provider)
// with a single parameterised family:
//
//   riverStationProvider(StationId.kosiBirpur)  →  AsyncValue<RiverStation>
//
// All 31 Bihar gauge stations from GAUGE_THRESHOLDS are enumerated in StationId.
// Backward-compat alias: kosiBirpurProvider is re-exported below.
//
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import 'kosi_birpur_provider.dart' show kosiBirpurProvider, KosiBirpurReading;
import 'real_time_river_provider.dart' show mergedStationsProvider;

// ─────────────────────────────────────────────────────────────────────────────
// Station identifier enum — mirrors GAUGE_THRESHOLDS in flood_predictor.py
// ─────────────────────────────────────────────────────────────────────────────
enum StationId {
  // Ganga basin
  gandhighat,
  dighaghat,
  hathidah,
  munger,
  kahalgaon,
  bhagalpur,
  buxar,
  // Kosi basin
  kosiBirpur,
  baltara,
  basua,
  kursela,
  // Gandak basin
  chatia,
  dumariaghat,
  rewaghat,
  hajipur,
  // Bagmati basin
  dhengBridge,
  benibad,
  hayaghat,
  // Burhi Gandak basin
  sikandarpur,
  samastipur,
  rosera,
  khagaria,
  // Ghaghra basin
  darauli,
  gangpurSiswan,
  // Mahananda basin
  dhengraghat,
  taibpur,
  // Minor rivers
  jainagar,
  jhanjharpur,
  sonbarsa,
  kamtaul,
  sripalpur;

  /// Display name matching CWC / WRD station name strings
  String get stationName => switch (this) {
    StationId.gandhighat    => 'Gandhighat',
    StationId.dighaghat     => 'Dighaghat',
    StationId.hathidah      => 'Hathidah',
    StationId.munger        => 'Munger',
    StationId.kahalgaon     => 'Kahalgaon',
    StationId.bhagalpur     => 'Bhagalpur',
    StationId.buxar         => 'Buxar',
    StationId.kosiBirpur    => 'Birpur (CWC)',
    StationId.baltara       => 'Baltara',
    StationId.basua         => 'Basua',
    StationId.kursela       => 'Kursela',
    StationId.chatia        => 'Chatia',
    StationId.dumariaghat   => 'Dumariaghat',
    StationId.rewaghat      => 'Rewaghat',
    StationId.hajipur       => 'Hajipur',
    StationId.dhengBridge   => 'Dheng Bridge',
    StationId.benibad       => 'Benibad',
    StationId.hayaghat      => 'Hayaghat',
    StationId.sikandarpur   => 'Sikandarpur',
    StationId.samastipur    => 'Samastipur',
    StationId.rosera        => 'Rosera',
    StationId.khagaria      => 'Khagaria',
    StationId.darauli       => 'Darauli',
    StationId.gangpurSiswan => 'Gangpur Siswan',
    StationId.dhengraghat   => 'Dhengraghat',
    StationId.taibpur       => 'Taibpur',
    StationId.jainagar      => 'Jainagar',
    StationId.jhanjharpur   => 'Jhanjharpur',
    StationId.sonbarsa      => 'Sonbarsa',
    StationId.kamtaul       => 'Kamtaul',
    StationId.sripalpur     => 'Sripalpur',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// riverStationProvider — parameterised family
//
// For StationId.kosiBirpur: delegates to the enriched kosiBirpurProvider
// (discharge, trend, WRIS hydrograph) and converts to RiverStation.
//
// For all other stations: looks up the station in mergedStationsProvider
// (already the single source of truth) by name match.
// ─────────────────────────────────────────────────────────────────────────────
final riverStationProvider = FutureProvider.autoDispose
    .family<RiverStation?, StationId>((ref, id) async {
  if (id == StationId.kosiBirpur) {
    // Delegate to the enriched Birpur provider
    final reading = await ref.watch(kosiBirpurProvider.future);
    return RiverStation(
      city:        'Birpur',
      state:       'Bihar',
      river:       'Kosi',
      station:     'Birpur',
      current:     reading.levelM,
      warning:     reading.warningLevel,
      danger:      reading.dangerLevel,
      hfl:         reading.dangerLevel + 1.5,
      dataSource:  reading.source,
      lastUpdated:
          '${reading.observedAt.hour.toString().padLeft(2, '0')}:'
          '${reading.observedAt.minute.toString().padLeft(2, '0')}',
      isLive: reading.source != 'SEED',
    );
  }

  // All other stations — look up in merged list by station name
  final merged = ref.watch(mergedStationsProvider);
  final name   = id.stationName.toLowerCase();
  return merged
      .where((s) => s.station.toLowerCase().contains(name) ||
                    name.contains(s.station.toLowerCase()))
      .firstOrNull;
});

// ─────────────────────────────────────────────────────────────────────────────
// Backward-compat re-export: existing widgets using kosiBirpurProvider
// can keep importing from this file without any changes.
// ─────────────────────────────────────────────────────────────────────────────
export 'kosi_birpur_provider.dart' show
    kosiBirpurProvider,
    kosiBirpurStationProvider,
    cwcStationsWithBirpurProvider,
    kosiStationsProvider,
    birpurBadgeProvider,
    BirpurBadge;
