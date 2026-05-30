import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/station.dart';

class ApiService {
  // Change to your Render URL when deployed
  static const String _base = 'http://localhost:8000';

  static Future<List<Station>> getBiharStations() async {
    final uri = Uri.parse('$_base/api/stations?state=Bihar');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body);
    final list = body['data'] as List;
    return list.map((e) => Station.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Summary> getSummary() async {
    final uri = Uri.parse('$_base/api/summary');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body);
    return Summary.fromJson(body);
  }

  static Future<List<Station>> getDangerAlerts() async {
    final uri = Uri.parse('$_base/api/alerts/danger');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body);
    final list = body['data'] as List;
    return list.map((e) => Station.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Station>> getCriticalAlerts() async {
    final uri = Uri.parse('$_base/api/alerts');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body);
    final list = body['data'] as List;
    return list.map((e) => Station.fromJson(e as Map<String, dynamic>)).toList();
  }
}
