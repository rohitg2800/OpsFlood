// test/api_service_test.dart
import 'package:equinox_flood/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiService retry-loop safety', () {
    test('backupBaseUrl is empty so _baseCandidates has 1 entry (no dead dupe)', () {
      final candidates = [
        AppConstants.baseUrl,
        if (AppConstants.backupBaseUrl.isNotEmpty) AppConstants.backupBaseUrl,
      ];
      expect(candidates.length, 1,
          reason: 'Only baseUrl should be present when backupBaseUrl is empty');
    });

    test('baseUrl and backupBaseUrl are different strings (or backup is empty)', () {
      final base   = AppConstants.baseUrl;
      final backup = AppConstants.backupBaseUrl;
      expect(
        backup.isEmpty || backup != base,
        isTrue,
        reason: 'backupBaseUrl must not be identical to baseUrl',
      );
    });
  });
}
