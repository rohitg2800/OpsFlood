// test/unit/alert_engine_test.dart
// OpsFlood — Module 10: Unit tests — Alert threshold crossing logic

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Pure-Dart threshold engine (mirrors AlertEngine in lib/services/)
// ---------------------------------------------------------------------------

enum Severity { normal, warning, danger, emergency }

Severity classifyLevel({
  required double level,
  required double warningLevel,
  required double dangerLevel,
  required double emergencyLevel,
}) {
  if (level >= emergencyLevel) return Severity.emergency;
  if (level >= dangerLevel)    return Severity.danger;
  if (level >= warningLevel)   return Severity.warning;
  return Severity.normal;
}

bool hasCrossedThreshold({
  required double previous,
  required double current,
  required double threshold,
}) => previous < threshold && current >= threshold;

double percentOfDanger(double level, double dangerLevel) =>
    dangerLevel == 0 ? 0 : (level / dangerLevel).clamp(0.0, 1.5);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('classifyLevel', () {
    const w = 48.0, d = 52.0, e = 56.0;

    test('returns normal below warning', () {
      expect(
          classifyLevel(
              level: 40.0,
              warningLevel: w,
              dangerLevel: d,
              emergencyLevel: e),
          Severity.normal);
    });

    test('returns warning at warning threshold', () {
      expect(
          classifyLevel(
              level: 48.0,
              warningLevel: w,
              dangerLevel: d,
              emergencyLevel: e),
          Severity.warning);
    });

    test('returns danger between danger and emergency', () {
      expect(
          classifyLevel(
              level: 54.0,
              warningLevel: w,
              dangerLevel: d,
              emergencyLevel: e),
          Severity.danger);
    });

    test('returns emergency at or above emergency level', () {
      expect(
          classifyLevel(
              level: 56.0,
              warningLevel: w,
              dangerLevel: d,
              emergencyLevel: e),
          Severity.emergency);
    });

    test('returns emergency well above emergency level', () {
      expect(
          classifyLevel(
              level: 65.0,
              warningLevel: w,
              dangerLevel: d,
              emergencyLevel: e),
          Severity.emergency);
    });
  });

  group('hasCrossedThreshold', () {
    test('detects upward crossing', () {
      expect(
          hasCrossedThreshold(
              previous: 49.9, current: 50.1, threshold: 50.0),
          isTrue);
    });

    test('no crossing when already above', () {
      expect(
          hasCrossedThreshold(
              previous: 51.0, current: 52.0, threshold: 50.0),
          isFalse);
    });

    test('no crossing when still below', () {
      expect(
          hasCrossedThreshold(
              previous: 48.0, current: 49.5, threshold: 50.0),
          isFalse);
    });

    test('no crossing on downward movement', () {
      expect(
          hasCrossedThreshold(
              previous: 51.0, current: 49.0, threshold: 50.0),
          isFalse);
    });
  });

  group('percentOfDanger', () {
    test('returns 0.5 at half danger level', () {
      expect(percentOfDanger(25.0, 50.0), closeTo(0.5, 0.001));
    });

    test('returns 1.0 at danger level', () {
      expect(percentOfDanger(50.0, 50.0), closeTo(1.0, 0.001));
    });

    test('clamps at 1.5 above danger', () {
      expect(percentOfDanger(100.0, 50.0), closeTo(1.5, 0.001));
    });

    test('returns 0 for zero danger level (guard)', () {
      expect(percentOfDanger(10.0, 0.0), equals(0.0));
    });
  });
}
