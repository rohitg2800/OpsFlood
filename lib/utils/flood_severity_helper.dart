// ─────────────────────────────────────────────────────────────────────────────
//  FloodSeverityHelper  —  Single source of truth for flood severity
//  Integrates with existing AppPalette from river_theme.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

/// Five-level severity scale used across all CWC stations.
enum FloodSeverity { normal, watch, warning, danger, extreme }

/// Trend direction for a station's water level over the last hour.
enum WaterLevelTrend { rising, falling, stable, unknown }

class FloodSeverityHelper {
  FloodSeverityHelper._();

  // ── Parse from raw string (API / CWC response) ──────────────────────────
  static FloodSeverity fromString(String? raw) {
    switch ((raw ?? '').toUpperCase().trim()) {
      case 'NORMAL':
      case 'SAFE':
        return FloodSeverity.normal;
      case 'WATCH':
        return FloodSeverity.watch;
      case 'WARNING':
      case 'WARN':
        return FloodSeverity.warning;
      case 'DANGER':
      case 'FLOOD':
        return FloodSeverity.danger;
      case 'EXTREME':
      case 'CRITICAL':
        return FloodSeverity.extreme;
      default:
        return FloodSeverity.normal;
    }
  }

  // ── Derive severity from water level vs thresholds ───────────────────────
  static FloodSeverity fromLevels({
    required double current,
    required double warningLevel,
    required double dangerLevel,
  }) {
    if (current >= dangerLevel * 1.15) return FloodSeverity.extreme;
    if (current >= dangerLevel)        return FloodSeverity.danger;
    if (current >= warningLevel)       return FloodSeverity.warning;
    if (current >= warningLevel * 0.9) return FloodSeverity.watch;
    return FloodSeverity.normal;
  }

  // ── Color ────────────────────────────────────────────────────────────────
  static Color color(FloodSeverity s) {
    switch (s) {
      case FloodSeverity.normal:  return AppPalette.safe;
      case FloodSeverity.watch:   return const Color(0xFFFFD700);
      case FloodSeverity.warning: return AppPalette.warning;
      case FloodSeverity.danger:  return AppPalette.danger;
      case FloodSeverity.extreme: return AppPalette.critical;
    }
  }

  static Color glowColor(FloodSeverity s) {
    switch (s) {
      case FloodSeverity.normal:  return AppPalette.safeGlow;
      case FloodSeverity.watch:   return const Color(0x28FFD700);
      case FloodSeverity.warning: return AppPalette.warnGlow;
      case FloodSeverity.danger:  return AppPalette.dangerGlow;
      case FloodSeverity.extreme: return AppPalette.critGlow;
    }
  }

  // ── Icon ─────────────────────────────────────────────────────────────────
  static IconData icon(FloodSeverity s) {
    switch (s) {
      case FloodSeverity.normal:  return Icons.check_circle_outline_rounded;
      case FloodSeverity.watch:   return Icons.visibility_rounded;
      case FloodSeverity.warning: return Icons.warning_amber_rounded;
      case FloodSeverity.danger:  return Icons.dangerous_rounded;
      case FloodSeverity.extreme: return Icons.crisis_alert_rounded;
    }
  }

  // ── Short label ──────────────────────────────────────────────────────────
  static String label(FloodSeverity s) {
    switch (s) {
      case FloodSeverity.normal:  return 'Normal';
      case FloodSeverity.watch:   return 'Watch';
      case FloodSeverity.warning: return 'Warning';
      case FloodSeverity.danger:  return 'Danger';
      case FloodSeverity.extreme: return 'Extreme';
    }
  }

  // ── Hindi label ──────────────────────────────────────────────────────────
  static String labelHindi(FloodSeverity s) {
    switch (s) {
      case FloodSeverity.normal:  return 'सामान्य';
      case FloodSeverity.watch:   return 'सतर्क';
      case FloodSeverity.warning: return 'चेतावनी';
      case FloodSeverity.danger:  return 'खतरा';
      case FloodSeverity.extreme: return 'अतिखतरा';
    }
  }

  // ── Background fill for cards (semi-transparent) ─────────────────────────
  static Color cardFill(FloodSeverity s) => color(s).withValues(alpha: 0.08);
  static Color cardBorder(FloodSeverity s) => color(s).withValues(alpha: 0.35);

  // ── Trend helpers ─────────────────────────────────────────────────────────
  static WaterLevelTrend trendFromDelta(double deltaMeters) {
    if (deltaMeters > 0.1)  return WaterLevelTrend.rising;
    if (deltaMeters < -0.1) return WaterLevelTrend.falling;
    return WaterLevelTrend.stable;
  }

  static IconData trendIcon(WaterLevelTrend t) {
    switch (t) {
      case WaterLevelTrend.rising:  return Icons.trending_up_rounded;
      case WaterLevelTrend.falling: return Icons.trending_down_rounded;
      case WaterLevelTrend.stable:  return Icons.trending_flat_rounded;
      case WaterLevelTrend.unknown: return Icons.remove_rounded;
    }
  }

  static Color trendColor(WaterLevelTrend t) {
    switch (t) {
      case WaterLevelTrend.rising:  return AppPalette.danger;
      case WaterLevelTrend.falling: return AppPalette.safe;
      case WaterLevelTrend.stable:  return AppPalette.textGrey;
      case WaterLevelTrend.unknown: return AppPalette.textDim;
    }
  }

  static String trendLabel(WaterLevelTrend t) {
    switch (t) {
      case WaterLevelTrend.rising:  return 'Rising';
      case WaterLevelTrend.falling: return 'Falling';
      case WaterLevelTrend.stable:  return 'Stable';
      case WaterLevelTrend.unknown: return '--';
    }
  }
}
