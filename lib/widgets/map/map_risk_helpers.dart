// lib/widgets/map/map_risk_helpers.dart
// Risk colour + label helpers shared across all map widgets.
// v1.1: riskLabel aligned with AlertSeverity / FloodData labels used
//       across the rest of the app (HIGH→SEVERE, MODERATE→WARNING).
import 'package:flutter/material.dart';
import '../../models/river_station.dart'; // DangerClass lives here

Color riskColor(DangerClass dc, {double opacity = 0.35}) {
  switch (dc) {
    case DangerClass.extreme:
      return const Color(0xFFD32F2F).withValues(alpha: opacity);
    case DangerClass.severe:
      return const Color(0xFFF57C00).withValues(alpha: opacity);
    case DangerClass.aboveNormal:
      return const Color(0xFFFBC02D).withValues(alpha: opacity);
    case DangerClass.normal:
      return const Color(0xFF388E3C).withValues(alpha: opacity);
  }
}

Color riskColorSolid(DangerClass dc) => riskColor(dc, opacity: 1.0);

/// Labels are kept in sync with AlertSeverity / FloodData.riskLevel so
/// users see the same terminology on every screen.
String riskLabel(DangerClass dc) {
  switch (dc) {
    case DangerClass.extreme:     return 'CRITICAL';
    case DangerClass.severe:      return 'SEVERE';    // was HIGH
    case DangerClass.aboveNormal: return 'WARNING';   // was MODERATE
    case DangerClass.normal:      return 'NORMAL';    // was LOW
  }
}
