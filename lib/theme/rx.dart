// lib/theme/rx.dart
// ─────────────────────────────────────────────────────────────────────────────
// Convenience helpers so every screen reads theme tokens correctly.
//
// USAGE:
//   import '../theme/rx.dart';
//
//   final rc = context.rc;          // RiverColors — all design tokens
//   final cs = context.cs;          // ColorScheme  — Material tokens
//   final tt = context.tt;          // TextTheme    — text styles
//
// RiverColors.of(context) already falls back to the golden (dark) palette if
// no extension is registered, so rc is never null.
// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'river_theme.dart';

extension ThemeX on BuildContext {
  /// All per-mode design tokens (accent, cardBg, scaffoldBg, nav colours …)
  RiverColors get rc => RiverColors.of(this);

  /// Material 3 ColorScheme — use for standard Material widgets.
  ColorScheme get cs => Theme.of(this).colorScheme;

  /// Text theme.
  TextTheme get tt => Theme.of(this).textTheme;

  /// True when the active theme uses a dark scaffold background.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
