// lib/services/api_service.dart
// Legacy health-check wrapper — kept for backwards compatibility.
import 'package:http/http.dart' as http;
import '../config/app_config.dart';  // was: constants/app_constants.dart

class ApiService {
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse(AppConfig.baseUrl + '/health');  // AppConfig, not AppConstants
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
