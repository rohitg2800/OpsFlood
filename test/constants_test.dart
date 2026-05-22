// test/constants_test.dart
import 'package:equinox_flood/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConstants — threshold sanity', () {
    test('criticalThreshold > highThreshold > moderateThreshold', () {
      expect(AppConstants.criticalThreshold,
          greaterThan(AppConstants.highThreshold));
      expect(AppConstants.highThreshold,
          greaterThan(AppConstants.moderateThreshold));
    });

    test('defaultDangerLevel > defaultWarningLevel > defaultSafeLevel', () {
      expect(AppConstants.defaultDangerLevel,
          greaterThan(AppConstants.defaultWarningLevel));
      expect(AppConstants.defaultWarningLevel,
          greaterThan(AppConstants.defaultSafeLevel));
    });

    test('backupBaseUrl is empty string (no dummy duplicate)', () {
      expect(AppConstants.backupBaseUrl, isEmpty);
    });

    test('all monitoredCities have lat, lon, danger_level, warning_level', () {
      for (final city in AppConstants.monitoredCities) {
        final name = city['city']?.toString() ?? 'unknown';
        expect(city['lat'],           isNotNull, reason: '$name missing lat');
        expect(city['lon'],           isNotNull, reason: '$name missing lon');
        expect(city['danger_level'],  isNotNull, reason: '$name missing danger_level');
        expect(city['warning_level'], isNotNull, reason: '$name missing warning_level');
        expect(
          (city['danger_level'] as num).toDouble(),
          greaterThan((city['warning_level'] as num).toDouble()),
          reason: '$name: danger_level must exceed warning_level',
        );
      }
    });

    test('baseUrl is non-empty and starts with https', () {
      expect(AppConstants.baseUrl, isNotEmpty);
      expect(AppConstants.baseUrl, startsWith('https://'));
    });
  });
}
