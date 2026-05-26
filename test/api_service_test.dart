// test/api_service_test.dart
//
// AppConfig unit tests.
//
// AppConfig uses String/bool.fromEnvironment (dart-define) — NOT flutter_dotenv.
// No initialisation is required before tests; the compile-time constants
// resolve to their defaultValue in test mode automatically.
//
// Run: flutter test test/api_service_test.dart

import 'package:equinox_flood/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── URL safety ───────────────────────────────────────────────────────────
  group('AppConfig URL safety', () {
    test('baseUrl is non-empty and starts with https', () {
      expect(AppConfig.baseUrl, isNotEmpty);
      expect(AppConfig.baseUrl, startsWith('https://'));
    });

    test('baseUrl + epHealth forms a valid URI', () {
      final url = Uri.tryParse(AppConfig.baseUrl + AppConfig.epHealth);
      expect(url, isNotNull);
      expect(url!.hasScheme, isTrue);
      expect(url.host, isNotEmpty);
    });

    test('all API endpoints start with /', () {
      for (final ep in [
        AppConfig.epHealth,
        AppConfig.epPredict,
        AppConfig.epLiveTelemetry,
        AppConfig.epLiveLevels,
        AppConfig.epCriticalAlerts,
        AppConfig.epWeatherCurrent,
        AppConfig.epWeatherForecast,
        AppConfig.epNdmaAdvisories,
        AppConfig.epNdmaContacts,
      ]) {
        expect(ep, startsWith('/'), reason: 'endpoint must start with /: $ep');
      }
    });

    test('baseUrl + every endpoint forms a valid URI', () {
      for (final ep in [
        AppConfig.epHealth,
        AppConfig.epPredict,
        AppConfig.epLiveTelemetry,
        AppConfig.epLiveLevels,
        AppConfig.epCriticalAlerts,
        AppConfig.epWeatherCurrent,
        AppConfig.epWeatherForecast,
        AppConfig.epNdmaAdvisories,
        AppConfig.epNdmaContacts,
      ]) {
        final url = Uri.tryParse(AppConfig.baseUrl + ep);
        expect(url, isNotNull,
            reason: 'baseUrl + $ep must parse as a valid URI');
        expect(url!.hasScheme, isTrue);
        expect(url.host, isNotEmpty);
      }
    });
  });

  // ── Timeout config ──────────────────────────────────────────────────────────
  group('AppConfig timeout config', () {
    test('requestTimeout is positive and reasonable (5–60 s)', () {
      final secs = AppConfig.requestTimeout.inSeconds;
      expect(secs, inInclusiveRange(5, 60));
    });

    test('coldStartTimeout is longer than requestTimeout', () {
      expect(
        AppConfig.coldStartTimeout > AppConfig.requestTimeout,
        isTrue,
        reason: 'coldStartTimeout must exceed requestTimeout',
      );
    });

    test('healthTimeout is <= requestTimeout', () {
      expect(
        AppConfig.healthTimeout <= AppConfig.requestTimeout,
        isTrue,
        reason: 'healthTimeout must not exceed requestTimeout',
      );
    });
  });

  // ── Polling + retry config ───────────────────────────────────────────────
  group('AppConfig polling + retry', () {
    test('realtimeInterval is at least 10 seconds', () {
      expect(AppConfig.realtimeInterval.inSeconds, greaterThanOrEqualTo(10));
    });

    test('maxRetries is between 1 and 10', () {
      expect(AppConfig.maxRetries, inInclusiveRange(1, 10));
    });

    test('cacheTtl is positive', () {
      expect(AppConfig.cacheTtl.inSeconds, greaterThan(0));
    });

    test('backgroundInterval is at least 1 minute', () {
      expect(AppConfig.backgroundInterval.inMinutes, greaterThanOrEqualTo(1));
    });
  });

  // ── Environment defaults ─────────────────────────────────────────────────
  group('AppConfig environment defaults', () {
    test('env defaults to production in test mode', () {
      // dart-define not set in test runner → defaultValue kicks in
      expect(AppConfig.env, equals('production'));
      expect(AppConfig.isProduction, isTrue);
      expect(AppConfig.isDevelopment, isFalse);
    });

    test('apiToken defaults to empty string', () {
      expect(AppConfig.apiToken, isEmpty);
    });
  });
}
