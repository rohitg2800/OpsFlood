// lib/models/threshold_alert.dart
//
// OpsFlood — River basin threshold alert data model.
// Represents a single evaluated breach event at one gauge station.
library;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Alert severity levels — ordered low → critical
// ─────────────────────────────────────────────────────────────────────────────
enum AlertLevel {
  normal,    // below warning level
  watch,     // approaching warning (within 20 % of WL gap)
  warning,   // at or above warning level
  danger,    // at or above danger level
  extreme,   // at or above HFL (record broken / near-record)
}

extension AlertLevelX on AlertLevel {
  String get label => switch (this) {
    AlertLevel.normal  => 'Normal',
    AlertLevel.watch   => 'Watch',
    AlertLevel.warning => 'Warning',
    AlertLevel.danger  => 'Danger',
    AlertLevel.extreme => 'Extreme',
  };

  Color get color => switch (this) {
    AlertLevel.normal  => const Color(0xFF4CAF50), // green
    AlertLevel.watch   => const Color(0xFFFFEB3B), // yellow
    AlertLevel.warning => const Color(0xFFFF9800), // orange
    AlertLevel.danger  => const Color(0xFFF44336), // red
    AlertLevel.extreme => const Color(0xFF9C27B0), // purple
  };

  IconData get icon => switch (this) {
    AlertLevel.normal  => Icons.check_circle_outline,
    AlertLevel.watch   => Icons.remove_red_eye_outlined,
    AlertLevel.warning => Icons.warning_amber_rounded,
    AlertLevel.danger  => Icons.dangerous_outlined,
    AlertLevel.extreme => Icons.crisis_alert,
  };

  bool get requiresPush => index >= AlertLevel.warning.index;
  bool get requiresEmergency => index >= AlertLevel.danger.index;
}

// ─────────────────────────────────────────────────────────────────────────────
// A single threshold breach event
// ─────────────────────────────────────────────────────────────────────────────
class ThresholdAlert {
  final String  id;            // unique: '${cityId}_${level.name}_${timestamp.millisecondsSinceEpoch}'
  final String  cityId;        // matches IndiaCity.id or BiharGauge station id
  final String  cityName;
  final String  state;
  final String  river;
  final AlertLevel level;

  // Gauge values (m MSL or m³/s from GloFAS)
  final double  currentValue;  // latest observed/forecast value
  final double  warningLevel;
  final double  dangerLevel;
  final double  hfl;

  /// How far above the active threshold (positive = breach, negative = margin).
  final double  breachMargin;

  /// % of gap between warning and danger that is filled.
  final double  fillPercent;  // 0–100+

  /// Whether this is discharge (m³/s) or gauge height (m MSL)
  final bool    isDischarge;

  final DateTime timestamp;
  final bool    isNew;         // not yet seen by user

  // Trend from previous poll
  final double?  previousValue;
  final TrendDirection trend;

  const ThresholdAlert({
    required this.id,
    required this.cityId,
    required this.cityName,
    required this.state,
    required this.river,
    required this.level,
    required this.currentValue,
    required this.warningLevel,
    required this.dangerLevel,
    required this.hfl,
    required this.breachMargin,
    required this.fillPercent,
    required this.timestamp,
    this.isDischarge = false,
    this.isNew = true,
    this.previousValue,
    this.trend = TrendDirection.steady,
  });

  ThresholdAlert copyWith({bool? isNew}) => ThresholdAlert(
    id: id, cityId: cityId, cityName: cityName, state: state, river: river,
    level: level, currentValue: currentValue, warningLevel: warningLevel,
    dangerLevel: dangerLevel, hfl: hfl, breachMargin: breachMargin,
    fillPercent: fillPercent, timestamp: timestamp, isDischarge: isDischarge,
    isNew: isNew ?? this.isNew,
    previousValue: previousValue, trend: trend,
  );

  String get unitLabel => isDischarge ? 'm³/s' : 'm';

  String get summaryLine {
    final sign = breachMargin >= 0 ? '+' : '';
    return '$cityName · ${river} · ${currentValue.toStringAsFixed(2)} $unitLabel '
        '(${sign}${breachMargin.toStringAsFixed(2)} vs ${level.label})';
  }

  @override
  String toString() => 'ThresholdAlert($id, ${level.label}, $summaryLine)';
}

enum TrendDirection { rising, steady, falling }

extension TrendDirectionX on TrendDirection {
  IconData get icon => switch (this) {
    TrendDirection.rising  => Icons.trending_up,
    TrendDirection.steady  => Icons.trending_flat,
    TrendDirection.falling => Icons.trending_down,
  };
  Color get color => switch (this) {
    TrendDirection.rising  => const Color(0xFFF44336),
    TrendDirection.steady  => const Color(0xFF9E9E9E),
    TrendDirection.falling => const Color(0xFF4CAF50),
  };
}
