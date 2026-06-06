// lib/providers/location_provider.dart
// OpsFlood — GPS location provider (geolocator)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationState {
  final double? lat;
  final double? lon;
  final bool    hasLocation;
  final String? error;
  const LocationState({this.lat, this.lon, this.hasLocation = false, this.error});
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        state = const LocationState(
            error: 'Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      state = LocationState(
          lat: pos.latitude, lon: pos.longitude, hasLocation: true);
    } catch (e) {
      state = LocationState(error: e.toString());
    }
  }

  Future<void> refresh() => _init();
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>(
        (_) => LocationNotifier());
