import 'package:flutter/material.dart';

/// Single source of truth for all flood severity levels and colors.
/// Resolves issue #9: Better Color Coding System for Flood Severity
enum FloodSeverityLevel {
  normal,
  watch,
  warning,
  danger,
  extreme,
  offline,
}

extension FloodSeverityLevelExtension on FloodSeverityLevel {
  String get label {
    switch (this) {
      case FloodSeverityLevel.normal:
        return 'Normal';
      case FloodSeverityLevel.watch:
        return 'Watch';
      case FloodSeverityLevel.warning:
        return 'Warning';
      case FloodSeverityLevel.danger:
        return 'Danger';
      case FloodSeverityLevel.extreme:
        return 'Extreme';
      case FloodSeverityLevel.offline:
        return 'Offline';
    }
  }

  String get labelHindi {
    switch (this) {
      case FloodSeverityLevel.normal:
        return 'सामान्य';
      case FloodSeverityLevel.watch:
        return 'सतर्क';
      case FloodSeverityLevel.warning:
        return 'चेतावनी';
      case FloodSeverityLevel.danger:
        return 'खतरा';
      case FloodSeverityLevel.extreme:
        return 'अत्यंत खतरा';
      case FloodSeverityLevel.offline:
        return 'ऑफलाइन';
    }
  }

  Color get color => FloodSeverityColor.colorFor(this);
  Color get lightColor => FloodSeverityColor.lightColorFor(this);
  IconData get icon => FloodSeverityColor.iconFor(this);

  /// Returns severity from API string value
  static FloodSeverityLevel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'normal':
        return FloodSeverityLevel.normal;
      case 'watch':
        return FloodSeverityLevel.watch;
      case 'warning':
        return FloodSeverityLevel.warning;
      case 'danger':
        return FloodSeverityLevel.danger;
      case 'extreme':
        return FloodSeverityLevel.extreme;
      case 'offline':
        return FloodSeverityLevel.offline;
      default:
        return FloodSeverityLevel.normal;
    }
  }
}

class FloodSeverityColor {
  FloodSeverityColor._();

  static const Color normal = Color(0xFF4CAF50);
  static const Color watch = Color(0xFFFFC107);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFF44336);
  static const Color extreme = Color(0xFFB71C1C);
  static const Color offline = Color(0xFF9E9E9E);

  static Color colorFor(FloodSeverityLevel level) {
    switch (level) {
      case FloodSeverityLevel.normal:
        return normal;
      case FloodSeverityLevel.watch:
        return watch;
      case FloodSeverityLevel.warning:
        return warning;
      case FloodSeverityLevel.danger:
        return danger;
      case FloodSeverityLevel.extreme:
        return extreme;
      case FloodSeverityLevel.offline:
        return offline;
    }
  }

  static Color lightColorFor(FloodSeverityLevel level) {
    return colorFor(level).withOpacity(0.15);
  }

  static IconData iconFor(FloodSeverityLevel level) {
    switch (level) {
      case FloodSeverityLevel.normal:
        return Icons.check_circle_outline;
      case FloodSeverityLevel.watch:
        return Icons.visibility_outlined;
      case FloodSeverityLevel.warning:
        return Icons.warning_amber_outlined;
      case FloodSeverityLevel.danger:
        return Icons.dangerous_outlined;
      case FloodSeverityLevel.extreme:
        return Icons.crisis_alert;
      case FloodSeverityLevel.offline:
        return Icons.signal_wifi_off_outlined;
    }
  }
}

/// Reusable severity badge widget
class SeverityBadge extends StatelessWidget {
  final FloodSeverityLevel level;
  final bool compact;

  const SeverityBadge({super.key, required this.level, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: level.lightColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: level.color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: compact ? 10 : 13, color: level.color),
          const SizedBox(width: 4),
          Text(
            level.label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              color: level.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Severity legend for map and dashboard
class SeverityLegend extends StatelessWidget {
  const SeverityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flood Severity',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ...FloodSeverityLevel.values
                .where((l) => l != FloodSeverityLevel.offline)
                .map(
                  (l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: l.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(l.label,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
