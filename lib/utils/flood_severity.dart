// lib/utils/flood_severity.dart
// Resolves issue #9: FloodSeverityLevel enum + color/label helpers
// Golden Ops Design Language v6
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Primary enum used throughout the app
// ─────────────────────────────────────────────────────────────────────────────
enum FloodSeverity {
  normal,
  watch,
  warning,
  danger,
  extreme;

  // Legacy alias so state_matrix_screen.dart compiles without changes
  static const FloodSeverity critical = FloodSeverity.extreme;

  String get label {
    switch (this) {
      case FloodSeverity.normal:  return 'Normal';
      case FloodSeverity.watch:   return 'Watch';
      case FloodSeverity.warning: return 'Warning';
      case FloodSeverity.danger:  return 'Danger';
      case FloodSeverity.extreme: return 'Extreme';
    }
  }

  String get shortLabel {
    switch (this) {
      case FloodSeverity.normal:  return 'NRM';
      case FloodSeverity.watch:   return 'WCH';
      case FloodSeverity.warning: return 'WRN';
      case FloodSeverity.danger:  return 'DNG';
      case FloodSeverity.extreme: return 'EXT';
    }
  }

  Color get color {
    switch (this) {
      case FloodSeverity.normal:  return AppPalette.safe;
      case FloodSeverity.watch:   return AppPalette.cyan;
      case FloodSeverity.warning: return AppPalette.warning;
      case FloodSeverity.danger:  return AppPalette.danger;
      case FloodSeverity.extreme: return AppPalette.critical;
    }
  }

  Color get glowColor {
    switch (this) {
      case FloodSeverity.normal:  return AppPalette.safeGlow;
      case FloodSeverity.watch:   return AppPalette.cyanGlow;
      case FloodSeverity.warning: return AppPalette.warnGlow;
      case FloodSeverity.danger:  return AppPalette.dangerGlow;
      case FloodSeverity.extreme: return AppPalette.critGlow;
    }
  }

  bool get requiresAction => index >= FloodSeverity.warning.index;
  bool get isCritical     => index >= FloodSeverity.danger.index;

  static FloodSeverity fromLevel(double current, double warning, double danger) {
    if (current >= danger * 1.15) return FloodSeverity.extreme;
    if (current >= danger)        return FloodSeverity.danger;
    if (current >= warning * 1.1) return FloodSeverity.warning;
    if (current >= warning * 0.9) return FloodSeverity.watch;
    return FloodSeverity.normal;
  }

  static FloodSeverity fromString(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'NORMAL':   return FloodSeverity.normal;
      case 'WATCH':    return FloodSeverity.watch;
      case 'WARNING':  return FloodSeverity.warning;
      case 'DANGER':   return FloodSeverity.danger;
      case 'EXTREME':
      case 'CRITICAL': return FloodSeverity.extreme;
      default:         return FloodSeverity.normal;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodSeverityColor — static helper used by widgets
// ─────────────────────────────────────────────────────────────────────────────
class FloodSeverityColor {
  const FloodSeverityColor._();

  static Color forSeverity(FloodSeverity s) => s.color;
  static Color glowForSeverity(FloodSeverity s) => s.glowColor;

  static Color forLevel(double current, double warning, double danger) =>
      FloodSeverity.fromLevel(current, warning, danger).color;
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodSeverityLevel — backward-compat alias for old code
// ─────────────────────────────────────────────────────────────────────────────
typedef FloodSeverityLevel = FloodSeverity;
