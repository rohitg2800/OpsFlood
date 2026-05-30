import 'package:http/http.dart' as http;
import '../constants.dart';

class ApiService {
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
