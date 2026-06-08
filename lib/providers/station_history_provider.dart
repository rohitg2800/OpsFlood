// lib/providers/station_history_provider.dart
// StationHistoryStore — keeps a rolling 24-hour ring buffer of snapshots.
// Each snapshot is a List<RiverStation> taken when live data refreshes.
// The timeline scrubber uses stationsAtTime() to replay past state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';

// Max snapshots kept in memory (one per minute → 1440 for 24 h).
// Reduce to 144 (10-min cadence) if memory is a concern.
const _kMaxSnapshots = 144;

class StationHistoryStore extends Notifier<List<List<RiverStation>>> {
  @override
  List<List<RiverStation>> build() => [];

  /// Call this every time live data refreshes.
  void pushSnapshot(List<RiverStation> snapshot) {
    final next = [...state, snapshot];
    if (next.length > _kMaxSnapshots) next.removeAt(0);
    state = next;
  }

  /// Returns the snapshot at position [pct] (0.0=oldest, 1.0=latest).
  /// Falls back to [current] when history is empty.
  List<RiverStation> stationsAtTime(double pct, List<RiverStation> current) {
    if (state.isEmpty) return current;
    final idx = ((state.length - 1) * pct.clamp(0.0, 1.0)).round();
    return state[idx];
  }
}

final stationHistoryProvider =
    NotifierProvider<StationHistoryStore, List<List<RiverStation>>>(
  StationHistoryStore.new,
);
