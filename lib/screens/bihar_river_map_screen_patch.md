# bihar_river_map_screen.dart — opacity patch note

`flutter_map 8.3.0` removed all opacity params from `TileLayer`.
The precipitation layer opacity must be applied by wrapping `TileLayer` in
a Flutter `Opacity` widget:

```dart
// BEFORE (broken):
TileLayer(
  urlTemplate: precipUrl,
  opacity: _precipOpacity,   // ← no such param
)

// AFTER (correct):
Opacity(
  opacity: _precipOpacity,
  child: TileLayer(
    urlTemplate: precipUrl,
  ),
)
```

The actual fix is applied directly in `bihar_river_map_screen.dart`.
See commit message for details.
