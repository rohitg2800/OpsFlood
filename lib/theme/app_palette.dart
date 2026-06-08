// lib/theme/app_palette.dart
// Thin re-export of AppPalette from river_theme.dart.
// Also adds the surface / surface2 / textPrimary aliases that
// monitors_screen.dart expects.
library;

export 'river_theme.dart' show AppPalette, RiverColors;

// The constants below extend AppPalette's static surface tokens.
// They are defined here as top-level constants because Dart does not
// allow adding static members to an existing class via extensions.
import 'package:flutter/material.dart';
import 'river_theme.dart';

extension AppPaletteExtra on AppPalette {
  // not used — constants below are what monitors_screen needs
}

// surface  ≈ abyss2  (card background)
const Color kPaletteSurface  = AppPalette.abyss2;
// surface2 ≈ abyss3  (slightly elevated card / progress track)
const Color kPaletteSurface2 = AppPalette.abyss3;
// textPrimary ≈ textWhite
const Color kPaletteTextPrimary = AppPalette.textWhite;
