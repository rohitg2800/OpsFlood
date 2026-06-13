// lib/models/flood_alert.dart
//
// OpsFlood — FloodAlert model
//
// A lightweight alert model used by the legacy screens that import
// '../models/flood_alert.dart'. It wraps the same severity vocabulary
// as ThresholdAlert / AlertLevel in threshold_alert.dart but lives
// separately so the import paths in the affected screens resolve without
// touching the existing model layer.

library;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertLevel
// ─────────────────────────────────────────────────────────────────────────────

enum AlertLevel {
  normal,
  warning,
  danger,
  extreme;

  bool get requiresEmergency =>
      this == AlertLevel.danger || this == AlertLevel.extreme;

  String get label {
    switch (this) {
      case AlertLevel.normal:  return 'Normal';
      case AlertLevel.warning: return 'Warning';
      case AlertLevel.danger:  return 'Danger';
      case AlertLevel.extreme: return 'Extreme';
    }
  }

  Color get color {
    switch (this) {
      case AlertLevel.normal:  return const Color(0xFF00E676);
      case AlertLevel.warning: return const Color(0xFFFFB300);
      case AlertLevel.danger:  return const Color(0xFFFF6D00);
      case AlertLevel.extreme: return const Color(0xFFFF1744);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodAlert
// ─────────────────────────────────────────────────────────────────────────────

class FloodAlert {
  const FloodAlert({
    required this.id,
    required this.station,
    required this.river,
    required this.district,
    required this.state,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.level,
    required this.issuedAt,
    this.message,
  });

  final String     id;
  final String     station;
  final String     river;
  final String     district;
  final String     state;
  final double     currentLevel;
  final double     dangerLevel;
  final double     warningLevel;
  final AlertLevel level;
  final DateTime   issuedAt;
  final String?    message;

  /// How far the current level is above the relevant threshold (metres).
  double get breach {
    if (level == AlertLevel.danger || level == AlertLevel.extreme) {
      return currentLevel - dangerLevel;
    }
    return currentLevel - warningLevel;
  }

  bool get isDanger  => level == AlertLevel.danger || level == AlertLevel.extreme;
  bool get isWarning => level == AlertLevel.warning;

  @override
  String toString() =>
      'FloodAlert($station · ${level.label} · ${currentLevel.toStringAsFixed(2)} m)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloodAlert && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
