// lib/providers/location_provider.dart
// Riverpod 3.x compatible — uses Notifier + NotifierProvider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class LocationState {
  final double? lat;
  final double? lon;
  final bool isLoading;
  final String? error;

  const LocationState({
    this.lat,
    this.lon,
    this.isLoading = false,
    this.error,
  });
}

// ── Notifier (Riverpod 3.x) ───────────────────────────────────────────────────
class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() {
    Future.microtask(fetchLocation);
    return const LocationState(isLoading: true);
  }

  Future<void> fetchLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        state = const LocationState(error: 'Location permission denied');
        return;
      }
      // Use LocationSettings instead of the deprecated desiredAccuracy param.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      state = LocationState(lat: pos.latitude, lon: pos.longitude);
    } catch (e) {
      state = LocationState(error: e.toString());
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);
