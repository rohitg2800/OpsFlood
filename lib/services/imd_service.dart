// lib/services/imd_service.dart
// OpsFlood — ImdService stub (IMD weather alert fetcher)
library;

import 'package:flutter/foundation.dart';

class ImdService {
  ImdService._();
  static final ImdService instance = ImdService._();

  Future<List<Map<String, dynamic>>> fetchAlerts({String? state}) async {
    try {
      // TODO: implement real IMD API call
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('[ImdService] fetchAlerts error: $e');
      return [];
    }
  }
}
