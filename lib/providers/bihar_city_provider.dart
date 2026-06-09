// lib/providers/bihar_city_provider.dart
//
// Family provider: look up a single BiharStationData by city name.
// Matching is case-insensitive and trims whitespace.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bihar_live_provider.dart';

/// Returns the [BiharStationData] for [city], or null if not in the list yet.
final biharCityProvider =
    Provider.family<BiharStationData?, String>((ref, city) {
  final state = ref.watch(biharLiveProvider);
  return state.maybeWhen(
    data: (s) {
      final key = city.trim().toLowerCase();
      try {
        return s.stations.firstWhere(
          (st) => st.city.trim().toLowerCase() == key,
        );
      } catch (_) {
        return null;
      }
    },
    orElse: () => null,
  );
});

/// True while biharLiveProvider is fetching for the first time.
final biharCityLoadingProvider = Provider<bool>((ref) {
  return ref.watch(biharLiveProvider).isLoading;
});
