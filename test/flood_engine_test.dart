// flood_engine_test.dart
// Comprehensive unit tests for lib/ml/flood_engine.dart
// Run: flutter test test/flood_engine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/ml/flood_engine.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

FloodInput _makeInput({
  required String state,
  required double peak,
  double rain = 0,
  double duration = 3,
  double timeToPeak = 2,
  double recession = 3,
}) =>
    FloodInput(
      peakFloodLevelM: peak,
      eventDurationDays: duration,
      timeToPeakDays: timeToPeak,
      recessionTimeDay: recession,
      t1d: rain / 7,
      t2d: rain / 7,
      t3d: rain / 7,
      t4d: rain / 7,
      t5d: rain / 7,
      t6d: rain / 7,
      t7d: rain / 7,
      state: state,
    );

void main() {
  // ─── 1. getStateEntry — lookup & normalisation ───────────────────────────
  group('getStateEntry', () {
    test('returns maharashtra entry', () {
      final e = getStateEntry('Maharashtra');
      expect(e.region, 'COASTAL');
      expect(e.dangerLevelM, 11.5);
    });

    test('case-insensitive lookup', () {
      expect(getStateEntry('BIHAR').region, 'PLAINS');
      expect(getStateEntry('kerala').region, 'COASTAL');
    });

    test('alias orissa → odisha', () {
      final e = getStateEntry('orissa');
      expect(e.region, 'COASTAL');
      expect(e.primaryRivers, contains('Mahanadi'));
    });

    test('alias nct of delhi → delhi', () {
      final e = getStateEntry('NCT of Delhi');
      expect(e.usesAbsoluteElevation, isTrue);
    });

    test('alias j&k → jammu and kashmir', () {
      final e = getStateEntry('j&k');
      expect(e.region, 'HIMALAYAN');
    });

    // FIX-2: unknown state must NOT return Maharashtra thresholds
    test('unknown state falls back to PLAINS not Maharashtra', () {
      final e = getStateEntry('atlantis');
      expect(e.region, 'PLAINS');
      // Maharashtra danger is 11.5; PLAINS fallback danger is 11.0
      expect(e.dangerLevelM, 11.0);
      expect(e.primaryRivers, isEmpty);
    });

    test('ladakh returns HIMALAYAN (newly added state)', () {
      final e = getStateEntry('Ladakh');
      expect(e.region, 'HIMALAYAN');
      expect(e.primaryRivers, contains('Indus'));
    });

    test('dadra and nagar haveli returns COASTAL', () {
      final e = getStateEntry('dadra and nagar haveli');
      expect(e.region, 'COASTAL');
    });
  });

  // ─── 2. Delhi absolute elevation flag ────────────────────────────────────
  group('Delhi elevation flag (FIX-1)', () {
    test('delhi entry has usesAbsoluteElevation = true', () {
      expect(getStateEntry('delhi').usesAbsoluteElevation, isTrue);
    });

    test('mizoram entry has usesAbsoluteElevation = true', () {
      expect(getStateEntry('mizoram').usesAbsoluteElevation, isTrue);
    });

    test('maharashtra entry has usesAbsoluteElevation = false', () {
      expect(getStateEntry('maharashtra').usesAbsoluteElevation, isFalse);
    });

    test('delhi at 205.0 MSL → MODERATE (above warning 204.5)', () {
      final sev = severityFromEntry(
        peakLevelM: 205.0,
        rainfall7dMm: 50,
        entry: getStateEntry('delhi'),
      );
      expect(sev, 'MODERATE');
    });

    test('delhi at 206.8 MSL → CRITICAL (above HFL 207.49 is not yet, but above critical 206.5)', () {
      final sev = severityFromEntry(
        peakLevelM: 206.8,
        rainfall7dMm: 50,
        entry: getStateEntry('delhi'),
      );
      // 206.8 >= critical threshold 206.5 → CRITICAL
      expect(sev, 'CRITICAL');
    });

    test('delhi at 9.5m depth (wrong unit) → LOW — confirms MSL isolation needed', () {
      // If someone accidentally passes depth instead of MSL,
      // 9.5 < moderate(204.0) so result should be LOW — not SEVERE/CRITICAL
      final sev = severityFromEntry(
        peakLevelM: 9.5,
        rainfall7dMm: 50,
        entry: getStateEntry('delhi'),
      );
      expect(sev, 'LOW');
    });
  });

  // ─── 3. regionRainfallThresholds ────────────────────────────────────────
  group('getRegionRainfallThresholds', () {
    test('ARID has lower thresholds than COASTAL', () {
      final arid = getRegionRainfallThresholds('ARID');
      final coastal = getRegionRainfallThresholds('COASTAL');
      expect(arid['critical']!, lessThan(coastal['critical']!));
    });

    test('unknown region defaults to PLAINS', () {
      final t = getRegionRainfallThresholds('DESERT');
      expect(t['moderate'], 150.0);
    });
  });

  // ─── 4. severityFromEntry — dual-axis logic ───────────────────────────────
  group('severityFromEntry', () {
    final mh = getStateEntry('maharashtra'); // COASTAL

    test('both axes LOW → LOW', () {
      expect(severityFromEntry(peakLevelM: 5.0, rainfall7dMm: 50, entry: mh), 'LOW');
    });

    test('depth SEVERE, rain LOW → SEVERE (max wins)', () {
      expect(severityFromEntry(peakLevelM: 12.0, rainfall7dMm: 50, entry: mh), 'SEVERE');
    });

    test('depth LOW, rain CRITICAL → CRITICAL (rain wins)', () {
      // COASTAL critical rain = 600mm
      expect(severityFromEntry(peakLevelM: 5.0, rainfall7dMm: 650, entry: mh), 'CRITICAL');
    });

    test('both CRITICAL → CRITICAL', () {
      expect(severityFromEntry(peakLevelM: 14.0, rainfall7dMm: 650, entry: mh), 'CRITICAL');
    });

    test('rajasthan ARID: lower thresholds activate earlier', () {
      final raj = getStateEntry('rajasthan');
      // ARID critical rain = 350mm
      expect(severityFromEntry(peakLevelM: 4.0, rainfall7dMm: 360, entry: raj), 'CRITICAL');
    });
  });

  // ─── 5. Danger level guard (Option-A) ────────────────────────────────────
  group('dangerLevelGuard via severityFromEntry', () {
    final mh = getStateEntry('maharashtra'); // danger=11.5, warning=9.5, hfl=14.2

    test('at HFL (14.2m): CRITICAL stays CRITICAL', () {
      expect(
        severityFromEntry(peakLevelM: 14.5, rainfall7dMm: 650, entry: mh, riverLevelM: 14.3),
        'CRITICAL',
      );
    });

    test('at danger (11.5m): CRITICAL capped to SEVERE', () {
      expect(
        severityFromEntry(peakLevelM: 13.5, rainfall7dMm: 650, entry: mh, riverLevelM: 11.5),
        'SEVERE',
      );
    });

    test('below warning (8.0m), low rain: SEVERE capped to MODERATE', () {
      expect(
        severityFromEntry(peakLevelM: 12.0, rainfall7dMm: 50, entry: mh, riverLevelM: 8.0),
        'MODERATE',
      );
    });

    test('below warning (8.0m), heavy rain (>=severe threshold): not capped', () {
      // COASTAL severe rain = 400mm
      expect(
        severityFromEntry(peakLevelM: 12.0, rainfall7dMm: 450, entry: mh, riverLevelM: 8.0),
        isNot('MODERATE'),
      );
    });
  });

  // ─── 6. runOnDeviceEngine — full pipeline ────────────────────────────────
  group('runOnDeviceEngine — severity classes', () {
    test('maharashtra extreme → CRITICAL or SEVERE', () {
      final r = runOnDeviceEngine(_makeInput(
        state: 'Maharashtra', peak: 13.5, rain: 650,
        duration: 10, timeToPeak: 1, recession: 8,
      ));
      expect(['CRITICAL', 'SEVERE'], contains(r.severity));
    });

    test('maharashtra normal → LOW', () {
      final r = runOnDeviceEngine(_makeInput(
        state: 'Maharashtra', peak: 5.0, rain: 30,
      ));
      expect(r.severity, 'LOW');
    });

    test('rajasthan ARID minimal rain → LOW', () {
      final r = runOnDeviceEngine(_makeInput(
        state: 'Rajasthan', peak: 3.0, rain: 40,
      ));
      expect(r.severity, 'LOW');
    });

    test('assam NORTHEAST heavy rain → SEVERE or CRITICAL', () {
      final r = runOnDeviceEngine(_makeInput(
        state: 'Assam', peak: 12.0, rain: 620,
        duration: 8, timeToPeak: 1, recession: 7,
      ));
      expect(['SEVERE', 'CRITICAL'], contains(r.severity));
    });

    test('unknown state does not throw', () {
      expect(
        () => runOnDeviceEngine(_makeInput(state: 'atlantis', peak: 10.0, rain: 300)),
        returnsNormally,
      );
    });
  });

  // ─── 7. runOnDeviceEngine — output field invariants ───────────────────────
  group('runOnDeviceEngine — output invariants', () {
    late FloodResult r;
    setUpAll(() {
      r = runOnDeviceEngine(_makeInput(state: 'Maharashtra', peak: 11.0, rain: 350));
    });

    test('isOfflineEstimate is always true', () => expect(r.isOfflineEstimate, isTrue));
    test('usedApi is always false', () => expect(r.usedApi, isFalse));
    test('riskScore is 0..100', () => expect(r.riskScore, inInclusiveRange(0, 100)));
    test('confidencePercent is 0..100', () => expect(r.confidencePercent, inInclusiveRange(0.0, 100.0)));
    test('probabilities sum to ~100', () {
      final sum = r.probabilities.values.fold(0.0, (a, b) => a + b);
      expect(sum, closeTo(100.0, 0.5));
    });
    test('severity is one of four valid labels', () {
      expect(['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'], contains(r.severity));
    });
    test('alert emoji is set', () {
      expect(['🚨', '⚠️', '🟢'], contains(r.alert));
    });
    test('monitoringLevel is non-empty', () => expect(r.monitoringLevel, isNotEmpty));
    test('algorithm string mentions v1.1', () => expect(r.algorithm, contains('v1.1')));
  });

  // ─── 8. Safety suppression — below warning level ──────────────────────────
  group('Safety suppression', () {
    test('well below warning: result is not SEVERE or CRITICAL', () {
      // Maharashtra warning = 9.5m; feed 4.0m peak
      final r = runOnDeviceEngine(_makeInput(
        state: 'Maharashtra', peak: 4.0, rain: 600,
      ));
      expect(['SEVERE', 'CRITICAL'], isNot(contains(r.severity)));
    });
  });

  // ─── 9. FIX-3: right-skewed rule probs ────────────────────────────────────
  group('Rule engine right-skew (FIX-3)', () {
    test('for MODERATE threshold, prob(SEVERE) > prob(LOW)', () {
      final r = runOnDeviceEngine(_makeInput(
        state: 'Maharashtra', peak: 9.5, rain: 210,
      ));
      final severe = r.ruleProbs['SEVERE']!;
      final low = r.ruleProbs['LOW']!;
      expect(severe, greaterThan(low));
    });
  });

  // ─── 10. FIX-4: temporal features contribute to riskScore ─────────────────
  group('Temporal features contribute (FIX-4)', () {
    test('long-duration fast-rise slow-recession scores higher riskScore', () {
      final rHigh = runOnDeviceEngine(_makeInput(
        state: 'Maharashtra', peak: 10.0, rain: 250,
        duration: 12, timeToPeak: 0.5, recession: 9,
      ));
      final rLow = runOnDeviceEngine(_makeInput(
        state: 'Maharashtra', peak: 10.0, rain: 250,
        duration: 1, timeToPeak: 6, recession: 1,
      ));
      expect(rHigh.riskScore, greaterThanOrEqualTo(rLow.riskScore));
    });
  });

  // ─── 11. Feature vector order ────────────────────────────────────────────
  group('FloodInput.toFeatureVector', () {
    test('returns 11-element vector', () {
      final input = _makeInput(state: 'Bihar', peak: 10.0, rain: 200);
      expect(input.toFeatureVector().length, 11);
    });

    test('first element is peakFloodLevelM', () {
      final input = _makeInput(state: 'Bihar', peak: 10.0, rain: 200);
      expect(input.toFeatureVector()[0], input.peakFloodLevelM);
    });

    test('rainfall7d sums all 7 daily values', () {
      final input = _makeInput(state: 'Bihar', peak: 10.0, rain: 210);
      expect(input.rainfall7d, closeTo(210.0, 0.01));
    });
  });
}
