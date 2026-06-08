// lib/widgets/map/map_risk_helpers.dart
// Risk colour + label helpers shared across all map widgets.
import 'package:flutter/material.dart';
import '../../providers/map_command_provider.dart';

Color riskColor(DangerClass dc, {double opacity = 0.35}) {
  switch (dc) {
    case DangerClass.extreme:     return const Color(0xFFD32F2F).withOpacity(opacity);
    case DangerClass.severe:      return const Color(0xFFF57C00).withOpacity(opacity);
    case DangerClass.aboveNormal: return const Color(0xFFFBC02D).withOpacity(opacity);
    case DangerClass.normal:      return const Color(0xFF388E3C).withOpacity(opacity);
  }
}

Color riskColorSolid(DangerClass dc) => riskColor(dc, opacity: 1.0);

String riskLabel(DangerClass dc) {
  switch (dc) {
    case DangerClass.extreme:     return 'CRITICAL';
    case DangerClass.severe:      return 'HIGH';
    case DangerClass.aboveNormal: return 'MODERATE';
    case DangerClass.normal:      return 'LOW';
  }
}
