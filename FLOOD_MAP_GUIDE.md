# Bihar Flood Command Map — Integration Guide

## Required Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  geolocator: ^13.0.1
```

## Required Asset

Place your Bihar GeoJSON file at:
```
assets/geodata/bihar_districts.geojson
```

Add to `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/geodata/
```

Free source: https://github.com/datameet/maps/tree/master/Districts
Filter for Bihar (state code 10) in QGIS or use ogr2ogr.

## Wire Up Real-Time Data

In `lib/providers/real_time_river_provider.dart`, replace the stub:

```dart
final stations = await ref.watch(yourExistingServiceProvider.future);
ref.read(stationHistoryProvider.notifier).pushSnapshot(stations);
return stations;
```

## Add Route in main.dart

```dart
case MapScreen.route:
  return _fade(const MapScreen());
```

## Add Station Coordinates

In `map_screen.dart`, extend `_stationCoords` with your full WRD Bihar station lat/lon table.

## Platform Permissions

### Android — `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS — `ios/Runner/Info.plist`
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to highlight your nearest flood monitoring station.</string>
```

## Performance Notes

- GeoJSON is loaded once via `FutureProvider` (never re-parsed).
- `PolygonLayer` rebuilds only when `realTimeRiverProvider` changes value.
- The flow animation (`_RiverFlowOverlay`) is an isolated `AnimationController` — it never triggers a map rebuild.
- For 50+ stations, wrap `PolygonLayer` in `RepaintBoundary`.
- Use `flutter_map_cancellable_tile_provider` to cancel in-flight tile requests on fast zoom.
