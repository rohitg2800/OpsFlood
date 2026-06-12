// lib/screens/dashboard_screen_strip_wiring.dart
//
// Drop-in wired wrapper for StationStatusStrip.
//
// USAGE — in dashboard_screen.dart:
//   1. Add import:
//        import 'dashboard_screen_strip_wiring.dart';
//   2. Replace any StationStatusStrip(...) call with:
//        StationStatusStripWired(
//          activeFilter: _activeFilter,   // FloodSeverity? from your state
//          onTap:        _onChipTap,      // void Function(FloodSeverity)?
//        )
//
// The widget watches stationCountsProvider, stationLastSyncedProvider, and
// stationIsLoadingProvider — all derived from mergedStationsProvider —
// so the strip auto-refreshes whenever live data changes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/station_counts_provider.dart';
import '../utils/flood_severity.dart';
import '../widgets/station_status_strip.dart';

class StationStatusStripWired extends ConsumerWidget {
  const StationStatusStripWired({
    super.key,
    this.activeFilter,
    this.onTap,
  });

  final FloodSeverity?                   activeFilter;
  final void Function(FloodSeverity)?    onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts    = ref.watch(stationCountsProvider);
    final lastSync  = ref.watch(stationLastSyncedProvider);
    final isLoading = ref.watch(stationIsLoadingProvider);

    return StationStatusStrip(
      counts:       counts,
      lastSynced:   lastSync,
      isLoading:    isLoading,
      activeFilter: activeFilter,
      onTap:        onTap,
    );
  }
}
