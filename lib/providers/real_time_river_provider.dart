// lib/providers/real_time_river_provider.dart
// Thin Riverpod wrapper around your existing RealTimeRiverService.
// Also pushes each fresh snapshot into StationHistoryStore.
//
// IMPORTANT: Replace the stub below with your actual service call.
// The pattern is identical to your existing flood_data_provider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import 'station_history_provider.dart';

// ── Replace with your real service ────────────────────────────────────────
// import '../services/real_time_river_service.dart';

final realTimeRiverProvider = FutureProvider.autoDispose<List<RiverStation>>((ref) async {
  // TODO: replace stub with your service:
  // final service = ref.read(realTimeRiverServiceProvider);
  // final stations = await service.fetchAll();

  // Stub: return empty list until wired up
  const List<RiverStation> stations = [];

  // Push snapshot into history store (works with real data too)
  ref.read(stationHistoryProvider.notifier).pushSnapshot(stations);

  return stations;
});
