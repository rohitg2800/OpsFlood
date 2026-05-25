// lib/models/live_river_result_ext.dart
//
// Convenience extension that adds `currentLevel` and `trend` getters to
// LiveRiverResult, delegating to the embedded RiverStation fields.
// This keeps india_rivers_screen.dart readable without touching the core model.

import '../services/real_time_river_service.dart';

extension LiveRiverResultX on LiveRiverResult {
  /// Current gauge reading in metres (delegates to station.current).
  double? get currentLevel {
    final v = station.current;
    return v > 0 ? v : null;
  }

  /// Water-level trend string, e.g. 'RISING', 'FALLING', 'STEADY'.
  /// Delegates to station.trend (nullable).
  String? get trend => station.trend;
}
