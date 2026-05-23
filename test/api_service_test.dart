// test/api_service_test.dart
//
// flutter_dotenv must be initialised before any code that calls
// dotenv.maybeGet() is executed.  Tests never run main(), so we
// call dotenv.testLoad() in setUpAll with hard-coded fallback
// values that mirror .env.example. This keeps tests hermetic —
// no .env file required on CI.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:equinox_flood/constants/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    // testLoad() initialises dotenv in-memory without reading any file.
    // Values here mirror .env.example — safe to commit.
    dotenv.testLoad(fileInput: '''
BASE_URL=https://opsflood.onrender.com
BACKUP_URL=
''');
  });

  group('AppConfig URL safety', () {
    test('baseUrl is non-empty and starts with https', () {
      expect(AppConfig.baseUrl, isNotEmpty);
      expect(AppConfig.baseUrl, startsWith('https://'));
    });

    test('backupBaseUrl is empty so candidate list has 1 entry', () {
      final candidates = [
        AppConfig.baseUrl,
        if (AppConfig.backupBaseUrl.isNotEmpty) AppConfig.backupBaseUrl,
      ];
      expect(candidates.length, 1,
          reason: 'Only baseUrl should be present when backupBaseUrl is empty');
    });

    test('backupBaseUrl is either empty or different from baseUrl', () {
      final base   = AppConfig.baseUrl;
      final backup = AppConfig.backupBaseUrl;
      expect(
        backup.isEmpty || backup != base,
        isTrue,
        reason: 'backupBaseUrl must not be identical to baseUrl',
      );
    });

    test('all API endpoints start with /', () {
      for (final ep in [
        AppConfig.healthEndpoint,
        AppConfig.liveTelemetryEndpoint,
        AppConfig.liveLevelsEndpoint,
        AppConfig.criticalAlertsEndpoint,
        AppConfig.predictLegacyEndpoint,
        AppConfig.weatherCurrentEndpoint,
        AppConfig.weatherForecastEndpoint,
      ]) {
        expect(ep, startsWith('/'), reason: 'endpoint must start with /: $ep');
      }
    });

    test('baseUrl + endpoint forms a valid URL', () {
      final url = Uri.tryParse(
        AppConfig.baseUrl + AppConfig.healthEndpoint,
      );
      expect(url, isNotNull);
      expect(url!.hasScheme, isTrue);
      expect(url.host, isNotEmpty);
    });
  });

  group('AppConfig polling config', () {
    test('pollingInterval is exactly 5 minutes', () {
      expect(AppConfig.pollingInterval, const Duration(minutes: 5));
    });

    test('maxRetries is between 1 and 10', () {
      expect(AppConfig.maxRetries, inInclusiveRange(1, 10));
    });
  });
}
